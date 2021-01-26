class openstack::neutron::dhcp_agent::train(
    $dhcp_domain,
    $report_interval,
) {
    class { "openstack::neutron::dhcp_agent::train::${::lsbdistcodename}": }

    file { '/etc/neutron/dhcp_agent.ini':
        owner   => 'neutron',
        group   => 'neutron',
        mode    => '0640',
        content => template('openstack/train/neutron/dhcp_agent.ini.erb'),
        require => Package['neutron-common'];
    }

    file { '/etc/neutron/dnsmasq-neutron.conf':
        owner   => 'neutron',
        group   => 'neutron',
        mode    => '0640',
        content => template('openstack/train/neutron/dnsmasq-neutron.conf.erb'),
        require => Package['neutron-common'];
    }
}
