# SPDX-License-Identifier: Apache-2.0
# @summary install and configure puppet agent
# @param puppetmaster the puppet server
# @param ca_server the ca server
# @param ca_source to source of the CA file
# @param manage_ca_file if true manage the puppet ca file
# @param interval the, in minutes, interval to perform puppet runs
# @param force_puppet7 on bullseye hosts this enables an experimental puppet7
#   backport.  however this is known to have some issues with puppetmaster5
#   specifically related to certificate provisioning.  On bookworm this flag
#   disables the puppet5 forward-port so systems use the default Debian package
# @param timer_seed Add ability to seed the systemd timer.  usefull if jobs happen to collide
# @param environment the agent environment
# @param serialization_format the serilasation format of catalogs
# @param dns_alt_names a list of dns alt names
# @param certificate_revocation The level of certificate revocation to perform
class profile::puppet::agent (
    String                          $puppetmaster           = lookup('puppetmaster'),
    Optional[String[1]]             $ca_server              = lookup('puppet_ca_server'),
    Stdlib::Filesource              $ca_source              = lookup('puppet_ca_source'),
    Boolean                         $manage_ca_file         = lookup('manage_puppet_ca_file'),
    Integer[1,59]                   $interval               = lookup('profile::puppet::agent::interval'),
    Boolean                         $force_puppet7         = lookup('profile::puppet::agent::force_puppet7'),
    Optional[String[1]]             $timer_seed             = lookup('profile::puppet::agent::timer_seed'),
    Optional[String[1]]             $environment            = lookup('profile::puppet::agent::environment'),
    Enum['pson', 'json', 'msgpack'] $serialization_format   = lookup('profile::puppet::agent::serialization_format'),
    Array[Stdlib::Fqdn]             $dns_alt_names          = lookup('profile::puppet::agent::dns_alt_names'),
    Optional[Enum['chain', 'leaf']] $certificate_revocation = lookup('profile::puppet::agent::certificate_revocation'),
) {
    if $force_puppet7 {
        if debian::codename::lt('bullseye') {
            # We only have packages for bullseye currently
            fail('puppet7 is only avalible for bullseye')
        }
        # puppet7 is available in bookworm
        if debian::codename::eq('bullseye') {
            apt::package_from_component { 'puppet':
                component => 'component/puppet7',
                priority  => 1002,
            }
        }
    } elsif debian::codename::eq('bookworm') {
        # On Bookworm we're forcing a 5.5 backport until we have migrated to Puppet 7
        # T330495
        apt::package_from_component { 'puppet':
            component => 'component/puppet5',
            priority  => 1002,
        }
    }
    class { 'puppet::agent':
        ca_source              => $ca_source,
        manage_ca_file         => $manage_ca_file,
        server                 => $puppetmaster,
        ca_server              => $ca_server,
        dns_alt_names          => $dns_alt_names,
        environment            => $environment,
        certificate_revocation => $certificate_revocation,
    }
    class { 'puppet_statsd':
        statsd_host   => 'statsd.eqiad.wmnet',
        metric_format => 'puppet.<%= metric %>',
    }
    class { 'prometheus::node_puppet_agent': }
    include profile::puppet::client_bucket

    ensure_packages([
        # needed for the ssh_ca_host_certificate custom fact
        'ruby-net-ssh',
    ])

    # Mode 0751 to make sure non-root users can access
    # /var/lib/puppet/state/agent_disabled.lock to check if puppet is enabled
    file { '/var/lib/puppet':
        ensure => directory,
        owner  => 'puppet',
        group  => 'puppet',
        mode   => '0751',
    }
    # WMF helper scripts
    file {
        default:
            ensure => file,
            mode   => '0555',
            owner  => 'root',
            group  => 'root';
        '/usr/local/share/bash/puppet-common.sh':
            source => 'puppet:///modules/profile/puppet/bin/puppet-common.sh';
        '/usr/local/sbin/puppet-run':
            content => template('profile/puppet/puppet-run.erb');
        '/usr/local/bin/puppet-enabled':
            source => 'puppet:///modules/profile/puppet/bin/puppet-enabled';
        '/usr/local/sbin/disable-puppet':
            mode   => '0550',
            source => 'puppet:///modules/profile/puppet/bin/disable-puppet';
        '/usr/local/sbin/enable-puppet':
            mode   => '0550',
            source => 'puppet:///modules/profile/puppet/bin/enable-puppet';
        '/usr/local/sbin/run-puppet-agent':
            mode   => '0550',
            source => 'puppet:///modules/profile/puppet/bin/run-puppet-agent';
        '/usr/local/sbin/run-no-puppet':
            mode   => '0550',
            source => 'puppet:///modules/profile/puppet/bin/run-no-puppet';
    }
    $min = $interval.fqdn_rand($timer_seed)
    $timer_interval = "*:${min}/${interval}:00"

    systemd::timer::job { 'puppet-agent-timer':
        ensure        => present,
        description   => "Run Puppet agent every ${interval} minutes",
        user          => 'root',
        ignore_errors => true,
        command       => '/usr/local/sbin/puppet-run',
        interval      => [
            { 'start' => 'OnCalendar', 'interval' => $timer_interval },
            { 'start' => 'OnStartupSec', 'interval' => '1min' },
        ],
    }

    logrotate::rule { 'puppet':
        ensure       => present,
        file_glob    => '/var/log/puppet /var/log/puppet.log',
        frequency    => 'daily',
        compress     => true,
        missing_ok   => true,
        not_if_empty => true,
        rotate       => 7,
        post_rotate  => ['/usr/lib/rsyslog/rsyslog-rotate'],
    }

    rsyslog::conf { 'puppet-agent':
        source   => 'puppet:///modules/profile/puppet/rsyslog.conf',
        priority => 10,
        require  => File['/etc/logrotate.d/puppet'],
    }
    motd::script { 'last-puppet-run':
        ensure   => present,
        priority => 97,
        source   => 'puppet:///modules/profile/puppet/97-last-puppet-run',
    }
}
