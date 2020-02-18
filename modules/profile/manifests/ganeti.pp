# === Class: profile::ganeti
#
# This profile configures Ganeti's keys, RAPI users, and configures
# the firewall on the host.
#
# Actions:
#
# Requires:
#
# Sample Usage:
#       include profile::ganeti
#
# === Parameters
#
# [*ganeti_nodes*]
#   A list of Ganeti nodes in this particular cluster.
#
# [*rapi_nodes*]
#   A list of nodes to open the RAPI port to.
#
# [*rapi_ro_user*]
#   A string containing the name of the read-only user to configure in RAPI.
#
# [*rapi_ro_password*]
#   A string containing the password for the aforementioned user.
#

class profile::ganeti (
    String $ganeti_cluster_name = lookup('profile::ganeti::ganeti_cluster_name', { default_value => "ganeti01.svc.${::site}.wmnet" }),
    Array[Stdlib::Fqdn] $ganeti_nodes = lookup("profile::ganeti::${ganeti_cluster_name}::nodes", { default_value => [] }),
    Array[Stdlib::Fqdn] $rapi_nodes = lookup('profile::ganeti::rapi_nodes', { default_value => [] }),
    Optional[String] $rapi_ro_user = lookup('profile::ganeti::rapi::ro_user', { default_value => undef }),
    Optional[String] $rapi_ro_password = lookup('profile::ganeti::rapi::ro_password', { default_value => undef }),
) {

    class { '::ganeti': }

    # Ganeti needs intracluster SSH root access
    # DSS+RSA keys in here, but note that DSS is deprecated
    ssh::userkey { 'root-ganeti':
        ensure => present,
        user   => 'root',
        skey   => 'ganeti',
        source => 'puppet:///modules/profile/ganeti/ganeti.pub',
    }

    # The RSA private key
    file { '/root/.ssh/id_rsa':
        ensure    => present,
        owner     => 'root',
        group     => 'root',
        mode      => '0400',
        content   => secret('ganeti/id_rsa'),
        show_diff => false,
    }
    # This is here for completeness
    file { '/root/.ssh/id_rsa.pub':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0400',
        source => 'puppet:///modules/profile/ganeti/id_rsa.pub',
    }

    # Interactive script to create instances
    file { '/usr/local/bin/makevm':
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/profile/ganeti/makevm.sh',
    }

    motd::script { 'ganeti-master-motd':
        ensure => present,
        source => 'puppet:///modules/profile/ganeti/motd',
    }

    if defined('$rapi_ro_user') and defined('$rapi_ro_password') {
        $ro_password_hash = md5("${rapi_ro_user}:Ganeti Remote API:${rapi_ro_password}")
        # Authentication for RAPI (for now just a single read-only user)
        file { '/var/lib/ganeti/rapi/users':
            ensure  => present,
            owner   => 'gnt-rapi',
            group   => 'gnt-masterd',
            mode    => '0440',
            content => "${rapi_ro_user} {HA1}${ro_password_hash} read\n",
        }
    }
    else {
        # Provide a blank authentication file for the RAPI server (no users will be defined, thus denying all)
        file { '/var/lib/ganeti/rapi/users':
            ensure  => present,
            owner   => 'gnt-rapi',
            group   => 'gnt-masterd',
            mode    => '0640',
            content => '',
        }

    }

    # Firewalling
    #

    $ganeti_ferm_nodes = join($ganeti_nodes, ' ')
    $rapi_access = join(concat($ganeti_nodes, $rapi_nodes), ' ')

    # Allow SSH between ganeti cluster members
    ferm::service { 'ganeti_ssh_cluster':
        proto  => 'tcp',
        port   => 'ssh',
        srange => "@resolve((${ganeti_ferm_nodes}))",
    }

    # RAPI is the API of ganeti
    ferm::service { 'ganeti_rapi_cluster':
        proto  => 'tcp',
        port   => 5080,
        srange => "@resolve((${rapi_access}))",
    }

    # Ganeti noded is responsible for all cluster/node actions
    ferm::service { 'ganeti_noded_cluster':
        proto  => 'tcp',
        port   => 1811,
        srange => "@resolve((${ganeti_ferm_nodes}))",
    }

    # Ganeti confd provides a HA and fast way to query cluster configuration
    ferm::service { 'ganeti_confd_cluster':
        proto  => 'udp',
        port   => 1814,
        srange => "@resolve((${ganeti_ferm_nodes}))",
    }

    # Ganeti mond is the monitoring daemon. Data is available via port 1815
    ferm::service { 'ganeti_mond_cluster':
        proto  => 'tcp',
        port   => 1815,
        srange => "@resolve((${ganeti_ferm_nodes}))",
    }

    # DRBD is used for HA of disk images. Port range for ganeti is
    # 11000-14999
    ferm::service { 'ganeti_drbd':
        proto  => 'tcp',
        port   => '11000:14999',
        srange => "@resolve((${ganeti_ferm_nodes}))",
    }

    # Migration is done over TCP port
    ferm::service { 'ganeti_migration':
        proto  => 'tcp',
        port   => 8102,
        srange => "@resolve((${ganeti_ferm_nodes}))",
    }

    # If ganeti_cluster fact is not defined, the node has not been added to a
    # cluster yet, so don't monitor
    if $facts['ganeti_cluster'] {

        # Monitoring
        nrpe::monitor_service{ 'ganeti-noded':
            description  => 'ganeti-noded running',
            nrpe_command => '/usr/lib/nagios/plugins/check_procs -w 1:2 -c 1:2 -u root -C ganeti-noded',
            notes_url    => 'https://wikitech.wikimedia.org/wiki/Ganeti',
        }

        nrpe::monitor_service{ 'ganeti-confd':
            description  => 'ganeti-confd running',
            nrpe_command => '/usr/lib/nagios/plugins/check_procs -w 1:1 -c 1:1 -u gnt-confd -C ganeti-confd',
            notes_url    => 'https://wikitech.wikimedia.org/wiki/Ganeti',
        }

        nrpe::monitor_service{ 'ganeti-mond':
            description  => 'ganeti-mond running',
            nrpe_command => '/usr/lib/nagios/plugins/check_procs -w 1:1 -c 1:1 -u root -C ganeti-mond',
            notes_url    => 'https://wikitech.wikimedia.org/wiki/Ganeti',
        }

    }

}
