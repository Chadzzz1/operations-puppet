class openstack::glance::service::queens(
    $db_user,
    $db_pass,
    $db_name,
    $db_host,
    $glance_data,
    $ldap_user_pass,
    $keystone_admin_uri,
    $keystone_public_uri,
    Stdlib::Port $api_bind_port,
    Stdlib::Port $registry_bind_port,
) {
    require "openstack::serverpackages::queens::${::lsbdistcodename}"

    package { 'glance':
        ensure => 'present',
    }

    file {
        '/etc/glance/glance-api.conf':
            content   => template('openstack/queens/glance/glance-api.conf.erb'),
            owner     => 'glance',
            group     => 'nogroup',
            mode      => '0440',
            show_diff => false,
            notify    => Service['glance-api'],
            require   => Package['glance'];
        '/etc/glance/glance-registry.conf':
            content => template('openstack/queens/glance/glance-registry.conf.erb'),
            owner   => 'glance',
            group   => 'nogroup',
            mode    => '0440',
            notify  => Service['glance-registry'],
            require => Package['glance'];
        '/etc/glance/policy.json':
            ensure  => 'absent';
        '/etc/glance/policy.yaml':
            source  => 'puppet:///modules/openstack/queens/glance/policy.yaml',
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            notify  => Service['glance-api'],
            require => Package['glance'];
        '/etc/init.d/glance-api':
            content => template('openstack/queens/glance/glance-api'),
            owner   => 'root',
            group   => 'root',
            mode    => '0755',
            notify  => Service['glance-api'],
            require => Package['glance'];
    }
}
