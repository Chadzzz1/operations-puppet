# == Class: phabricator::phd
#
# Setup PHD service to run securely
#

class phabricator::phd (
    String $phd_user              = 'phd',
    Stdlib::Unixpath $phd_log_dir = '/var/log/phd',
    Stdlib::Unixpath $phd_home    = '/var/run/phd',
    Integer $phd_uid              = 920,
    Stdlib::Unixpath $basedir     = '/',
    Boolean $use_systemd_sysuser  = false,
) {

    # PHD user needs perms to drop root perms on start
    file { "${basedir}/phabricator/scripts/daemon/":
        owner   => $phd_user,
        recurse => true,
    }

    # Managing repo's as the PHD user
    file { "${basedir}/phabricator/scripts/repository/":
        owner   => $phd_user,
        recurse => true,
    }

    file { $phd_home:
        ensure => directory,
        owner  => $phd_user,
        group  => $phd_user,
    }

    file { $phd_log_dir:
        ensure => 'directory',
        owner  => $phd_user,
        group  => $phd_user,
    }

    # TODO: remove if/else and parameter after migration to new servers
    if $use_systemd_sysuser {
        systemd::sysuser { $phd_user:
            ensure      => present,
            id          => "${phd_uid}:${phd_uid}",
            description => 'Phabricator daemon user',
            home_dir    => $phd_home,
        }

    } else {

        group { $phd_user:
            ensure => present,
            system => true,
        }

        user { $phd_user:
        gid    => $phd_user,
        shell  => '/bin/false',
        home   => $phd_home,
        system => true,
        }
    }

    logrotate::conf { 'phd':
        ensure => present,
        source => 'puppet:///modules/phabricator/logrotate_phd',
    }
}
