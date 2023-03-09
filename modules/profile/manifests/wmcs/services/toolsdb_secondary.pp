# SPDX-License-Identifier: Apache-2.0
# = Class: profile::wmcs::services::toolsdb_secondary
#
# This class sets up MariaDB for a secondary tools database.
#
class profile::wmcs::services::toolsdb_secondary (
    Stdlib::Unixpath $socket = lookup('profile::wmcs::services::toolsdb::socket', {default_value => '/var/run/mysqld/mysqld.sock'}),
    Boolean $rebuild = lookup('profile::wmcs::services::toolsdb::rebuild', {default_value => false}),
    Optional[Stdlib::Fqdn] $primary_server = lookup('profile::wmcs::services::toolsdb::rebuild_primary'),
    Optional[Stdlib::Fqdn] $secondary_server = lookup('profile::wmcs::services::toolsdb::rebuild_secondary'),
    Boolean $legacy_config = lookup('profile::wmcs::services::toolsdb::legacy_config', {default_value => true}),
) {
    require profile::wmcs::services::toolsdb_apt_pinning

    require profile::mariadb::packages_wmf
    include profile::mariadb::wmfmariadbpy
    class { '::mariadb::service': }

    # This should depend on labs_lvm::srv but the /srv/ vols were hand built
    # on the first two toolsdb VMs to exactly match the physical servers.
    # New ones should directly use that profile so we can add it here.
    file { '/srv/labsdb':
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
    }

    file { '/srv/labsdb/binlogs':
        ensure => directory,
        mode   => '0755',
        owner  => 'mysql',
        group  => 'mysql',
    }

    if $legacy_config {
      $config_file_template = 'role/mariadb/mysqld_config/tools_legacy.my.cnf.erb'
    } else {
      $config_file_template = 'role/mariadb/mysqld_config/tools.my.cnf.erb'
    }

    class { 'mariadb::config':
        config        => $config_file_template,
        datadir       => '/srv/labsdb/data',
        tmpdir        => '/srv/labsdb/tmp',
        basedir       => $profile::mariadb::packages_wmf::basedir,
        read_only     => 'ON',
        p_s           => 'on',
        ssl           => 'puppet-cert',
        binlog_format => 'ROW',
        socket        => $socket,
    }

    class { 'mariadb::heartbeat':
        datacenter => $::site,
        enabled    => false,
    }

    class { 'profile::mariadb::monitor::prometheus':
        socket => $socket,
    }
    if $rebuild {
        rsync::quickdatacopy { 'srv-labsdb-backup1':
            ensure      => present,
            auto_sync   => false,
            source_host => $primary_server,
            dest_host   => $secondary_server,
            module_path => '/srv/labsdb',
        }
    }
}
