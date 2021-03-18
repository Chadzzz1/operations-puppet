# = Class: prometheus::node_local_crontabs
#
# Periodically export local crontab information via node-exporter
# textfile collector.
class profile::prometheus::node_local_crontabs {
    class { 'prometheus::node_local_crontabs': }

    sudo::user { 'prometheus_sudo_for_local_crontab':
        ensure     => 'present',
        user       => 'prometheus',
        privileges => [
            'ALL=(root) NOPASSWD: /bin/ls -1 /var/spool/cron/crontabs/',
        ],
    }

    # Collect every 5 minutes
    cron { 'prometheus_local_crontabs':
        ensure  => 'present',
        user    => 'prometheus',
        minute  => '*/5',
        command => '/usr/local/bin/prometheus-local-crontabs',
    }
}
