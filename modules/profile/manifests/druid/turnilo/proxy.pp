# == Class profile::druid::turnilo::proxy
#
# Sets up an apache http proxy with WMF ldap authentication.
# To login, you must be in either the wmf or ops ldap group.
#
# This class can only be used on the same host running turnilo.
#
# == Parameters
#
# [*server_name*]
#   VirtualHost ServerName hostname to use.
#
# [*turnilo_port*]
#   Port bound by the Turnilo nodejs service.
#
class profile::druid::turnilo::proxy(
    Hash $ldap_config         = lookup('ldap', Hash, hash, {}),
    Integer $turnilo_port     = lookup('profile::turnilo::proxy::turnilo_port', { 'default_value' => 9091 }),
    Stdlib::Fqdn $server_name = lookup('profile::turnilo::proxy::server_name', { 'default_value' =>'turnilo.wikimedia.org' }),
) {

    require ::profile::analytics::httpd::utils

    class { '::httpd':
        modules => ['proxy_http',
                    'proxy',
                    'auth_basic',
                    'authnz_ldap']
    }

    class { '::passwords::ldap::production': }

    ferm::service { 'turnilo-http':
        proto  => 'tcp',
        port   => '80',
        srange => '$CACHES',
    }

    $proxypass = $passwords::ldap::production::proxypass
    $ldap_server_primary = $ldap_config['ro-server']
    $ldap_server_fallback = $ldap_config['ro-server-fallback']

    # Set up the VirtualHost
    httpd::site { $server_name:
        content => template('profile/druid/turnilo/proxy/turnilo.vhost.erb'),
        require => File['/var/www/health_check'],
    }

    base::service_auto_restart { 'apache2': }
}
