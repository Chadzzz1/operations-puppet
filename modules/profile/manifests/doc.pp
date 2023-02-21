# SPDX-License-Identifier: Apache-2.0
# web server hosting https://doc.wikimedia.org
class profile::doc (
    Stdlib::Fqdn        $active_host  = lookup('profile::doc::active_host'),
    Array[Stdlib::Fqdn] $all_hosts    = lookup('profile::doc::all_hosts'),
    Stdlib::Unixpath    $wmf_doc_path = lookup('profile::doc::wmf_doc_path', {'default_value' => '/srv/doc'}),
    Array[Stdlib::Host] $gitlab_runner_hosts = lookup('profile::doc::gitlab_runner_hosts'),
    Array[Stdlib::Host] $contint_hosts = lookup('jenkins_master_hosts'),
) {

    $deploy_user = 'deploy-ci-docroot'

    scap::target { 'integration/docroot':
        deploy_user => $deploy_user,
    }

    $php = debian::codename() ? {
        'buster'   => 'php7.3',
        'bullseye' => 'php7.4',
        default    => fail("${module_name} not supported by ${debian::codename()}")
    }

    ensure_packages(["${php}-fpm", "${php}-xml"])

    $restart_cmd = "/bin/systemctl restart ${php}-fpm"

    # scap deployment swap symlink which confuses PHP opcache. On promote
    # stage, scap invoke this script to clear the opcache.
    file { '/usr/local/sbin/restart-php-fpm-unsafe':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
        content => "#!/bin/bash\nexec sudo -u root -- ${restart_cmd}\n"
    }

    sudo::user { 'deploy_restart_fpm':
        user       => $deploy_user,
        privileges => ["ALL = NOPASSWD: ${restart_cmd}"],
    }

    class { '::httpd':
        modules => ['setenvif',
                    'headers',
                    'rewrite',
                    'proxy',
                    'proxy_fcgi'],
    }

    class { '::httpd::mpm':
        mpm    => 'worker',
        source => 'puppet:///modules/profile/doc/httpd_worker.conf'
    }

    httpd::conf { 'wmf_doc_path':
        priority => 40,
        content  => "Define WMF_DOC_PATH ${wmf_doc_path}\nDefine WMF_DOC_PHP_VERSION ${php}",
    }

    # Apache configuration for doc.wikimedia.org
    httpd::site { 'doc.wikimedia.org':
        source => 'puppet:///modules/profile/doc/httpd-doc.wikimedia.org.conf'
    }

    profile::auto_restarts::service { "${php}-fpm": }

    ferm::service { 'doc-http':
        proto  => 'tcp',
        port   => '80',
        srange => '($CACHES $DEPLOYMENT_HOSTS)',
    }

    profile::auto_restarts::service { 'apache2': }
    profile::auto_restarts::service { 'envoyproxy': }

    user { 'doc-uploader':
        ensure => present,
        shell  => '/bin/false',
        system => true,
    }

    file { '/srv/doc':
        ensure => 'directory',
        owner  => 'doc-uploader',
        group  => 'doc-uploader',
        mode   => '0755',
    }

    # This is to prevent monitoring from alerting. The directory is empty until
    # we have completed the migration of generated documentations. Once done,
    # we should remove the file.
    file { '/srv/doc/BACKMEUP':
        ensure  => 'file',
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => 'Placeholder for Bacula',
    }

    backup::set { 'srv-doc': }

    class { '::rsync::server': }

    $is_active = $::fqdn == $active_host
    $ensure_on_active = $is_active.bool2str('present', 'absent')

    rsync::server::module { 'doc':
        ensure         => $ensure_on_active,
        comment        => 'Docroot of https://doc.wikimedia.org/',
        read_only      => 'no',
        path           => '/srv/doc',
        uid            => 'doc-uploader',
        gid            => 'doc-uploader',
        incoming_chmod => 'D775,F664',
        hosts_allow    => $gitlab_runner_hosts + $contint_hosts,
        auto_ferm      => true,
        auto_ferm_ipv6 => true,
        require        => [
            User['doc-uploader'],
            File['/srv/doc'],
        ],
    }

    rsync::server::module { 'doc-between-nodes':
        ensure         => $is_active.bool2str('absent', 'present'),
        path           => '/srv/doc',
        read_only      => 'no',
        hosts_allow    => [$active_host],
        auto_ferm      => true,
        auto_ferm_ipv6 => true,
    }

    $all_hosts.each |Stdlib::Fqdn $other_host| {
        if $::fqdn != $other_host {
            systemd::timer::job { "rsync-doc-${other_host}":
                ensure      => $ensure_on_active,
                user        => 'root',
                description => 'rsync documentation to a non-active server',
                command     => "/usr/bin/rsync -avp --delete /srv/doc/ rsync://${other_host}/doc-between-nodes",
                interval    => {'start' => 'OnUnitInactiveSec', 'interval' => '1h'},
            }

        }

        prometheus::blackbox::check::http { $other_host:
            server_name        => 'doc.wikimedia.org',
            instance_label     => $other_host,
            team               => 'serviceops-collab',
            severity           => 'task',
            path               => '/',
            ip_families        => ['ip4'],
            force_tls          => true,
            body_regex_matches => ['open-source'],
        }
    }
    profile::auto_restarts::service { 'rsync': }
}
