# SPDX-License-Identifier: Apache-2.0

# Prometheus black box metrics exporter. See also
# https://github.com/prometheus/blackbox_exporter
#
# This does 'active' checks over TCP / UDP / ICMP / HTTP / DNS
# and reports status to the prometheus scraper

class prometheus::blackbox_exporter(
    Optional[Stdlib::HTTPUrl] $http_proxy = undef,
) {
    require prometheus::assemble_config

    # Grant permissions to send out ICMP probes
    debconf::set { 'prometheus-blackbox-exporter/want_cap_net_raw':
        type   => 'boolean',
        value  => true,
        before => Package['prometheus-blackbox-exporter'],
    }

    package { 'prometheus-blackbox-exporter':
        ensure => present,
    }

    file { '/etc/prometheus/blackbox.yml.d':
        ensure  => directory,
        mode    => '0555',
        owner   => 'root',
        group   => 'root',
        recurse => true,
        purge   => true,
    }

    ['misc', 'common'].each |$frag| {
        prometheus::blackbox::module { $frag:
            content => template("prometheus/blackbox_exporter/${frag}.yml.erb"),
        }
    }

    # The exec is always run (gated by onlyif) to be able to recover from the following scenario:
    # - a fragment changes, a refresh of this exec is triggered
    # - the exec fails for some reason, the configuration is not updated
    # - at the next puppet run the fragment doesn't change, therefore the exec is not refreshed again
    # - the old configuration is silently kept in place until a fragment changes again

    exec { 'assemble blackbox.yml':
        onlyif  => 'prometheus-assemble-config --onlyif blackbox',
        command => 'prometheus-assemble-config blackbox',
        notify  => Service['prometheus-blackbox-exporter'],
        path    => '/usr/local/bin',
    }

    systemd::service { 'prometheus-blackbox-exporter':
        ensure   => present,
        content  => init_template('prometheus-blackbox-exporter', 'systemd_override'),
        override => true,
        restart  => true,
    }

    profile::auto_restarts::service { 'prometheus-blackbox-exporter': }

    logrotate::conf { 'blackbox_exporter':
        ensure => present,
        source => 'puppet:///modules/prometheus/blackbox_exporter.logrotate.conf',
    }

    rsyslog::conf { 'blackbox_exporter':
        source   => 'puppet:///modules/prometheus/blackbox_exporter.rsyslog.conf',
        priority => 40,
    }
}
