#
# Generic monitoring for all labstore NFS servers
#
# == Parameters
#
# [*monitor_iface*]
#   Name of interface to monitor for network saturation.
#   This should be the interface holding the IP address
#   that serves NFS

class labstore::monitoring::interfaces(
    $monitor_iface = 'eth0',
    $contact_groups='wmcs-team,admins',
    $int_throughput_warn = 93750000,  # 750Mbps
    $int_throughput_crit = 106250000, # 850Mbps
    $load_warn = $::processorcount * 0.75,
    $load_crit = $::processorcount * 1.25,
) {

    # In minutes, how long icinga will wait before considering HARD state, see also T188624
    $retries = 10

    monitoring::check_prometheus { 'network_out_saturated':
        description     => 'Outgoing network saturation',
        dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/labs-monitoring'],
        query           => "sum(irate(node_network_transmit_bytes_total{instance=\"${::hostname}:9100\",device=\"${monitor_iface}\"}[5m]))",
        warning         => $int_throughput_warn,
        critical        => $int_throughput_crit,
        retries         => $retries,
        method          => 'ge',
        contact_group   => $contact_groups,
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Portal:Data_Services/Admin/Labstore',
        prometheus_url  => "http://prometheus.svc.${::site}.wmnet/ops",
    }

    monitoring::check_prometheus { 'network_in_saturated':
        description     => 'Incoming network saturation',
        dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/labs-monitoring'],
        query           => "sum(irate(node_network_receive_bytes_total{instance=\"${::hostname}:9100\",device=\"${monitor_iface}\"}[5m]))",
        warning         => $int_throughput_warn,
        critical        => $int_throughput_crit,
        retries         => $retries,
        method          => 'ge',
        contact_group   => $contact_groups,
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Portal:Data_Services/Admin/Labstore',
        prometheus_url  => "http://prometheus.svc.${::site}.wmnet/ops",
    }

    monitoring::check_prometheus { 'high_iowait_stalling':
        description     => 'Persistent high iowait',
        dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/labs-monitoring'],
        # iowait % across all CPUs
        query           => "100 * sum(irate(node_cpu_seconds_total{instance=\"${::hostname}:9100\",mode=\"iowait\"}[5m])) / scalar(count(node_cpu_seconds_total{mode=\"idle\",instance=\"${::hostname}:9100\"}))",
        warning         => 5,
        critical        => 10,
        retries         => $retries,
        method          => 'ge',
        contact_group   => $contact_groups,
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Portal:Data_Services/Admin/Labstore',
        prometheus_url  => "http://prometheus.svc.${::site}.wmnet/ops",
    }

    # Monitor for high load consistently, is a 'catchall'
    # Since we don't yet have a sensible prometheus recording rule for this to query,
    # This is now 5m vs the older 1m check.  That is a TODO because "average" != 85% of all
    # values over time that we had in graphite.
    # Also considering making this an "email only" alert because we often want to wait
    # the condition out rather than immediately respond.
    monitoring::check_prometheus { 'high_load':
        description     => 'High 5m load average',
        dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/labs-monitoring'],
        query           => "node_load5{instance=\"${::hostname}:9100\"}",
        warning         => $load_warn,
        critical        => $load_crit,
        retries         => $retries,
        method          => 'ge',
        contact_group   => $contact_groups,
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Portal:Data_Services/Admin/Labstore',
        prometheus_url  => "http://prometheus.svc.${::site}.wmnet/ops",
    }
}
