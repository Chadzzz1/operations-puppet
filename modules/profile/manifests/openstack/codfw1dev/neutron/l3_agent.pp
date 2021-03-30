class profile::openstack::codfw1dev::neutron::l3_agent(
    $version = lookup('profile::openstack::codfw1dev::version'),
    $bridges = lookup('profile::openstack::codfw1dev::neutron::l3_agent_bridges'),
    $bridge_mappings = lookup('profile::openstack::codfw1dev::neutron::l3_agent_bridge_mappings'),
    $network_flat_interface_vlan_external = lookup('profile::openstack::codfw1dev::neutron::network_flat_interface_vlan_external'),
    $network_flat_interface_vlan = lookup('profile::openstack::codfw1dev::neutron::network_flat_interface_vlan'),
    $dmz_cidr = lookup('profile::openstack::codfw1dev::neutron::dmz_cidr'),
    $network_public_ip = lookup('profile::openstack::codfw1dev::neutron::network_public_ip'),
    $report_interval = lookup('profile::openstack::codfw1dev::neutron::report_interval'),
    $base_interface = lookup('profile::openstack::codfw1dev::neutron::base_interface'),
    Boolean $enable_hacks       = lookup('profile::openstack::codfw1dev::neutron::enable_hacks', {default_value => true}),
    ) {

    require ::profile::openstack::codfw1dev::clientpackages
    require ::profile::openstack::codfw1dev::neutron::common

    class {'::profile::openstack::base::neutron::l3_agent':
        version                              => $version,
        dmz_cidr                             => $dmz_cidr,
        network_public_ip                    => $network_public_ip,
        report_interval                      => $report_interval,
        base_interface                       => $base_interface,
        network_flat_interface_vlan          => $network_flat_interface_vlan,
        network_flat_interface_vlan_external => $network_flat_interface_vlan_external,
        enable_hacks                         => $enable_hacks,
    }
    contain '::profile::openstack::base::neutron::l3_agent'

    class {'::profile::openstack::base::neutron::linuxbridge_agent':
        version         => $version,
        bridges         => $bridges,
        bridge_mappings => $bridge_mappings,
        report_interval => $report_interval,
    }
    contain '::profile::openstack::base::neutron::linuxbridge_agent'
}
