# Class profile::mcrouter_wancache
#
# Configures a mcrouter instance for multi-datacenter caching
class profile::mediawiki::mcrouter_wancache(
    Stdlib::Port $port                 = lookup('profile::mediawiki::mcrouter_wancache::port'),
    Boolean      $has_ssl              = lookup('profile::mediawiki::mcrouter_wancache::has_ssl'),
    Stdlib::Port $ssl_port             = lookup('profile::mediawiki::mcrouter_wancache::ssl_port'),
    Integer      $num_proxies          = lookup('profile::mediawiki::mcrouter_wancache::num_proxies'),
    Integer      $timeouts_until_tko   = lookup('profile::mediawiki::mcrouter_wancache::timeouts_until_tko'),
    Integer      $gutter_ttl           = lookup('profile::mediawiki::mcrouter_wancache::gutter_ttl'),
    Boolean      $use_onhost_memcached = lookup('profile::mediawiki::mcrouter_wancache::use_onhost_memcached'),
    Boolean      $prometheus_exporter  = lookup('profile::mediawiki::mcrouter_wancache::prometheus_exporter'),
    Hash         $servers_by_datacenter_category = lookup('profile::mediawiki::mcrouter_wancache::shards'),
) {

    $servers_by_datacenter = $servers_by_datacenter_category['wancache']
    $proxies_by_datacenter = pick($servers_by_datacenter_category['proxies'], {})
    if $use_onhost_memcached {
        # TODO: Consider using a unix socket instead of a loopback address.
        $onhost_pool = profile::mcrouter_pools('onhost', {'' => {'host' => '127.0.0.1', 'port' => 11211}})
    } else {
        $onhost_pool = {}
    }
    # We only need to configure the gutter pool for DC-local routes. Remote-DC
    # routes are reached via an mcrouter proxy in that dc, that will be
    # configured to use its gutter pool itself.
    $local_gutter_pool = profile::mcrouter_pools('gutter', $servers_by_datacenter_category['gutter'][$::site])

    $pools = $servers_by_datacenter.map |$region, $servers| {
        # We need to get the servers from the current datacenter, and the proxies from the others
        if $region == $::site {
            profile::mcrouter_pools($region, $servers)
        } else {
            profile::mcrouter_pools($region, $proxies_by_datacenter[$region])
        }
    }
    .reduce($onhost_pool + $local_gutter_pool) |$memo, $value| { $memo + $value }

    $routes = union(
        # local cache for each region
        $servers_by_datacenter.map |$region, $servers| {
            {
                'aliases' => [ "/${region}/mw/" ],
                'route' => profile::mcrouter_route($region, $gutter_ttl)  # @TODO: force $::site like mw-wan default?
            }
        },
        # WAN cache: issues reads and add/cas/touch locally and issues set/delete everywhere.
        # MediaWiki will set a prefix of /*/mw-wan when broadcasting, explicitly matching
        # all the mw-wan routes. Broadcasting is thus completely controlled by MediaWiki,
        # but is only allowed for set/delete operations.
        $servers_by_datacenter.map |$region, $servers| {
            {
                'aliases' => [ "/${region}/mw-wan/" ],
                'route'   => {
                    'type'               => 'OperationSelectorRoute',
                    'default_policy'     => profile::mcrouter_route($::site, $gutter_ttl), # We want reads to always be local!
                    # AllAsyncRoute is used by mcrouter when replicating data to the non-active DC:
                    # https://github.com/facebook/mcrouter/wiki/List-of-Route-Handles#allasyncroute
                    # More info in T225642
                    'operation_policies' => {
                        'set'    => {
                            'type'     => $region ? {
                                $::site => 'AllSyncRoute',
                                default => 'AllAsyncRoute'
                            },
                            'children' => [ profile::mcrouter_route($region, $gutter_ttl) ]
                        },
                        'delete' => {
                            'type'     => $region ? {
                                $::site => 'AllSyncRoute',
                                default => 'AllAsyncRoute'
                            },
                            'children' => [ profile::mcrouter_route($region, $gutter_ttl) ]
                        },
                    }
                }
            }
        },
        # On-host memcache tier: Keep a short-lived local cache to reduce network load for very hot
        # keys, at the cost of a few seconds' staleness.
        $servers_by_datacenter.map |$region, $servers| {
            {
                'aliases' => [ "/${region}/mw-with-onhost-tier/" ],
                'route'   => $use_onhost_memcached ? {
                    true  => {
                        'type'               => 'OperationSelectorRoute',
                        'operation_policies' => {
                            # For reads, use WarmupRoute to try on-host memcache first. If it's not
                            # there, WarmupRoute tries the ordinary regional pool next, and writes the
                            # result back to the on-host cache, with a short expiration time. The
                            # exptime is ten seconds in order to match our tolerance for DB replication
                            # delay; that level of staleness is acceptable. Based on
                            # https://github.com/facebook/mcrouter/wiki/Two-level-caching#local-instance-with-small-ttl
                            'get' => {
                                'type'    => 'WarmupRoute',
                                'cold'    => 'PoolRoute|onhost',
                                'warm'    => profile::mcrouter_route($region, $gutter_ttl),
                                'exptime' => 10,
                            }
                        },
                        # For everything except reads, bypass the on-host tier completely. That means
                        # if a get, set, and get are sent within a ten-second period, they're
                        # guaranteed *not* to have read-your-writes consistency. (If sets updated the
                        # on-host cache, read-your-writes consistency would depend on whether the
                        # requests happened to hit the same host or not, so e.g. mwdebug hosts would
                        # behave differently from the rest of prod, which would be confusing.)
                        'default_policy'     => profile::mcrouter_route($region, $gutter_ttl)
                    },
                    # If use_onhost_memcached is turned off, always bypass the onhost tier.
                    false => profile::mcrouter_route($region, $gutter_ttl)
                }
            }
        }
    )
    if $has_ssl {
        file { '/etc/mcrouter/ssl':
            ensure  => directory,
            owner   => 'mcrouter',
            group   => 'root',
            mode    => '0750',
            require => Package['mcrouter'],
        }
        file { '/etc/mcrouter/ssl/ca.pem':
            ensure  => present,
            content => secret('mcrouter/mcrouter_ca/ca.crt.pem'),
            owner   => 'mcrouter',
            group   => 'root',
            mode    => '0444',
        }

        file { '/etc/mcrouter/ssl/cert.pem':
            ensure  => present,
            content => secret("mcrouter/${::fqdn}/${::fqdn}.crt.pem"),
            owner   => 'mcrouter',
            group   => 'root',
            mode    => '0444',
        }

        file { '/etc/mcrouter/ssl/key.pem':
            ensure  => present,
            content => secret("mcrouter/${::fqdn}/${::fqdn}.key.private.pem"),
            owner   => 'mcrouter',
            group   => 'root',
            mode    => '0400',
        }

        $ssl_options = {
            'port'    => $ssl_port,
            'ca_cert' => '/etc/mcrouter/ssl/ca.pem',
            'cert'    => '/etc/mcrouter/ssl/cert.pem',
            'key'     => '/etc/mcrouter/ssl/key.pem',
        }

        # We can allow any other mcrouter to connect via SSL here
        ferm::service { 'mcrouter_ssl':
            desc    => 'Allow connections to mcrouter via SSL',
            proto   => 'tcp',
            notrack => true,
            port    => $ssl_port,
            srange  => '$DOMAIN_NETWORKS',
        }
    }
    else {
        $ssl_options = undef
    }

    class { 'mcrouter':
        pools                  => $pools,
        routes                 => $routes,
        region                 => $::site,
        cluster                => 'mw',
        num_proxies            => $num_proxies,
        timeouts_until_tko     => $timeouts_until_tko,
        probe_delay_initial_ms => 60000,
        port                   => $port,
        ssl_options            => $ssl_options,
    }

    class { 'mcrouter::monitoring': }

    ferm::rule { 'skip_mcrouter_wancache_conntrack_out':
        desc  => 'Skip outgoing connection tracking for mcrouter',
        table => 'raw',
        chain => 'OUTPUT',
        rule  => "proto tcp sport (${port} ${ssl_port}) NOTRACK;",
    }

    ferm::rule { 'skip_mcrouter_wancache_conntrack_in':
        desc  => 'Skip incoming connection tracking for mcrouter',
        table => 'raw',
        chain => 'PREROUTING',
        rule  => "proto tcp dport (${port} ${ssl_port}) NOTRACK;",
    }
    if $prometheus_exporter {
        class {'profile::prometheus::mcrouter_exporter':
            mcrouter_port => $mcrouter::port
        }
    }
}
