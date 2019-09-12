# == Class: profile::prometheus::alerts
#
# Install icinga alerts based on Prometheus metrics.
# NOTE to be included only from one host, icinga will generate different alerts
# for all hosts that include this class.
#
class profile::prometheus::alerts (
    $datacenters = hiera('datacenters'),
) {

    # Monitor Druid realtime ingestion event rate.
    # Experimental, only alerting the Analytics alias.
    # Temporary disabled
    # monitoring::check_prometheus { 'druid_realtime_banner_activity':
    #     description     => 'Number of banner_activity realtime events received by Druid over a 30 minutes period',
    #     query           => 'scalar(sum(sum_over_time(druid_realtime_ingest_events_processed_count{cluster="druid_analytics", instance=~"druid.*:8000", datasource=~"banner_activity_minutely"}[30m])))',
    #     prometheus_url  => 'http://prometheus.svc.eqiad.wmnet/analytics',
    #     method          => 'le',
    #     warning         => 10,
    #     critical        => 0,
    #     contact_group   => 'analytics',
    #     dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/druid?refresh=1m&panelId=41&fullscreen&orgId=1']
    # }

    # Monitor Druid segments reported as unavailable by the Coordinator
    monitoring::check_prometheus { 'druid_coordinator_segments_unavailable_analytics':
        description     => 'Number of segments reported as unavailable by the Druid Coordinators of the Analytics cluster',
        query           => 'scalar(sum(sum_over_time(druid_coordinator_segment_unavailable_count{cluster="druid_analytics", instance=~"druid.*:8000", datasource=~".*"}[15m])))',
        prometheus_url  => 'http://prometheus.svc.eqiad.wmnet/analytics',
        method          => 'gt',
        warning         => 180,
        critical        => 200,
        retry_interval  => 15,
        retries         => 6,
        contact_group   => 'analytics',
        dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/druid?refresh=1m&panelId=46&fullscreen&orgId=1&var-cluster=druid_analytics&var-druid_datasource=All'],
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Analytics/Systems/Druid#Troubleshooting',
    }

    monitoring::check_prometheus { 'druid_coordinator_segments_unavailable_public':
        description     => 'Number of segments reported as unavailable by the Druid Coordinators of the Public cluster',
        query           => 'scalar(sum(sum_over_time(druid_coordinator_segment_unavailable_count{cluster="druid_public", instance=~"druid.*:8000", datasource=~".*"}[15m])))',
        prometheus_url  => 'http://prometheus.svc.eqiad.wmnet/analytics',
        method          => 'gt',
        warning         => 180,
        critical        => 200,
        retry_interval  => 15,
        retries         => 6,
        contact_group   => 'analytics',
        dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/druid?refresh=1m&panelId=46&fullscreen&orgId=1&var-cluster=druid_public&var-druid_datasource=All'],
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Analytics/Systems/Druid#Troubleshooting',
    }

    # Monitor throughput and dropped messages on MirrorMaker instances.
    # main-eqiad -> jumbo MirrorMaker
    profile::kafka::mirror::alerts { 'main-eqiad_to_jumbo-eqiad':
        #  For now, alert analytics admins.  Change this back to admins soon.
        contact_group         => 'analytics',
        topic_blacklist       => '.*(change-prop|\.job\.|changeprop).*',
        prometheus_url        => 'http://prometheus.svc.eqiad.wmnet/ops',
        source_prometheus_url => 'http://prometheus.svc.eqiad.wmnet/ops',
    }

    # Cross DC main-eqiad <-> main-codfw MirrorMakers.
    profile::kafka::mirror::alerts { 'main-eqiad_to_main-codfw':
        prometheus_url        => 'http://prometheus.svc.codfw.wmnet/ops',
        source_prometheus_url => 'http://prometheus.svc.eqiad.wmnet/ops',
        # Less data (resource_change) from main eqiad -> codfw.
        warning_throughput    => 25,
    }
    profile::kafka::mirror::alerts { 'main-codfw_to_main-eqiad':
        #  For now, alert analytics admins, until alerts are more stable.
        prometheus_url        => 'http://prometheus.svc.eqiad.wmnet/ops',
        source_prometheus_url => 'http://prometheus.svc.codfw.wmnet/ops',
    }


    # Eventlogging

    # Warn if p50 of overall error event throughput goes above 20 events/s
    # in a 15 minute period.
    # The EventError topic counted here includes both events that do not
    # validate and events that can not be processed for other reasons
    monitoring::check_prometheus { 'eventlogging_EventError_throughput':
        description     => 'Throughput of EventLogging EventError events',
        query           => 'scalar(quantile(0.50,sum(rate(kafka_server_BrokerTopicMetrics_MessagesIn_total{cluster="kafka_jumbo",topic="eventlogging_EventError"}[15m]))))',
        prometheus_url  => 'http://prometheus.svc.eqiad.wmnet/ops',
        warning         => 20,
        critical        => 30,
        method          => 'ge',
        contact_group   => 'analytics',
        dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/eventlogging?panelId=13&fullscreen&orgId=1'],
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Analytics/Systems/EventLogging/Administration',
    }

    # Alarms if p50 of Navigation Timing event throughput goes under 1 req/sec
    # in a 15 min period
    # https://meta.wikimedia.org/wiki/Schema:NavigationTiming
    monitoring::check_prometheus { 'eventlogging_NavigationTiming_throughput':
        description     => 'Throughput of EventLogging NavigationTiming events',
        query           => 'scalar(quantile(0.50,sum(rate(kafka_server_BrokerTopicMetrics_MessagesIn_total{cluster="kafka_jumbo",topic="eventlogging_NavigationTiming"}[15m]))))',
        prometheus_url  => 'http://prometheus.svc.eqiad.wmnet/ops',
        warning         => 1,
        critical        => 0,
        method          => 'le',
        contact_group   => 'analytics',
        dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/eventlogging?panelId=6&fullscreen&orgId=1'],
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Analytics/Systems/EventLogging/Administration',
    }

    # Warn if p50 of overall event throughput goes beyond 1500 events/s
    # in a 15 min period.
    # These thresholds are somewhat arbtirary.
    monitoring::check_prometheus { 'eventlogging_throughput':
        description     => 'Throughput of EventLogging events',
        query           => 'scalar(quantile(0.50,sum(rate(kafka_server_BrokerTopicMetrics_MessagesIn_total{cluster="kafka_jumbo",topic="eventlogging-client-side"}[15m]))))',
        prometheus_url  => 'http://prometheus.svc.eqiad.wmnet/ops',
        warning         => 6000,
        critical        => 8000,
        method          => 'ge',
        contact_group   => 'analytics',
        dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/eventlogging?panelId=6&fullscreen&orgId=1'],
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Analytics/Systems/EventLogging/Administration',
    }

    # Alert if the Kafka consumer lag of EL's processors builds up. This usually means that EL
    # is not processing events, or for some reason it slowed down a lot and can't keep up anymore.
    monitoring::check_prometheus { 'eventlogging_processors_kafka_lag':
        description     => 'Kafka Consumer lag of the EventLogging processors',
        query           => 'scalar(sum(kafka_burrow_partition_lag{exported_cluster="jumbo-eqiad",topic="eventlogging-client-side",group="eventlogging_processor_client_side_00"}))',
        prometheus_url  => 'http://prometheus.svc.eqiad.wmnet/ops',
        warning         => 250000,
        critical        => 500000,
        check_interval  => 60,
        method          => 'ge',
        contact_group   => 'analytics',
        dashboard_links => ['https://grafana.wikimedia.org/d/000000484/kafka-consumer-lag?orgId=1&prometheus=ops&var-cluster=jumbo-eqiad&var-topic=All&var-consumer_group=eventlogging_processor_client_side_00'],
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Analytics/Systems/EventLogging/Administration',
    }

    monitoring::alerts::kafka_topic_throughput { 'eventgate-analytics_validation_errors':
        kafka_cluster_name => 'jumbo-eqiad',
        topic              => '.*\.eventgate-analytics\.error\.validation',
        method             => 'gt',
        warning            => 0.0,
        # 1 per second rate over the last 15 minutes.
        critical           => 1.0,
        contact_group      => 'analytics',
        dashboard_links    => ['https://grafana.wikimedia.org/d/ePFPOkqiz/eventgate?refresh=1m&orgId=1&var-dc=eqiad prometheus/k8s&var-service=eventgate-analytics&var-kafka_topic=All&var-kafka_broker=All&var-kafka_producer_type=All'],
    }
    monitoring::alerts::kafka_topic_throughput { 'eventgate-main_validation_errors':
        kafka_cluster_name => 'jumbo-eqiad',
        topic              => '.*\.eventgate-main\.error\.validation',
        method             => 'gt',
        warning            => 0.0,
        # 0.5 per second rate over the last 15 minutes.
        critical           => 0.5,
        dashboard_links    => ['https://grafana.wikimedia.org/d/ePFPOkqiz/eventgate?refresh=1m&orgId=1&var-dc=eqiad prometheus/k8s&var-service=eventgate-main&var-kafka_topic=All&var-kafka_broker=All&var-kafka_producer_type=All'],
    }

    monitoring::alerts::http_availability{'http_availability_eqiad': site => 'eqiad'}
    monitoring::alerts::http_availability{'http_availability_codfw': site => 'codfw'}
    monitoring::alerts::http_availability{'http_availability_esams': site => 'esams'}
    monitoring::alerts::http_availability{'http_availability_ulsfo': site => 'ulsfo'}
    monitoring::alerts::http_availability{'http_availability_eqsin': site => 'eqsin'}

    monitoring::alerts::traffic_drop{'traffic_drop_eqiad': site => 'eqiad'}
    monitoring::alerts::traffic_drop{'traffic_drop_codfw': site => 'codfw'}
    monitoring::alerts::traffic_drop{'traffic_drop_esams': site => 'esams'}
    monitoring::alerts::traffic_drop{'traffic_drop_ulsfo': site => 'ulsfo'}
    monitoring::alerts::traffic_drop{'traffic_drop_eqsin': site => 'eqsin'}

    monitoring::alerts::rsyslog{'rsyslog_eqiad': site => 'eqiad'}
    monitoring::alerts::rsyslog{'rsyslog_codfw': site => 'codfw'}
    monitoring::alerts::rsyslog{'rsyslog_esams': site => 'esams'}
    monitoring::alerts::rsyslog{'rsyslog_ulsfo': site => 'ulsfo'}
    monitoring::alerts::rsyslog{'rsyslog_eqsin': site => 'eqsin'}

    # Alert on unusual day-over-day logstash ingestion rate change - T202307
    monitoring::check_prometheus { 'logstash_ingestion_spike':
        description     => 'Logstash rate of ingestion percent change compared to yesterday',
        # Divide rate of input now vs yesterday, multiplied by 100
        query           => '100 * (sum (rate(logstash_node_plugin_events_out_total{plugin_id=~"input/.*"}[5m])) / sum (rate(logstash_node_plugin_events_out_total{plugin_id=~"input/.*"}[5m] offset 1d)))',
        prometheus_url  => 'http://prometheus.svc.eqiad.wmnet/ops',
        warning         => 150,
        critical        => 210,
        method          => 'ge',
        dashboard_links => ['https://grafana.wikimedia.org/dashboard/db/logstash?orgId=1&panelId=2&fullscreen'],
        # Check every 120 minutes, once in breach check every 10 minutes up to 5 times
        check_interval  => 120,
        retry_interval  => 10,
        retries         => 5,
        notes_link      => 'https://phabricator.wikimedia.org/T202307',
    }

    monitoring::check_prometheus { 'kafka logging-eqiad consumer lag':
        description     => 'Too many messages in kafka logging-eqiad',
        query           => 'kafka_burrow_partition_lag{exported_cluster="logging-eqiad"}',
        prometheus_url  => 'http://prometheus.svc.eqiad.wmnet/ops',
        warning         => 1000,
        critical        => 1500,
        retries         => 10,
        method          => 'ge',
        dashboard_links => ['https://grafana.wikimedia.org/d/000000484/kafka-consumer-lag?from=now-3h&to=now&orgId=1&var-datasource=eqiad prometheus/ops&var-cluster=logging-eqiad&var-topic=All&var-consumer_group=All'],
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Logstash#Kafka_consumer_lag',
    }

    monitoring::check_prometheus { 'kafka logging-codfw consumer lag':
        description     => 'Too many messages in kafka logging-codfw',
        query           => 'kafka_burrow_partition_lag{exported_cluster="logging-codfw"}',
        prometheus_url  => 'http://prometheus.svc.codfw.wmnet/ops',
        warning         => 1000,
        critical        => 1500,
        retries         => 10,
        method          => 'ge',
        dashboard_links => ['https://grafana.wikimedia.org/d/000000484/kafka-consumer-lag?from=now-3h&to=now&orgId=1&var-datasource=codfw prometheus/ops&var-cluster=logging-codfw&var-topic=All&var-consumer_group=All'],
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Logstash#Kafka_consumer_lag',
    }

    monitoring::check_prometheus { 'widespread-puppet-agent-fail':
        description     => 'Widespread puppet agent failures',
        dashboard_links => ['https://grafana.wikimedia.org/d/yOxVDGvWk/puppet'],
        query           => 'sum(cluster:puppet_agent_failed:sum) by (site) / sum(cluster:puppet_agent_failed:count) by (site)',
        warning         => 0.02,
        critical        => 0.05,
        method          => 'ge',
        # Icinga will query the site-local Prometheus 'global' instance
        prometheus_url  => "http://prometheus.svc.${::site}.wmnet/global",
    }

    monitoring::check_prometheus { 'widespread-puppet-agent-no-resources':
        description     => 'Widespread puppet agent failures, no resources reported',
        dashboard_links => ['https://grafana.wikimedia.org/d/yOxVDGvWk/puppet'],
        query           => 'sum(cluster:puppet_agent_resources_total:count0) by (site) / sum(cluster:puppet_agent_resources_total:count) by (site)',
        warning         => 0.02,
        critical        => 0.05,
        method          => 'ge',
        # Icinga will query the site-local Prometheus 'global' instance
        prometheus_url  => "http://prometheus.svc.${::site}.wmnet/global",
    }

    # Perform aggregate ipsec checks per-datacenter (site) to ease downtimes/maintenance
    $datacenters.each |String $datacenter| {
        monitoring::alerts::aggregate_ipsec{"aggregate_ipsec_${datacenter}": site => $datacenter }
    }

}
