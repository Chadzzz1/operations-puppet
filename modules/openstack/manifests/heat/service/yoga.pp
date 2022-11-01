# SPDX-License-Identifier: Apache-2.0

class openstack::heat::service::yoga(
    String $db_user,
    Array[Stdlib::Fqdn] $openstack_controllers,
    String $region,
    String $db_pass,
    String $db_name,
    Stdlib::Fqdn $db_host,
    String $ldap_user_pass,
    String $keystone_admin_uri,
    String $keystone_internal_uri,
    Stdlib::Port $api_bind_port,
    Stdlib::Port $cfn_api_bind_port,
    Array[Stdlib::Fqdn] $rabbitmq_nodes,
    String $rabbit_user,
    String $rabbit_pass,
    String[32] $auth_encryption_key,
    String $domain_admin_pass,
) {
    require "openstack::serverpackages::yoga::${::lsbdistcodename}"

    package { 'heat-api':
        ensure => 'present',
    }
    package { 'heat-api-cfn':
        ensure => 'present',
    }
    package { 'heat-engine':
        ensure => 'present',
    }

    file {
        '/etc/heat/heat.conf':
            content   => template('openstack/yoga/heat/heat.conf.erb'),
            owner     => 'heat',
            group     => 'heat',
            mode      => '0440',
            show_diff => false,
            notify    => Service['heat-api', 'heat-engine', 'heat-api-cfn'],
            require   => Package['heat-api', 'heat-engine', 'heat-api-cfn'];
        '/etc/heat/policy.yaml':
            source  => 'puppet:///modules/openstack/yoga/heat/policy.yaml',
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            notify  => Service['heat-api', 'heat-engine', 'heat-api-cfn'],
            require => Package['heat-api', 'heat-engine', 'heat-api-cfn'];
        '/etc/init.d/heat-api':
            owner   => 'root',
            group   => 'root',
            mode    => '0755',
            content => template('openstack/yoga/heat/heat-api.erb');
        '/etc/init.d/heat-api-cfn':
            owner   => 'root',
            group   => 'root',
            mode    => '0755',
            content => template('openstack/yoga/heat/heat-api-cfn.erb');
    }
}
