# SPDX-License-Identifier: Apache-2.0
# == Class confd
#
# Installs confd and (optionally) starts it via a base::service_unit define.
#
# === Parameters
#
# [*running*] If true, the service will be ran. Default: true
#
# [*backend*] The backend to use. Default: etcd
#
# [*node*] If defined, the specific backend node to connect to in the host:port
#          form. Default: undef
#
# [*srv_dns*] The domain under which to perform a SRV query to discover the
#             backend cluster. Default: $::domain
#
# [*scheme*] Protocol ("http" or "https"). Default: https
#
# [*interval*] Polling interval to etcd. If undefined, a direct watch will be
#              executed (the default)
#
# [*prefix*] A global prefix with respect to which confd will do all of its
#            operations. Default: undef
#
class confd(
    Wmflib::Ensure   $ensure        = present,
    Boolean          $running       = true,
    String           $backend       = 'etcd',
    Optional[String] $node          = undef,
    Stdlib::Fqdn     $srv_dns       = $facts['domain'],
    String           $scheme        = 'https',
    Integer          $interval      = 3,
    Optional[String] $prefix        = undef,
) {

    package { ['confd', 'python3-toml']:
        ensure => $ensure,
    }

    if $running {
        $params = { ensure => 'running'}
    }
    else {
        $params = { ensure => 'stopped'}
    }

    base::service_unit { 'confd':
        ensure         => $ensure,
        refresh        => true,
        systemd        => systemd_template('confd'),
        service_params => $params,
        require        => Package['confd'],
    }

    file { '/etc/confd':
        ensure => directory,
        mode   => '0550',
    }

    file { '/etc/confd/conf.d':
        ensure  => directory,
        recurse => true,
        purge   => true,
        mode    => '0550',
        before  => Service['confd'],
    }

    file { '/etc/confd/templates':
        ensure  => directory,
        recurse => true,
        purge   => true,
        mode    => '0550',
        before  => Service['confd'],
    }

    file { '/usr/local/bin/confd-lint-wrap':
        ensure => present,
        mode   => '0555',
        source => 'puppet:///modules/confd/confd-lint-wrap.py',
    }

    nrpe::plugin { 'check_confd_lint':
        source => 'puppet:///modules/confd/check_confd_lint.sh';
    }

    file { '/usr/local/bin/confd-prometheus-metrics':
        ensure => present,
        mode   => '0555',
        source => 'puppet:///modules/confd/confd_prometheus_metrics.py',
    }

    systemd::timer::job { 'confd_prometheus_metrics':
        ensure      => present,
        description => 'Export confd Prometheus metrics',
        command     => '/usr/local/bin/confd-prometheus-metrics',
        interval    => {
            'start'    => 'OnCalendar',
            'interval' => 'minutely',
        },
        user        => 'root',
    }

    # Cleanup stale confd errors
    # https://phabricator.wikimedia.org/T321678
    $run_dir = '/var/run/confd-template'

    # Force creation here to avoid the following spam from puppet:
    # Info: /Stage[main]/Confd/Tidy[/var/run/confd-template]: File does not exist
    # Normally confd creates the directory on errors
    file { $run_dir:
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
    }

    tidy { $run_dir:
        age     => '30m',
        type    => 'mtime',
        recurse => true,
        backup  => false,
    }

    # Any change to a service configuration or to a template should reload confd.
    Confd::File <| |> ~> Service['confd']

    nrpe::monitor_systemd_unit_state { 'confd':
        require => Service['confd'],
    }

    # Log to a dedicated file
    logrotate::conf { 'confd':
        ensure => present,
        source => 'puppet:///modules/confd/logrotate.conf',
    }

    rsyslog::conf { 'confd':
        source   => 'puppet:///modules/confd/rsyslog.conf',
        priority => 20,
        require  => File['/etc/logrotate.d/confd'],
    }

    # Used by modules/profile/files/mediawiki/maintenance/mw-cli-wrapper.py
    nrpe::plugin { 'check_confd_template':
        source => 'puppet:///modules/confd/check_confd_template';
    }
}
