class profile::swift::storage (
    Array[String] $aux_partitions                    = lookup('swift_aux_partitions'),
    Array[String] $all_drives                        = lookup('swift_storage_drives'),
    Hash[String, Hash] $replication_accounts         = lookup('profile::swift::replication_accounts'),
    Hash[String, Hash] $replication_keys             = lookup('profile::swift::replication_keys'),
    String $hash_path_suffix                         = lookup('profile::swift::hash_path_suffix'),
    String $swift_cluster                            = lookup('profile::swift::cluster'),
    Array[String] $memcached_servers                 = lookup('swift::proxy::memcached_servers'),
    Array[Stdlib::Host] $swift_backends              = lookup('swift::storagehosts'),
    Array[Stdlib::Host] $swift_frontends             = lookup('swift::proxyhosts'),
    Stdlib::Port $statsd_port                        = lookup('profile::swift::storage::statsd_port'),
    Integer $container_replicator_concurrency        = lookup('profile::swift::storage::container_replicator_concurrency'),
    Integer $object_server_default_workers           = lookup('profile::swift::storage::object_server_default_workers'),
    Integer $object_replicator_concurrency           = lookup('profile::swift::storage::object_replicator_concurrency'),
    Optional[Integer] $object_replicator_interval    = lookup('profile::swift::storage::object_replicator_interval'),
    Optional[Integer] $servers_per_port              = lookup('profile::swift::storage::servers_per_port'),
    Optional[Stdlib::Host] $statsd_host              = lookup('profile::swift::storage::statsd_host'),
    Optional[Integer] $container_replicator_interval = lookup('profile::swift::storage::container_replicator_interval')
){

    class { 'swift':
        hash_path_suffix => $hash_path_suffix,
    }

    class { 'swift::ring':
        swift_cluster => $swift_cluster,
    }

    class { 'swift::storage':
        statsd_host                      => $statsd_host,
        statsd_port                      => $statsd_port,
        statsd_metric_prefix             => "swift.${swift_cluster}.${::hostname}",
        memcached_servers                => $memcached_servers,
        container_replicator_concurrency => $container_replicator_concurrency,
        object_server_default_workers    => $object_server_default_workers,
        object_replicator_concurrency    => $object_replicator_concurrency,
        object_replicator_interval       => $object_replicator_interval,
        servers_per_port                 => $servers_per_port,
        container_replicator_interval    => $container_replicator_interval,
    }

    class { 'swift::container_sync':
        accounts => $replication_accounts,
        keys     => $replication_keys,
    }

    nrpe::monitor_service { 'load_average':
        description  => 'very high load average likely xfs',
        nrpe_command => '/usr/lib/nagios/plugins/check_load -w 80,80,80 -c 200,100,100',
        notes_url    => 'https://wikitech.wikimedia.org/wiki/Swift',
    }

    swift::init_device { $all_drives:
        partition_nr => '1',
    }

    $swift_access = concat($swift_backends, $swift_frontends)
    $swift_access_ferm = join($swift_access, ' ')
    $swift_rsync_access_ferm = join($swift_backends, ' ')

    # Optimize ferm rule aggregating all ports, it includes:
    # - base object server (6000)
    # - container server (6001)
    # - account server (6002)
    # - per-disk object-server ports T222366 (6010:6040)
    ferm::service { 'swift-object-server':
        proto   => 'tcp',
        port    => '(6000:6002 6010:6040)',
        notrack => true,
        srange  => "@resolve((${swift_access_ferm}))",
    }

    ferm::service { 'swift-rsync':
        proto   => 'tcp',
        port    => '873',
        notrack => true,
        srange  => "@resolve((${swift_rsync_access_ferm}))",
    }

    # these are already partitioned and xfs formatted by the installer
    swift::label_filesystem { $aux_partitions: }
    swift::mount_filesystem { $aux_partitions: }
}
