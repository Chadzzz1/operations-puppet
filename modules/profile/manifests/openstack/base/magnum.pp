# SPDX-License-Identifier: Apache-2.0

class profile::openstack::base::magnum(
    String $version = lookup('profile::openstack::base::version'),
    Boolean $active = lookup('profile::openstack::base::magnum::active'),
    Array[Stdlib::Fqdn] $openstack_controllers = lookup('profile::openstack::base::openstack_controllers'),
    Array[Stdlib::Fqdn] $rabbitmq_nodes = lookup('profile::openstack::base::rabbitmq_nodes'),
    Stdlib::Fqdn $keystone_fqdn = lookup('profile::openstack::base::keystone_api_fqdn'),
    String $region = lookup('profile::openstack::base::region'),
    String $db_user = lookup('profile::openstack::base::magnum::db_user'),
    String $db_name = lookup('profile::openstack::base::magnum::db_name'),
    String $db_pass = lookup('profile::openstack::base::magnum::db_pass'),
    String $ldap_user_pass = lookup('profile::openstack::base::magnum::service_user_pass'),
    String $domain_admin_pass = lookup('profile::openstack::base::magnum::domain_admin_pass'),
    Stdlib::Fqdn $db_host = lookup('profile::openstack::base::magnum::db_host'),
    Stdlib::Port $api_bind_port = lookup('profile::openstack::base::magnum::api_bind_port'),
    String $rabbit_user = lookup('profile::openstack::base::magnum::rabbit_user'),
    String $rabbit_pass = lookup('profile::openstack::base::magnum::rabbit_pass'),
    Boolean $enforce_policy_scope = lookup('profile::openstack::base::keystone::enforce_policy_scope'),
    Boolean $enforce_new_policy_defaults = lookup('profile::openstack::base::keystone::enforce_new_policy_defaults'),
    Array[Stdlib::Fqdn] $haproxy_nodes = lookup('profile::openstack::base::haproxy_nodes'),
) {
    class { '::openstack::magnum::service':
        version                     => $version,
        openstack_controllers       => $openstack_controllers,
        rabbitmq_nodes              => $rabbitmq_nodes,
        keystone_fqdn               => $keystone_fqdn,
        db_user                     => $db_user,
        db_pass                     => $db_pass,
        db_name                     => $db_name,
        db_host                     => $db_host,
        api_bind_port               => $api_bind_port,
        ldap_user_pass              => $ldap_user_pass,
        rabbit_user                 => $rabbit_user,
        rabbit_pass                 => $rabbit_pass,
        region                      => $region,
        domain_admin_pass           => $domain_admin_pass,
        enforce_policy_scope        => $enforce_policy_scope,
        enforce_new_policy_defaults => $enforce_new_policy_defaults,
    }

    include ::network::constants
    $prod_networks = join($network::constants::production_networks, ' ')
    $labs_networks = join($network::constants::labs_networks, ' ')

    ferm::service { 'magnum-api-backend':
        proto  => 'tcp',
        port   => $api_bind_port,
        srange => "@resolve((${haproxy_nodes.join(' ')}))",
    }

    # TODO: move to haproxy/cloudlb profiles
    ferm::service { 'magnum-api-access':
        proto  => 'tcp',
        port   => 29511,
        srange => "(${prod_networks} ${labs_networks})",
    }

    openstack::db::project_grants { 'magnum':
        access_hosts => $openstack_controllers,
        db_name      => $db_name,
        db_user      => $db_user,
        db_pass      => $db_pass,
    }
}
