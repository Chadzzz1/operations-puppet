class openstack::neutron::common::rocky(
    Array[Stdlib::Fqdn] $openstack_controllers,
    $keystone_host,
    $db_pass,
    $db_user,
    $db_host,
    $region,
    $dhcp_domain,
    $ldap_user_pass,
    $rabbit_user,
    $rabbit_pass,
    $tld,
    $log_agent_heartbeats,
    $agent_down_time,
    Stdlib::Port $bind_port,
    Stdlib::HTTPUrl $keystone_admin_uri,
    Stdlib::HTTPUrl $keystone_public_uri,
    ) {

    class { "openstack::neutron::common::rocky::${::lsbdistcodename}": }

    file { '/etc/neutron/neutron.conf':
            owner     => 'neutron',
            group     => 'neutron',
            mode      => '0660',
            show_diff => false,
            content   => template('openstack/rocky/neutron/neutron.conf.erb'),
            require   => Package['neutron-common'];
    }

    file { '/etc/neutron/policy.json':
        ensure => absent,
    }

    file { '/etc/neutron/policy.yaml':
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            source  => 'puppet:///modules/openstack/rocky/neutron/policy.yaml',
            require => Package['neutron-common'];
    }

    file { '/etc/neutron/plugins/ml2/ml2_conf.ini':
        owner   => 'neutron',
        group   => 'neutron',
        mode    => '0744',
        content => template('openstack/rocky/neutron/plugins/ml2/ml2_conf.ini.erb'),
        require => Package['neutron-common'];
    }
}
