# == Class profile::analytics::refinery::job::data_purge
#
# Installs systemd-timer jobs to drop old hive partitions,
# delete old data from HDFS and sanitize EventLogging data.
#
# [*deploy_jobs*]
#   Temporary flag to avoid deploying jobs on new hosts.
#   Default: true
#
class profile::analytics::refinery::job::data_purge (
    $public_druid_host = lookup('profile::analytics::refinery::job::data_purge::public_druid_host', { 'default_value' => undef }),
    $use_kerberos = lookup('profile::analytics::refinery::job::data_purge::use_kerberos', { 'default_value' => false }),
    $ensure_timers = lookup('profile::analytics::refinery::job::data_purge::ensure_timers', { 'default_value' => 'present' }),
) {
    require ::profile::analytics::refinery

    $query_clicks_log_file           = "${profile::analytics::refinery::log_dir}/drop-query-clicks.log"
    $public_druid_snapshots_log_file = "${profile::analytics::refinery::log_dir}/drop-druid-public-snapshots.log"
    $mediawiki_dumps_log_file        = "${profile::analytics::refinery::log_dir}/drop-mediawiki-dumps.log"
    $el_unsanitized_log_file         = "${profile::analytics::refinery::log_dir}/drop-el-unsanitized-events.log"

    # Shortcut to refinery path
    $refinery_path = $profile::analytics::refinery::path

    # Shortcut var to DRY up commands.
    $env = "export PYTHONPATH=\${PYTHONPATH}:${refinery_path}/python"
    $systemd_env = {
        'PYTHONPATH' => "\${PYTHONPATH}:${refinery_path}/python",
    }

    # Send an email to analytics in case of failure
    $mail_to = 'analytics-alerts@wikimedia.org'

    # Keep this many days of raw webrequest data.
    $raw_retention_days = 31
    kerberos::systemd_timer { 'refinery-drop-webrequest-raw-partitions':
        ensure       => $ensure_timers,
        description  => 'Drop Webrequest raw data imported on HDFS following data retention policies.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='wmf_raw' --tables='webrequest' --base-path='/wmf/data/raw/webrequest' --path-format='.+/hourly/(?P<year>[0-9]+)(/(?P<month>[0-9]+)(/(?P<day>[0-9]+)(/(?P<hour>[0-9]+))?)?)?' --older-than='${raw_retention_days}' --skip-trash --execute='96726ec893174544fc9bd7c7fa0083ea'",
        interval     => '*-*-* 00/4:15:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # Keep this many days of refined webrequest data.
    $refined_retention_days = 90
    kerberos::systemd_timer { 'refinery-drop-webrequest-refined-partitions':
        ensure       => $ensure_timers,
        description  => 'Drop Webrequest refined data imported on HDFS following data retention policies.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='wmf' --tables='webrequest' --base-path='/wmf/data/wmf/webrequest' --path-format='.+/year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='${refined_retention_days}' --skip-trash --execute='cf16215b8158e765b623db7b3f345d36'",
        interval     => '*-*-* 00/4:45:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # Keep this many days of pageview_actor_hourly data.
    kerberos::systemd_timer { 'refinery-drop-pageview-actor-hourly-partitions':
        ensure       => $ensure_timers,
        description  => 'Drop pageview_actor_hourly data from HDFS following data retention policies.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='wmf' --tables='pageview_actor_hourly' --base-path='/wmf/data/wmf/pageview/actor/hourly' --path-format='year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='${refined_retention_days}' --skip-trash --execute='96f2d4a6800314113b9bf23822854d4d'",
        interval     => '*-*-* 00/4:50:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # Keep this many days of raw event data (all data that comes via EventGate instances).
    $event_raw_retention_days = 90
    kerberos::systemd_timer { 'refinery-drop-raw-event':
        ensure       => $ensure_timers,
        description  => 'Drop raw event (/wmf/data/raw/event) data imported on HDFS following data retention policies.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/raw/event' --path-format='.+/hourly/(?P<year>[0-9]+)(/(?P<month>[0-9]+)(/(?P<day>[0-9]+)(/(?P<hour>[0-9]+))?)?)?' --older-than='${event_raw_retention_days}' --skip-trash --execute='209837413aff8d4332104e7dc454a27d'",
        interval     => '*-*-* 00/4:20:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # Keep this many days of refined event data (all data that comes via EventGate instances).
    $event_refined_retention_days = 90
    # Most (non EventLogging legacy) event data does not contain PII, so we keep it indefinetly.
    # Only tables with PII must be purged after $event_refined_retention_days.
    #
    # Maps dataset (table + base path in /wmf/data/event/$table) to the refinery-drop-older-than
    # --execute checksum to use.  A refinery-drop-refined-event job will be declared for
    # each entry in this hash.
    #
    $event_refined_to_drop = {
        'mediawiki_api_request'          => 'e06eaf4f3c6894fe7b943d9b40f83ace',
        'mediawiki_cirrussearch_request' => 'e93b86033b2025f8a793c8b170e6474f',
        'wdqs_external_sparql_query'     => 'f32f99c8fa41b56782bf22e1866cd79b',
        'wdqs_internal_sparql_query'     => '15f545ef0fe0ba8573c568ded41fb6e3',
    }

    # Since we are only dropping very specific event data, we don't want to use
    # refinery-drop-older-than with a --base-path of /wmf/data/event.
    # Doing so would cause it to hdfs dfs -ls glob EVERY event dataset path and then
    # prune the results for directories to drop.  By separating each dataset drop
    # into an individual job and using a --base-path specific to that dataset's LOCATION path,
    # we avoid having to ls glob and parse all other event dataset paths.
    #
    # NOTE: The tables parameter uses a double $$ sign. Systemd will transform this into a single $ sign.
    # So, if you want to make changes to this job, make sure to execute all tests (DRY-RUN) with just 1
    # single $ sign, to get the correct checksum. And then add the double $$ sign here.
    # Also, we need the systemd to escape our \w, AND we need puppet to do the same.  So we use
    # \\\\w to result in \\w in systemd which then ends up executing with a \w.  DRY-RUN with just
    # \w to get the proper checksum.
    $event_refined_to_drop.each |String $dataset, String $checksum| {
        kerberos::systemd_timer { "refinery-drop-refined-event.${dataset}":
            ensure       => $ensure_timers,
            description  => "Drop refined event.${dataset} data imported on Hive/HDFS following data retention policies.",
            command      => "${refinery_path}/bin/refinery-drop-older-than --database='event' --tables='^${dataset}$$' --base-path='/wmf/data/event/${dataset}' --path-format='datacenter=\\\\w+(/year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?)?' --older-than='90' --skip-trash --execute='${checksum}'",
            interval     => '*-*-* 00:00:00',
            environment  => $systemd_env,
            user         => 'analytics',
            use_kerberos => $use_kerberos,
        }
    }

    # Keep this many days of raw eventlogging data.
    $eventlogging_retention_days = 90
    kerberos::systemd_timer { 'refinery-drop-eventlogging-partitions':
        ensure       => $ensure_timers,
        description  => 'Drop Eventlogging data imported on HDFS following data retention policies.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/raw/eventlogging' --path-format='.+/hourly/(?P<year>[0-9]+)(/(?P<month>[0-9]+)(/(?P<day>[0-9]+)(/(?P<hour>[0-9]+))?)?)?' --older-than='${eventlogging_retention_days}' --skip-trash --execute='bb7022b36bcf0d75bdd03b6f836f09e6'",
        interval     => '*-*-* 00/4:15:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    kerberos::systemd_timer { 'refinery-drop-eventlogging-client-side-partitions':
        ensure       => $ensure_timers,
        description  => 'Drop Eventlogging Client Side data imported on HDFS following data retention policies.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/raw/eventlogging_client_side' --path-format='eventlogging-client-side/hourly/(?P<year>[0-9]+)(/(?P<month>[0-9]+)(/(?P<day>[0-9]+)(/(?P<hour>[0-9]+))?)?)?' --older-than='${eventlogging_retention_days}' --skip-trash --execute='1fcad629ec569645ff864686e523029d'",
        interval     => '*-*-* 00/4:30:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # keep this many days of druid webrequest sampled
    # Currently being tested as systemd timer, see below
    $druid_webrequest_sampled_retention_days = 60
    kerberos::systemd_timer { 'refinery-drop-webrequest-sampled-druid':
        ensure       => $ensure_timers,
        description  => 'Drop Druid Webrequest sampled data from deep storage following data retention policies.',
        command      => "${refinery_path}/bin/refinery-drop-druid-deep-storage-data -d ${druid_webrequest_sampled_retention_days} webrequest_sampled_128",
        interval     => '*-*-* 05:15:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # keep this many public druid mediawiki history refined snapshots
    # runs once a month
    if $public_druid_host {
        $druid_public_keep_snapshots = 4
        $mediawiki_history_reduced_basename = 'mediawiki_history_reduced'
        kerberos::systemd_timer { 'refinery-druid-drop-public-snapshots':
            ensure       => $ensure_timers,
            description  => 'Drop Druid Public snapshots from deep storage following data retention policies.',
            command      => "${refinery_path}/bin/refinery-drop-druid-snapshots -d ${mediawiki_history_reduced_basename} -t ${public_druid_host} -s ${druid_public_keep_snapshots} -f ${public_druid_snapshots_log_file}",
            environment  => $systemd_env,
            interval     => 'Mon,Tue,Wed,Thu,Fri *-*-15 09:00:00',
            user         => 'analytics',
            use_kerberos => $use_kerberos,
        }
    }

    # keep this many mediawiki history snapshots, 6 minimum
    # runs once a month
    $keep_snapshots = 6
    kerberos::systemd_timer { 'mediawiki-history-drop-snapshot':
        ensure       => $ensure_timers,
        description  => 'Drop snapshots from multiple raw and refined mediawiki datasets, configured in the refinery-drop script.',
        command      => "${refinery_path}/bin/refinery-drop-mediawiki-snapshots -s ${keep_snapshots}",
        environment  => $systemd_env,
        interval     => '*-*-15 06:15:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # Delete mediawiki history dump snapshots older than 6 months.
    # Runs on the first day of each month. This way it frees up space for the new snapshot.
    $mediawiki_history_dumps_retention_days = 180
    kerberos::systemd_timer { 'refinery-drop-mediawiki-history-dumps':
        ensure       => $ensure_timers,
        description  => 'Drop mediawiki history dump versions older than 6 months.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/archive/mediawiki/history' --path-format='(?P<year>[0-9]+)-(?P<month>[0-9]+)' --older-than='${mediawiki_history_dumps_retention_days}' --skip-trash --execute='40f24e7bbccb397671dfa3266c5ebd2f'",
        interval     => '*-*-01 00:00:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # keep this many days of banner activity success files
    # runs once a day
    $banner_activity_retention_days = 90
    kerberos::systemd_timer { 'refinery-drop-banner-activity':
        ensure       => $ensure_timers,
        description  => 'Clean old Banner Activity _SUCCESS flags from HDFS.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --base-path='/wmf/data/wmf/banner_activity' --path-format='daily/year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+))?)?' --older-than='${banner_activity_retention_days}' --skip-trash --execute='39b7f84330a54c2128f6ade41feba28b'",
        environment  => $systemd_env,
        interval     => '*-*-* 02:00:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # Create, rotate and delete EventLogging salts (for hashing).
    # Local directory for salt files:
    $refinery_config_dir = $::profile::analytics::refinery::config_dir
    file { ["${refinery_config_dir}/salts", "${refinery_config_dir}/salts/eventlogging_sanitization"]:
        ensure => 'directory',
        owner  => 'analytics',
    }

    file { '/usr/local/bin/refinery-eventlogging-saltrotate':
        ensure  => $ensure_timers,
        content => template('profile/analytics/refinery/job/refinery-eventlogging-saltrotate.erb'),
        mode    => '0550',
        owner   => 'analytics',
        group   => 'analytics',
    }

    # Timer runs at midnight (salt rotation time):
    kerberos::systemd_timer { 'refinery-eventlogging-saltrotate':
        ensure       => $ensure_timers,
        description  => 'Create, rotate and delete cryptographic salts for EventLogging sanitization.',
        command      => '/usr/local/bin/refinery-eventlogging-saltrotate',
        environment  => $systemd_env,
        interval     => '*-*-* 00:00:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
        require      => File['/usr/local/bin/refinery-eventlogging-saltrotate']
    }

    # EventLogging sanitization. Runs in two steps.
    # Common parameters for both jobs:
    $eventlogging_sanitization_job_config = {
        'input_path'          => '/wmf/data/event',
        'database'            => 'event_sanitized',
        'output_path'         => '/wmf/data/event_sanitized',
        'whitelist_path'      => '/wmf/refinery/current/static_data/eventlogging/whitelist.yaml',
        'salts_path'          => '/user/hdfs/salts/eventlogging_sanitization',
        'parallelism'         => '16',
        'should_email_report' => true,
        'to_emails'           => 'analytics-alerts@wikimedia.org',
    }
    # Execute 1st sanitization pass, right after data collection. Runs once per hour.
    # Job starts a couple minutes after the hour, to leave time for the salt files to be updated.
    profile::analytics::refinery::job::refine_job { 'sanitize_eventlogging_analytics_immediate':
        ensure                         => $ensure_timers,
        job_class                      => 'org.wikimedia.analytics.refinery.job.refine.EventLoggingSanitization',
        monitor_class                  => 'org.wikimedia.analytics.refinery.job.refine.EventLoggingSanitizationMonitor',
        job_config                     => $eventlogging_sanitization_job_config,
        spark_driver_memory            => '16G',
        spark_max_executors            => '128',
        spark_extra_opts               => '--conf spark.ui.retainedStage=20 --conf spark.ui.retainedTasks=1000 --conf spark.ui.retainedJobs=100',
        interval                       => '*-*-* *:02:00',
        use_kerberos                   => $use_kerberos,
        refine_monitor_failure_enabled => false,
    }
    # Execute 2nd sanitization pass, after 45 days of collection.
    # Runs once per day at a less busy time.
    profile::analytics::refinery::job::refine_job { 'sanitize_eventlogging_analytics_delayed':
        ensure                         => $ensure_timers,
        job_class                      => 'org.wikimedia.analytics.refinery.job.refine.EventLoggingSanitization',
        monitor_class                  => 'org.wikimedia.analytics.refinery.job.refine.EventLoggingSanitizationMonitor',
        job_config                     => $eventlogging_sanitization_job_config.merge({
            'since' => 1104,
            'until' => 1080,
        }),
        spark_driver_memory            => '16G',
        spark_max_executors            => '128',
        spark_extra_opts               => '--conf spark.ui.retainedStage=20 --conf spark.ui.retainedTasks=1000 --conf spark.ui.retainedJobs=100',
        interval                       => '*-*-* 06:00:00',
        use_kerberos                   => $use_kerberos,
        refine_monitor_failure_enabled => false,
    }

    # Drop unsanitized EventLogging data from the event database after retention period.
    # Runs once a day.
    # NOTE: The regexes here don't include underscores '_' when matching table names or directory paths.
    # No EventLogging (legacy) generated datasets have underscores, while all EventGate generated datasets do.
    # This implicitly excludes non EventLogging (legacy) datasets from being deleted.
    # Some EventGate datasets do need to be deleted.  This is done above by the refinery-drop-event job.
    # NOTE: The tables parameter uses a double $$ sign. Systemd will transform this into a single $ sign.
    # So, if you want to make changes to this job, make sure to execute all tests (DRY-RUN) with just 1
    # single $ sign, to get the correct checksum. And then add the double $$ sign here.
    kerberos::systemd_timer { 'drop-el-unsanitized-events':
        ensure       => $ensure_timers,
        description  => 'Drop unsanitized EventLogging data from the event database after retention period.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='event' --tables='^(?!wmdebanner)[A-Za-z0-9]+$$' --base-path='/wmf/data/event' --path-format='(?!WMDEBanner)[A-Za-z0-9]+/year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='90' --skip-trash --execute='dc3b5e020579ae5516b7f372081d1fac' --log-file='${el_unsanitized_log_file}'",
        interval     => '*-*-* 00:00:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # Drop sanitized EventLogging data for growth schemas after 270 days of collection. Runs once a day.
    # NOTE: The tables parameter uses a double $$ sign. Systemd will transform this into a single $ sign.
    # So, if you want to make changes to this job, make sure to execute all tests (DRY-RUN) with just 1
    # single $ sign, to get the correct checksum. And then add the double $$ sign here.
    kerberos::systemd_timer { 'drop-el-helppanel-events':
        ensure       => $ensure_timers,
        description  => 'Drop HelpPanel data from the event_sanitized database after 270 days.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='event_sanitized' --tables='^helppanel$$' --base-path='/wmf/data/event_sanitized/HelpPanel' --path-format='year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='270' --skip-trash --execute='e1447ccd3a6f808d038e2f4656e5a016'",
        interval     => '*-*-* 04:40:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }
    kerberos::systemd_timer { 'drop-el-homepagevisit-events':
        ensure       => $ensure_timers,
        description  => 'Drop HomepageVisit data from the event_sanitized database after 270 days.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='event_sanitized' --tables='^homepagevisit$$' --base-path='/wmf/data/event_sanitized/HomepageVisit' --path-format='year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='270' --skip-trash --execute='22e0daca11d3085a43149b3bf963b392'",
        interval     => '*-*-* 04:45:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }
    kerberos::systemd_timer { 'drop-el-homepagemodule-events':
        ensure       => $ensure_timers,
        description  => 'Drop HomepageModule data from the event_sanitized database after 270 days.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='event_sanitized' --tables='^homepagemodule$$' --base-path='/wmf/data/event_sanitized/HomepageModule' --path-format='year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='270' --skip-trash --execute='98a07ca21191bdaf1e6ce8c59093377a'",
        interval     => '*-*-* 04:50:00',
        environment  => $systemd_env,
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # drop data older than 2-3 months from cu_changes table, which is sqooped in
    # runs once a day (but only will delete data on the needed date)
    $geoeditors_private_retention_days = 60
    kerberos::systemd_timer { 'mediawiki-raw-cu-changes-drop-month':
        ensure       => $ensure_timers,
        description  => 'Drop raw MediaWiki cu_changes from Hive/HDFS following data retention policies.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='wmf_raw' --tables='mediawiki_private_cu_changes' --base-path='/wmf/data/raw/mediawiki_private/tables/cu_changes' --path-format='month=(?P<year>[0-9]+)-(?P<month>[0-9]+)' --older-than='${geoeditors_private_retention_days}' --skip-trash --execute='9d9f8adf2eb7de69c9c3634e45e1f7d9'",
        environment  => $systemd_env,
        interval     => '*-*-* 05:00:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # drop data older than 2-3 months from geoeditors_daily table
    # runs once a day (but only will delete data on the needed date)
    # Temporary stopped to prevent data to be dropped.
    kerberos::systemd_timer { 'mediawiki-geoeditors-drop-month':
        ensure       => $ensure_timers,
        description  => 'Drop Geo-editors data from Hive/HDFS following data retention policies.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='wmf' --tables='geoeditors_daily' --base-path='/wmf/data/wmf/mediawiki_private/geoeditors_daily' --path-format='month=(?P<year>[0-9]+)-(?P<month>[0-9]+)' --older-than='${geoeditors_private_retention_days}' --skip-trash --execute='5faa519abce3840e7718cfbde8779078'",
        environment  => $systemd_env,
        interval     => '*-*-* 06:00:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # drop monthly pages_meta_history dumps data after 80 days (last day of month as reference)
    # runs once a month
    $dumps_retention_days = 80
    kerberos::systemd_timer { 'drop-mediawiki-pages_meta_history-dumps':
        ensure       => $ensure_timers,
        description  => 'Drop pages_meta_history dumps data from HDFS after 80 days.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --base-path /wmf/data/raw/mediawiki/dumps/pages_meta_history --path-format '(?P<year>[0-9]{4})(?P<month>[0-9]{2})01' --older-than ${dumps_retention_days} --log-file ${mediawiki_dumps_log_file} --skip-trash --execute 88d1df6aee62b8562ab3d31964ba6b49",
        environment  => $systemd_env,
        interval     => '*-*-20 06:00:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # drop monthly pages_meta_current dumps data after 80 days (last day of month as reference)
    # runs once a month
    kerberos::systemd_timer { 'drop-mediawiki-pages_meta_current-dumps':
        ensure       => $ensure_timers,
        description  => 'Drop pages_meta_current dumps data from HDFS after 80 days.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --base-path /wmf/data/raw/mediawiki/dumps/pages_meta_current --path-format '(?P<year>[0-9]{4})(?P<month>[0-9]{2})01' --older-than ${dumps_retention_days} --log-file ${mediawiki_dumps_log_file} --skip-trash --execute 7fd55f34e12cb3a6c586a29043ae5402",
        environment  => $systemd_env,
        interval     => '*-*-20 07:00:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # drop monthly siteinfo_namespaces dumps data after 80 days (last day of month as reference)
    # runs once a month
    kerberos::systemd_timer { 'drop-mediawiki-siteinfo_namespaces-dumps':
        ensure       => $ensure_timers,
        description  => 'Drop pages_meta_current dumps data from HDFS after 80 days.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --base-path /wmf/data/raw/mediawiki/dumps/siteinfo_namespaces --path-format '(?P<year>[0-9]{4})(?P<month>[0-9]{2})01' --older-than ${dumps_retention_days} --log-file ${mediawiki_dumps_log_file} --skip-trash --execute b5ced2ce9e4be85f144a2228ade9125d",
        environment  => $systemd_env,
        interval     => '*-*-20 05:00:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }

    # drop hourly pageview-actors data (3 datasets) used to compute automated agent-type after 90 days
    kerberos::systemd_timer { 'drop-features-actor-hourly':
        ensure       => $ensure_timers,
        description  => 'Drop features.actor_hourly data from Hive and HDFS after 90 days.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='features' --tables='actor_hourly' --base-path='/wmf/data/learning/features/actor/hourly' --path-format='year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='90' --skip-trash --execute='ef89b092947eb2f203ed01954e2b2d0b'",
        environment  => $systemd_env,
        interval     => '*-*-* 00/4:40:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }
    kerberos::systemd_timer { 'drop-features-actor-rollup-hourly':
        ensure       => $ensure_timers,
        description  => 'Drop features.actor_rollup_hourly data from Hive and HDFS after 90 days.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='features' --tables='actor_rollup_hourly' --base-path='/wmf/data/learning/features/actor/rollup/hourly' --path-format='year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='90' --skip-trash --execute='bf6a6e00d03fbd7a4b57f778ff0fa35b'",
        environment  => $systemd_env,
        interval     => '*-*-* 00/4:45:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }
    kerberos::systemd_timer { 'drop-predictions-actor_label-hourly':
        ensure       => $ensure_timers,
        description  => 'Drop predictions.actor_label_hourly data from Hive and HDFS after 90 days.',
        command      => "${refinery_path}/bin/refinery-drop-older-than --database='predictions' --tables='actor_label_hourly' --base-path='/wmf/data/learning/predictions/actor/hourly' --path-format='year=(?P<year>[0-9]+)(/month=(?P<month>[0-9]+)(/day=(?P<day>[0-9]+)(/hour=(?P<hour>[0-9]+))?)?)?' --older-than='90' --skip-trash --execute='ad7bb119301815c3a17a2948ebbbf75a'",
        environment  => $systemd_env,
        interval     => '*-*-* 00/4:50:00',
        user         => 'analytics',
        use_kerberos => $use_kerberos,
    }
}
