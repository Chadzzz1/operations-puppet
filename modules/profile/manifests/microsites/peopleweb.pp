# SPDX-License-Identifier: Apache-2.0
# https://people.wikimedia.org
# lets shells users publish their own files (apache2, mod_userdir)
# e.g. https://people.wikimedia.org/~username/
class profile::microsites::peopleweb (
    Stdlib::Host     $deployment_server = lookup('deployment_server'),
    Stdlib::Host     $sitename          = lookup('profile::microsites::peopleweb::sitename'),
    Stdlib::Unixpath $docroot           = lookup('profile::microsites::peopleweb::docroot'),
    Stdlib::Host     $rsync_src_host    = lookup('profile::microsites::peopleweb::rsync_src_host'),
    Stdlib::Host     $rsync_dst_host    = lookup('profile::microsites::peopleweb::rsync_dst_host'),
){

    # firewall: allow caching layer to talk to http backend
    ferm::service { 'people-http':
        proto  => 'tcp',
        port   => '80',
        srange => '$CACHES',
    }

    # firewall: allow http from deployment servers for testing
    ferm::service { 'people-http-deployment':
        proto  => 'tcp',
        port   => '80',
        srange => "(@resolve((${deployment_server})) @resolve((${deployment_server}), AAAA))"
    }

    # httpd (apache2)
    class { '::httpd':
        modules => ['userdir', 'rewrite', 'headers'],
    }

    class { '::httpd::mpm':
        mpm => 'prefork'
    }

    profile::auto_restarts::service { 'apache2': }
    profile::auto_restarts::service { 'envoyproxy': }

    rsyslog::input::file { 'apache2-error':
        path => '/var/log/apache2/*error*.log',
    }

    wmflib::dir::mkdir_p($docroot)

    # the index page shown at https://people.wikimedia.org/
    file { "${docroot}/index.html":
        content => template('profile/microsites/peopleweb/index.html.erb'),
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
    }

    # ensure each user automatically gets a public_html dir inside their home dir
    admin::unique_users(['all-users']).each |String $user| {
        file { "/home/${user}/public_html":
            ensure => 'directory',
            owner  => $user,
            group  => 'wikidev',
            mode   => '0755',
        }
    }

    # Wikimedia single sign-on portal (idp.wikimedia.org)
    # allows users to password protect files
    include profile::idp::client::httpd

    # Monitoring
    prometheus::blackbox::check::http { $sitename:
        team               => 'serviceops-collab',
        severity           => 'task',
        path               => '/',
        ip_families        => ['ip4'],
        force_tls          => true,
        body_regex_matches => ['Welcome to people'],
    }

    # warn users on servers that are NOT the active backend and source of rsync
    if $::fqdn == $rsync_src_host {
      $motd_content = "#!/bin/sh\necho '\nThis is people.wikimedia.org.\nFiles you put in 'public_html' in your home dir will be accessible on the web.\nMore info on https://wikitech.wikimedia.org/wiki/People.wikimedia.org.\n'"
      $rsync_auto_restart_ensure = 'present'
    } else {
      $motd_content = "#!/bin/sh\necho '\nThis is NOT the active backend for people.wikimedia.org. DO NOT USE THIS. Please go to ${rsync_src_host} instead.\n'"
      $rsync_auto_restart_ensure = 'absent'
      service { 'rsync': ensure => 'stopped' }
    }


    motd::script { 'people-motd':
        ensure  => present,
        content => $motd_content,
    }

    # people's entire home dirs (not just public_html) are backed up in Bacula
    backup::set {'home': }
    backup::set {'srv-org-wikimedia': }

    # allow copying /home from one server to another for migrations
    ensure_packages(['rsync'])
    rsync::quickdatacopy { 'people-home':
        ensure      => present,
        auto_sync   => false,
        source_host => $rsync_src_host,
        dest_host   => $rsync_dst_host,
        module_path => '/home',
    }

    profile::auto_restarts::service { 'rsync':
        ensure => $rsync_auto_restart_ensure,
    }
}
