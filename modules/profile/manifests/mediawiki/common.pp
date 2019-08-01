class profile::mediawiki::common(
    $logstash_host = hiera('logstash_host'),
    $logstash_syslog_port = hiera('logstash_syslog_port'),
    $log_aggregator = hiera('udp2log_aggregator'),
    Boolean $install_hhvm = lookup('profile::mediawiki::install_hhvm', {'default_value' => true})
){

    # GeoIP is needed for MW
    class { '::geoip': }

    class { '::tmpreaper': }

    # Configure cgroups used by MediaWiki
    class { '::mediawiki::cgroup': }
    # Install all basic support packages for MediaWiki
    class { '::mediawiki::packages': }
    # Install the users needed for MediaWiki
    class { '::mediawiki::users':
        web => 'www-data'
    }
    # Install scap
    include ::profile::mediawiki::scap_client

    # mwrepl is only supported under hhvm at the moment
    if $install_hhvm {
        class { '::mediawiki::mwrepl': }
    }

    class { '::mediawiki::syslog':
        log_aggregator => $log_aggregator,
    }

    include ::profile::rsyslog::udp_localhost_compat

    # These should properly be included in the role. Bear with me for now.
    if $install_hhvm {
        include ::profile::mediawiki::hhvm
    }
    include ::profile::mediawiki::php

    # furl is a cURL-like command-line tool for making FastCGI requests.
    # See `furl --help` for documentation and usage.

    file { '/usr/local/bin/furl':
        source => 'puppet:///modules/mediawiki/furl',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }


    file { '/usr/local/bin/mediawiki-firejail-convert':
        source => 'puppet:///modules/mediawiki/mediawiki-firejail-convert.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    file { '/etc/firejail/mediawiki-converters.profile':
        source => 'puppet:///modules/mediawiki/mediawiki-converters.profile',
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
    }

    file { '/usr/local/bin/mediawiki-firejail-ghostscript':
        source => 'puppet:///modules/mediawiki/mediawiki-firejail-ghostscript.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    # /var/log/mediawiki contains log files for the MediaWiki jobrunner
    # and for various periodic jobs that are managed by cron.
    file { '/var/log/mediawiki':
        ensure => directory,
        owner  => $::mediawiki::users::web,
        group  => 'wikidev',
        mode   => '0644',
    }

    # Script to use for decommissioning a machine and move it to role::system::spare
    file { '/root/decommission_appserver':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0500',
        source => 'puppet:///modules/mediawiki/decommission_appserver.sh',
    }


    # TODO: move to profile::mediawiki::webserver ?
    ferm::service{ 'ssh_pybal':
        proto  => 'tcp',
        port   => '22',
        srange => '$PRODUCTION_NETWORKS',
        desc   => 'Allow incoming SSH for pybal health checks',
    }

    # Allow sockets in TIME_WAIT state to be re-used.
    # This helps prevent exhaustion of ephemeral port or conntrack sessions.
    # See <http://vincent.bernat.im/en/blog/2014-tcp-time-wait-state-linux.html>
    sysctl::parameters { 'tcp_tw_reuse':
        values => { 'net.ipv4.tcp_tw_reuse' => 1 },
    }

    monitoring::service { 'mediawiki-installation DSH group':
        description    => 'mediawiki-installation DSH group',
        check_command  => 'check_dsh_groups!mediawiki-installation',
        check_interval => 60,
        notes_url      => 'https://wikitech.wikimedia.org/wiki/Monitoring/check_dsh_groups',
    }

}
