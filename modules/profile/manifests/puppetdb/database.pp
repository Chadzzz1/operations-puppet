# == Class profile::puppetdb::database
#
# Sets up a puppetdb postgresql database.
#
class profile::puppetdb::database(
    Stdlib::Host               $master               = lookup('profile::puppetdb::master'),
    String                     $shared_buffers       = lookup('profile::puppetdb::database::shared_buffers'),
    String                     $replication_password = lookup('puppetdb::password::replication'),
    String                     $puppetdb_password    = lookup('puppetdb::password::rw'),
    Hash                       $users                = lookup('profile::puppetdb::database::users'),
    Integer                    $replication_lag_crit = lookup('profile::puppetdb::database::replication_lag_crit'),
    Integer                    $replication_lag_warn = lookup('profile::puppetdb::database::replication_lag_warn'),
    String                     $log_line_prefix      = lookup('profile::puppetdb::database::log_line_prefix'),
    Array[Stdlib::Host]        $slaves               = lookup('profile::puppetdb::slaves'),
    Optional[Stdlib::Unixpath] $ssldir               = lookup('profile::puppetdb::database::ssldir'),
    Optional[Integer[250]] $log_min_duration_statement = lookup('profile::puppetdb::database::log_min_duration_statement'),
) {
    $pgversion = debian::codename() ? {
        'bullseye' => 13,
        'buster'   => 11,
        'stretch'  => 9.6,
    }
    $slave_range = join($slaves, ' ')
    $on_master = ($master == $facts['networking']['fqdn'])

    sysctl::parameters { 'postgres_shmem':
        values => {
            # That is derived after tuning postgresql, deriving automatically is
            # not the safest idea yet.
            'kernel.shmmax' => 8388608000,
        },
    }
    if $on_master {
        class { 'postgresql::master':
            includes                   => ['tuning.conf'],
            root_dir                   => '/srv/postgres',
            use_ssl                    => true,
            ssldir                     => $ssldir,
            log_line_prefix            => $log_line_prefix,
            log_min_duration_statement => $log_min_duration_statement,
        }
    } else {
        class { 'postgresql::slave':
            includes         => ['tuning.conf'],
            master_server    => $master,
            root_dir         => '/srv/postgres',
            replication_pass => $replication_password,
            use_ssl          => true,
        }
        class { 'postgresql::slave::monitoring':
            pg_master   => $master,
            pg_user     => 'replication',
            pg_password => $replication_password,
            pg_database => 'puppetdb',
            critical    => $replication_lag_crit,
            warning     => $replication_lag_warn,
        }
    }
    file { "/etc/postgresql/${pgversion}/main/tuning.conf":
        ensure  => 'present',
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('puppetmaster/puppetdb/tuning.conf.erb'),
        require => Package["postgresql-${pgversion}"]
    }
    $users.each |$pg_name, $config| {
        postgresql::user { $pg_name:
            * => $config + {'master' => $on_master, 'pgversion' => $pgversion}
        }
    }
    postgresql::db { 'puppetdb':
        owner   => 'puppetdb',
    }

    exec { 'create_tgrm_extension':
        command => '/usr/bin/psql puppetdb -c "create extension pg_trgm"',
        unless  => '/usr/bin/psql puppetdb -c \'\dx\' | /bin/grep -q pg_trgm',
        user    => 'postgres',
        require => Postgresql::Db['puppetdb'],
    }
    # Firewall rules
    # Allow connections from all the slaves
    ferm::service { 'postgresql_puppetdb':
        proto  => 'tcp',
        port   => 5432,
        srange => "@resolve((${slave_range}))",
    }
}
