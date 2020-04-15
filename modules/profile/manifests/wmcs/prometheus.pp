class profile::wmcs::prometheus(
    $targets_path = '/srv/prometheus/labs/targets',
    $storage_retention = hiera('prometheus::server::storage_retention', '4032h'),
    $max_chunks_to_persist = hiera('prometheus::server::max_chunks_to_persist', '524288'),
    $memory_chunks = hiera('prometheus::server::memory_chunks', '1048576'),
    $toolforge_redis_hosts = hiera('profile::wmcs::prometheus::toolforge_redis_hosts', []),
) {
    include ::prometheus::blackbox_exporter
    $blackbox_jobs = [
        {
            'job_name'        => 'blackbox_http',
            'metrics_path'    => '/probe',
            'params'          => {
                'module' => [ 'http_200_300_connect' ],
            },
            'file_sd_configs' => [
                { 'files' => [ "${targets_path}/blackbox_http_*.yaml" ] }
            ],
            'relabel_configs' => [
                { 'source_labels' => ['__address__'],
                    'target_label'  => '__param_target',
                },
                { 'source_labels' => ['__param_target'],
                    'target_label'  => 'instance',
                },
                { 'target_label' => '__address__',
                    'replacement'  => '127.0.0.1:9115',
                },
              ],
        },
    ]

    $rabbitmq_jobs = [
        {
            'job_name'        => 'rabbitmq',
            'scheme'          => 'http',
            'file_sd_configs' => [
                { 'files' => [ "${targets_path}/rabbitmq_*.yaml" ] }
            ],
        },
    ]

    $pdns_jobs = [
        {
            'job_name'        => 'pdns',
            'scheme'          => 'http',
            'file_sd_configs' => [
                { 'files' => [ "${targets_path}/pdns_*.yaml" ] }
            ],
        },
    ]

    $pdns_rec_jobs = [
        {
            'job_name'        => 'pdns_rec',
            'scheme'          => 'http',
            'file_sd_configs' => [
                { 'files' => [ "${targets_path}/pdns-rec_*.yaml" ] }
            ],
        },
    ]

    $openstack_jobs = [
        {
            'job_name'        => 'openstack',
            'scheme'          => 'http',
            'file_sd_configs' => [
                { 'files' => [ "${targets_path}/openstack_*.yaml" ] }
            ],
        },
    ]

    $redis_jobs = [
        {
            'job_name'        => 'redis_toolforge',
            'scheme'          => 'http',
            'file_sd_configs' => [
                { 'files' => [ "${targets_path}/redis_toolforge_*.yaml" ] }
            ],
            'metric_relabel_configs' => [
                # redis_exporter runs alongside each redis instance, thus drop
                # the (uninteresting in this case) 'addr' and 'alias' labels
                {
                    'regex'  => '(addr|alias)',
                    'action' => 'labeldrop',
                },
            ],
        },
    ]

    $ceph_jobs = [
      {
        'job_name'        => "ceph_${::site}",
        'scheme'          => 'http',
        'file_sd_configs' => [
          { 'files' => [ "${targets_path}/ceph_${::site}.yaml" ]}
        ],
      },
    ]

    file { "${targets_path}/blackbox_http_keystone.yaml":
      content => ordered_yaml([{
        'targets' => ['openstack.eqiad1.wikimediacloud.org:5000/v3', # keystone
                      'openstack.eqiad1.wikimediacloud.org:9292', # glance
                      'openstack.eqiad1.wikimediacloud.org:8774', # nova
                      'openstack.eqiad1.wikimediacloud.org:9001', # designate
                      'openstack.eqiad1.wikimediacloud.org:9696', # neutron
                      'proxy-eqiad1.wmflabs.org:5668', # proxy
            ]
        }]),
    }

    prometheus::class_config{ "rabbitmq_${::site}":
        dest       => "${targets_path}/rabbitmq_${::site}.yaml",
        site       => $::site,
        class_name => 'role::wmcs::openstack::eqiad1::control',
        port       => 9195,
    }

    prometheus::class_config{ "pdns_${::site}":
        dest       => "${targets_path}/pdns_${::site}.yaml",
        site       => $::site,
        class_name => 'role::wmcs::openstack::eqiad1::services',
        port       => 9192,
    }

    prometheus::class_config{ "pdns-rec_${::site}":
        dest       => "${targets_path}/pdns-rec_${::site}.yaml",
        site       => $::site,
        class_name => 'role::wmcs::openstack::eqiad1::services',
        port       => 9199,
    }

    prometheus::class_config{ "openstack_${::site}":
        dest       => "${targets_path}/openstack_${::site}.yaml",
        site       => $::site,
        class_name => 'role::wmcs::openstack::eqiad1::control',
        # same as profile::openstack::eqiad1::metrics::prometheus_listen_port and friends
        port       => 12345,
    }

    file { "${targets_path}/redis_toolforge_hosts.yaml":
        content => ordered_yaml([{
            'targets' => regsubst($toolforge_redis_hosts, '(.*)', '[\0]:9121')
        }]);
    }

    prometheus::class_config{ "ceph_${::site}":
        dest       => "${targets_path}/ceph_${::site}.yaml",
        site       => $::site,
        class_name => 'role::wmcs::ceph::mon',
        port       => 9283,
    }

    prometheus::server { 'labs':
        listen_address        => '127.0.0.1:9900',
        storage_retention     => $storage_retention,
        max_chunks_to_persist => $max_chunks_to_persist,
        memory_chunks         => $memory_chunks,
        scrape_configs_extra  => array_concat(
            $blackbox_jobs, $rabbitmq_jobs, $pdns_jobs,
            $pdns_rec_jobs, $openstack_jobs, $redis_jobs,
            $ceph_jobs,
        ),
    }

    httpd::site{ 'prometheus':
        priority => 10,
        content  => template('profile/wmcs/prometheus/prometheus-apache.erb'),
    }

    prometheus::web { 'labs':
        proxy_pass => 'http://localhost:9900/labs',
        require    => Httpd::Site['prometheus'],
    }


    ferm::service { 'prometheus-web':
        proto  => 'tcp',
        port   => '80',
        srange => '$DOMAIN_NETWORKS',
    }
}
