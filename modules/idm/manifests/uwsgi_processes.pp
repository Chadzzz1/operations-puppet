# SPDX-License-Identifier: Apache-2.0

class idm::uwsgi_processes (
    String           $project             = 'bitu',
    Stdlib::Unixpath $base_dir            = '/srv/idm',
    Stdlib::Unixpath $static_dir          = "${base_dir}/static",
    StdLib::Unixpath $media_dir           = "${base_dir}/media",
    String           $deploy_user         = 'www-data',
    String           $uwsgi_socket        = '/tmp/uwsgi.sock',
    Integer          $uwsgi_process_count = 4,
){
    ensure_packages(['python3-django-uwsgi'])

    $project_dir = "${base_dir}/${project}"

    file { [$static_dir, $media_dir, '/etc/bitu'] :
        ensure => directory,
        owner  => $deploy_user,
        group  => $deploy_user,
    }

    uwsgi::app{ $project:
        settings => {
            uwsgi => {
                'plugins'      => 'python3',
                'project'      => $project,
                'uid'          => $deploy_user,
                'base'         => $project_dir,
                'env'          => [
                    "PYTHONPATH=/etc/${project}:\$PYTHONPATH",
                    'DJANGO_SETTINGS_MODULE=settings'
                ],
                'chdir'        => '%(base)/',
                'module'       => '%(project).wsgi:application',
                'master'       => true,
                'processes'    => $uwsgi_process_count,
                'socket'       => $uwsgi_socket,
                'chown-socket' => $deploy_user,
                'chmod-socket' => 660,
                'vacuum'       => true
            }
        }
    }
}
