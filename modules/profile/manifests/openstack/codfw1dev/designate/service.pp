class profile::openstack::codfw1dev::designate::service(
    $version = hiera('profile::openstack::codfw1dev::version'),
    Array[Stdlib::Fqdn] $designate_hosts = lookup('profile::openstack::codfw1dev::designate_hosts'),
    $nova_controller = hiera('profile::openstack::codfw1dev::nova_controller'),
    $nova_controller_standby = hiera('profile::openstack::codfw1dev::nova_controller_standby'),
    $keystone_host = hiera('profile::openstack::codfw1dev::keystone_host'),
    $puppetmaster_hostname = hiera('profile::openstack::codfw1dev::puppetmaster_hostname'),
    $db_pass = hiera('profile::openstack::codfw1dev::designate::db_pass'),
    $db_host = hiera('profile::openstack::codfw1dev::designate::db_host'),
    $domain_id_internal_forward = hiera('profile::openstack::codfw1dev::designate::domain_id_internal_forward'),
    $domain_id_internal_forward_legacy = hiera('profile::openstack::codfw1dev::designate::domain_id_internal_forward_legacy'),
    $domain_id_internal_reverse = hiera('profile::openstack::codfw1dev::designate::domain_id_internal_reverse'),
    $ldap_user_pass = hiera('profile::openstack::codfw1dev::ldap_user_pass'),
    $pdns_db_pass = hiera('profile::openstack::codfw1dev::designate::pdns_db_pass'),
    $pdns_api_key = lookup('profile::openstack::codfw1dev::pdns::api_key'),
    $db_admin_pass = hiera('profile::openstack::codfw1dev::designate::db_admin_pass'),
    $primary_pdns = hiera('profile::openstack::codfw1dev::pdns::host'),
    $secondary_pdns = hiera('profile::openstack::codfw1dev::pdns::host_secondary'),
    $rabbit_pass = hiera('profile::openstack::codfw1dev::nova::rabbit_pass'),
    $osm_host = hiera('profile::openstack::codfw1dev::osm_host'),
    $labweb_hosts = hiera('profile::openstack::codfw1dev::labweb_hosts'),
    $region = hiera('profile::openstack::codfw1dev::region'),
    $puppet_git_repo_name = lookup('profile::openstack::codfw1dev::horizon::puppet_git_repo_name'),
    $puppet_git_repo_user = lookup('profile::openstack::codfw1dev::horizon::puppet_git_repo_user'),
) {

    class{'::profile::openstack::base::designate::service':
        version                           => $version,
        designate_hosts                   => $designate_hosts,
        keystone_host                     => $keystone_host,
        db_pass                           => $db_pass,
        db_host                           => $db_host,
        domain_id_internal_forward        => $domain_id_internal_forward,
        domain_id_internal_forward_legacy => $domain_id_internal_forward_legacy,
        domain_id_internal_reverse        => $domain_id_internal_reverse,
        puppetmaster_hostname             => $puppetmaster_hostname,
        nova_controller                   => $nova_controller,
        nova_controller_standby           => $nova_controller_standby,
        ldap_user_pass                    => $ldap_user_pass,
        pdns_db_pass                      => $pdns_db_pass,
        pdns_api_key                      => $pdns_api_key,
        db_admin_pass                     => $db_admin_pass,
        primary_pdns                      => $primary_pdns,
        secondary_pdns                    => $secondary_pdns,
        rabbit_pass                       => $rabbit_pass,
        osm_host                          => $osm_host,
        labweb_hosts                      => $labweb_hosts,
        region                            => $region,
        puppet_git_repo_name              => $puppet_git_repo_name,
        puppet_git_repo_user              => $puppet_git_repo_user,
    }
    contain '::profile::openstack::base::designate::service'

    # Memcached for coordination between pool managers
    class { '::memcached':
    }

    class { '::profile::prometheus::memcached_exporter': }
}
