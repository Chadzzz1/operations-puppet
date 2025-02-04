# == Class: role::doc
#
# Sets up a machine to serve generated documentation.
# https://docs.wikimedia.org - T211974
class role::doc {

    system::role { 'doc':
        ensure      => 'present',
        description => 'Wikimedia Documentation Server',
    }

    include ::profile::base::production
    include ::profile::base::firewall
    include ::profile::backup::host
    include ::profile::doc

    if $::realm == 'production' {
        include ::profile::tlsproxy::envoy
    }
}
