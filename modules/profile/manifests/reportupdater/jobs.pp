# == Class profile::reportupdater::jobs
# Installs reportupdater jobs that run on Hadoop/Hive.
# This profile should only be included in a single role.
#
# This requires that a Hadoop client is installed and the statistics compute role
# for the published_path.
class profile::reportupdater::jobs(
    $ensure_jobs = lookup('profile::reportupdater::jobs::ensure_jobs', { 'default_value' => 'present' }),
) {

    require ::profile::analytics::cluster::packages::hadoop
    require ::profile::analytics::cluster::client

    $base_path = '/srv/reportupdater'

    # Set up reportupdater.
    # Reportupdater here launches Hadoop jobs, and
    # the 'analytics' user is the Analytics 'system' user that has
    # access to required files in Hadoop.
    class { 'reportupdater':
        user      => 'analytics',
        base_path => $base_path,
    }

    # And set up a link for periodic jobs to be included in published reports.
    # Because periodic is in published_path, files will be synced to
    # analytics.wikimedia.org/published/datasets/periodic/reports
    file { "${::statistics::compute::published_path}/datasets/periodic":
        ensure => 'directory',
        owner  => 'root',
        group  => 'wikidev',
        mode   => '0775',
    }
    file { "${::statistics::compute::published_path}/datasets/periodic/reports":
        ensure  => 'link',
        target  => "${base_path}/output",
        require => Class['reportupdater'],
    }

    # Set up a job to create browser reports on hive db.
    reportupdater::job { 'browser':
        ensure     => $ensure_jobs,
        output_dir => 'metrics/browser',
    }

    reportupdater::job { 'codemirror':
        ensure     => $ensure_jobs,
        output_dir => 'metrics/codemirror',
    }

    reportupdater::job { 'interlanguage':
        ensure     => $ensure_jobs,
        output_dir => 'metrics/interlanguage',
    }

    reportupdater::job { 'pingback':
        ensure     => $ensure_jobs,
        output_dir => 'metrics/pingback',
    }

    reportupdater::job { 'reference-previews':
        ensure     => $ensure_jobs,
        output_dir => 'metrics/reference-previews',
    }

    reportupdater::job { 'wmcs':
        ensure     => $ensure_jobs,
        output_dir => 'metrics/wmcs',
    }

    reportupdater::job { 'structured-data':
        ensure     => $ensure_jobs,
        output_dir => 'metrics/structured-data',
    }

    # Set up various jobs to be executed by reportupdater
    # creating several reports on mysql research db.
    reportupdater::job { 'flow-beta-features':
        ensure       => $ensure_jobs,
        output_dir   => 'metrics/beta-feature-enables',
        use_kerberos => false,
    }

    reportupdater::job { 'edit-beta-features':
        ensure       => $ensure_jobs,
        output_dir   => 'metrics/beta-feature-enables',
        use_kerberos => false,
    }

    reportupdater::job { 'language':
        ensure       => $ensure_jobs,
        output_dir   => 'metrics/beta-feature-enables',
        use_kerberos => false,
    }

    # Note:
    # The published_cx2_translations jobs were on stat1007 (hive based)
    # and on stat1006 (mysql based). They now have different job names,
    # but their output directory is the same on purpose, to allow rsync
    # jobs to properly collect and merge data downstream.
    reportupdater::job { 'published_cx2_translations':
        ensure      => $ensure_jobs,
        config_file => "${base_path}/jobs/reportupdater-queries/published_cx2_translations/config-hive.yaml",
        output_dir  => 'metrics/published_cx2_translations',
    }
    reportupdater::job { 'published_cx2_translations_mysql':
        ensure       => $ensure_jobs,
        config_file  => "${base_path}/jobs/reportupdater-queries/published_cx2_translations/config-mysql.yaml",
        output_dir   => 'metrics/published_cx2_translations',
        query_dir    => 'published_cx2_translations',
        interval     => '*-*-* *:30:00',
        use_kerberos => false,
    }

    reportupdater::job { 'mt_engines':
        ensure       => $ensure_jobs,
        output_dir   => 'metrics/mt_engines',
        use_kerberos => false,
    }

    reportupdater::job { 'cx':
        ensure       => $ensure_jobs,
        output_dir   => 'metrics/cx',
        use_kerberos => false,
    }

    reportupdater::job { 'ee':
        ensure       => $ensure_jobs,
        output_dir   => 'metrics/echo',
        use_kerberos => false,
    }
}
