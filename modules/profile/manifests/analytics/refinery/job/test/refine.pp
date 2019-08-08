# == Class profile::analytics::refinery::job::test::refine
#
# Install cron jobs for Spark Refine jobs.  These jobs
# transform data imported into Hadoop into augmented Parquet backed
# Hive tables.
#
# This version is only for the Hadoop testing cluster
#
class profile::analytics::refinery::job::test::refine {
    require ::profile::analytics::refinery
    require ::profile::hive::client

    # Update this when you want to change the version of the refinery job jar
    # being used for the refine job.
    $refinery_version = '0.0.97'

    # Use this value by default
    Profile::Analytics::Refinery::Job::Refine_job {
        # Use this value as default refinery_job_jar.
        refinery_job_jar => "${::profile::analytics::refinery::path}/artifacts/org/wikimedia/analytics/refinery/refinery-job-${refinery_version}.jar"
    }

    # These configs will be used for all refine jobs unless otherwise overridden.
    $default_config = {
        'to_emails'           => 'ltoscano@wikimedia.org',
        'should_email_report' => true,
        'database'            => 'event',
        'output_path'         => '/wmf/data/event',
        'hive_server_url'     => "${::profile::hive::client::hiveserver_host}:${::profile::hive::client::hiveserver_port}",
        # Look for data to refine from 26 hours ago to 2 hours ago, giving some time for
        # raw data to be imported in the last hour or 2 before attempting refine.
        'since'               => '26',
        'until'               => '2',
    }

    # Refine EventLogging Analytics (capsule based) data.
    profile::analytics::refinery::job::refine_job { 'eventlogging_analytics':
        job_config       => merge($default_config, {
            input_path                      => '/wmf/data/raw/eventlogging',
            input_path_regex                => 'eventlogging_(.+)/hourly/(\\d+)/(\\d+)/(\\d+)/(\\d+)',
            input_path_regex_capture_groups => 'table,year,month,day,hour',
            table_whitelist_regex           => '^NavigationTiming$',
            # Deduplicate basd on uuid field and geocode ip in EventLogging analytics data.
            transform_functions             => 'org.wikimedia.analytics.refinery.job.refine.deduplicate_eventlogging,org.wikimedia.analytics.refinery.job.refine.geocode_ip,org.wikimedia.analytics.refinery.job.refine.eventlogging_filter_is_allowed_hostname',
            # Get EventLogging JSONSchemas from meta.wikimedia.org.
            schema_base_uri                 => 'eventlogging',
        }),
        # Use webproxy so that this job can access meta.wikimedia.org to retrive JSONSchemas.
        spark_extra_opts => '--driver-java-options=\'-Dhttp.proxyHost=webproxy.eqiad.wmnet -Dhttp.proxyPort=8080 -Dhttps.proxyHost=webproxy.eqiad.wmnet -Dhttps.proxyPort=8080\'',
        interval         => '*-*-* *:30:00',
    }
}
