# SPDX-License-Identifier: Apache-2.0
# sets up the WMF annual report site
# https://annual.wikimedia.org/
# https://foundation.wikimedia.org/wiki/Annual_Report
# T599 - https://15.wikipedia.org (aka. annual report 2015)
class profile::microsites::annualreport {

    httpd::site { 'annual.wikimedia.org':
        source => 'puppet:///modules/profile/annualreport/annual.wikimedia.org',
    }

    httpd::site { '15.wikipedia.org':
        source => 'puppet:///modules/profile/annualreport/15.wikipedia.org',
    }

    git::clone { 'wikimedia/annualreport':
        ensure    => 'present',
        directory => '/srv/org/wikimedia/annualreport',
        branch    => 'master',
    }

    prometheus::blackbox::check::http { 'annual.wikimedia.org':
        team           => 'serviceops-collab',
        severity       => 'task',
        path           => '/2017/',
        ip_families    => ['ip4'],
        force_tls      => true,
        status_matches => [200],
    }
}

