class profile::wmcs::prometheus::metricsinfra(
    Array[Hash]  $projects          = lookup('profile::wmcs::prometheus::metricsinfra::projects'),
    Stdlib::Fqdn $ext_fqdn          = lookup('profile::wmcs::prometheus::metricsinfra::ext_fqdn'),
    Stdlib::Fqdn $keystone_api_fqdn = lookup('profile::openstack::eqiad1::keystone_api_fqdn'),
    String       $observer_password = lookup('profile::openstack::eqiad1::observer_password'),
    String       $observer_user     = lookup('profile::openstack::base::observer_user'),
    String       $region            = lookup('profile::openstack::eqiad1::region'),
) {
    # Base Prometheus data and configuration path
    $base_path = '/srv/prometheus/cloud'

    # Project node-exporter scrape configuration
    $project_configs = $projects.map |Hash $project| {
        {
            'job_name'             => "${project['name']}_node",
            'openstack_sd_configs' => [
                {
                    'role'              => 'instance',
                    'region'            => $region,
                    'identity_endpoint' => "http://${keystone_api_fqdn}:5000/v3",
                    'username'          => $observer_user,
                    'password'          => $observer_password,
                    'domain_name'       => 'default',
                    'project_name'      => $project['name'],
                    'all_tenants'       => false,
                    'refresh_interval'  => '5m',
                    'port'              => 9100,
                }
            ],
            'relabel_configs'      => [
                {
                    'source_labels' => ['__meta_openstack_instance_name'],
                    'target_label'  => 'instance',
                },
                {
                    'source_labels' => ['__meta_openstack_instance_status'],
                    'action'        => 'keep',
                    'regex'         => 'ACTIVE',
                }
            ]
        }
    }

    prometheus::server { 'cloud':
        # Localhost is being used here to pass prometheus module input validation
        alertmanager_url     => 'localhost:9093',
        external_url         => "https://${$ext_fqdn}/cloud",
        listen_address       => '127.0.0.1:9900',
        scrape_configs_extra => $project_configs,
    }

    # Prometheus alert rules
    file { "${base_path}/rules/alerts_projects.yml":
        ensure  => file,
        mode    => '0444',
        owner   => 'root',
        group   => 'root',
        source  => 'puppet:///modules/profile/wmcs/prometheus/metricsinfra/alerts_projects.yml',
        notify  => Exec['prometheus@cloud-reload'],
        require => Class['prometheus'],
    }

    # Prometheus alert manager service setup and config
    package { 'prometheus-alertmanager':
        ensure => present,
    }

    service { 'prometheus-alertmanager':
        ensure => running,
    }

    exec { 'alertmanager-reload':
        command     => '/bin/systemctl reload prometheus-alertmanager',
        refreshonly => true,
    }

    exec { 'alertmanager-restart':
        command     => '/bin/systemctl restart prometheus-alertmanager',
        refreshonly => true,
    }

    file { '/etc/default/prometheus-alertmanager':
        content => template('profile/wmcs/prometheus/metricsinfra/prometheus-alertmanager-defaults.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Exec['alertmanager-restart'],
    }

    file { "${base_path}/alertmanager.yml":
        content => template('profile/wmcs/prometheus/metricsinfra/alertmanager.yml.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Exec['alertmanager-reload'],
    }

    # Apache config
    class { '::httpd':
        modules => ['proxy', 'proxy_http', 'rewrite', 'headers'],
    }

    httpd::site{ 'prometheus':
        priority => 10,
        content  => template('profile/wmcs/prometheus/prometheus-apache.erb'),
    }

    prometheus::web { 'cloud':
        proxy_pass => 'http://localhost:9900/cloud',
        require    => Httpd::Site['prometheus'],
    }

    ferm::service { 'prometheus-web':
        proto  => 'tcp',
        port   => '80',
        srange => '$DOMAIN_NETWORKS',
    }
}
