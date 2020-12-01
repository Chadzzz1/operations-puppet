# == Class: elasticsearch::packages
#
# Provisions Elasticsearch package and dependencies.
#
class elasticsearch::packages (
    String $package_name,
    Boolean $send_logs_to_logstash,
) {
    include ::java::tools

    package { 'elasticsearch':
        ensure => present,
        name   => $package_name,
    }

    # library for elasticsearch
    ensure_packages(['python3-elasticsearch','python3-ipaddr'])

    ### install and link additional log4j appender to send logs over GELF

    # we only require the packages, we do not remove them as there might be
    # other dependencies
    if $send_logs_to_logstash {
        require_package('liblogstash-gelf-java')
        require_package('libjson-simple-java')
    }

    # symlinks are removed if log shipping is disabled
    file { '/usr/share/elasticsearch/lib/logstash-gelf.jar':
        ensure => ensure_link($send_logs_to_logstash),
        target => '/usr/share/java/logstash-gelf.jar',
    }
    file { '/usr/share/elasticsearch/lib/json-simple.jar':
        ensure => ensure_link($send_logs_to_logstash),
        target => '/usr/share/java/json-simple.jar',
    }

}
