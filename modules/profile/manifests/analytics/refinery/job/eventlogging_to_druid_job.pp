# == Define profile::analytics::refinery::job::eventlogging_to_druid_job
#
# Installs cron jobs to run EventLoggingToDruid Spark job.
# This job loads data from the given EL Hive table to a Druid datasource.
#
# We use spark's --files option to load each job's config file to the
# corresponding working HDFS dir. It will be then referenced via its relative
# file name with the --config_file option.
#
#
# TEMPORARY HACK
#
# The problem:
# EventLoggingToDruid does not use RefineTarget to determine which data pieces
# are available at a given moment and are to be loaded to Druid, because
# currently RefineTarget does not support Druid. Instead, EventLoggingToDruid
# just assumes that the passed date/time interval is correct and loads it
# without any check or filter. The interval checking needs to be done then by
# puppet (cron), passing a relative number of hours ago as since and until.
#
# Potential issues:
# 1) If the data pipeline is late for any reason (high load, outage, restarts,
#    etc.) EventLoggingToDruid might not find the input data, or find it
#    incomplete, thus loading corrupt data to Druid for that hour.
# 2) If the cluster is busy and the EventLoggingToDruid job takes more than
#    1 hour to launch (waiting), then 'since 6 hours ago' will skip 1 hour
#    (or more) and there will be a hole in the corresponding Druid datasource.
# This would cause user confusion, frustration and give the maintainers lots
# of work to manually backfill datasources.
#
# The right solution:
# We should improve RefineTarget to support Druid. However, this seems to be
# quite a bit of work. Task: https://phabricator.wikimedia.org/T207207
# But in the meantime...
#
# The temporary solution:
# Issue 1) Make this module install 3 loading jobs for each
#    given datasource: one hourly, one daily and one monthly. The hourly one
#    will load data as soon as possible with the mentioned potential issues.
#    The daily one, will load data with a lag of 4 days, to automatically
#    cover up any hourly loading issues that happened during that lag. The
#    monthly one will load the whole month after a 40 day lag, to
#    automatically cover up any issues that happened since the daily job
#    loaded the corresponding data. A desirable side-effect of this hack is
#    that Druid data gets compacted in daily and then monthly segments.
# Issue 2) Instead of passing relative time offsets (hours ago), calculate
#    absolute timestamps for since and until using bash. To allow bash to
#    interpret date commands since and until params can not be passed via
#    config property file.
#
# == Properties
#
# [*job_config*]
#   A hash of job config properites that will be rendered as a properties file
#   and given to the EventLoggingToDruid job as the --config_file argument.
#   Please, do not include the following properties: since, until,
#   segment_granularity, reduce_memory, num_shards. The reason being:
#   This job will install 3 jobs for each datasource: an hourly one, a daily
#   one and a monthly one. This improves compaction of Druid segments, and
#   also serves as a temporary solution to avoid having to rerun ingestions in
#   case of input data being delayed because of restarts, issues or outages.
#
# [*job_name*]
#   The Spark job name. Default: eventlogging_to_druid_$title
#
define profile::analytics::refinery::job::eventlogging_to_druid_job (
    $job_config,
    $job_name            = "eventlogging_to_druid_${title}",
    $refinery_job_jar    = undef,
    $job_class           = 'org.wikimedia.analytics.refinery.job.EventLoggingToDruid',
    $queue               = 'production',
    $user                = 'hdfs',
    $ensure              = 'present',
) {
    require ::profile::analytics::refinery
    $refinery_path = $profile::analytics::refinery::path

    # If $refinery_job_jar not given, use the symlink at artifacts/refinery-job.jar
    $_refinery_job_jar = $refinery_job_jar ? {
        undef   => "${refinery_path}/artifacts/refinery-job.jar",
        default => $refinery_job_jar,
    }

    # Directory where EventLoggingToDruid config property files will go
    $job_config_dir = "${::profile::analytics::refinery::config_dir}/eventlogging_to_druid"
    if !defined(File[$job_config_dir]) {
        file { $job_config_dir:
            ensure => 'directory',
        }
    }

    # Config options for all jobs, can be overriden by define params
    $default_config = {
        'database'            => 'event',
        'table'               => $title,
        'query_granularity'   => 'minute',
        'hadoop_queue'        => $queue,
        'druid_host'          => 'druid1001.eqiad.wmnet',
        'druid_port'          => '8090',
    }

    # Common Spark options for all jobs
    $default_spark_opts = "--master yarn --deploy-mode cluster --queue ${queue} --conf spark.driver.extraClassPath=/usr/lib/hive/lib/hive-jdbc.jar:/usr/lib/hadoop-mapreduce/hadoop-mapreduce-client-common.jar:/usr/lib/hive/lib/hive-service.jar"

    # Hourly job
    $hourly_job_config_file = "${job_config_dir}/${job_name}_hourly.properties"
    profile::analytics::refinery::job::config { $hourly_job_config_file:
        ensure     => $ensure,
        properties => merge($default_config, $job_config, {
            'segment_granularity' => 'hour',
            'num_shards'          => 2,
            'reduce_memory'       => '4096',
        }),
    }
    profile::analytics::refinery::job::spark_job { "${job_name}_hourly":
        ensure     => $ensure,
        jar        => $_refinery_job_jar,
        class      => $job_class,
        spark_opts => "${default_spark_opts} --files /etc/hive/conf/hive-site.xml,${hourly_job_config_file} --conf spark.dynamicAllocation.maxExecutors=16 --driver-memory 4G",
        job_opts   => "--config_file ${job_name}_hourly.properties --since $(date --date '-6hours' -u +'%Y-%m-%dT%H:00:00') --until $(date --date '-5hours' -u +'%Y-%m-%dT%H:00:00')",
        require    => Profile::Analytics::Refinery::Job::Config[$hourly_job_config_file],
        user       => $user,
        minute     => 0,
    }

    # Daily job
    $daily_job_config_file = "${job_config_dir}/${job_name}_daily.properties"
    profile::analytics::refinery::job::config { $daily_job_config_file:
        ensure     => $ensure,
        properties => merge($default_config, $job_config, {
            'segment_granularity' => 'day',
            'num_shards'          => 4,
            'reduce_memory'       => '8192',
        }),
    }
    profile::analytics::refinery::job::spark_job { "${job_name}_daily":
        ensure     => $ensure,
        jar        => $_refinery_job_jar,
        class      => $job_class,
        spark_opts => "${default_spark_opts} --files /etc/hive/conf/hive-site.xml,${daily_job_config_file} --conf spark.dynamicAllocation.maxExecutors=32 --driver-memory 8G",
        job_opts   => "--config_file ${job_name}_daily.properties --since $(date --date '-4days' -u +'%Y-%m-%dT00:00:00') --until $(date --date '-3days' -u +'%Y-%m-%dT00:00:00')",
        require    => Profile::Analytics::Refinery::Job::Config[$daily_job_config_file],
        user       => $user,
        hour       => 0,
        minute     => 0,
    }

    # Monthly job
    $monthly_job_config_file = "${job_config_dir}/${job_name}_monthly.properties"
    profile::analytics::refinery::job::config { $monthly_job_config_file:
        ensure     => $ensure,
        properties => merge($default_config, $job_config, {
            'segment_granularity' => 'month',
            'num_shards'          => 8,
            'reduce_memory'       => '16384',
        }),
    }
    profile::analytics::refinery::job::spark_job { "${job_name}_monthly":
        ensure     => $ensure,
        jar        => $_refinery_job_jar,
        class      => $job_class,
        spark_opts => "${default_spark_opts} --files /etc/hive/conf/hive-site.xml,${monthly_job_config_file} --conf spark.dynamicAllocation.maxExecutors=64 --driver-memory 16G",
        job_opts   => "--config_file ${job_name}_monthly.properties --since $(date --date '-1month' -u +'%Y-%m-01T00:00:00') --until $(date -u +'%Y-%m-01T00:00:00')",
        require    => Profile::Analytics::Refinery::Job::Config[$monthly_job_config_file],
        user       => $user,
        monthday   => 10,
        hour       => 0,
        minute     => 0,
    }

}
