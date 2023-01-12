class profile::thumbor(
    Array[Stdlib::Host] $memcached_servers = lookup('thumbor_memcached_servers'),
    Array[String] $memcached_servers_nutcracker = lookup('thumbor_memcached_servers_nutcracker'),
    Stdlib::Port $logstash_port = lookup('logstash_logback_port'),
    Array[String] $swift_sharded_containers = lookup('profile::swift::proxy::shard_container_list', {'merge' => 'unique'}),
    Array[String] $swift_private_containers = lookup('profile::swift::proxy::private_container_list', {'merge' => 'unique'}),
    String $thumbor_mediawiki_shared_secret = lookup('thumbor::mediawiki::shared_secret'),
    Stdlib::Port $statsd_port = lookup('statsd_exporter_port'),
    Hash[String, Hash] $global_swift_account_keys = lookup('profile::swift::global_account_keys'),
){
    require profile::base::memory_cgroup
    include ::profile::conftool::client
    class { 'conftool::scripts': }

    class { '::thumbor::nutcracker':
        thumbor_memcached_servers => $memcached_servers_nutcracker,
    }

    # rsyslog forwards json messages sent to localhost along to logstash via kafka
    class { '::profile::rsyslog::udp_json_logback_compat':
        port => $logstash_port,
    }

    class { '::thumbor':
        logstash_host => 'localhost',
        logstash_port => $logstash_port,
        statsd_port   => $statsd_port,
    }

    # Get the local site's swift credentials
    $swift_account_keys = $global_swift_account_keys[$::site]
    class { '::thumbor::swift':
        swift_key                       => $swift_account_keys['mw_thumbor'],
        swift_private_key               => $swift_account_keys['mw_thumbor-private'],
        swift_sharded_containers        => $swift_sharded_containers,
        swift_private_containers        => $swift_private_containers,
        thumbor_mediawiki_shared_secret => $thumbor_mediawiki_shared_secret,
    }

    ferm::service { 'thumbor':
        proto  => 'tcp',
        port   => '8800',
        srange => '$DOMAIN_NETWORKS',
    }

    $thumbor_memcached_servers_ferm = join($memcached_servers, ' ')

    ferm::service { 'memcached_memcached_role':
        proto  => 'tcp',
        port   => '11211',
        srange => "(@resolve((${thumbor_memcached_servers_ferm})))",
    }
}
