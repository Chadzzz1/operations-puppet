# SPDX-License-Identifier: Apache-2.0
# Class: profile::kafka::broker::monitoring
#
# Sets up Prometheus based monitoring and icinga alerts.
#
# [*is_critical]
#   Whether or not to generate critical alerts.
#   Hiera: profile::kafka::broker::monitoring::is_critical
#
# [*should_monitor_tls*]
#   Whether or not to add monitors for TLS certificate expiry/validity.
#   Hiera: profile::kafka::broker::ssl_enabled

class profile::kafka::broker::monitoring (
    String $kafka_cluster_name            = lookup('profile::kafka::broker::kafka_cluster_name'),
    Boolean $is_critical                  = lookup('profile::kafka::broker::monitoring::is_critical', {'default_value' => false}),
    Boolean $should_monitor_tls           = lookup('profile::kafka::broker::ssl_enabled', {'default_value' => false }),
) {
    # Get fully qualified Kafka cluster name
    $config        = kafka_config($kafka_cluster_name)
    $kafka_cluster = $config['name']

    $prometheus_jmx_exporter_port = 7800
    $config_dir                   = '/etc/prometheus'
    $jmx_exporter_config_file     = "${config_dir}/kafka_broker_prometheus_jmx_exporter.yaml"

    # Use this in your JAVA_OPTS you pass to the Kafka  broker process
    $java_opts = "-javaagent:/usr/share/java/prometheus/jmx_prometheus_javaagent.jar=${::ipaddress}:${prometheus_jmx_exporter_port}:${jmx_exporter_config_file}"

    # Declare a prometheus jmx_exporter instance.
    # This will render the config file, declare the jmx_exporter_instance,
    # and configure ferm.
    profile::prometheus::jmx_exporter { "kafka_broker_${::hostname}":
        hostname                 => $::hostname,
        port                     => $prometheus_jmx_exporter_port,
        # Allow each kafka broker node access to other broker's prometheus JMX exporter port.
        # This will help us use kafka-tools to calculate partition reassignements
        # based on broker metrics like partition sizes, etc.
        # https://github.com/linkedin/kafka-tools/tree/master/kafka/tools/assigner
        extra_ferm_allowed_nodes => $config['brokers']['array'],
        labels                   => {'kafka_cluster' => $kafka_cluster},
        config_file              => $jmx_exporter_config_file,
        config_dir               => $config_dir,
        source                   => 'puppet:///modules/profile/kafka/broker_prometheus_jmx_exporter.yaml',
    }

    ### Icinga alerts
    # Generate icinga alert if Kafka Broker Server is not running.
    nrpe::monitor_service { 'kafka':
        description  => 'Kafka Broker Server',
        nrpe_command => '/usr/lib/nagios/plugins/check_procs -c 1:1 -C java -a "Kafka /etc/kafka/server.properties"',
        critical     => $is_critical,
        notes_url    => 'https://wikitech.wikimedia.org/wiki/Kafka/Administration',
    }

    if $should_monitor_tls {
        $kafka_ssl_port = $config['brokers']['hash'][$::fqdn]['ssl_port']
        monitoring::service { 'kafka-broker-tls':
            description   => 'Kafka broker TLS certificate validity',
            check_command => "check_ssl_kafka!${::fqdn}!${::fqdn}!${kafka_ssl_port}",
            notes_url     => 'https://wikitech.wikimedia.org/wiki/Kafka/Administration#Renew_TLS_certificate',
        }
    }
}
