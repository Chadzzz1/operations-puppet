# = Class: logstash
#
# Logstash is a flexible log aggregation framework built on top of
# Elasticsearch, a distributed document store. It lets you configure logging
# pipelines that ingress log data from various sources in a variety of formats.
#
# == Parameters:
# - $heap_memory: amount of memory to allocate to logstash.
# - $pipeline_workers: number of worker threads to run to process filters
# - $pipeline_batch_size: batch size to reach per worker before executing a flush
# - $pipeline_batch_delay: execute a flush after this many milliseconds except when batch size has been reached
# - $java_package: which java package to install
# - $gc_log: turn off/on garbage collector plain text logs
# - $jmx_exporter_port: if defined, what port to listen on
# - $jmx_exporter_config: if defined, what's the path to jmx_exporter's config
#
# == Sample usage:
#
#   class { 'logstash':
#       heap_memory => "192m",
#       pipeline_workers => 3,
#   }
#
class logstash (
    String $heap_memory            = '192m',
    Integer $pipeline_workers      = $::processorcount,
    Integer $pipeline_batch_size   = 125,
    Integer $pipeline_batch_delay  = 50,
    String $java_package           = 'openjdk-8-jdk',
    String $logstash_package       = 'logstash',
    Boolean $gc_log                = true,
    Integer $jmx_exporter_port     = undef,
    String $jmx_exporter_config    = undef,
    Integer[5,7] $logstash_version = 5,
) {
    require_package($java_package)

    package { 'logstash':
        ensure  => 'present',
        name    => $logstash_package,
        require => Package[$java_package],
    }

    if $gc_log == true {
        $gc_log_flags = $java_package ? {
            'openjdk-8-jdk'  => [
                '-Xloggc:/var/log/logstash/logstash_jvm_gc.%p.log',
                '-XX:+PrintGCDetails',
                '-XX:+PrintGCDateStamps',
                '-XX:+PrintGCTimeStamps',
                '-XX:+PrintTenuringDistribution',
                '-XX:+PrintGCCause',
                '-XX:+PrintGCApplicationStoppedTime',
                '-XX:+UseGCLogFileRotation',
                '-XX:NumberOfGCLogFiles=10',
                '-XX:GCLogFileSize=20M',
            ],
            'openjdk-11-jdk' => [
                '-Xlog:gc*:file=/var/log/logstash/logstash_jvm_gc.%p.log::filecount=10,filesize=20000',
                '-Xlog:gc+age=trace',
                '-Xlog:safepoint',
            ],
            default          => fail("java_package: ${java_package} not yet supported"),
        }
    } else {
        $gc_log_flags = []
    }

    if $logstash_version == 5 {

        # This creates the deploy-service user on targets
        scap::target { 'logstash/plugins':
            deploy_user => 'deploy-service',
        }

        $plugin_zip_path = '/srv/deployment/logstash/plugins/target/releases/plugins-latest.zip'

        exec { 'install-logstash-plugins':
            command => "/usr/share/logstash/bin/logstash-plugin install file://${plugin_zip_path} && /usr/bin/sha256sum ${plugin_zip_path} > /etc/logstash/plugins.sha256sum",
            # Only install plugins if hash of latest does not match stored state
            unless  => "/usr/bin/test \"$(/bin/cat /etc/logstash/plugins.sha256sum)\" = \"$(/usr/bin/sha256sum ${plugin_zip_path})\"",
            # Intentionally does not notify Service['logstash'], preferring a manual rolling restart of logstash servers
            require => Package['logstash'],
            before  => Service['logstash'],
        }

    }

    if $logstash_version == 7 {

        # install plugins from offline plugin pack built using bin/logstash-plugin prepare-offline-pack

        # lint:ignore:puppet_url_without_modules
        logstash::plugin{'logstash-output-statsd':
            source      => 'puppet:///volatile/logstash/plugins/logstash-output-statsd-3.2.0.zip',
            environment => ['LS_JAVA_OPTS=-Xms128m -Xmx128m'],
        }
        # lint:endignore

    }

    file { '/etc/default/logstash':
        content => template('logstash/default.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['logstash'],
        notify  => Service['logstash'],
    }

    file { '/etc/logstash/jvm.options':
        content => template('logstash/jvm.options.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['logstash'],
        notify  => Service['logstash'],
    }

    file { '/etc/logstash/log4j2.properties':
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        content => template('logstash/log4j2.properties.erb'),
        mode    => '0444',
        require => Package['logstash'],
    }

    file { '/etc/logstash/logstash.yml':
        content => ordered_yaml({
            'path.data'            => '/var/lib/logstash',
            'path.config'          => '/etc/logstash/conf.d',
            'path.logs'            => '/var/log/logstash',
            'pipeline.workers'     => $pipeline_workers,
            'pipeline.batch.size'  => $pipeline_batch_size,
            'pipeline.batch.delay' => $pipeline_batch_delay,
        }),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['logstash'],
        notify  => Service['logstash'],
    }

    file { '/etc/logstash/conf.d':
        ensure  => directory,
        recurse => true,
        purge   => true,
        force   => true,
        owner   => 'logstash',
        group   => 'logstash',
        source  => 'puppet:///modules/logstash/conf.d',
        require => Package['logstash'],
    }

    # Older 1.x versions of logstash needed this file deployed,
    # but 5.x comes with a sensible service definition for systemd
    # in /etc/systemd/logstash.service
    file { '/lib/systemd/system/logstash.service':
        ensure  => absent,
    }

    service { 'logstash':
        ensure     => running,
        provider   => systemd,
        enable     => true,
        hasstatus  => true,
        hasrestart => true,
    }

    file { '/etc/init/logstash.conf':
        ensure  => absent,
        require => Package['logstash'],
    }

    file { '/etc/init/logstash-web.conf':
        ensure  => absent,
        require => Package['logstash'],
    }
}
