class openstack::neutron::l3_agent(
    $version,
    $dmz_cidr_array,
    $network_public_ip,
    $report_interval,
    $enabled=true,
    Boolean $enable_hacks = true,
    ) {

    class { "openstack::neutron::l3_agent::${version}":
        dmz_cidr_array    => $dmz_cidr_array,
        network_public_ip => $network_public_ip,
        report_interval   => $report_interval,
    }

    if $enable_hacks {
        class { "openstack::neutron::l3_agent::${version}::l3_agent_hacks": }
    }

    service {'neutron-l3-agent':
        ensure  => $enabled,
        require => Package['neutron-l3-agent'],
    }

    # ensure the module is loaded at boot, otherwise sysctl parameters might be ignored
    kmod::module { 'nf_conntrack':
        ensure => present,
    }

    sysctl::parameters { 'openstack':
        values   => {
            # Turn off IP filter
            'net.ipv4.conf.default.rp_filter'    => 0,
            'net.ipv4.conf.all.rp_filter'        => 0,

            # Enable IP forwarding
            'net.ipv4.ip_forward'                => 1,
            'net.ipv6.conf.all.forwarding'       => 1,

            # Disable RA
            'net.ipv6.conf.all.accept_ra'        => 0,

            # Tune arp cache table
            'net.ipv4.neigh.default.gc_thresh1'  => 1024,
            'net.ipv4.neigh.default.gc_thresh2'  => 2048,
            'net.ipv4.neigh.default.gc_thresh3'  => 4096,

            # Increase connection tracking size
            # and bucket since all of CloudVPS VM instances ingress/egress
            # are flowing through cloudnet servers
            # default buckets is 65536. Let's use x8; 65536 * 8 = 524288
            # default max is buckets x4; 524288 * 4 = 2097152
            'net.netfilter.nf_conntrack_buckets' => 524288,
            'net.netfilter.nf_conntrack_max'     => 2097152,
        },
        priority => 50,
    }

    class { '::openstack::monitor::neutron::l3_agent_conntrack': }
}
