# SPDX-License-Identifier: Apache-2.0
# == Class: profile::phabricator::monitoring
#
class profile::phabricator::monitoring (
    Stdlib::Fqdn $active_server = lookup('phabricator_server'),
){

    $phab_contact_groups = 'admins,phabricator'

    # https monitoring is on the virtual host 'phabricator'.
    # It should not be duplicated.
    if $::fqdn == $active_server {
        prometheus::blackbox::check::http { 'phabricator.wikimedia.org':
            severity => 'page',
        }

        nrpe::monitor_service { 'check_phab_phd':
            description   => 'PHD should be running',
            nrpe_command  => "/usr/lib/nagios/plugins/check_procs -c 1: --ereg-argument-array  'php ./phd-daemon' -u phd",
            contact_group => $phab_contact_groups,
            notes_url     => 'https://wikitech.wikimedia.org/wiki/Phabricator',
        }
    }
}
