# keystone is the identity service of openstack
# http://docs.openstack.org/developer/keystone/

class openstack::keystone::service(
    $active,
    $version,
    $token_driver,
    $controller_hosts,
    $osm_host,
    $db_name,
    $db_user,
    $db_pass,
    $db_host,
    $public_workers,
    $admin_workers,
    $ldap_hosts,
    $ldap_base_dn,
    $ldap_rw_host,
    $ldap_user_id_attribute,
    $ldap_user_name_attribute,
    $ldap_user_dn,
    $ldap_user_pass,
    $region,
    $keystone_admin_uri,
    $wiki_status_page_prefix,
    $wiki_status_consumer_token,
    $wiki_status_consumer_secret,
    $wiki_status_access_token,
    $wiki_status_access_secret,
    $wiki_consumer_token,
    $wiki_consumer_secret,
    $wiki_access_token,
    $wiki_access_secret,
    String $wsgi_server,
    Stdlib::IP::Address::V4::CIDR $instance_ip_range,
    String $wmcloud_domain_owner,
    String $bastion_project_id,
    Array[String] $prod_networks,
    Array[String] $labs_networks,
    Boolean $enforce_policy_scope,
    Boolean $enforce_new_policy_defaults,
    Stdlib::Port $public_bind_port,
    Stdlib::Port $admin_bind_port,
    Array[Stdlib::IP::Address::V4::Nosubnet] $prometheus_metricsinfra_reserved_ips,
    Array[Stdlib::Port] $prometheus_metricsinfra_default_ports,
) {
    class { "openstack::keystone::service::${version}":
        controller_hosts                      => $controller_hosts,
        osm_host                              => $osm_host,
        db_name                               => $db_name,
        db_user                               => $db_user,
        db_pass                               => $db_pass,
        db_host                               => $db_host,
        admin_workers                         => $admin_workers,
        public_workers                        => $public_workers,
        ldap_hosts                            => $ldap_hosts,
        ldap_rw_host                          => $ldap_rw_host,
        ldap_base_dn                          => $ldap_base_dn,
        ldap_user_id_attribute                => $ldap_user_id_attribute,
        ldap_user_name_attribute              => $ldap_user_name_attribute,
        ldap_user_dn                          => $ldap_user_dn,
        ldap_user_pass                        => $ldap_user_pass,
        region                                => $region,
        keystone_admin_uri                    => $keystone_admin_uri,
        wiki_status_page_prefix               => $wiki_status_page_prefix,
        wiki_status_consumer_token            => $wiki_status_consumer_token,
        wiki_status_consumer_secret           => $wiki_status_consumer_secret,
        wiki_status_access_token              => $wiki_status_access_token,
        wiki_status_access_secret             => $wiki_status_access_secret,
        wiki_consumer_token                   => $wiki_consumer_token,
        wiki_consumer_secret                  => $wiki_consumer_secret,
        wiki_access_token                     => $wiki_access_token,
        wiki_access_secret                    => $wiki_access_secret,
        wsgi_server                           => $wsgi_server,
        instance_ip_range                     => $instance_ip_range,
        wmcloud_domain_owner                  => $wmcloud_domain_owner,
        bastion_project_id                    => $bastion_project_id,
        prod_networks                         => $prod_networks,
        labs_networks                         => $labs_networks,
        enforce_policy_scope                  => $enforce_policy_scope,
        enforce_new_policy_defaults           => $enforce_new_policy_defaults,
        public_bind_port                      => $public_bind_port,
        admin_bind_port                       => $admin_bind_port,
        prometheus_metricsinfra_reserved_ips  => $prometheus_metricsinfra_reserved_ips,
        prometheus_metricsinfra_default_ports => $prometheus_metricsinfra_default_ports,
    }

    group { 'keystone':
        ensure  => 'present',
        require => Package['keystone'],
    }

    user { 'keystone':
        ensure  => 'present',
        require => Package['keystone'],
    }

    if $token_driver == 'redis' {
        package { 'python-keystone-redis':
            ensure => 'present';
        }
    }

    $require = [
        Package['keystone'],
        Group['keystone'],
        User['keystone'],
    ]

    file {
        '/var/log/keystone':
            ensure  => 'directory',
            owner   => 'keystone',
            group   => 'keystone',
            mode    => '0775',
            require => $require;
        '/etc/keystone':
            ensure  => 'directory',
            owner   => 'keystone',
            group   => 'keystone',
            mode    => '0755',
            require => $require,
    }

}
