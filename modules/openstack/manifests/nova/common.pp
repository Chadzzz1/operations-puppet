class openstack::nova::common(
    $version,
    $region,
    $db_user,
    $db_pass,
    $db_host,
    $db_name,
    $db_name_api,
    $nova_controller,
    $controller_hosts,
    $keystone_host,
    $scheduler_filters,
    $ldap_user_pass,
    $rabbit_user,
    $rabbit_primary_host,
    $rabbit_secondary_host,
    $rabbit_pass,
    $glance_host,
    $metadata_proxy_shared_secret,
    $compute_workers,
    $metadata_workers,
    Stdlib::Port $metadata_listen_port,
    Stdlib::Port $osapi_compute_listen_port,
    String       $dhcp_domain,
    ) {

    class { "openstack::nova::common::${version}::${::lsbdistcodename}": }

    # For some reason the Mitaka nova-common package installs
    #  a logrotate rule for nova/*.log and also a nova/nova-manage.log.
    #  This is redundant and makes log-rotate unhappy.
    # Not to mention, nova-manage.log is very low traffic and doesn't
    #  really need to be rotated anyway.
    file { '/etc/logrotate.d/nova-manage':
        ensure  => 'absent',
        require => Package['nova-common'],
    }

    file { '/etc/nova/policy.json':
        ensure => absent,
    }

    file { '/etc/nova/policy.yaml':
        source  => "puppet:///modules/openstack/${version}/nova/common/policy.yaml",
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        require => Package['nova-common'],
    }

    file {
        '/etc/nova/nova.conf':
            content   => template("openstack/${version}/nova/common/nova.conf.erb"),
            owner     => 'nova',
            group     => 'nogroup',
            mode      => '0440',
            show_diff => false,
            require   => Package['nova-common'];
        '/etc/nova/api-paste.ini':
            content => template("openstack/${version}/nova/common/api-paste.ini.erb"),
            owner   => 'nova',
            group   => 'nogroup',
            mode    => '0440',
            require => Package['nova-common'];
        '/etc/nova/vendor_data.json':
            content => template('openstack/nova/vendor_data.json.erb'),
            owner   => 'nova',
            group   => 'nogroup',
            mode    => '0444',
            require => Package['nova-common'];
    }

    # Overlay a tooz driver that has an encoding bug.  This bug is present
    #  in version of this package found in the rocky apt repo, 1.62.0-1~bpo9+1.
    #  It is likely fixed in any future version, so this should probably not be
    #  forwarded to S.
    #
    # Upstream bug: https://bugs.launchpad.net/python-tooz/+bug/1530888
    file { '/usr/lib/python3/dist-packages/tooz/drivers/memcached.py':
        ensure => 'present',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
        source => 'puppet:///modules/openstack/rocky/toozpatch/tooz-memcached.py';
    }
}
