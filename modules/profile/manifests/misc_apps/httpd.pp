# setup a webserver for misc. apps
class profile::misc_apps::httpd (
    $deployment_server = hiera('deployment_server'),
){

    $apache_modules_common = ['rewrite', 'headers', 'authnz_ldap', 'proxy', 'proxy_http']

    require_package('libapache2-mod-php')

    if os_version('debian == buster') {
        $apache_php_module = 'php7.3'
    } else {
        $apache_php_module = 'php7.0'
    }

    $apache_modules = concat($apache_modules_common, $apache_php_module)

    class { '::httpd':
        modules => $apache_modules,
    }

    ferm::service { 'miscweb-http-envoy':
        proto  => 'tcp',
        port   => '80',
        srange => "(${::ipaddress} ${::ipaddress6})"
    }

    ferm::service { 'miscweb-http-deployment':
        proto  => 'tcp',
        port   => '80',
        srange => "(@resolve((${deployment_server})) @resolve((${deployment_server}), AAAA))"
    }
}
