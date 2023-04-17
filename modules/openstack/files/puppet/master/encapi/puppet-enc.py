#!/usr/bin/env python3
# ^ above line exists purely to make Jenkins test this using Python 3
import json
import re
from typing import Dict, List, Optional, Tuple

import pymysql
import yaml
from flask import Flask, Response, abort, g, has_request_context, jsonify, request
from flask_keystone import FlaskKeystone, current_user
from flask_oslolog import OsloLog
from oslo_config import cfg
from oslo_context import context
from oslo_policy import policy
from werkzeug.exceptions import HTTPException

cfgGroup = cfg.OptGroup("enc")
opts = [
    cfg.StrOpt("mysql_host"),
    cfg.StrOpt("mysql_db"),
    cfg.StrOpt("mysql_username", secret=True),
    cfg.StrOpt("mysql_password"),
    cfg.StrOpt("git_repository_path"),
    cfg.StrOpt("git_repository_url"),
    cfg.StrOpt("git_keyholder_key"),
]

key = FlaskKeystone()
log = OsloLog()

cfg.CONF.register_group(cfgGroup)
cfg.CONF.register_opts(opts, group=cfgGroup)

cfg.CONF(default_config_files=["/etc/puppet-enc-api/config.ini"])

enforcer = policy.Enforcer(cfg.CONF)
enforcer.register_defaults(
    [
        policy.RuleDefault("admin", "role:admin"),
        policy.RuleDefault("admin_or_member", "rule:admin or role:member"),
        policy.RuleDefault("prefix:index", ""),
        policy.RuleDefault("prefix:view", ""),
        policy.RuleDefault("prefix:create", "rule:admin_or_member"),
        policy.RuleDefault("prefix:update", "rule:admin_or_member"),
        policy.RuleDefault("prefix:delete", "rule:admin_or_member"),
        policy.RuleDefault("project:index", ""),
        policy.RuleDefault("puppetrole:index", ""),
        policy.RuleDefault("puppetrole:view", ""),
    ]
)

app = Flask(__name__)


key.init_app(app)
log.init_app(app)


def _preprocess_prefix(prefix):
    """
    Preprocess prefixes to provide some convenience features

    - Take a single _ to mean empty. The empty prefix applies to all
      instances in a project, and this makes it easier than trying
      to have an empty url segment
    """
    if prefix == "_":
        return ""

    # If the VM thinks it's under .eqiad.wmflabs, give it
    #  a .eqiad1.wikimedia.cloud config anyway.
    prefix = re.sub(r"\.eqiad\.wmflabs$", ".eqiad1.wikimedia.cloud", prefix)

    return prefix


def _format_prefix(prefix: str) -> str:
    """
    Does the opposite of _preprocess_prefix so that the API callers
    have a consistent view.
    """
    if prefix == "":
        return "_"
    return prefix


def dump_with_requested_format(data):
    """Returns the given data in the format specified in the Accept header."""
    accept = request.headers.get("Accept", "")

    if "application/json" in accept:
        return jsonify(data)

    if "application/x-yaml" in accept:
        return Response(yaml.safe_dump(data), mimetype="application/x-yaml")

    return abort(400, f"unsupported Accept header: {accept}")


class EncException(HTTPException):
    def get_headers(self, environ, scope: Optional[dict]) -> List[Tuple[str, str]]:
        return [("Content-Type", "application/json; charset=utf-8")]

    def get_body(self, environ, scope) -> str:
        error_msg = f"{self.code} {self.name}"
        if self.description:
            error_msg += f" {self.description}"

        return json.dumps({"error": error_msg})


class Forbidden(EncException):
    code = 403
    description = "Forbidden."


def enforce_policy(rule: str, project_id: Optional[str]):
    # headers in a specific format that oslo.context wants
    headers = {
        "HTTP_{}".format(name.upper().replace("-", "_")): value
        for name, value in request.headers.items()
    }

    ctx = context.RequestContext.from_environ(headers)

    if project_id:
        # if the project in the url is for a different project than what
        # the keystone token is, error out early.
        if ctx.project_id != project_id:
            log.logger.warning(
                "Encountered project id %s but keystone token was for project %s",
                project_id,
                ctx.project_id,
            )
            raise Forbidden("Invalid project id.")

    log.logger.info(
        "Enforcing policy %s for user %s (%s) and project %s",
        rule,
        ctx.user_id,
        ", ".join(ctx.roles),
        project_id,
    )

    scope = {"project_id": project_id} if project_id else {}

    enforcer.authorize(
        rule,
        scope,
        ctx,
        do_raise=True,
        exc=Forbidden,
    )


def should_edit_git():
    """Checks if Git should be updated for these changes."""
    if not has_request_context():
        return True
    return request.headers.get("X-Enc-Edit-Git", "true") != "false"


def get_git_author() -> str:
    return current_user.user_id


def get_git_path(project: str, path: str, extension: str) -> str:
    if path == "":
        path = "_"
    return f"{project}/{path}.{extension}"


def add_git_commit(*, cursor, files: Dict[str, Optional[str]], message: str):
    if not should_edit_git():
        return

    author = get_git_author()
    cursor.execute(
        """
        INSERT INTO git_update_queue_commit (guqc_author_user, guqc_commit_message)
        VALUES (%s, %s)
        """,
        (author, message),
    )

    commit_id = cursor.lastrowid

    for file_path, file_content in files.items():
        cursor.execute(
            """
            INSERT INTO git_update_queue_file (guqf_commit, guqf_file_path, guqf_new_content)
            VALUES (%s, %s, %s)
            """,
            (commit_id, file_path, file_content),
        )


@app.before_request
def before_request():
    g.db = pymysql.connect(
        host=cfg.CONF.enc.mysql_host,
        db=cfg.CONF.enc.mysql_db,
        user=cfg.CONF.enc.mysql_username,
        passwd=cfg.CONF.enc.mysql_password,
        charset="utf8",
    )


@app.teardown_request
def teardown_request(exception):
    db = getattr(g, "db", None)
    if db is not None:
        db.close()


@app.route("/v1/<string:project>/prefix/<string:prefix>/roles", methods=["GET"])
@key.login_required
def get_roles(project, prefix):
    enforce_policy("prefix:view", project)
    prefix = _preprocess_prefix(prefix)
    cur = g.db.cursor()
    try:
        cur.execute(
            """
                SELECT roleassignment.role FROM prefix, roleassignment
                WHERE prefix.project = %s AND prefix.prefix = %s AND
                    prefix.id = roleassignment.prefix_id
            """,
            (project, prefix),
        )
        roles = [r[0] for r in cur.fetchall()]

        if len(roles) == 0:
            return dump_with_requested_format({"error": "notfound"}), 404
        return dump_with_requested_format({"roles": roles})
    finally:
        cur.close()


@app.route("/v1/roles", methods=["GET"])
@key.login_required
def get_all_roles():
    enforce_policy("puppetrole:index", None)
    cur = g.db.cursor()
    try:
        cur.execute("SELECT distinct roleassignment.role FROM roleassignment")
        roles = [r[0] for r in cur.fetchall()]
        if len(roles) == 0:
            return dump_with_requested_format({"error": "notfound"}), 404
        return dump_with_requested_format({"roles": roles})
    finally:
        cur.close()


@app.route("/v1/projects", methods=["GET"])
@key.login_required
def get_all_projects():
    enforce_policy("project:index", None)
    cur = g.db.cursor()
    try:
        cur.execute("SELECT distinct prefix.project FROM prefix")
        projects = [r[0] for r in cur.fetchall()]
        if len(projects) == 0:
            return dump_with_requested_format({"error": "notfound"}), 404
        return dump_with_requested_format({"projects": projects})
    finally:
        cur.close()


@app.route("/v1/<string:project>/prefix/<string:prefix>/roles", methods=["POST"])
@key.login_required
def set_roles(project, prefix):
    enforce_policy("prefix:update", project)

    prefix = _preprocess_prefix(prefix)
    try:
        roles = yaml.safe_load(request.data)
    except yaml.YAMLError:
        return (
            dump_with_requested_format(
                {
                    "error": "Unable to parse input provided as YAML",
                }
            ),
            400,
        )

    if type(roles) is not list:
        return (
            dump_with_requested_format({"error": "Provided YAML should be a list"}),
            400,
        )

    # TODO: Add more validation for roles?
    cur = g.db.cursor()
    try:
        g.db.begin()
        # Create this prefix if it does not exist yet!
        # This monstrosity because http://stackoverflow.com/a/779252
        cur.execute(
            """
                INSERT INTO prefix (project, prefix) VALUES (%s, %s)
                ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id)
            """,
            (project, prefix),
        )
        prefix_id = cur.lastrowid
        # We delete all the role associations for this prefix and then
        # re-insert the ones we have. This causes churn in the roleassignment
        # tables, but seems cleaner than the alternatives.
        cur.execute(
            "DELETE FROM roleassignment WHERE prefix_id = %s",
            (prefix_id,),
        )
        # Add the new ones!
        cur.executemany(
            "INSERT INTO roleassignment (prefix_id, role) VALUES (%s, %s)",
            [(prefix_id, role) for role in roles],
        )

        add_git_commit(
            cursor=cur,
            files={get_git_path(project, prefix, "roles"): request.data},
            message=f"Update roles for {project} {prefix}",
        )

        g.db.commit()
    finally:
        cur.close()

    return dump_with_requested_format({"status": "ok"})


@app.route("/v1/<string:project>/prefix/<string:prefix>/hiera", methods=["GET"])
@key.login_required
def get_hiera(project, prefix):
    enforce_policy("prefix:view", project)
    prefix = _preprocess_prefix(prefix)
    cur = g.db.cursor()
    try:
        cur.execute(
            """
            SELECT hieraassignment.hiera_data FROM prefix, hieraassignment
            WHERE prefix.project = %s AND prefix.prefix = %s AND
                  prefix.id = hieraassignment.prefix_id
        """,
            (project, prefix),
        )
        row = cur.fetchone()
        if row is None:
            return dump_with_requested_format({"error": "notfound"}), 404

        return dump_with_requested_format({"hiera": row[0]})
    finally:
        cur.close()


@app.route("/v1/<string:project>/prefix/<string:prefix>/hiera", methods=["POST"])
@key.login_required
def set_hiera(project, prefix):
    enforce_policy("prefix:update", project)

    prefix = _preprocess_prefix(prefix)
    try:
        hiera = yaml.safe_load(request.data)
    except yaml.YAMLError:
        return (
            dump_with_requested_format(
                {
                    "error": "Unable to parse input provided as YAML",
                }
            ),
            400,
        )

    if type(hiera) is not dict:
        return (
            dump_with_requested_format(
                {
                    "error": "Provided YAML should be a dictionary",
                }
            ),
            400,
        )

    # TODO: Add more validation for hiera?
    cur = g.db.cursor()
    try:
        g.db.begin()
        # Create this prefix if it does not exist yet!
        # This monstrosity because http://stackoverflow.com/a/779252
        cur.execute(
            """
                INSERT INTO prefix (project, prefix) VALUES (%s, %s)
                ON DUPLICATE KEY UPDATE id=LAST_INSERT_ID(id)
            """,
            (project, prefix),
        )
        prefix_id = cur.lastrowid
        # Add the new ones!
        cur.execute(
            """
                INSERT INTO hieraassignment (prefix_id, hiera_data) VALUES (%s, %s)
                ON DUPLICATE KEY UPDATE hiera_data=%s
            """,
            (prefix_id, request.data, request.data),
        )

        add_git_commit(
            cursor=cur,
            files={get_git_path(project, prefix, "yaml"): request.data},
            message=f"Update Hiera for {project} {prefix}",
        )

        g.db.commit()
    finally:
        cur.close()

    return dump_with_requested_format({"status": "ok"})


# No @key.login_required, since this one is queried by Puppetmasters
@app.route("/v1/<string:project>/node/<string:fqdn>", methods=["GET"])
def get_node_config(project, fqdn):
    # If the VM thinks it's under .eqiad.wmflabs, give it
    #  a .eqiad1.wikimedia.cloud config anyway.
    fqdn = re.sub(r"\.eqiad\.wmflabs$", ".eqiad1.wikimedia.cloud", fqdn)

    cur = g.db.cursor()
    roles = []
    try:
        cur.execute(
            """
                SELECT role
                FROM roleassignment
                WHERE prefix_id in (
                    SELECT id
                    FROM prefix
                    WHERE project = %s
                    AND %s LIKE CONCAT(prefix, '%%')
                )
            """,
            (project, fqdn),
        )
        for row in cur.fetchall():
            roles.append(row[0])

        cur.execute(
            """
                SELECT prefix, hiera_data
                FROM prefix, hieraassignment
                WHERE prefix_id in (
                    SELECT id
                    FROM prefix
                    WHERE project = %s
                    AND %s LIKE CONCAT(prefix, '%%')
                ) AND prefix.id = prefix_id
                ORDER BY CHAR_LENGTH(prefix)
            """,
            (project, fqdn),
        )
        hiera = {}
        for row in cur.fetchall():
            hiera.update(yaml.safe_load(row[1]))
    finally:
        cur.close()

    # this is only queried by Puppet, and explicitely only returns yaml
    return Response(
        yaml.safe_dump({"roles": roles, "hiera": hiera}),
        status=200,
        mimetype="application/x-yaml",
    )


@app.route("/v1/<string:project>/prefix", methods=["GET"])
@key.login_required
def get_prefixes(project):
    enforce_policy("prefix:index", project)
    cur = g.db.cursor()
    try:
        cur.execute(
            "SELECT id, prefix FROM prefix WHERE project = %s",
            (project,),
        )

        if "detailed" in request.args:
            data = {
                "prefixes": [{"id": r[0], "prefix": _format_prefix(r[1])} for r in cur.fetchall()]
            }
        else:
            data = {"prefixes": [_format_prefix(r[1]) for r in cur.fetchall()]}

        return dump_with_requested_format(data)
    finally:
        cur.close()


@app.route("/v1/<string:project>/prefix", methods=["POST"])
@key.login_required
def create_prefix(project: str):
    enforce_policy("prefix:create", project)

    prefix = _preprocess_prefix(request.json["prefix"])

    with g.db.cursor() as cur:
        g.db.begin()

        try:
            cur.execute(
                "INSERT INTO prefix (project, prefix) VALUES (%s, %s)",
                (project, prefix),
            )
        except pymysql.err.IntegrityError:
            return dump_with_requested_format({"error": "prefix already exists"}), 400

        prefix_id = cur.lastrowid

        g.db.commit()

    return dump_with_requested_format(
        {
            "id": prefix_id,
            "prefix": _format_prefix(prefix),
            "hiera": {},
            "roles": [],
        }
    )


@app.route("/v1/<string:project>/prefix/id/<int:prefix_id>", methods=["GET"])
@key.login_required
def get_prefix_by_id(project: str, prefix_id: int):
    enforce_policy("prefix:view", project)

    with g.db.cursor() as cur:
        cur.execute(
            """
                SELECT prefix.id, prefix.prefix, hieraassignment.hiera_data
                FROM prefix
                LEFT JOIN hieraassignment ON hieraassignment.prefix_id = prefix.id
                WHERE prefix.id = %s AND prefix.project = %s
            """,
            (prefix_id, project),
        )

        result = cur.fetchone()

        if not result:
            return dump_with_requested_format({"error": "notfound"}), 404

        cur.execute("SELECT role FROM roleassignment WHERE prefix_id = %s", (prefix_id,))
        roles = [r[0] for r in cur.fetchall()]

        data = {
            "id": result[0],
            "prefix": _format_prefix(result[1]),
            "hiera": yaml.safe_load(result[2]) if result[2] else {},
            "roles": sorted(roles),
        }

    return dump_with_requested_format(data)


@app.route("/v1/<string:project>/prefix/id/<int:prefix_id>", methods=["PUT"])
@key.login_required
def update_prefix_by_id(project: str, prefix_id: int):
    enforce_policy("prefix:update", project)

    with g.db.cursor() as cur:
        cur.execute(
            """
                SELECT prefix.id, prefix.prefix, hieraassignment.hiera_data
                FROM prefix
                LEFT JOIN hieraassignment ON hieraassignment.prefix_id = prefix.id
                WHERE prefix.id = %s AND prefix.project = %s
            """,
            (prefix_id, project),
        )

        result = cur.fetchone()

        if not result:
            return dump_with_requested_format({"error": "notfound"}), 404

        prefix = result[1]

        cur.execute("SELECT role FROM roleassignment WHERE prefix_id = %s", (prefix_id,))
        current_roles = [r[0] for r in cur.fetchall()]

        g.db.begin()

        git_update = {}

        if "hiera" in request.json:
            hiera = request.json["hiera"]

            if type(hiera) is not dict:
                return (
                    dump_with_requested_format(
                        {
                            "error": "Provided YAML should be a dictionary",
                        }
                    ),
                    400,
                )

            hiera_str = yaml.safe_dump(hiera)
            cur.execute(
                """
                    INSERT INTO hieraassignment (prefix_id, hiera_data) VALUES (%s, %s)
                    ON DUPLICATE KEY UPDATE hiera_data = %s
                """,
                (prefix_id, hiera_str, hiera_str),
            )

            git_update.update({get_git_path(project, prefix, "yaml"): hiera_str})
        else:
            hiera = yaml.safe_load(result[2]) if result[2] else {}

        if "roles" in request.json:
            roles = request.json["roles"]

            to_remove = set(current_roles) - set(roles)
            to_add = set(roles) - set(current_roles)

            if len(to_remove) > 0:
                cur.execute(
                    "DELETE FROM roleassignment WHERE prefix_id = %s AND role IN %s",
                    (prefix_id, to_remove),
                )

            if len(to_add) > 0:
                cur.executemany(
                    "INSERT INTO roleassignment (prefix_id, role) VALUES (%s, %s)",
                    [(prefix_id, role) for role in to_add],
                )

            git_update.update(
                {get_git_path(project, prefix, "roles"): yaml.safe_dump(roles) if roles else None}
            )
        else:
            roles = current_roles

        add_git_commit(
            cursor=cur,
            files=git_update,
            message=request.json.get("message", f"Updating {project} {prefix}"),
        )

        g.db.commit()

        data = {
            "id": prefix_id,
            "prefix": _format_prefix(prefix),
            "hiera": hiera,
            "roles": sorted(roles),
        }

    return dump_with_requested_format(data)


@app.route("/v1/<string:project>/prefix/<string:role>", methods=["GET"])
@key.login_required
def get_prefixes_for_project_and_role(project, role):
    enforce_policy("prefix:index", project)
    cur = g.db.cursor()
    try:
        cur.execute(
            """
                SELECT prefix.prefix FROM prefix, roleassignment
                WHERE prefix.project = %s AND
                    roleassignment.role = %s AND
                    prefix.id = roleassignment.prefix_id
            """,
            (project, role),
        )
        # Do the inverse of _preprocess_prefix, so callers get a consistent view
        return dump_with_requested_format(
            {"prefixes": ["_" if r[0] == b"" or r[0] == "" else r[0] for r in cur.fetchall()]}
        )
    finally:
        cur.close()


@app.route("/v1/prefix/<string:role>", methods=["GET"])
@key.login_required
def get_prefixes_for_role(role):
    enforce_policy("puppetrole:view", None)
    cur = g.db.cursor()
    try:
        cur.execute(
            """
                SELECT prefix.project, prefix.prefix FROM prefix, roleassignment
                WHERE roleassignment.role = %s AND
                      prefix.id = roleassignment.prefix_id
            """,
            (role),
        )
        # Return a list of project dicts with '_' meaning 'everything':
        rdict = {}
        for r in cur.fetchall():
            project = r[0]
            prefix = r[1]
            if project not in rdict:
                rdict[project] = {"prefixes": []}
            rdict[project]["prefixes"].append("_" if prefix == b"" or prefix == "" else r[1])

        return dump_with_requested_format(rdict)
    finally:
        cur.close()


@app.route("/v1/<string:project>/prefix/<string:prefix>", methods=["DELETE"])
@key.login_required
def delete_prefix(project, prefix):
    enforce_policy("prefix:delete", project)

    prefix = _preprocess_prefix(prefix)
    cur = g.db.cursor()
    try:
        cur.execute(
            "SELECT id  FROM prefix WHERE project = %s and prefix = %s",
            (project, prefix),
        )
        row = cur.fetchone()

        if not row:
            return dump_with_requested_format({"error": "notfound"}), 404

        prefix_id = row[0]

        g.db.begin()
        cur.execute(
            "DELETE FROM roleassignment WHERE prefix_id = %s",
            (prefix_id,),
        )

        cur.execute(
            "DELETE FROM hieraassignment WHERE prefix_id = %s",
            (prefix_id,),
        )

        cur.execute(
            "DELETE FROM prefix WHERE id = %s",
            (prefix_id,),
        )

        add_git_commit(
            cursor=cur,
            files={
                get_git_path(project, prefix, "yaml"): None,
                get_git_path(project, prefix, "roles"): None,
            },
            message=f"Delete data for {project} {prefix}",
        )

        g.db.commit()

        return dump_with_requested_format({"status": "ok"})
    finally:
        cur.close()


@app.route("/v1/healthz")
def healthz():
    """
    Where we do a token db operation to check the health of the whole application.
    """
    cur = g.db.cursor()
    try:
        cur.execute("SHOW TABLES")
        cur.fetchall()

        return dump_with_requested_format({"status": "ok"})
    finally:
        cur.close()


if __name__ == "__main__":
    app.run(debug=True)
