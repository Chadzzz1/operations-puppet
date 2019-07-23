# sets up a webserver configured for phabricator
#
class profile::phabricator::httpd (
    Boolean $enable_php_fpm = hiera('phabricator_enable_php_fpm', false),
    Boolean $enable_forensic_log = hiera('profile::phabricator::httpd::enable_forensic_log', false),
) {

    $httpd_base_modules = [ 'headers', 'rewrite', 'remoteip' ]

    if $enable_php_fpm {
        $httpd_extra_modules = [ 'proxy', 'proxy_fcgi' ]
        $php_lib = 'php7.2-fpm'
    } else {
        $httpd_extra_modules = [ 'php7.2' ]
        $php_lib = 'libapache2-mod-php7.2'
        }

    $httpd_modules = concat($httpd_base_modules, $httpd_extra_modules)

    class { '::httpd':
        modules => $httpd_modules,
        require => Package[$php_lib],
    }

    $mpm = $enable_php_fpm ? {
        true => 'worker',
        default => 'prefork'
    }

    $mpm_source = $enable_php_fpm ? {
        true    => 'puppet:///modules/phabricator/apache/worker.conf',
        default => 'puppet:///modules/phabricator/apache/mpm_prefork.conf'
    }

    # MPM tweaks for high load systems
    # More performance specific tweaks to follow here
    class { '::httpd::mpm':
        mpm    => $mpm,
        source => $mpm_source,
    }

    # Forensic logging (logs requests at both beginning and end of request processing)
    if $enable_forensic_log {
        ::httpd::mod_conf { 'log_forensic':
            ensure  => present,
        }

        ::httpd::conf { 'log_forensic':
            ensure  => present,
            source  => 'puppet:///modules/phabricator/apache/log_forensic.conf',
            require => Httpd::Mod_conf['log_forensic'],
        }
    }
}
