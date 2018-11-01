class profile::wdqs (
    String $logstash_host = hiera('logstash_host'),
    Enum['scap3', 'autodeploy', 'manual'] $deploy_mode = hiera('profile::wdqs::deploy_mode'),
    String $package_dir = hiera('profile::wdqs::package_dir'),
    String $data_dir = hiera('profile::wdqs::data_dir'),
    String $endpoint = hiera('profile::wdqs::endpoint'),
    Array[String] $blazegraph_options = hiera('profile::wdqs::blazegraph_options'),
    String $blazegraph_heap_size = hiera('profile::wdqs::blazegraph_heap_size'),
    String $blazegraph_config_file = hiera('profile::wdqs::blazegraph_config_file'),
    String $updater_options = hiera('profile::wdqs::updater_options'),
    Array[String] $nodes = hiera('profile::wdqs::nodes'),
    Boolean $use_kafka_for_updates = hiera('profile::wdqs::use_kafka_for_updates'),
    String $kafka_options = hiera('profile::wdqs::kafka_updater_options'),
    Array[String] $cluster_names = hiera('profile::wdqs::cluster_names'),
    String $rc_options = hiera('profile::wdqs::rc_updater_options'),
    Boolean $enable_ldf = hiera('profile::wdqs::enable_ldf'),
    Integer $max_query_time_millis = hiera('profile::wdqs::max_query_time_millis'),
    Boolean $high_query_time_port = hiera('profile::wdqs::high_query_time_port'),
    Array[String] $prometheus_nodes = hiera('prometheus_nodes'),
    String $contact_groups = hiera('contactgroups', 'admins'),
    Boolean $fetch_constraints = hiera('profile::wdqs::fetch_constraints'),
    Enum['none', 'daily', 'weekly'] $load_categories = hiera('profile::wdqs::load_categories'),
    Array[String] $blazegraph_extra_jvm_opts = hiera('profile::wdqs::blazegraph_extra_jvm_opts'),
    Integer[0] $lag_warning  = hiera('profile::wdqs::lag_warning', 1200),
    Integer[0] $lag_critical = hiera('profile::wdqs::lag_critical', 3600),
) {
    require ::profile::prometheus::blazegraph_exporter

    $nagios_contact_group = 'admins,wdqs-admins'

    $prometheus_agent_path = '/usr/share/java/prometheus/jmx_prometheus_javaagent.jar'
    $prometheus_blazegraph_agent_port = '9102'
    $prometheus_updater_agent_port = '9101'
    $prometheus_blazegraph_agent_config = '/etc/wdqs/wdqs-blazegraph-prometheus-jmx.yaml'
    $prometheus_updater_agent_config = '/etc/wdqs/wdqs-updater-prometheus-jmx.yaml'

    $default_extra_jvm_opts = [
        '-XX:+UseNUMA',
        '-XX:+UnlockExperimentalVMOptions',
        '-XX:G1NewSizePercent=20',
        '-XX:+ParallelRefProcEnabled',
        "-javaagent:${prometheus_agent_path}=${prometheus_blazegraph_agent_port}:${prometheus_blazegraph_agent_config}"
    ]

    # Install services - both blazegraph and the updater
    class { '::wdqs':
        deploy_mode            => $deploy_mode,
        package_dir            => $package_dir,
        data_dir               => $data_dir,
        endpoint               => $endpoint,
        blazegraph_options     => $blazegraph_options,
        blazegraph_heap_size   => $blazegraph_heap_size,
        blazegraph_config_file => $blazegraph_config_file,
        logstash_host          => $logstash_host,
        extra_jvm_opts         => $default_extra_jvm_opts + $blazegraph_extra_jvm_opts,
    }

    profile::prometheus::jmx_exporter { 'wdqs_blazegraph':
        hostname         => $::hostname,
        port             => $prometheus_blazegraph_agent_port,
        prometheus_nodes => $prometheus_nodes,
        config_file      => $prometheus_blazegraph_agent_config,
        source           => 'puppet:///modules/profile/wdqs/wdqs-blazegraph-prometheus-jmx.yaml',
    }
    profile::prometheus::jmx_exporter { 'wdqs_updater':
        hostname         => $::hostname,
        port             => $prometheus_updater_agent_port,
        prometheus_nodes => $prometheus_nodes,
        config_file      => $prometheus_updater_agent_config,
        source           => 'puppet:///modules/profile/wdqs/wdqs-updater-prometheus-jmx.yaml',
    }

    if $use_kafka_for_updates {
        $kafka_brokers = kafka_config('main')['brokers']['string']
        $base_kafka_options = "--kafka ${kafka_brokers} --consumer ${::hostname} ${kafka_options}"
        $joined_cluster_names = join($cluster_names, ',')

        $poller_options = count($cluster_names) ? {
            0       => $base_kafka_options,
            default => "${base_kafka_options} --clusters ${joined_cluster_names}",
        }
    } else {
        $poller_options = $rc_options
    }

    $fetch_constraints_options = $fetch_constraints ? {
        true    => '--constraints',
        default => '',
    }
    # 0 - Main, 120 - Property, 146 - Lexeme
    $extra_updater_options = "${poller_options} ${fetch_constraints_options} --entityNamespaces 0,120,146"

    class { 'wdqs::updater':
        options        => "${updater_options} -- ${extra_updater_options}",
        logstash_host  => $logstash_host,
        package_dir    => $package_dir,
        data_dir       => $data_dir,
        extra_jvm_opts => [
            '-XX:+UseNUMA',
            "-javaagent:${prometheus_agent_path}=${prometheus_updater_agent_port}:${prometheus_updater_agent_config}",
        ],
        require        => Profile::Prometheus::Jmx_exporter['wdqs_updater'],
    }

    # Service Web proxy
    class { '::wdqs::gui':
        package_dir           => $package_dir,
        data_dir              => $data_dir,
        deploy_mode           => $deploy_mode,
        enable_ldf            => $enable_ldf,
        max_query_time_millis => $max_query_time_millis,
        load_categories       => $load_categories,
    }

    # Firewall
    ferm::service {
        'wdqs_http':
            proto => 'tcp',
            port  => '80';
        'wdqs_https':
            proto => 'tcp',
            port  => '443';
        # temporary port to transfer data file between wdqs nodes via netcat
        'wdqs_file_transfer':
            proto  => 'tcp',
            port   => '9876',
            srange => inline_template("@resolve((<%= @nodes.join(' ') %>))");
    }

    if $high_query_time_port {
        # port 8888 accepts queries and runs them with a higher time limit.
        ferm::service { 'wdqs_internal_http':
            proto  => 'tcp',
            port   => '8888',
            srange => '$DOMAIN_NETWORKS';
        }
    }

    # Monitoring
    class { '::wdqs::monitor::services':
        contact_groups => $contact_groups,
        lag_warning    => $lag_warning,
        lag_critical   => $lag_critical,
    }

    # spread IRQ for NIC
    interface::rps { $facts['interface_primary']: }
}
