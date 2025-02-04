class role::thanos::frontend {
    system::role { 'thanos::frontend':
        description => 'Thanos (Prometheus long-term storage) frontend',
    }

    include ::profile::base::production
    include ::profile::base::firewall

    include ::profile::lvs::realserver

    include ::profile::tlsproxy::envoy

    include ::profile::thanos::query
    include ::profile::thanos::query_frontend
    include ::profile::thanos::httpd

    include ::profile::thanos::store
    include ::profile::thanos::compact

    include ::profile::thanos::bucket_web

    include ::profile::thanos::rule
    include ::profile::alerts::deploy::thanos

    include ::profile::thanos::swift::frontend
}
