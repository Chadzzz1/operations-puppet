# SPDX-License-Identifier: Apache-2.0

class openstack::barbican::service::yoga(
    Array[Stdlib::Fqdn] $openstack_controllers,
    String $db_user,
    String $db_pass,
    String $db_name,
    Stdlib::Fqdn $db_host,
    String $crypto_kek,
    String $ldap_user_pass,
    String $keystone_fqdn,
    Stdlib::Port $bind_port,
) {
    require "openstack::serverpackages::yoga::${::lsbdistcodename}"

    package { 'barbican-api':
        ensure => 'present',
    }

    $version = inline_template("<%= @title.split(':')[-1] -%>")
    $keystone_auth_username = 'novaadmin'
    $keystone_auth_project = 'admin'
    file {
        '/etc/barbican/barbican.conf':
            content   => template('openstack/yoga/barbican/barbican.conf.erb'),
            owner     => 'barbican',
            group     => 'barbican',
            mode      => '0440',
            show_diff => false,
            notify    => Service['barbican-api'],
            require   => Package['barbican-api'];
        '/etc/barbican/policy.yaml':
            source  => 'puppet:///modules/openstack/yoga/barbican/policy.yaml',
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            notify  => Service['barbican-api'],
            require => Package['barbican-api'];
        '/etc/init.d/barbican-api':
            owner   => 'root',
            group   => 'root',
            mode    => '0755',
            content => template('openstack/yoga/barbican/barbican-api.erb');
    }
}
