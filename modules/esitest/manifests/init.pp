# SPDX-License-Identifier: Apache-2.0
# == Class: esitest
#
# This is a one-off for a limited-time experiment with defined goals (test
# whether using the ESI feature is viable with our production varnish config in
# 2022).  It will not evolve towards some eventual production service, and will
# be deleted at the end of the experiment regardless of the outcome.
#
# @param numa_iface
#   Network interface used to bound HAProxy to a NUMA node.
#   Defaults to lo

class esitest(
    String $numa_iface = 'lo',
) {
    # esitest is implemented using the haproxy package, but not the haproxy
    # puppet module.  The haproxy module has a different model of sharing
    # between site-level configs with a single daemon, and what we want here is
    # a completely independent daemon instance with its own custom config and
    # runtime paths.

    file { '/run/esitest':
        ensure => directory,
        mode   => '0775',
        owner  => 'root',
        group  => 'haproxy',
    }

    file { '/etc/haproxy/esitest.cfg':
        ensure  => present,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        content => template('esitest/esitest.cfg.erb'),
        notify  => Service['esitest'],
        require => Package['haproxy'],
    }

    systemd::service { 'esitest':
        content        => template('esitest/esitest.service.erb'),
        service_params => {'restart' => '/bin/systemctl reload esitest.service'},
    }
}
