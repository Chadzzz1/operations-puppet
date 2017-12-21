# The IPs of the servers allowed to populate dumps ($dump_servers_ips),
# and IPs of maps instances where the maps nfs share is to be mounted
# ($maps_project_internal_ips) must be set at the node level or via hiera.
#

class role::labs::nfs::misc(
    $dump_servers_ips,
    $maps_project_internal_ips,
    $statistics_servers = hiera('statistics_servers'),
    ) {

    system::role { 'labs::nfs::misc':
        description => 'Labs NFS service (misc)',
    }

    include ::standard
    include labstore
    include rsync::server
    include labstore::backup_keys
    include labstore::monitoring::interfaces
    include labstore::monitoring::nfsd
    # to be included post ldap integration
    # include labstore::monitoring::ldap

    # for cleanup of old xmldumps, other datasets
    # copied over from dataset1001. this should
    # not be carried over to the new labstore6,7
    # servers, they have cleanups already added
    # in the role
    include ::profile::dumps::web::cleanup
    include ::profile::dumps::web::dumpsuser

    rsync::server::module { 'pagecounts':
        path        => '/srv/dumps/pagecounts',
        read_only   => 'no',
        hosts_allow => $dump_servers_ips,
    }

    rsync::server::module { 'dumps':
        path        => '/srv/dumps',
        read_only   => 'no',
        hosts_allow => $dump_servers_ips,
    }


    # This also exports /srv/statistics to allow statistics servers
    # a way to rsync public data in from production.
    rsync::server::module { 'statistics':
        path        => '/srv/statistics',
        read_only   => 'no',
        hosts_allow => $statistics_servers,
        require     => File['/srv/statistics']
    }

    # This has a flat exports list
    # because it only exports data
    # available to all
    file { '/etc/exports':
        ensure  => present,
        content => template('labstore/exports.labs_extras.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
    }

    file { '/srv/scratch':
        ensure => 'directory',
    }

    file { '/srv/dumps':
        ensure => 'directory',
    }

    file { '/srv/statistics':
        ensure => 'directory',
    }

    file {'/srv/maps':
        ensure => 'directory',
    }

    mount { '/srv/dumps':
        ensure  => mounted,
        fstype  => ext4,
        options => 'defaults,noatime',
        atboot  => true,
        device  => '/dev/srv/dumps',
        require => File['/srv/dumps'],
    }

    mount { '/srv/scratch':
        ensure  => mounted,
        fstype  => ext4,
        options => 'defaults,noatime',
        atboot  => true,
        device  => '/dev/srv/scratch',
        require => File['/srv/scratch'],
    }

    mount { '/srv/statistics':
        ensure  => mounted,
        fstype  => ext4,
        options => 'defaults,noatime',
        atboot  => true,
        device  => '/dev/srv/statistics/',
        require => File['/srv/statistics'],
    }

    mount { '/srv/maps':
        ensure  => mounted,
        fstype  => ext4,
        options => 'defaults,noatime',
        atboot  => true,
        device  => '/dev/srv/maps/',
        require => File['/srv/maps'],
    }

    # this is how prod hosts drop off datasets for serving
    ferm::rule{'puppetbackendgetter':
        ensure => 'present',
        rule   => "saddr (@resolve((${dump_servers_ips})) @resolve((${statistics_servers})))
                   proto tcp dport 873 ACCEPT;",
    }
}
