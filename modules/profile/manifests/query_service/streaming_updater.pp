class profile::query_service::streaming_updater (
    String $username = lookup('profile::query_service::username'),
    String $kafka_cluster = lookup('profile::query_service::streaming_updater_kafka_cluster'),
    String $kafka_topic = lookup('profile::query_service::streaming_updater_kafka_topic'),
    Stdlib::Port $logstash_logback_port = lookup('logstash_logback_port'),
    Stdlib::Unixpath $package_dir = lookup('profile::query_service::package_dir'),
    Stdlib::Unixpath $data_dir = hiera('profile::query_service::data_dir'),
    Stdlib::Unixpath $log_dir = lookup('profile::query_service::log_dir'),
    String $deploy_name = lookup('profile::query_service::deploy_name'),
    Array[String] $prometheus_nodes = lookup('prometheus_nodes'),
) {
    require ::profile::query_service::common

    $instance_name = "${deploy_name}-updater"
    $prometheus_agent_path = '/usr/share/java/prometheus/jmx_prometheus_javaagent.jar'
    $prometheus_agent_port = '9101'
    $prometheus_agent_config = "/etc/${deploy_name}/${instance_name}-prometheus-jmx.yaml"
    profile::prometheus::jmx_exporter { $instance_name:
        hostname         => $::hostname,
        port             => $prometheus_agent_port,
        prometheus_nodes => $prometheus_nodes,
        config_file      => $prometheus_agent_config,
        source           => 'puppet:///modules/profile/query_service/updater-prometheus-jmx.yaml',
        before           => Service[$instance_name],
    }

    $default_jvm_options = ['-XX:+UseNUMA', "-javaagent:${prometheus_agent_path}=${prometheus_agent_port}:${prometheus_agent_config}"]

    $kafka_brokers = kafka_config($kafka_cluster)['brokers']['string']
    $kafka_options = [
        '--brokers', $kafka_brokers,
        '--consumerGroup', $::hostname,
        '--topic', $kafka_topic
    ]

    class { 'query_service::updater':
        package_dir            => $package_dir,
        data_dir               => $data_dir,
        log_dir                => $log_dir,
        deploy_name            => $deploy_name,
        username               => $username,
        logstash_logback_port  => $logstash_logback_port,
        options                => ['--'] + $kafka_options,
        extra_jvm_opts         => $default_jvm_options,
        updater_startup_script => 'runStreamingUpdater.sh',
        updater_service_desc   => 'Query Service Streaming Updater',
    }

    class { 'query_service::monitor::updater':
        username           => $username,
        updater_main_class => 'org.wikidata.query.rdf.tool.StreamingUpdate',
    }

}
