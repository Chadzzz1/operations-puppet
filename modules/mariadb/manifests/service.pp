# Make /etc/init/mysql managed by puppet. This allows us to make quick
# changes to harden the wrapper without rebuilding the custom wmf-mariadb10
# package
# Once all trusty dbs are gone, we can hopefully discard init.d in favour
# of a custom systemd service unit
#
# Default behavior is for the service to be unmanaged and manually
# started/stopped.
# It is important to keep this like this for all production services (if
# mysql and replication start automatically and there has been a crash
# or an upgrade (hardware or software), data will get corrupted).
# However, for non critical services (beta, other small, non-dedicated
# services, we allow mysql to auto-start.
# With $manage = true this class will set $ensure and $enabled as specified.

class mariadb::service (
    $package = 'wmf-mariadb10',
    $basedir = 'undefined',
    $manage  = false,
    $ensure  = stopped,
    $enable  = false,
    ) {

    if $basedir == 'undefined' {
        $initd_basedir = "/opt/${package}"
    } else {
        $initd_basedir = $basedir
    }

    if os_version('debian >= stretch') {
        #TODO: setup optional systemd options
    } else {
        file { "${initd_basedir}/service":
            ensure  => present,
            owner   => 'root',
            group   => 'root',
            mode    => '0755',
            content => template('mariadb/mariadb.server.erb'),
            require => Package[$package],
        }

        file { '/etc/init.d/mysql':
            ensure  => 'link',
            target  => "${initd_basedir}/service",
            require => File["${initd_basedir}/service"],
        }

        file { '/etc/init.d/mariadb':
            ensure  => 'link',
            target  => "${initd_basedir}/service",
            require => File["${initd_basedir}/service"],
        }

        if $manage {
            service { 'mysql':
                ensure  => $ensure,
                enable  => $enable,
                require => File['/etc/init.d/mysql'],
            }
        }
    }

}
