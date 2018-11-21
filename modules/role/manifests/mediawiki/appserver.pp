# filtertags: labs-project-deployment-prep
class role::mediawiki::appserver {
    system::role { 'mediawiki::appserver': }
    include standard
    include ::role::mediawiki::common

    include ::profile::base::firewall
    include ::profile::prometheus::apache_exporter
    include ::profile::prometheus::hhvm_exporter
    include ::profile::prometheus::php_fpm_exporter
    include ::profile::mediawiki::webserver
}
