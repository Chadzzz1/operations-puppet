# filtertags: labs-project-deployment-prep labs-project-swift
class role::swift::proxy (
    $use_tls = hiera('role::swift::proxy::use_tls', false),
    $accounts = lookup('profile::swift::accounts'), # lint:ignore:wmf_styleguide
    $accounts_keys = lookup('profile::swift::accounts_keys'), # lint:ignore:wmf_styleguide
    Hash[String, Hash] $replication_accounts = lookup('profile::swift::replication_accounts'), # lint:ignore:wmf_styleguide
    Hash[String, Hash] $replication_keys = lookup('profile::swift::replication_keys'), # lint:ignore:wmf_styleguide
    String $hash_path_suffix = lookup('profile::swift::hash_path_suffix'), # lint:ignore:wmf_styleguide
    String $stats_reporter_host = lookup('profile::swift::stats_reporter_host'), # lint:ignore:wmf_styleguide
) {
    system::role { 'swift::proxy':
        description => 'swift frontend proxy',
    }

    $swift_cluster = lookup('profile::swift::cluster') # lint:ignore:wmf_styleguide

    include ::profile::standard
    include ::profile::base::firewall

    class { '::swift':
        hash_path_suffix => $hash_path_suffix,
    }

    class { '::swift::container_sync':
        accounts => $replication_accounts,
        keys     => $replication_keys,
    }

    class { '::swift::ring':
        swift_cluster => $swift_cluster,
    }

    include ::profile::conftool::client
    class { 'conftool::scripts': }

    $stats_ensure = $stats_reporter_host == $::fqdn ? {
        true  => present,
        false => absent,
    }

    class { '::profile::swift::stats_reporter':
        ensure        => $stats_ensure,
        swift_cluster => $swift_cluster,
        accounts      => $accounts,
        credentials   => $accounts_keys,
    }

    swift::stats::stats_container { 'mw-media':
        ensure        => $stats_ensure,
        account_name  => 'AUTH_mw',
        container_set => 'mw-media',
        statsd_prefix => "swift.${swift_cluster}.containers.mw-media",
    }

    class { '::swift::proxy':
        statsd_metric_prefix => "swift.${swift_cluster}.${::hostname}",
        accounts             => $accounts,
        credentials          => $accounts_keys,
    }

    if $use_tls {
        include ::profile::swift::proxy_tls
    }

    class { '::memcached':
        size => 128,
        port => 11211,
    }

    include ::profile::prometheus::memcached_exporter

    include ::profile::statsite
    class { '::profile::prometheus::statsd_exporter':
        relay_address => '',
    }

    ferm::service { 'swift-proxy':
        proto   => 'tcp',
        notrack => true,
        port    => '80',
    }

    ferm::client { 'swift-object-server-client':
        proto   => 'tcp',
        notrack => true,
        port    => '6000',
    }

    # Per-disk object-server ports T222366
    range(6010, 6030).each |$port| {
        ferm::client { "swift-object-server-client-${port}":
            proto   => 'tcp',
            notrack => true,
            port    => $port,
        }
    }

    ferm::client { 'swift-container-server-client':
        proto   => 'tcp',
        notrack => true,
        port    => '6001',
    }

    ferm::client { 'swift-account-server-client':
        proto   => 'tcp',
        notrack => true,
        port    => '6002',
    }

    $swift_backends = hiera('swift::storagehosts')
    $swift_frontends = hiera('swift::proxyhosts')
    $swift_access = concat($swift_backends, $swift_frontends)
    $swift_access_ferm = join($swift_access, ' ')

    ferm::service { 'swift-memcached':
        proto   => 'tcp',
        port    => '11211',
        notrack => true,
        srange  => "@resolve((${swift_access_ferm}))",
    }

    $http_s = $use_tls ? {
        true  => 'https',
        false => 'http',
    }
    monitoring::service { "swift-${http_s}-frontend":
        description   => "Swift ${http_s} frontend",
        check_command => "check_${http_s}_url!${::swift::proxy::proxy_service_host}!/monitoring/frontend",
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Swift',
    }
    monitoring::service { "swift-${http_s}-backend":
        description   => "Swift ${http_s} backend",
        check_command => "check_${http_s}_url!${::swift::proxy::proxy_service_host}!/monitoring/backend",
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Swift',
    }
}
