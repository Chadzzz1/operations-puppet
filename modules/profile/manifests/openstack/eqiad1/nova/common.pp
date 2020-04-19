class profile::openstack::eqiad1::nova::common(
    $version = hiera('profile::openstack::eqiad1::version'),
    $region = hiera('profile::openstack::eqiad1::region'),
    $db_pass = hiera('profile::openstack::eqiad1::nova::db_pass'),
    $db_host = hiera('profile::openstack::eqiad1::nova::db_host'),
    $db_name = hiera('profile::openstack::eqiad1::nova::db_name'),
    $db_name_api = hiera('profile::openstack::eqiad1::nova::db_name_api'),
    $openstack_controllers = hiera('profile::openstack::eqiad1::openstack_controllers'),
    $keystone_host = hiera('profile::openstack::eqiad1::keystone_host'),
    $glance_host = hiera('profile::openstack::eqiad1::glance_host'),
    $ldap_user_pass = hiera('profile::openstack::eqiad1::ldap_user_pass'),
    $rabbit_pass = hiera('profile::openstack::eqiad1::nova::rabbit_pass'),
    $metadata_proxy_shared_secret = hiera('profile::openstack::eqiad1::neutron::metadata_proxy_shared_secret'),
    Stdlib::Port $metadata_listen_port = lookup('profile::openstack::eqiad1::nova::metadata_listen_port'),
    Stdlib::Port $osapi_compute_listen_port = lookup('profile::openstack::eqiad1::nova::osapi_compute_listen_port'),
    String       $dhcp_domain               = lookup('profile::openstack::eqiad1::nova::dhcp_domain',
                                                    {default_value => 'example.com'}),
    ) {

    require ::profile::openstack::eqiad1::clientpackages
    class {'::profile::openstack::base::nova::common':
        version                      => $version,
        region                       => $region,
        db_pass                      => $db_pass,
        db_host                      => $db_host,
        db_name                      => $db_name,
        db_name_api                  => $db_name_api,
        openstack_controllers        => $openstack_controllers,
        keystone_host                => $keystone_host,
        glance_host                  => $glance_host,
        ldap_user_pass               => $ldap_user_pass,
        rabbit_pass                  => $rabbit_pass,
        metadata_listen_port         => $metadata_listen_port,
        metadata_proxy_shared_secret => $metadata_proxy_shared_secret,
        osapi_compute_listen_port    => $osapi_compute_listen_port,
        dhcp_domain                  => $dhcp_domain,
    }
    contain '::profile::openstack::base::nova::common'
}
