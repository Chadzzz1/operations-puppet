# SPDX-License-Identifier: Apache-2.0
# server running "Request Tracker"
# https://bestpractical.com/request-tracker
class profile::requesttracker {

    include ::passwords::misc::rt
    include profile::idp::client::httpd

    ensure_packages(['libapache2-mod-perl2', 'libapache2-mod-scgi'])
    $cgi_module = 'scgi'

    class { '::httpd':
        modules => ['headers', 'rewrite', 'perl', $cgi_module],
    }

    profile::auto_restarts::service { 'apache2': }

    class { '::requesttracker':
        apache_site => 'rt.wikimedia.org',
        dbhost      => 'm1-master.eqiad.wmnet',
        dbport      => '',
        dbuser      => $passwords::misc::rt::rt_mysql_user,
        dbpass      => $passwords::misc::rt::rt_mysql_pass,
    }

    ferm::service { 'rt-http':
        proto  => 'tcp',
        port   => '80',
        srange => '$CACHES',
    }

    prometheus::blackbox::check::http { 'rt.wikimedia.org':
        team             => 'serviceops-collab',
        severity         => 'task',
        path             => '/',
        status_matches   => [302], # Ensure we redirect to IDP
        follow_redirects => false,
        ip_families      => [ip4],
    }
}
