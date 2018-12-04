# Establish the gridengine master role (one per cluster)

class profile::toolforge::grid::master (
    $etcdir = hiera('profile::toolforge::etcdir'),
    $sge_root = lookup('profile::toolforge::grid::base::sge_root'),
    $geconf = lookup('profile::toolforge::grid::base::geconf'),
    $collectors = lookup('profile::toolforge::grid::base::collectors'),
){
    include profile::openstack::main::clientpackages
    include profile::openstack::main::observerenv
    include profile::toolforge::infrastructure

    $hostlist = '@general'

    sonofgridengine::queue { 'task':
        config => 'profile/toolforge/grid/queue-task.erb',
    }

    sonofgridengine::queue { 'continuous':
        config => 'profile/toolforge/grid/queue-continuous.erb',
    }

    sonofgridengine::checkpoint { 'continuousckpt':
        config => 'profile/toolforge/grid/ckpt-continuous.erb',
    }

    file { "${collectors}/hostgroups":
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { "${collectors}/queues":
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    sonofgridengine::collectors::hostgroups { '@general':
        store => "${collectors}/hostgroups",
    }

    sonofgridengine::collectors::queues { 'webgrid-lighttpd':
        store  => "${collectors}/queues",
        config => 'toollabs/gridengine/queue-webgrid.erb',
    }

    sonofgridengine::collectors::queues { 'webgrid-generic':
        store  => "${collectors}/queues",
        config => 'toollabs/gridengine/queue-webgrid.erb',
    }


    # These things are done on toollabs::master because they
    # need to be done exactly once per project (they live on the
    # shared filesystem), and there can only be exactly one
    # gridmaster in this setup.  They could have been done on
    # any singleton instance.


    # Make sure that old-style fqdn for nodes are still understood
    # in this new-style fqdn environment by making aliases for the
    # nodes that existed before the change:
    # UPDATE: commented out because all of the aliases are for old hosts.
    # file { '/var/lib/gridengine/default/common/host_aliases':
    #     ensure  => file,
    #     owner   => 'root',
    #     group   => 'root',
    #     mode    => '0444',
    #     source  => 'puppet:///modules/profile/toolforge/host_aliases',
    #     require => File['/var/lib/gridengine'],
    # }


    file { '/usr/local/bin/dequeugridnodes.sh':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/profile/toolforge/gridscripts/dequeuegridnodes.sh',
    }
    file { '/usr/local/bin/requeugridnodes.sh':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/profile/toolforge/gridscripts/requeuegridnodes.sh',
    }
    file { '/usr/local/bin/runninggridtasks.py':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/profile/toolforge/gridscripts/runninggridtasks.py',
    }
    file { '/usr/local/bin/runninggridjobsmail.py':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/profile/toolforge/gridscripts/runninggridjobsmail.py',
    }

    file { "${geconf}/spool":
        ensure  => directory,
        owner   => 'sgeadmin',
        group   => 'sgeadmin',
        require => File[$geconf],
    }

    file { '/var/spool/gridengine':
        ensure  => link,
        target  => "${geconf}/spool",
        force   => true,
        require => File["${geconf}/spool"],
    }

    file { '/var/spool/gridengine/qmaster':
        ensure  => directory,
        owner   => 'sgeadmin',
        group   => 'sgeadmin',
        require => File[$geconf],
    }

    file { '/var/spool/gridengine/spooldb':
        ensure  => directory,
        owner   => 'sgeadmin',
        group   => 'sgeadmin',
        require => File[$geconf],
    }

    class { '::sonofgridengine::master':
        etcdir  => $etcdir,
    }

    file { "${geconf}/default/common/shadow_masters":
        ensure => present,
        owner  => 'sgeadmin',
        group  => 'sgeadmin',
        mode   => '0555',
    } -> file_line { 'shadow_masters':
        ensure => present,
        line   => $facts['fqdn'],
        path   => "${geconf}/default/common/shadow_masters",
    }

    # This must only run on install
    exec { 'initialize-grid-database':
        command  => "/usr/share/gridengine/scripts/init_cluster ${sge_root} default /var/spool/gridengine/spooldb sgeadmin",
        require  => File['/var/spool/gridengine', "${geconf}/spool"],
        creates  => '/var/spool/gridengine/spooldb/sge',
        user     => 'sgeadmin',
        provider => 'shell',
    }
}
