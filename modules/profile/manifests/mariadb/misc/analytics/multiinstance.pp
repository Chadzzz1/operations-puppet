# Class profile::mariadb::misc::analytics::multiinstance
#
# The Analytics team manages multiple small databases related to their
# tools (Superset, Druid, Matomo, etc..) and this profile implements
# a mariadb multi-instance environment that can be used as replica.
#
class profile::mariadb::misc::analytics::multiinstance (
    Hash[String, Stdlib::Datasize] $instances = lookup('profile::mariadb::misc::analytics::multiinstance::instances'),
    Hash[String, Stdlib::Port] $section_ports = lookup('profile::mariadb::section_ports'),
) {
    require profile::mariadb::packages_wmf
    class { 'mariadb::service':
        override => "[Service]\nExecStartPre=/bin/sh -c \"echo 'mariadb main service is \
disabled, use mariadb@<instance_name> instead'; exit 1\"",
    }

    include ::profile::mariadb::mysql_role
    include profile::mariadb::wmfmariadbpy

    class { 'mariadb::config':
        basedir       => $profile::mariadb::packages_wmf::basedir,
        config        => 'profile/mariadb/mysqld_config/analytics_multiinstance.my.cnf.erb',
        p_s           => 'on',
        ssl           => 'puppet-cert',
        binlog_format => 'ROW',
        read_only     => 1,
    }

    file { '/etc/mysql/mysqld.conf.d':
        ensure => directory,
        owner  => root,
        group  => root,
        mode   => '0755',
    }

    $instances.each |$section, $buffer_pool| {
        $port = $section_ports[$section]
        if (!$port) {
            fail("'${section}' is not a valid section.")
        }
        $prom_port = Integer("1${port}")
        mariadb::instance { $section:
            port                    => $port,
            innodb_buffer_pool_size => $buffer_pool,
        }
        profile::mariadb::section { $section: }
        profile::mariadb::ferm { $section: port => $port }
        profile::prometheus::mysqld_exporter_instance { $section: port => $prom_port }
    }

    class { 'mariadb::monitor_disk':
        is_critical   => false,
        contact_group => 'admins,analytics',
    }

    class { 'mariadb::monitor_process':
        process_count => length($instances),
        is_critical   => false,
        contact_group => 'admins,analytics',
    }

    class { 'mariadb::monitor_memory': }
}
