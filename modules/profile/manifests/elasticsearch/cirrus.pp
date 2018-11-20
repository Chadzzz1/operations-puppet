#
# This class configures elasticsearch
#
# == Parameters:
#
# For documentation of parameters, see the elasticsearch profile.
#
class profile::elasticsearch::cirrus(
    String $ferm_srange = hiera('profile::elasticsearch::cirrus::ferm_srange'),
    String $storage_device = hiera('profile::elasticsearch::cirrus::storage_device'),
    Array[String] $prometheus_nodes = hiera('prometheus_nodes'),
) {
    include ::profile::elasticsearch

    package {'wmf-elasticsearch-search-plugins':
        ensure => present,
    }

    # Since the elasticsearch service is dynamically named after the cluster
    # name, and because there can be multiple elasticsearch services on the
    # same node we need to use collectors.
    Package['wmf-elasticsearch-search-plugins'] -> Service <| tag == 'elasticsearch' |>

    # Alternatively we could pass these again?
    # certificate_name and tls_port aren't even
    # elasticsearch::instance params,

    $::profile::elasticsearch::filtered_instances.each |$instance_title, $instance_params| {
        $cluster_name = $instance_params['cluster_name']
        $certificate_name = $instance_params['certificate_name']
        $http_port = $instance_params['http_port']
        $tls_port = $instance_params['tls_port']

        ferm::service { "elastic-http-${http_port}":
            proto   => 'tcp',
            port    => $http_port,
            notrack => true,
            srange  => $ferm_srange,
        }

        ferm::service { "elastic-https-${tls_port}":
            proto  => 'tcp',
            port   => $tls_port,
            srange => $ferm_srange,
        }

        elasticsearch::tlsproxy { $cluster_name:
            certificate_name => $certificate_name,
            upstream_port    => $http_port,
            tls_port         => $tls_port,
        }

        elasticsearch::log::hot_threads_cluster { $cluster_name:
            http_port => $http_port,
        }
    }

    file { '/etc/udev/rules.d/elasticsearch-readahead.rules':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => "SUBSYSTEM==\"block\", KERNEL==\"${storage_device}\", ACTION==\"add|change\", ATTR{bdi/read_ahead_kb}=\"128\"",
        notify  => Exec['elasticsearch_udev_reload'],
    }

    exec { 'elasticsearch_udev_reload':
        command     => '/sbin/udevadm control --reload && /sbin/udevadm trigger',
        refreshonly => true,
    }

    # Install prometheus data collection
    $::profile::elasticsearch::filtered_instances.reduce(9108) |$prometheus_port, $kv_pair| {
        $instance_params = $kv_pair[1]
        $http_port = $instance_params['http_port']

        profile::prometheus::elasticsearch_exporter { "${::hostname}:${http_port}":
            prometheus_nodes   => $prometheus_nodes,
            prometheus_port    => $prometheus_port,
            elasticsearch_port => $http_port,
        }
        profile::prometheus::wmf_elasticsearch_exporter { "${::hostname}:${http_port}":
            prometheus_nodes   => $prometheus_nodes,
            prometheus_port    => $prometheus_port + 1,
            elasticsearch_port => $http_port,
        }
        $prometheus_port + 2
    }
}
