# Profile to manage the daemon for cache invalidation

class profile::cache::purge(
    $host_regex = hiera('profile::cache::purge::host_regex', undef),
    $multicasts = hiera('profile::cache::purge::multicasts', ['239.128.0.112']),
    Array[String] $kafka_topics = lookup('profile::cache::purge::kafka_topics', {'default_value' => []}),
    Boolean $kafka_tls = lookup('profile::cache::purge::kafka_tls', {'default_value' => false}),
    Optional[String] $tls_key_password = lookup('profile::cache::purge::tls_key_password', {'default_value' => undef}),
){
    $kafka_ensure = $kafka_topics ? {
        []      => 'absent',
        default => 'present'
    }
    if $kafka_topics != [] {
        # purged should attach to the kafka brokers in the nearest main dc.
        $kafka_conf = $::site ? {
            /^(ulsfo|codfw)$/ => kafka_config('main-codfw'),
            default           => kafka_config('main-eqiad')
        }

        $brokers = $kafka_tls ? {
            undef => $kafka_conf['brokers']['string'].split(','),
            default => $kafka_conf['brokers']['ssl_array']
        }
    } else {
        $brokers = []
    }

    # KAFKA TLS SETUP
    $base_dir = '/etc/purged'
    $tls_dir = "${base_dir}/ssl"
    $tls_private_dir = "${tls_dir}/private"
    $tls_key = "${tls_private_dir}/purged.key.pem"
    $tls_cert = "${tls_dir}/purged.crt.pem"
    file { $base_dir:
        ensure => 'directory',
        owner  => 'root',
        group  => 'root',
        mode   => '0555'
    }

    if $kafka_tls and $kafka_topics != [] {
        file { $tls_dir:
            ensure => 'directory',
            owner  => 'root',
            group  => 'root',
            mode   => '0555'
        }

        file { $tls_private_dir:
            ensure => 'directory',
            owner  => 'root',
            group  => 'root',
            mode   => '0500'
        }
        file { $tls_key:
            ensure  => 'present',
            content => secret('certificates/purged/purged.key.private.pem'),
            owner   => 'root',
            group   => 'root',
            mode    => '0400',
            before  => Service['purged']
        }

        file { $tls_cert:
            ensure  => 'present',
            content => secret('certificates/purged/purged.crt.pem'),
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            before  => Service['purged']
        }
        $tls_settings = {
            'ca_location' => '/etc/ssl/certs/Puppet_Internal_CA.pem',
            'key_location' => $tls_key,
            'key_password' => $tls_key_password,
            'certificate_location' => $tls_cert,
            'cipher_suites' => 'ECDHE-ECDSA-AES256-GCM-SHA384',
            'curves_list' => 'P-256',
            'sigalgs_list' => 'ECDSA+SHA256'
        }
    } else {
        # TODO: uncomment after the transition.
        #file { [$tls_key,$tls_cert,$tls_dir,$tls_private_dir]:
        #    ensure => 'absent'
        #}
        $tls_settings = undef
    }

    class { 'purged':
        backend_addr     => '127.0.0.1:3128',
        frontend_addr    => '127.0.0.1:3127',
        mc_addrs         => $multicasts,
        prometheus_addr  => ':2112',
        frontend_workers => 4,
        backend_workers  => $::processorcount,
        is_active        => true,
        host_regex       => $host_regex,
        kafka_topics     => $kafka_topics,
        brokers          => $brokers,
        tls              => $tls_settings,
        kafka_conf_file  => "${base_dir}/purged-kafka.conf"
    }

    nrpe::monitor_systemd_unit_state { 'purged':
        require => Service['purged'],
    }
}
