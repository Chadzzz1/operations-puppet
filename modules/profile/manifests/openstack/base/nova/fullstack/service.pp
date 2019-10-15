class profile::openstack::base::nova::fullstack::service(
    $osstackcanary_pass = hiera('profile::openstack::base::nova::fullstack_pass'),
    $nova_api_host = hiera('profile::openstack::base::nova_api_host'),
    $region = hiera('profile::openstack::base::region'),
    $network = hiera('profile::openstack::base::nova::instance_network_id'),
    $puppetmaster = hiera('profile::openstack::base::puppetmaster_hostname'),
    ) {

    class { '::openstack::nova::fullstack::service':
        active       => ($::fqdn == $nova_api_host),
        password     => $osstackcanary_pass,
        region       => $region,
        network      => $network,
        puppetmaster => $puppetmaster,
    }
    contain '::openstack::nova::fullstack::service'
}
