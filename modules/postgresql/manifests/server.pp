# Class: postgresql::server
#
# This class installs postgresql packages, standard configuration
#
# Parameters:
#   pgversion
#       Defaults to 9.6 in Debian Stretch
#       FIXME: Just use the unversioned package name and let apt
#       do the right thing.
#   ensure
#       Defaults to present
#   includes
#       An array of files that will be included in the config. It is
#       the caller's responsibility to provide these
#   root_dir
#       The root directory for postgresql data. The actual directory will be
#       "${root_dir}/${pgversion}/main".
#   use_ssl
#       Enable ssl
#
# Actions:
#  Install/configure postgresql
#
# Requires:
#
# Sample Usage:
#  include postgresql::server
#
class postgresql::server(
    $pgversion        = $::lsbdistcodename ? {
        'buster'  => '11',
        'stretch' => '9.6',
    },
    $ensure           = 'present',
    $includes         = [],
    $listen_addresses = '*',
    $port             = '5432',
    $root_dir         = '/var/lib/postgresql',
    $use_ssl          = false,
    $ssldir           = undef,
) {

    package { [
        "postgresql-${pgversion}",
        "postgresql-${pgversion}-debversion",
        "postgresql-client-${pgversion}",
        'libdbi-perl',
        'libdbd-pg-perl',
        $::lsbdistcodename ? {
            'buster' => 'pgtop',
            default  => 'ptop',
        },
        'check-postgres',
    ]:
        ensure => $ensure,
    }

    # The contrib package got dropped from Postgres in 10, it's only a virtual
    # package and not needed starting with Buster
    if os_version('debian < buster') {
        package { "postgresql-contrib-${pgversion}":
            ensure => $ensure,
        }
    }

    class { '::postgresql::dirs':
        ensure    => $ensure,
        pgversion => $pgversion,
        root_dir  => $root_dir,
    }

    $data_dir = "${root_dir}/${pgversion}/main"

    $service_name = 'postgresql'

    exec { 'pgreload':
        command     => "/usr/bin/pg_ctlcluster ${pgversion} main reload",
        user        => 'postgres',
        refreshonly => true,
    }

    if $use_ssl {
        file { "/etc/postgresql/${pgversion}/main/ssl.conf":
            ensure  => $ensure,
            source  => 'puppet:///modules/postgresql/ssl.conf',
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            require => Base::Expose_puppet_certs['/etc/postgresql'],
            before  => Service[$service_name],
        }

        ::base::expose_puppet_certs { '/etc/postgresql':
            ensure          => $ensure,
            provide_private => true,
            user            => 'postgres',
            group           => 'postgres',
            ssldir          => $ssldir,
        }
    }

    service { $service_name:
        ensure  => ensure_service($ensure),
    }

    file { "/etc/postgresql/${pgversion}/main/postgresql.conf":
        ensure  => $ensure,
        content => template('postgresql/postgresql.conf.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
    }
}
