class openstack::nova::api::service::queens
{
    # simple enough to don't require per-debian release split
    require "openstack::serverpackages::queens::${::lsbdistcodename}"

    package { 'nova-api':
        ensure => 'present',
    }

    # firstboot/user_data things:
    file { '/usr/lib/python3/dist-packages/wmfnovamiddleware':
        source  => 'puppet:///modules/openstack/queens/nova/api/wmfnovamiddleware',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        recurse => true,
    }
    file { '/etc/nova/userdata.txt':
        ensure  => 'present',
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        source  => 'puppet:///modules/openstack/nova/userdata.txt',
        require => Package['nova-api'],
    }
}
