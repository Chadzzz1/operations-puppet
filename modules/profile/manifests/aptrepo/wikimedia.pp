# http://apt.wikimedia.org/wikimedia/
class profile::aptrepo::wikimedia (
    Stdlib::Fqdn $primary_server = lookup('install_server'),
    Array[Stdlib::Fqdn] $secondary_servers = lookup('install_servers_failover'),
    Stdlib::Unixpath $basedir = lookup('profile::aptrepo::wikimedia::basedir'),
    Stdlib::Unixpath $homedir = lookup('profile::aptrepo::wikimedia::basedir'),
    String $gpg_user = lookup('profile::aptrepo::wikimedia::gpg_user'),
    String $gpg_pubring = lookup('profile::aptrepo::wikimedia::gpg_pubring'),
    String $gpg_secring = lookup('profile::aptrepo::wikimedia::gpg_secring'),
){

    class { '::aptrepo':
        basedir       => $basedir,
        homedir       => $homedir,
        incomingconf  => 'incoming-wikimedia',
        incominguser  => 'root',
        # Allow wikidev users to upload to /srv/wikimedia/incoming
        incominggroup => 'wikidev',
        gpg_pubring   => $gpg_pubring,
        gpg_secring   => $gpg_secring,
        gpg_user      => $gpg_user,
    }

    file { "${basedir}/conf/distributions":
        ensure       => present,
        mode         => '0444',
        owner        => 'root',
        group        => 'root',
        source       => 'puppet:///modules/aptrepo/distributions-wikimedia',
        validate_cmd => '/usr/bin/python -c "import apt_pkg; f=\'%\'; list(apt_pkg.TagFile(f))"',
    }

    include ::profile::backup::host

    # The repository data
    backup::set { 'srv-wikimedia': }

    # Home of the root user, contains keys and settings
    backup::set { 'roothome': }

    class { 'aptrepo::rsync':
        primary_server    => $primary_server,
        secondary_servers => $secondary_servers,
    }

    if $primary_server == $::fqdn {
        monitoring::service { 'https':
            description   => 'HTTPS',
            check_command => 'check_ssl_http_letsencrypt_ocsp!apt.wikimedia.org',
            notes_url     => 'https://wikitech.wikimedia.org/wiki/APT_repository',
        }
    }
}
