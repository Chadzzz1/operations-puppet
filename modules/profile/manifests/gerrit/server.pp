# modules/profile/manifests/gerrit/server.pp
#
# filtertags: labs-project-git
class profile::gerrit::server(
    Stdlib::Ipv4 $ipv4 = hiera('gerrit::service::ipv4'),
    Stdlib::Fqdn $host = hiera('gerrit::server::host'),
    Array[Stdlib::Fqdn] $replica_hosts = hiera('gerrit::server::replica_hosts'),
    Boolean $backups_enabled = hiera('gerrit::server::backups_enabled'),
    String $backup_set = hiera('gerrit::server::backup_set'),
    Array[Stdlib::Fqdn] $gerrit_servers = hiera('gerrit::servers'),
    String $config = hiera('gerrit::server::config'),
    Hash $cache_nodes = hiera('cache::nodes', {}),
    Boolean $use_acmechief = hiera('gerrit::server::use_acmechief', false),
    Hash $ldap_config = lookup('ldap', Hash, hash, {}),
    Optional[Stdlib::Ipv6] $ipv6 = hiera('gerrit::service::ipv6', undef),
    Enum['11', '8'] $java_version = hiera('gerrit::server::java_version', '8'),
    Boolean $is_replica = hiera('gerrit::server::is_replica', false),
    Optional[String] $scap_user = hiera('gerrit::server::scap_user', 'gerrit2'),
    Optional[String] $scap_key_name = hiera('gerrit::server::scap_key_name', 'gerrit'),
    Optional[String] $db_user = lookup('gerrit::server::db_user'),
    Optional[String] $db_pass = lookup('gerrit::server::db_pass'),
) {

    interface::alias { 'gerrit server':
        ipv4 => $ipv4,
        ipv6 => $ipv6,
    }

    if !$is_replica {
        monitoring::service { 'gerrit_ssh':
            description   => 'SSH access',
            check_command => "check_ssh_port_ip!29418!${ipv4}",
            contact_group => 'admins,gerrit',
            notes_url     => 'https://wikitech.wikimedia.org/wiki/Gerrit',
        }
    }

    # ssh from users to gerrit
    ferm::service { 'gerrit_ssh_users':
        proto => 'tcp',
        port  => '29418',
    }

    # ssh between gerrit servers for cluster support
    $gerrit_servers_ferm=join($gerrit_servers, ' ')
    ferm::service { 'gerrit_ssh_cluster':
        port   => '22',
        proto  => 'tcp',
        srange => "(@resolve((${gerrit_servers_ferm})) @resolve((${gerrit_servers_ferm}), AAAA))",
    }

    ferm::service { 'gerrit_http':
        proto => 'tcp',
        port  => 'http',
    }

    ferm::service { 'gerrit_https':
        proto => 'tcp',
        port  => 'https',
    }

    if $backups_enabled and $backup_set != undef {
        backup::set { $backup_set:
            jobdefaults => "Hourly-${profile::backup::host::day}-${profile::backup::host::pool}"
        }
    }

    if $use_acmechief {
        class { '::sslcert::dhparam': }
        acme_chief::cert { 'gerrit':
            puppet_svc => 'apache2',
        }
    } else {
        if $is_replica {
            $tls_host = $replica_hosts[0]
        } else {
            $tls_host = $host
        }
        letsencrypt::cert::integrated { 'gerrit':
            subjects   => $tls_host,
            puppet_svc => 'apache2',
            system_svc => 'apache2',
        }
    }

    class { '::gerrit':
        host             => $host,
        ipv4             => $ipv4,
        ipv6             => $ipv6,
        replica          => $is_replica,
        replica_hosts    => $replica_hosts,
        config           => $config,
        cache_text_nodes => pick($cache_nodes['text'], {}),
        use_acmechief    => $use_acmechief,
        ldap_config      => $ldap_config,
        java_version     => $java_version,
        scap_user        => $scap_user,
        scap_key_name    => $scap_key_name,
        db_user          => $db_user,
        db_pass          => $db_pass,
    }

    class { '::gerrit::replication_key':
        require => Class['gerrit'],
    }

    # Ship gerrit logs to ELK, everything should be in the JSON file now.
    # Just the sshd_log has a custom format.
    rsyslog::input::file { 'gerrit-json':
        path => '/var/log/gerrit/gerrit.json',
    }

    # Apache reverse proxies to jetty
    rsyslog::input::file { 'gerrit-apache2-error':
        path => '/var/log/apache2/*error*.log',
    }
    rsyslog::input::file { 'gerrit-apache2-access':
        path => '/var/log/apache2/*access*.log',
    }

    # For admins and assist with T236114
    package { 'colordiff':
        ensure => present,
    }
}
