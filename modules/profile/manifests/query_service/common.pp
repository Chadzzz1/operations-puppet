class profile::query_service::common(
    Query_service::DeployMode $deploy_mode = hiera('profile::wdqs::deploy_mode'),
    Stdlib::Unixpath $package_dir = hiera('profile::wdqs::package_dir', '/srv/deployment/wdqs/wdqs'),
    Stdlib::Unixpath $data_dir = hiera('profile::wdqs::data_dir', '/srv/wdqs'),
    Stdlib::Unixpath $log_dir = hiera('profile::wdqs::log_dir', '/var/log/wdqs'),
    String $deploy_name = hiera('profile::wdqs::deploy_name', 'wdqs'),
    String $endpoint = hiera('profile::wdqs::endpoint', 'https://query.wikidata.org'),
    Boolean $run_tests = hiera('profile::wdqs::run_tests', false),
    Enum['none', 'daily', 'weekly'] $load_categories = hiera('profile::wdqs::load_categories', 'daily'),
    Array[String] $nodes = hiera('profile::wdqs::nodes'),
    Stdlib::Httpurl $categories_endpoint =  hiera('profile::wdqs::categories_endpoint', 'http://localhost:9990'),
) {

    $username = 'blazegraph'
    $deploy_user = 'deploy-service'

    # Let's migrate to the new logging pipeline. See T232184.
    include ::profile::rsyslog::udp_json_logback_compat

    class { '::query_service::common':
        deploy_mode         => $deploy_mode,
        username            => $username,
        deploy_name         => $deploy_name,
        deploy_user         => $deploy_user,
        package_dir         => $package_dir,
        data_dir            => $data_dir,
        log_dir             => $log_dir,
        endpoint            => $endpoint,
        categories_endpoint => $categories_endpoint,
    }

    class { 'query_service::crontasks':
        package_dir     => $package_dir,
        data_dir        => $data_dir,
        log_dir         => $log_dir,
        deploy_name     => $deploy_name,
        username        => $username,
        load_categories => $load_categories,
        run_tests       => $run_tests,
    }

    require_package('python3-dateutil', 'python3-prometheus-client')
    file { '/usr/local/bin/prometheus-blazegraph-exporter':
        ensure => present,
        source => 'puppet:///modules/query_service/monitor/prometheus-blazegraph-exporter.py',
        mode   => '0555',
        owner  => 'root',
        group  => 'root',
    }

    # Firewall
    ferm::service {
        'query_service_http':
            proto => 'tcp',
            port  => '80';
        'query_service_https':
            proto => 'tcp',
            port  => '443';
        # temporary port to transfer data file between wdqs nodes via netcat
        'query_service_file_transfer':
            proto  => 'tcp',
            port   => '9876',
            srange => inline_template("@resolve((<%= @nodes.join(' ') %>))");
    }

    # spread IRQ for NIC
    interface::rps { $facts['interface_primary']: }
}
