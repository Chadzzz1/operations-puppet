# SPDX-License-Identifier: Apache-2.0
# == Class profile::fastnetmon
# Sets up Fastnetmon: netflow collector and DDoS detection
class profile::fastnetmon (
  Hash[String, Hash[String, Any]] $thresholds_overrides = lookup('profile::fastnetmon::thresholds_overrides'),
  ) {

    include network::constants

    ensure_resource('class', 'geoip')

    $icinga_dir = '/run/fastnetmon-actions'

    class { '::fastnetmon':
        networks             => $::network::constants::external_networks,
        thresholds_overrides => $thresholds_overrides,
        icinga_dir           => $icinga_dir,
    }

    file { '/usr/local/lib/nagios/plugins/check_fastnetmon':
        ensure => absent,
    }

    # Export notifications count as a metric for alerting purposes.
    prometheus::node_file_count { 'fastnetmon notifications':
        paths   => [ $icinga_dir ],
        outfile => '/var/lib/prometheus/node.d/fastnetmon.prom'
    }

    ferm::service { 'FNM-netflow':
        proto => 'udp',
        port  => '2055',
        desc  => 'FNM-netflow',
      srange  => '($NETWORK_INFRA $MGMT_NETWORKS)',
    }

    logrotate::rule { 'fastnetmon':
        ensure        => present,
        file_glob     => '/var/log/fastnetmon.log',
        frequency     => 'daily',
        copy_truncate => true,
        missing_ok    => true,
        compress      => true,
        not_if_empty  => true,
        rotate        => 15,
    }
}
