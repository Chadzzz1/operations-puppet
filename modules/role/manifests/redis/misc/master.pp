class role::redis::misc::master {
    include ::standard
    include ::profile::base::firewall

    # maxmemory depends on host's total memory
    $per_instance_memory = floor($facts['memorysize_mb'] * 0.8 / 5)

    include ::profile::redis::master

    system::role { 'redis::misc::master':
        description => 'Redis Misc master',
    }
}
