class profile::openstack::base::nova::common::nova_network(
    $version = hiera('profile::openstack::base::version'),
    $nova_controller = hiera('profile::openstack::base::nova_controller'),
    $keystone_host = hiera('profile::openstack::base::keystone_host'),
    $nova_api_host = hiera('profile::openstack::base::nova_api_host'),
    $dmz_cidr = hiera('profile::openstack::base::nova::dmz_cidr'),
    $dhcp_domain = hiera('profile::openstack::base::nova::dhcp_domain'),
    $dhcp_start = hiera('profile::openstack::base::nova::dhcp_start'),
    $quota_floating_ips = hiera('profile::openstack::base::nova::quota_floating_ips'),
    $network_flat_interface = hiera('profile::openstack::base::nova::network_flat_interface'),
    $flat_network_bridge = hiera('profile::openstack::base::nova::flat_network_bridge'),
    $fixed_range = hiera('profile::openstack::base::nova::fixed_range'),
    $network_public_interface = hiera('profile::openstack::base::nova::network_public_interface'),
    $network_public_ip = hiera('profile::openstack::base::nova::network_public_ip'),
    $zone = hiera('profile::openstack::base::nova::zone'),
    $scheduler_pool = hiera('profile::openstack::base::nova::scheduler_pool'),
    $db_user = hiera('profile::openstack::base::nova::db_user'),
    $db_pass = hiera('profile::openstack::base::nova::db_pass'),
    $db_host = hiera('profile::openstack::base::nova::db_host'),
    $db_name = hiera('profile::openstack::base::nova::db_name'),
    $ldap_user_pass = hiera('profile::openstack::base::ldap_user_pass'),
    $libvirt_type = hiera('profile::openstack::base::nova::libvirt_type'),
    $live_migration_uri = hiera('profile::openstack::base::nova::live_migration_uri'),
    $rabbit_user = hiera('profile::openstack::base::nova::rabbit_user'),
    $rabbit_pass = hiera('profile::openstack::base::rabbit_pass'),
    $auth_port = hiera('profile::openstack::base::keystone::auth_port'),
    $public_port = hiera('profile::openstack::base::keystone::public_port'),
    $spice_hostname = hiera('profile::openstack::base::spice_hostname'),
    ) {

    $keystone_admin_uri = "http://${keystone_host}:${auth_port}"
    $keystone_auth_uri = "http://${keystone_host}:${public_port}"
    $nova_api_host_ip = ipresolve($nova_api_host,4)

    class {'::openstack::nova::common::nova_network':
        version                  => $version,
        nova_controller          => $nova_controller,
        keystone_host            => $keystone_host,
        nova_api_host            => $nova_api_host,
        nova_api_host_ip         => $nova_api_host_ip,
        dmz_cidr                 => $dmz_cidr,
        dhcp_domain              => $dhcp_domain,
        quota_floating_ips       => $quota_floating_ips,
        dhcp_start               => $dhcp_start,
        network_flat_interface   => $network_flat_interface,
        flat_network_bridge      => $flat_network_bridge,
        fixed_range              => $fixed_range,
        network_public_interface => $network_public_interface,
        network_public_ip        => $network_public_ip,
        zone                     => $zone,
        scheduler_pool           => $scheduler_pool,
        db_user                  => $db_user,
        db_pass                  => $db_pass,
        db_host                  => $db_host,
        db_name                  => $db_name,
        ldap_user_pass           => $ldap_user_pass,
        libvirt_type             => $libvirt_type,
        live_migration_uri       => $live_migration_uri,
        glance_host              => $nova_controller,
        rabbit_user              => $rabbit_user,
        rabbit_host              => $nova_controller,
        rabbit_pass              => $rabbit_pass,
        spice_hostname           => $spice_hostname,
        keystone_auth_uri        => $keystone_auth_uri,
        keystone_admin_uri       => $keystone_admin_uri,
    }
    contain '::openstack::nova::common::nova_network'
}
