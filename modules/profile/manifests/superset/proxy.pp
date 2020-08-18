# == Class profile::superset::proxy
#
# Sets up a WMF HTTP LDAP auth proxy.
#
class profile::superset::proxy (
    Hash $ldap_config          = lookup('ldap', Hash, hash, {}),
    String $x_forwarded_proto  = lookup('profile::superset::proxy::x_forwarded_proto', {'default_value' => 'https'}),
    Boolean $enable_cas        = lookup('profile::superset::enable_cas'),
) {

    require ::profile::analytics::httpd::utils

    include ::profile::prometheus::apache_exporter

    class { '::httpd':
        modules => ['proxy_http',
                    'proxy',
                    'headers',
                    'auth_basic',
                    'authnz_ldap']
    }

    if $enable_cas {
        class {'profile::idp::client::httpd_legacy':
            vhost_settings => { 'x-forwarded-proto' => $x_forwarded_proto },
        }
    } else {
        class { '::passwords::ldap::production': }
        $proxypass = $passwords::ldap::production::proxypass
        $ldap_server_primary = $ldap_config['ro-server']
        $ldap_server_fallback = $ldap_config['ro-server-fallback']

        httpd::site { 'superset.wikimedia.org':
            content => template('profile/superset/proxy/superset.wikimedia.org.erb'),
            require => File['/var/www/health_check'],
        }
    }

    ferm::service { 'superset-http':
        proto  => 'tcp',
        port   => '80',
        srange => '$CACHES',
    }
}
