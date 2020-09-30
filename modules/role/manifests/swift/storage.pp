# filtertags: labs-project-deployment-prep labs-project-swift
class role::swift::storage {

    system::role { 'swift::storage':
        description => 'swift storage brick',
    }

    include ::profile::standard
    include ::profile::base::firewall
    include ::profile::swift::storage
    include ::toil::systemd_scope_cleanup
    include ::profile::statsite

    class { '::profile::prometheus::statsd_exporter':
        relay_address => '',
    }
}
