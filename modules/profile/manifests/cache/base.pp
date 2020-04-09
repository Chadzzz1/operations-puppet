# === Class profile::cache::base
#
# Sets up some common things for cache instances:
# - conftool
# - monitoring
# - logging/analytics
#
class profile::cache::base(
    $cache_cluster = hiera('cache::cluster'),
    $statsd_host = hiera('statsd'),
    $packages_version = hiera('profile::cache::base::packages_version', 'installed'),
    $purge_host_regex = hiera('profile::cache::base::purge_host_regex', ''),
    $purge_multicasts = hiera('profile::cache::base::purge_multicasts', ['239.128.0.112']),
    $logstash_host = hiera('logstash_host', undef),
    $logstash_syslog_port = hiera('logstash_syslog_port', undef),
    $logstash_json_lines_port = hiera('logstash_json_lines_port', undef),
    $log_slow_request_threshold = hiera('profile::cache::base::log_slow_request_threshold', '60.0'),
    $allow_iptables = hiera('profile::cache::base::allow_iptables', false),
    $performance_tweaks = hiera('profile::cache::base::performance_tweaks', true),
    $extra_trust = hiera('profile::cache::base::extra_trust', []),
    Optional[Hash[String, Integer]] $default_weights = lookup('profile::cache::base::default_weights', {'default_value' => undef}),
    Boolean $use_purged = lookup('profile::cache::base::use_purged', {'default_value' => false}),
) {
    require network::constants
    # NOTE: Add the public WMCS IP space when T209011 is done
    $wikimedia_nets = flatten(concat($::network::constants::aggregate_networks, '172.16.0.0/12'))
    $wikimedia_trust = flatten(concat($::network::constants::aggregate_networks, $extra_trust))

    # Needed profiles
    require ::profile::conftool::client
    require ::profile::prometheus::varnish_exporter
    require ::profile::prometheus::cadvisor_exporter
    require ::profile::standard
    require ::profile::base::systemd

    # FIXME: this cannot be required or it will cause a dependency cycle. It might be a good idea not to include it here
    include ::profile::cache::kafka::webrequest

    include ::profile::prometheus::varnishkafka_exporter

    # Globals we need to include
    include ::network::constants

    if ! $allow_iptables {
        # Prevent accidental iptables module loads
        kmod::blacklist { 'cp-bl':
            modules => ['x_tables'],
        }
    }

    # FIXME: Remove as soon as puppet runs on every cp node
    class { '::nginx':
        ensure => absent,
    }

    class { 'conftool::scripts': }

    if $performance_tweaks {
        # Only production needs system perf tweaks
        class { '::cpufrequtils': }
        class { 'cacheproxy::performance': }
    }
    # Basic varnish classes
    class { '::varnish::packages':
        version         => $packages_version,
    }

    class { '::varnish::common':
        log_slow_request_threshold => $log_slow_request_threshold,
        logstash_host              => $logstash_host,
        logstash_json_lines_port   => $logstash_json_lines_port,
    }

    class { [
        '::varnish::common::errorpage',
        '::varnish::common::browsersec',
        '::varnish::common::director_scripts',
    ]:
    }

    class { '::varnish::netmapper_update_common': }
    class { 'varnish::trusted_proxies': }

    ###########################################################################
    # Analytics/Logging stuff
    ###########################################################################
    class { '::varnish::logging':
        cache_cluster => $cache_cluster,
        statsd_host   => $statsd_host,
    }

    # auto-depool on shutdown + conditional one-shot auto-pool on start
    class { 'cacheproxy::traffic_pool': }

    ###########################################################################
    # Purging
    ###########################################################################
    if $use_purged {
        class { 'purged':
            backend_addr    => '127.0.0.1:3128',
            frontend_addr   => '127.0.0.1:3127',
            mc_addrs        => $purge_multicasts.map |$mc| { "${mc}:4827" },
            prometheus_addr => ':2112',
            concurrency     => $::processorcount,
        }
    } else {
        class { 'prometheus::node_vhtcpd': }
        class { 'varnish::htcppurger':
            host_regex => $purge_host_regex,
            mc_addrs   => $purge_multicasts,
            caches     => ['127.0.0.1:3128', '127.0.0.1:3127,1.0'],
        }
        Class[varnish::packages] -> Class[varnish::htcppurger]
    }

    # Node initialization script for conftool
    if $default_weights != undef {
        class { 'conftool::scripts::initialize':
            services => $default_weights,
        }
    }
}
