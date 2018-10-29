# Class: profile::toolforge::grid::node::compute::general
#
# This configures the compute node as a general node
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
# filtertags: toolforge
class profile::toolforge::grid::node::compute::general {

    include profile::toolforge::grid::node::compute

    class { '::sonofgridengine::exec_host':
        config  => 'profile/toolforge/grid/host-vmem.erb',
        require => File['/var/lib/gridengine'],
    }

    $hostlist = '@general'

    sonofgridengine::queue { 'continuous':
        config => 'profile/toolforge/grid/queue-continuous.erb',
    }

    sonofgridengine::queue { 'task':
        config => 'profile/toolforge/grid/queue-task.erb',
    }

    sonofgridengine::join { "hostgroups-${::fqdn}":
        sourcedir => "${profile::toolforge::grid::base::collectors}/hostgroups",
        list      => [ $hostlist ],
    }

    file { '/usr/local/bin/jobkill':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/profile/toolforge/jobkill',
    }

}

