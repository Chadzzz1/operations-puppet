#!/usr/bin/env python3

import argparse
import json
import logging
import os
from dataclasses import dataclass
from itertools import chain
from typing import Any, Dict, List, Optional

import mwopenstackclients
from rbd2backy2 import BackupEntry, cleanup, get_backups

# This holds cached openstack information
CACHE_FILE = "./backups.cache"
RED = "\033[91m"
GREEN = "\033[92m"
END = "\033[0m"
BOLD = "\033[1m"


def red(mystr: str) -> str:
    return RED + mystr + END


def green(mystr: str) -> str:
    return GREEN + mystr + END


def bold(mystr: str) -> str:
    return BOLD + mystr + END


def indent_lines(lines: str) -> str:
    return "\n".join(("    " + line) for line in lines.splitlines())


@dataclass
class VMBackup:
    vm_id: str
    project: Optional[str]
    vm_info: Dict[str, Any]
    backup_entry: BackupEntry
    size_mb: int
    size_percent: Optional[float] = None

    @classmethod
    def from_entry_and_servers(
        cls, entry: BackupEntry, servers: Dict[str, Dict[str, Any]]
    ):
        vm_id = entry.name.split("_", 1)[0]
        if vm_id not in servers:
            logging.warning("Unable to find vm with id %s", vm_id)
        server_dict = servers.get(vm_id, None)
        server_info = server_dict if server_dict is not None else {}
        return cls(
            backup_entry=entry,
            vm_id=vm_id,
            vm_info=server_info,
            project=server_info.get("tenant_id", None),
            size_mb=entry.size_mb,
        )

    def remove(self, noop: bool = True) -> None:
        self.backup_entry.remove(noop=noop)

    def __str__(self) -> str:
        percent_str = (
            f"({self.size_percent:.2f}% of total) "
            if self.size_percent
            else ""
        )
        return (
            f"created:{self.backup_entry.date.strftime('%Y-%m-%d %H:%M:%S')} "
            f"expires:{self.backup_entry.date.strftime('%Y-%m-%d %H:%M:%S')} "
            f"{green('VALID') if self.backup_entry.valid else red('INVALID')} "
            f"{'PROTECTED' if self.backup_entry.valid else 'UNPROTECTED'} "
            f"size:{self.size_mb}MB {percent_str}"
            f"name:{self.backup_entry.name} "
            f"snapshot:{self.backup_entry.snapshot_name} "
            f"uid:{self.backup_entry.uid} "
            f"tags:{self.backup_entry.tags}"
        )

    def __repr__(self) -> str:
        return (
            "VMBackup("
            f"vm_id={self.vm_id}, "
            f"project={self.project}, "
            f"size_mb={self.size_mb}, "
            f"size_percent={self.size_percent}, "
            f"backup_entry={self.backup_entry}, "
            f"vm_info={self.vm_info}"
            ")"
        )


@dataclass
class VMBackups:
    full_backups: List[BackupEntry]
    differential_backups: List[BackupEntry]
    vm_id: str
    project: Optional[str]
    vm_info: Dict[str, Any]
    size_mb: int = 0
    size_percent: Optional[float] = None

    def add_backup(self, backup: VMBackup) -> bool:
        if backup.vm_id != self.vm_id:
            raise Exception(
                "Invalid backup, non-matching vm_id "
                f"(backup.vm_id={backup.vm_id}, self.vm_id={self.vm_id})"
            )

        was_added = False
        if "differential_backup" in backup.backup_entry.tags:
            if backup not in self.differential_backups:
                self.differential_backups.append(backup)
                was_added = True
        else:
            if backup not in self.full_backups:
                self.full_backups.append(backup)
                was_added = True

        if was_added:
            self.size_mb += backup.backup_entry.size_mb

        return was_added

    def update_usages(self, total_size_mb: int) -> None:
        for backup in self.full_backups:
            backup.size_percent = backup.size_mb * 100 / total_size_mb

        for backup in self.differential_backups:
            backup.size_percent = backup.size_mb * 100 / total_size_mb

    def remove_invalids(self, force: bool, noop: bool = True) -> int:
        logging.info(
            "%sRemoving invalid backups for VM %s.%s(%s)",
            "NOOP:" if noop else "",
            self.project,
            self.vm_info.get("name", "unknown name"),
            self.vm_id,
        )
        if not force and not any(
            backup
            for backup in chain(self.full_backups, self.differential_backups)
            if backup.backup_entry.valid
        ):
            logging.warning(
                "Skipping VM backups for %s.%s(%s), not enough valid backups.",
                self.project,
                self.vm_info.get("name", "unknown name"),
                self.vm_id,
            )
            return 0
        elif force and not any(
            backup
            for backup in chain(self.full_backups, self.differential_backups)
            if backup.backup_entry.valid
        ):
            logging.warning(
                (
                    "Deleting all VM backups for %s.%s(%s), none of them are "
                    "valid."
                ),
                self.project,
                self.vm_info.get("name", "unknown name"),
                self.vm_id,
            )

        remove_count = 0
        valid_full_backups = [
            backup for backup in self.full_backups if backup.backup_entry.valid
        ]
        for backup in self.full_backups:
            if backup.backup_entry.valid:
                continue

            old_size = backup.size_mb
            backup.remove(noop=noop)
            self.size_mb = self.size_mb - old_size + backup.size_mb
            remove_count += 1

        self.full_backups = valid_full_backups

        valid_differential_backups = [
            backup
            for backup in self.differential_backups
            if backup.backup_entry.valid
        ]
        for backup in self.differential_backups:
            if backup.backup_entry.valid:
                continue

            old_size = backup.size_mb
            backup.remove(noop=noop)
            self.size_mb = self.size_mb - old_size + backup.size_mb
            remove_count += 1

        self.differential_backups = valid_differential_backups

        return remove_count

    def __str__(self) -> str:
        backups_strings = sorted(
            [bold("FULL") + f" {entry}" for entry in self.full_backups]
            + [f"DIFF {entry}" for entry in self.differential_backups]
        )
        return (
            bold("VM:")
            + f" {self.vm_info.get('name', 'unknown name')}(id:{self.vm_id})\n"
            + f"Total Size: {self.size_mb}MB"
            + (
                f"\nSize percent: {self.size_percent:.2f}%"
                if self.size_percent
                else ""
            )
            + "\nBackups:\n    "
            + "\n    ".join(backups_strings)
        )

    def __repr__(self) -> str:
        return (
            "VMBackups("
            f"vm_id={self.vm_id}, "
            f"project={self.project}, "
            f"vm_info={self.vm_info}, "
            f"size_mb={self.size_mb}, "
            f"size_percent={self.size_percent}, "
            f"full_backups={self.full_backups}, "
            f"differential_backups={self.differential_backups}"
            ")"
        )


@dataclass
class ProjectBackups:
    vms_backups: Dict[str, VMBackups]
    project: Optional[str]
    size_mb: int = 0
    size_percent: Optional[int] = None

    def add_vm_backup(self, backup: VMBackup) -> bool:
        if backup.vm_id not in self.vms_backups:
            self.vms_backups[backup.vm_id] = VMBackups(
                full_backups=[],
                differential_backups=[],
                vm_id=backup.vm_id,
                project=self.project,
                vm_info=backup.vm_info,
            )

        was_added = self.vms_backups[backup.vm_id].add_backup(backup)
        if was_added:
            self.size_mb += backup.backup_entry.size_mb

        return was_added

    def update_usages(self, total_size_mb: int) -> None:
        for vm_backups in self.vms_backups.values():
            vm_backups.size_percent = vm_backups.size_mb * 100 / total_size_mb
            vm_backups.update_usages(total_size_mb=total_size_mb)

    def __str__(self) -> str:
        return (
            bold("Project:")
            + f" {self.project}\n"
            + bold("Total Size:")
            + f" {self.size_mb}MB\n"
            + (
                (bold("Size percent:") + f" {self.size_percent:.2f}%\n")
                if self.size_percent
                else ""
            )
            + "\n".join(
                indent_lines(str(vm_backups))
                for vm_backups in self.vms_backups.values()
            )
        )

    def __repr__(self) -> str:
        return (
            "ProjectBackups("
            f"project={self.project}, "
            f"size_mb={self.size_mb}, "
            f"size_percent={self.size_percent}, "
            f"vms_backups={self.vms_backups}"
            ")"
        )

    def remove_invalids(self, force: bool, noop: bool):
        logging.info(
            "%sRemoving invalids for project %s",
            "NOOP:" if noop else "",
            self.project,
        )
        total_removed = 0
        for vm_backup in self.vms_backups.values():
            old_size = vm_backup.size_mb
            num_removed = vm_backup.remove_invalids(force=force, noop=noop)
            total_removed += num_removed
            self.size_mb = self.size_mb - old_size + vm_backup.size_mb

        return total_removed


@dataclass
class BackupsState:
    projects_backups: Dict[str, ProjectBackups]
    size_mb: int = 0

    def add_vm_backup(self, vm_backup: VMBackup) -> bool:
        """
        Returns True if it was added to the BackupsState, False if it was
        already there.
        """
        if vm_backup.project not in self.projects_backups:
            self.projects_backups[vm_backup.project] = ProjectBackups(
                vms_backups={},
                project=vm_backup.project,
            )

        was_added = self.projects_backups[vm_backup.project].add_vm_backup(
            vm_backup
        )
        if was_added:
            self.size_mb += vm_backup.size_mb

        return was_added

    def update_usages(self) -> None:
        for project_backups in self.projects_backups.values():
            project_backups.size_percent = (
                project_backups.size_mb * 100 / self.size_mb
            )
            project_backups.update_usages(total_size_mb=self.size_mb)

    def __str__(self) -> str:
        self.update_usages()
        out_str = bold(f"Total Size: {self.size_mb}MB") + "\n"
        out_str += (
            bold(f"Number of projects: {len(self.projects_backups)}") + "\n"
        )
        top_10_projects = "\n".join(
            list(
                f"{pb.size_percent:.2f}% - {name}"
                for name, pb in sorted(
                    self.projects_backups.items(),
                    reverse=True,
                    key=lambda x: x[1].size_mb,
                )
            )[:10]
        )
        top_10_vms = "\n".join(
            list(
                (
                    f"{vm.size_percent:.2f}% - "
                    f"{vm.vm_info.get('name', 'unknown name')}({vm.vm_id})"
                )
                for vm in sorted(
                    chain(
                        *list(
                            map(
                                lambda pb: pb.vms_backups.values(),
                                self.projects_backups.values(),
                            )
                        )
                    ),
                    reverse=True,
                    key=lambda vm: vm.size_mb,
                )
            )[:10]
        )
        out_str += (
            bold("Top 10 projects by size:")
            + f"\n{indent_lines(top_10_projects)}"
            + "\n"
        )
        out_str += (
            bold("Top 10 VMs by size:")
            + f" \n{indent_lines(top_10_vms)}"
            + "\n"
        )
        for project in self.projects_backups.values():
            out_str += ("#" * 75) + "\n"
            out_str += str(project) + "\n"

        out_str += ("#" * 75) + "\n"
        return out_str

    def __repr__(self) -> str:
        return (
            "BackupsState("
            f"size_mb={self.size_mb}, "
            f"projects_backups={self.projects_backups}"
            ")"
        )

    def remove_invalids(self, force: bool, noop: bool = True):
        logging.info("%sRemoving invalids", "NOOP:" if noop else "")
        total_removed = 0
        for project in self.projects_backups.values():
            old_size = project.size_mb
            num_removed = project.remove_invalids(force=force, noop=noop)
            total_removed += num_removed
            self.size_mb = self.size_mb - old_size + project.size_mb

        if total_removed > 0:
            logging.info(
                "Cleaning up leftover backy blocks (this frees the space)..."
            )
            cleanup(noop=noop)
        else:
            logging.info("No backups removed, skipping cleanup")

        logging.info(
            "%s %d invalid backups.",
            "Would have deleted" if noop else "Deleted",
            total_removed,
        )


def get_current_state(from_cache: bool = False) -> BackupsState:
    if not from_cache or not os.path.exists(CACHE_FILE):
        openstackclients = mwopenstackclients.Clients(
            envfile="/etc/novaobserver.yaml"
        )
        logging.debug("Getting instances...")
        server_id_to_server_dict = {
            server.id: server.to_dict()
            for server in openstackclients.allinstances()
        }
        with open(CACHE_FILE, "w") as cache_fd:
            cache_fd.write(json.dumps(server_id_to_server_dict))

    else:
        server_id_to_server_dict = json.load(open(CACHE_FILE, "r"))

    logging.debug("Getting backup entries...")
    backup_entries = get_backups()

    logging.debug("Creating project level summaries")
    projects_backups = BackupsState(projects_backups={})
    for backup_entry in backup_entries:
        vm_backup = VMBackup.from_entry_and_servers(
            entry=backup_entry, servers=server_id_to_server_dict
        )
        projects_backups.add_vm_backup(vm_backup)

    return projects_backups


def summary(current_state: BackupsState) -> None:
    print(str(current_state))


def print_excess_backups_per_vm(
    current_state: BackupsState, excess: int = 3
) -> None:
    for project in current_state.projects_backups.values():
        print("#" * 75 + f" {project.project}")
        for vm_backups in project.vms_backups.values():
            if (
                len(vm_backups.full_backups)
                + len(vm_backups.differential_backups)
                > 3
            ):
                candidate_backups_strings = sorted(
                    [f"FULL {entry}" for entry in vm_backups.full_backups]
                    + [
                        f"DIFF {entry}"
                        for entry in vm_backups.differential_backups
                    ],
                )
                print(
                    str(
                        "\n".join(
                            candidate_backups_strings[
                                : len(candidate_backups_strings) - 3
                            ]
                        )
                    )
                )

    print("#" * 75)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--debug", action="store_true")
    parser.add_argument(
        "--from-cache",
        action="store_true",
        help=(
            "If set, will try to load the list of servers from the cache file "
            f"{CACHE_FILE} instead of doing a request to openstack."
        ),
    )
    subparser = parser.add_subparsers()

    summary_parser = subparser.add_parser(
        "summary", help="Show a list of all backups."
    )
    summary_parser.set_defaults(
        func=lambda: summary(get_current_state(from_cache=args.from_cache))
    )

    show_excess_parser = subparser.add_parser(
        "show-excess",
        help=(
            "Shows the backups in excess of the givent number (default 3), "
            "that is, any extra backups over that number for each VM"
        ),
    )
    show_excess_parser.add_argument("-e", "--excess", default=3, type=int)
    show_excess_parser.set_defaults(
        func=lambda: print_excess_backups_per_vm(
            get_current_state(from_cache=args.from_cache)
        )
    )

    show_excess_parser = subparser.add_parser(
        "remove-invalids",
        help=(
            "Remove any invalid backups, if there's a valid one for that "
            "machine already."
        ),
    )
    show_excess_parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help=(
            "If set, will remove any invalid backup even if there's no other "
            "backup for that VM."
        ),
    )
    show_excess_parser.add_argument(
        "-n",
        "--noop",
        action="store_true",
        help=(
            "If set, will not really remove anything, just tell you what "
            "would be removed."
        ),
    )
    show_excess_parser.set_defaults(
        func=lambda: get_current_state(
            from_cache=args.from_cache
        ).remove_invalids(
            force=args.force,
            noop=args.noop,
        )
    )

    args = parser.parse_args()
    if args.debug:
        level = logging.DEBUG
    else:
        level = logging.INFO

    logging.basicConfig(
        level=level, format="%(levelname)s:[%(asctime)s] %(message)s"
    )
    # silence some too verbose loggers
    for logger in ["novaclient", "urllib3", "keystoneauth", "keystoneclient"]:
        logging.getLogger(logger).setLevel(logging.INFO)

    args.func()
