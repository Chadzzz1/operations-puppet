class openstack::keystone::service::pike(
    $keystone_host,
    $controller_hosts,
    $osm_host,
    $db_name,
    $db_user,
    $db_pass,
    $db_host,
    $db_max_pool_size,
    $public_workers,
    $admin_workers,
    $ldap_hosts,
    $ldap_base_dn,
    $ldap_user_id_attribute,
    $ldap_user_name_attribute,
    $ldap_user_dn,
    $ldap_user_pass,
    $region,
    $auth_protocol,
    $auth_port,
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
) {
    class { "openstack::keystone::service::pike::${::lsbdistcodename}": }

    include ::network::constants
    $prod_networks = $network::constants::production_networks
    $labs_networks = $network::constants::labs_networks

    file {
        '/etc/logrotate.d/keystone':
            ensure  => 'present',
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            source  => 'puppet:///modules/openstack/pike/keystone/keystone_logrotate',
            require => Package['keystone'];
        '/etc/keystone/keystone.conf':
            ensure    => 'present',
            owner     => 'keystone',
            group     => 'keystone',
            mode      => '0444',
            show_diff => false,
            content   => template('openstack/pike/keystone/keystone.conf.erb'),
            notify    => Service[$wsgi_server],
            require   => Package['keystone'];
        '/etc/keystone/keystone-paste.ini':
            ensure  => 'present',
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            source  => 'puppet:///modules/openstack/pike/keystone/keystone-paste.ini',
            notify  => Service[$wsgi_server],
            require => Package['keystone'];
        '/etc/keystone/policy.json':
            ensure  => 'present',
            mode    => '0644',
            owner   => 'root',
            group   => 'root',
            source  => 'puppet:///modules/openstack/pike/keystone/policy.json',
            notify  => Service[$wsgi_server],
            require => Package['keystone'];
        '/etc/keystone/logging.conf':
            ensure  => 'present',
            source  => 'puppet:///modules/openstack/pike/keystone/logging.conf',
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            notify  => Service[$wsgi_server],
            require => Package['keystone'];
        '/etc/keystone/keystone.my.cnf':
            ensure    => 'present',
            owner     => 'root',
            group     => 'root',
            mode      => '0400',
            show_diff => false,
            content   => template('openstack/pike/keystone/keystone.my.cnf.erb');
        '/usr/lib/python2.7/dist-packages/wmfkeystoneauth':
            ensure  => 'present',
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            source  => 'puppet:///modules/openstack/pike/keystone/wmfkeystoneauth',
            notify  => Service[$wsgi_server],
            recurse => true;
        '/usr/lib/python2.7/dist-packages/wmfkeystoneauth.egg-info':
            ensure  => 'present',
            source  => 'puppet:///modules/openstack/pike/keystone/wmfkeystoneauth.egg-info',
            owner   => 'root',
            group   => 'root',
            mode    => '0644',
            notify  => Service[$wsgi_server],
            recurse => true;
        '/usr/bin/keystone-wsgi-admin.py':
            ensure  => 'present',
            owner   => 'root',
            group   => 'root',
            mode    => '0755',
            source  => 'puppet:///modules/openstack/pike/keystone/keystone-wsgi-admin.py',
            notify  => Service[$wsgi_server],
            require => Package['keystone'];
    }
}
