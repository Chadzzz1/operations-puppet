# == Class profile::analytics::httpd
#
# Sets up a HTTP server for analytics sites.
#
class profile::analytics::httpd {

    class { '::httpd':
        modules => ['proxy_http',
                    'proxy',
                    'rewrite',
                    'headers',
                    'auth_basic',
                    'alias']
    }

    profile::auto_restarts::service { 'apache2': }
    profile::auto_restarts::service { 'envoyproxy': }
}
