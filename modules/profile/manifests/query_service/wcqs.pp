# = Class: profile::query_service::wcqs
#
# This class defines a meta-class that pulls in all the query_service profiles
# necessary for a query service installation servicing the commons.wikimedia.org
# dataset.
class profile::query_service::wcqs(
    Stdlib::Unixpath $package_dir = lookup('profile::query_service::package_dir'),
    Stdlib::Unixpath $data_dir = lookup('profile::query_service::data_dir'),
    Stdlib::Unixpath $log_dir = lookup('profile::query_service::log_dir'),
    String $deploy_name = lookup('profile::query_service::deploy_name'),
    Stdlib::Port $logstash_logback_port = lookup('logstash_logback_port'),
    String $heap_size = lookup('profile::query_service::blazegraph_heap_size'),
    Boolean $use_deployed_config = lookup('profile::query_service::blazegraph_use_deployed_config'),
    Array[String] $options = lookup('profile::query_service::blazegraph_options'),
    Array[String] $extra_jvm_opts = lookup('profile::query_service::blazegraph_extra_jvm_opts'),
    Array[String] $prometheus_nodes = lookup('prometheus_nodes'),
    String $contact_groups = lookup('contactgroups', {'default_value' => 'admins'}),
    Boolean $monitoring_enabled = lookup('profile::query_service::blazegraph::monitoring_enabled'),
    Optional[String] $sparql_query_stream = lookup('profile::query_service::sparql_query_stream', {'default_value' => undef}),
    Optional[String] $event_service_endpoint = lookup('profile::query_service::event_service_endpoint', {'default_value' => undef}),
    Optional[Query_service::OAuthSettings] $oauth_settings = lookup('profile::query_service::oauth_settings'),
    String $federation_user_agent = lookup('profile::query_service::federation_user_agent'),
    String $blazegraph_main_ns = lookup('profile::query_service::blazegraph_main_ns')
) {
    require ::profile::query_service::common
    require ::profile::query_service::gui

    $username = 'blazegraph'
    $instance_name = "${deploy_name}-blazegraph"
    $blazegraph_port = 9999
    $prometheus_port = 9195
    $prometheus_agent_port = 9102
    $query_event_log='/var/log/wdqs/query_event.log'


    $uri_scheme_options = ['-DwikibaseConceptUri=http://www.wikidata.org', '-DcommonsConceptUri=https://commons.wikimedia.org']
    $event_sender_options = ['-Dwdqs.event-sender-filter.file-event-sender=true',
        "-Dwdqs.event-sender-filter.file-event-sender-filepath=${query_event_log}",
        '-Dwdqs.event-sender-filter.enable-event-sender-if-header=']

    logrotate::rule { 'query_event_sender_log':
      ensure        => present,
      file_glob     => $query_event_log,
      frequency     => 'weekly',
      copy_truncate => true,
      missing_ok    => true,
      not_if_empty  => true,
      rotate        => 7,
      compress      => true,
    }

    profile::query_service::blazegraph { $instance_name:
        username               => $username,
        package_dir            => $package_dir,
        data_dir               => $data_dir,
        log_dir                => $log_dir,
        deploy_name            => $deploy_name,
        logstash_logback_port  => $logstash_logback_port,
        heap_size              => $heap_size,
        use_deployed_config    => $use_deployed_config,
        options                => $options,
        extra_jvm_opts         => $extra_jvm_opts + $uri_scheme_options + $event_sender_options,
        prometheus_nodes       => $prometheus_nodes,
        contact_groups         => $contact_groups,
        monitoring_enabled     => $monitoring_enabled,
        sparql_query_stream    => $sparql_query_stream,
        event_service_endpoint => $event_service_endpoint,
        blazegraph_port        => $blazegraph_port,
        prometheus_port        => $prometheus_port,
        prometheus_agent_port  => $prometheus_agent_port,
        config_file_name       => 'RWStore.wcqs.properties',
        prefixes_file          => 'prefixes-sdc.conf',
        use_geospatial         => true,
        journal                => 'wcqs',
        blazegraph_main_ns     => $blazegraph_main_ns,
        oauth_settings         => $oauth_settings,
        federation_user_agent  => $federation_user_agent,
    }
}
