# Uses the prometheus module and generates the specific configuration
# needed for WMF production
#
class profile::prometheus::k8s::staging (
    Hash $users = lookup('k8s_infrastructure_users'),
    String $replica_label = lookup('prometheus::replica_label', { 'default_value' => 'unset' }),
    Boolean $enable_thanos_upload = lookup('profile::prometheus::k8s::staging::thanos', { 'default_value' => false }),
    Optional[String] $thanos_min_time = lookup('profile::prometheus::thanos::min_time', { 'default_value' => undef }),
    Array[Stdlib::Host] $alertmanagers = lookup('alertmanagers', {'default_value' => []}),
){
    $targets_path = '/srv/prometheus/k8s-staging/targets'
    $storage_retention = hiera('prometheus::server::storage_retention', '4032h') # lint:ignore:wmf_styleguide
    $max_chunks_to_persist = hiera('prometheus::server::max_chunks_to_persist', '524288') # lint:ignore:wmf_styleguide
    $memory_chunks = hiera('prometheus::server::memory_chunks', '1048576') # lint:ignore:wmf_styleguide
    $bearer_token_file = '/srv/prometheus/k8s-staging/k8s.token'
    $master_host = 'neon.eqiad.wmnet'
    $client_token = $users['prometheus']['token']

    $config_extra = {
        # All metrics will get an additional 'site' label when queried by
        # external systems (e.g. via federation)
        'external_labels' => {
            'site'       => $::site,
            'replica'    => $replica_label,
            'prometheus' => 'k8s-staging',
        },
    }

    # Configure scraping from k8s cluster with distinct jobs:
    # - k8s-api: api server metrics (each one, as returned by k8s)
    # - k8s-node: metrics from each node running k8s
    # See also:
    # * https://prometheus.io/docs/operating/configuration/#<kubernetes_sd_config>
    # * https://github.com/prometheus/prometheus/blob/master/documentation/examples/prometheus-kubernetes.yml
    $scrape_configs_extra = [
        {
            'job_name'              => 'k8s-api',
            'bearer_token_file'     => $bearer_token_file,
            'scheme'                => 'https',
            'tls_config' => {
                'server_name' => $master_host,
            },
            'kubernetes_sd_configs' => [
                {
                    'api_server'        => "https://${master_host}:6443",
                    'bearer_token_file' => $bearer_token_file,
                    'role'              => 'endpoints',
                },
            ],
            # Scrape config for API servers, keep only endpoints for default/kubernetes to poll only
            # api servers
            'relabel_configs'       => [
                {
                    'source_labels' => ['__meta_kubernetes_namespace',
                                        '__meta_kubernetes_service_name',
                                        '__meta_kubernetes_endpoint_port_name'],
                    'action'        => 'keep',
                    'regex'         => 'default;kubernetes;https',
                },
            ],
        },
        {
            'job_name'              => 'k8s-node',
            'bearer_token_file'     => $bearer_token_file,
            'kubernetes_sd_configs' => [
                {
                    'api_server'        => "https://${master_host}:6443",
                    'bearer_token_file' => $bearer_token_file,
                    'role'              => 'node',
                },
            ],
            'relabel_configs'       => [
                # Map kubernetes node labels to prometheus metric labels
                {
                    'action' => 'labelmap',
                    'regex'  => '__meta_kubernetes_node_label_(.+)',
                },
                {
                    # Force read-only API for nodes. This listens on port 10255
                    # so rewrite the __address__ label to use that port. It's
                    # also HTTP, not HTTPS
                    'action'        => 'replace',  # Redundant but clearer
                    'source_labels' => ['__address__'],
                    'target_label'  => '__address__',
                    'regex'         => '([\d\.]+):(\d+)',
                    'replacement'   => "\${1}:10255",
                },
            ]
        },
        {
            'job_name'              => 'k8s-node-cadvisor',
            'bearer_token_file'     => $bearer_token_file,
            'metrics_path'          => '/metrics/cadvisor',
            'kubernetes_sd_configs' => [
                {
                    'api_server'        => "https://${master_host}:6443",
                    'bearer_token_file' => $bearer_token_file,
                    'role'              => 'node',
                },
            ],
            'relabel_configs'       => [
                # Map kubernetes node labels to prometheus metric labels
                {
                    'action' => 'labelmap',
                    'regex'  => '__meta_kubernetes_node_label_(.+)',
                },
                {
                    # Force read-only API for nodes. This listens on port 10255
                    # so rewrite the __address__ label to use that port. It's
                    # also HTTP, not HTTPS
                    'action'        => 'replace',  # Redundant but clearer
                    'source_labels' => ['__address__'],
                    'target_label'  => '__address__',
                    'regex'         => '([\d\.]+):(\d+)',
                    'replacement'   => "\${1}:10255",
                },
            ]
        },
        {
            'job_name'              => 'k8s-node-proxy',
            'bearer_token_file'     => $bearer_token_file,
            'kubernetes_sd_configs' => [
                {
                    'api_server'        => "https://${master_host}:6443",
                    'bearer_token_file' => $bearer_token_file,
                    'role'              => 'node',
                },
            ],
            'relabel_configs'       => [
                # Map kubernetes node labels to prometheus metric labels
                {
                    'action' => 'labelmap',
                    'regex'  => '__meta_kubernetes_node_label_(.+)',
                },
                {
                    # Force read-only API for talking to kubeproxy. Listens on
                    # port 10249 so rewrite the __address__ label to use that
                    # port. It's also HTTP, not HTTPS
                    'action'        => 'replace',  # Redundant but clearer
                    'source_labels' => ['__address__'],
                    'target_label'  => '__address__',
                    'regex'         => '([\d\.]+):(\d+)',
                    'replacement'   => "\${1}:10249",
                },
            ]
        },
        {
            'job_name'              => 'k8s-pods',
            'bearer_token_file'     => $bearer_token_file,
            # Note: We dont verify the cert on purpose. Issues IP SAN based
            # certs for all pods is impossible
            'tls_config'            => {
                insecure_skip_verify =>  true,
            },
            'kubernetes_sd_configs' => [
                {
                    'api_server'        => "https://${master_host}:6443",
                    'bearer_token_file' => $bearer_token_file,
                    'role'              => 'pod',
                },
            ],
            'relabel_configs' => [
                {
                    'action'        => 'keep',
                    'source_labels' => ['__meta_kubernetes_pod_annotation_prometheus_io_scrape'],
                    'regex'         => true,
                },
                {
                    'action'        => 'drop',
                    'source_labels' => ['envoy_cluster_name'],
                    'regex'         => '^admin_interface$',
                },
                {
                    'action'        => 'replace',
                    'source_labels' => ['__meta_kubernetes_pod_annotation_prometheus_io_path'],
                    'target_label'  => '__metrics_path__',
                    'regex'         => '(.+)',
                },
                {
                    'action'        => 'replace',
                    'source_labels' => ['__meta_kubernetes_pod_annotation_prometheus_io_scheme'],
                    'target_label'  => '__scheme__',
                    'regex'         => '(.+)',
                },
                {
                    'action'        => 'replace',
                    'source_labels' => ['__address__', '__meta_kubernetes_pod_annotation_prometheus_io_port'],
                    'regex'         => '([^:]+)(?::\d+)?;(\d+)',
                    'replacement'   => '$1:$2',
                    'target_label'  => '__address__',
                },
                {
                    'action'        => 'labelmap',
                    'regex'         => '__meta_kubernetes_pod_label_(.+)',
                },
                {
                    'action'        => 'replace',
                    'source_labels' => ['__meta_kubernetes_namespace'],
                    'target_label'  => 'kubernetes_namespace',
                },
                {
                    'action'        => 'replace',
                    'source_labels' => ['__meta_kubernetes_pod_name'],
                    'target_label'  => 'kubernetes_pod_name',
                },
            ]
        },
        {
            'job_name'              => 'k8s-pods-tls',
            'bearer_token_file'     => $bearer_token_file,
            'metrics_path'          => '/stats/prometheus',
            'scheme'                => 'http',
            'kubernetes_sd_configs' => [
                {
                    'api_server'        => "https://${master_host}:6443",
                    'bearer_token_file' => $bearer_token_file,
                    'role'              => 'pod',
                },
            ],
            'relabel_configs' => [
                {
                    'action'        => 'keep',
                    'source_labels' => ['__meta_kubernetes_pod_annotation_envoyproxy_io_scrape'],
                    'regex'         => true,
                },
                {
                    'action'        => 'replace',
                    'source_labels' => ['__address__', '__meta_kubernetes_pod_annotation_envoyproxy_io_port'],
                    'regex'         => '([^:]+)(?::\d+)?;(\d+)',
                    'replacement'   => '$1:$2',
                    'target_label'  => '__address__',
                },
                {
                    'action'        => 'labelmap',
                    'regex'         => '__meta_kubernetes_pod_label_(.+)',
                },
                {
                    'action'        => 'replace',
                    'source_labels' => ['__meta_kubernetes_namespace'],
                    'target_label'  => 'kubernetes_namespace',
                },
                {
                    'action'        => 'replace',
                    'source_labels' => ['__meta_kubernetes_pod_name'],
                    'target_label'  => 'kubernetes_pod_name',
                },
            ],
        },
        {
            'job_name'        => 'calico-felix',
            'file_sd_configs' =>  [
                { 'files' =>  [ "${targets_path}/calico-felix_*.yaml" ] },
            ],
        },
    ]

    $max_block_duration = $enable_thanos_upload ? {
        true    => '2h',
        default => '24h',
    }

    prometheus::server { 'k8s-staging':
        listen_address        => '127.0.0.1:9907',
        storage_retention     => $storage_retention,
        max_chunks_to_persist => $max_chunks_to_persist,
        memory_chunks         => $memory_chunks,
        global_config_extra   => $config_extra,
        scrape_configs_extra  => $scrape_configs_extra,
        min_block_duration    => '2h',
        max_block_duration    => $max_block_duration,
        alertmanagers         => $alertmanagers.map |$a| { "${a}:9093" },
    }

    prometheus::web { 'k8s-staging':
        proxy_pass => 'http://localhost:9907/k8s-staging',
    }

    profile::thanos::sidecar { 'k8s-staging':
        prometheus_port     => 9907,
        prometheus_instance => 'k8s-staging',
        enable_upload       => $enable_thanos_upload,
        min_time            => $thanos_min_time,
    }

    prometheus::rule { 'rules_k8s-staging.yml':
        instance => 'k8s-staging',
        source   => 'puppet:///modules/profile/prometheus/rules_k8s.yml',
    }

    prometheus::class_config { 'calico-felix-staging':
        dest           => "${targets_path}/calico-felix_${::site}.yaml",
        site           => $::site,
        class_name     => 'role::kubernetes::staging::worker',
        hostnames_only => false,
        port           => 9091,
    }

    file { $bearer_token_file:
        ensure  => present,
        content => $client_token,
        mode    => '0400',
        owner   => 'prometheus',
        group   => 'prometheus',
    }
}
