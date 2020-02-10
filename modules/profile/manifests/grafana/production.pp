# == Class: profile::grafana::production
#
# Grafana is a dashboarding web application.
# It powers <https://grafana.wikimedia.org>.
#
class profile::grafana::production {
    include ::profile::grafana

    rsync::quickdatacopy { 'var-lib-grafana':
      ensure              => present,
      source_host         => 'grafana1002.eqiad.wmnet',
      dest_host           => 'grafana2001.codfw.wmnet',
      module_path         => '/var/lib/grafana',
      server_uses_stunnel => true,
    }

    # On Grafana 5 and later, datasource configurations are stored in Puppet
    # as YAML and pushed to Grafana that way, which reads them at startup.
    file { '/etc/grafana/provisioning/datasources/production-datasources.yaml':
        ensure  => present,
        source  => 'puppet:///modules/profile/grafana/production-datasources.yaml',
        owner   => 'root',
        group   => 'grafana',
        mode    => '0440',
        require => Package['grafana'],
        notify  => Service['grafana-server'],
    }

    grafana::dashboard { 'varnish-http-errors':
        ensure  => absent,
        content => '',
    }

    grafana::dashboard { 'varnish-aggregate-client-status-codes':
        source => 'puppet:///modules/grafana/dashboards/varnish-aggregate-client-status-codes',
    }

    grafana::dashboard { 'swift':
        source => 'puppet:///modules/grafana/dashboards/swift',
    }
}
