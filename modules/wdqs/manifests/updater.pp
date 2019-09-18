# === Class wdqs::updater
#
# Wikidata Query Service updater service.
#
# Note: Installs and start the wdqs-updater service.
# == Parameters:
# - $options: extra updater options, passed to runUpdate.sh script.
# - $logstash_host: hostname where to send logs.
# - $package_dir:  Directory where the service should be installed.
# - $data_dir: Directory where the database should be stored.
# - $log_dir: Directory where the logs go.
# - $logstash_json_port: port on which to send logs in json format.
# - $logstash_logback_port: port which rsyslog server is listening on
# - $username: Username owning the service.
# - $extra_jvm_opts: extra JVM options for updater.
# - $logstash_transport: send logs directly or via rsyslog
# - $log_sparql: enable SPARQL logging.
class wdqs::updater(
    Array[String] $options,
    String $logstash_host,
    Stdlib::Unixpath $package_dir,
    Stdlib::Unixpath $data_dir,
    Stdlib::Unixpath $log_dir,
    Stdlib::Port $logstash_json_port,
    Stdlib::Port $logstash_logback_port,
    String $username,
    Array[String] $extra_jvm_opts,
    Enum['logstash-direct', 'syslog'] $logstash_transport = 'logstash-direct',
    Boolean $log_sparql = false,
) {
    file { '/etc/default/wdqs-updater':
        ensure  => present,
        content => template('wdqs/updater-default.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        before  => Systemd::Unit['wdqs-updater'],
        notify  => Service['wdqs-updater'],
    }

    wdqs::logback_config { 'wdqs-updater':
        pattern               => '%d{HH:mm:ss.SSS} [%thread] %-5level %logger{36} - %msg %mdc%n',
        log_dir               => $log_dir,
        logstash_host         => $logstash_host,
        logstash_port         => $logstash_json_port,
        logstash_logback_port => $logstash_logback_port,
        logstash_transport    => $logstash_transport,
        sparql                => $log_sparql,
    }

    systemd::unit { 'wdqs-updater':
        content => template('wdqs/initscripts/wdqs-updater.systemd.erb'),
        notify  => Service['wdqs-updater'],
    }

    service { 'wdqs-updater':
        ensure => 'running',
    }
}
