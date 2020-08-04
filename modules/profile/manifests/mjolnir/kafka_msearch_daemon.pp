# = Class: profile::mjolnir::kafka_daemon
#
# This class sets up the MjoLniR kafka daemon which facilitates running
# elasticsearch queries against relforge from the analytics network by using
# kafka as a middleman.
#
class profile::mjolnir::kafka_msearch_daemon(
    $es_cluster_endpoint = lookup('profile::mjolnir::kafka_msearch_daemon::es_cluster_nedpoint', { 'default_value' => 'localhost:9200' }),
    $kafka_cluster = hiera('profile::mjolnir::kafka_msearch_daemon::kafka_cluster'),
    String $input_topic = hiera('profile::mjolnir::kafka_msearch_daemon::input_topic'),
    String $output_topic = hiera('profile::mjolnir::kafka_msearch_daemon::output_topic'),
    Integer $num_workers = hiera('profile::mjolnir::kafka_msearch_daemon::num_workers'),
    Integer $max_concurrent_searches = hiera('profile::mjolnir::kafka_msearch_daemon::max_concurrent_searches'),
    Array[String] $prometheus_nodes = hiera('prometheus_nodes', []),
    Wmflib::Ensure $ensure = lookup('profile::mjolnir::kafka_msearch_daemon::ensure', { 'default_value' => 'present' }),
) {
    require ::profile::mjolnir

    $prometheus_port = 9171
    $kafka_config = kafka_config($kafka_cluster)
    ::systemd::service { 'mjolnir-kafka-msearch-daemon':
        ensure  => $ensure,
        content => template('profile/mjolnir/kafka-msearch-daemon.service.erb'),
    }

    ::base::service_auto_restart { 'mjolnir-kafka-msearch-daemon':
        ensure => $ensure,
    }

    $prometheus_nodes_ferm = join($prometheus_nodes, ' ')
    ferm::service { 'mjolnir-msearch-metrics':
        ensure => $ensure,
        proto  => 'tcp',
        port   => $prometheus_port,
        srange => "(@resolve((${prometheus_nodes_ferm})) @resolve((${prometheus_nodes_ferm}), AAAA))",
    }
}
