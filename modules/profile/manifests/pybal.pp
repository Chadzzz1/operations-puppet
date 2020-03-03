# == class profile::pybal
#
# Configures pybal on a server, lvs or otherwise.
class profile::pybal(
    $bgp = hiera('profile::pybal::bgp'),
    $primary = hiera('profile::pybal::primary'),
    $conftool_prefix = hiera('conftool_prefix'),
    $config_source = hiera('profile::pybal::config_source'),
    $config_host = hiera('profile::pybal::config_host'),
    $wikimedia_clusters = hiera('wikimedia_clusters'),
    $etcd_port = hiera('profile::pybal::etcd_port', 2379),
    Optional[Integer] $override_bgp_med = lookup('profile::pybal::override_bgp_med', {'default_value' => undef}),
) {
    # Includes all the common configs.
    include ::lvs::configuration
    $services = wmflib::service::get_services_for_lvs($::lvs::configuration::lvs_class, $::site)

    $ipv4_address = ipresolve($::fqdn, 4)

    $bgp_med = $override_bgp_med ? {
        undef   => $primary ? { true => 0, default => 100},
        default => $override_bgp_med,
    }

    $global_options = {
        'bgp' => $bgp,
        # This is being transitioned to a fixed list of all local routers,
        # per-DC.  Perhaps we can pull this from other shared site hieradata
        # instead after we're done with the conversion?
        'bgp-peer-address' => $::hostname ? {
            /^lvs101[3-6]$/     => "[ '208.80.154.196', '208.80.154.197' ]", # cr1-eqiad,cr2-eqiad
            'lvs2001'           => "[ '208.80.153.192', '208.80.153.193' ]", # cr1-codfw,cr2-codfw
            /^lvs20[01][0789]$/ => "[ '208.80.153.192', '208.80.153.193' ]", # cr1-codfw,cr2-codfw
            /^lvs300[567]$/     => "[ '91.198.174.244', '91.198.174.245' ]", # cr2-esams,cr3-esams
            /^lvs400[567]$/     => "[ '198.35.26.192', '198.35.26.193' ]",   # cr3-ulsfo,cr4-ulsfo
            /^lvs500[123]$/     => "[ '103.102.166.129', '103.102.166.130' ]", # cr1-eqsin,cr2-eqsin
            default             => '(unspecified)'
            },
        'bgp-nexthop-ipv4'    => $facts['ipaddress'],
        'bgp-nexthop-ipv6'    => inline_template("<%= require 'ipaddr'; (IPAddr.new(@ipaddress6).mask(64) | IPAddr.new(\"::\" + @ipaddress.gsub('.', ':'))).to_s() %>"),
        'instrumentation'     => 'yes',
        'instrumentation_ips' => "[ '127.0.0.1', '::1', '${ipv4_address}' ]",
        'bgp-local-ips'       => "[ '${ipv4_address}' ]",
        'bgp-med'             => $bgp_med,
    }

    # Base class, not parametrized
    class { '::pybal': }

    if ($config_source == 'etcd' and $etcd_port != 2379) {
        $pybal_config_host = "${config_host}:${etcd_port}"
    }
    else {
        $pybal_config_host = $config_host
    }
    class { '::pybal::configuration':
        global_options  => $global_options,
        services        => $services,
        lvs_class_hosts => $lvs::configuration::lvs_class_hosts,
        site            => $::site,
        conftool_prefix => $conftool_prefix,
        config          => $config_source,
        config_host     => $pybal_config_host
    }

    class { '::pybal::monitoring':
        config_host   => $config_host,
        config_source => $config_source,
        etcd_port     => $etcd_port,
        services      => $services,
    }

    # Sites with MediaWiki appservers need runcommand
    if $::site in keys($wikimedia_clusters['appserver']['sites']) {
        class { '::lvs::balancer::runcommand': }
    }

}
