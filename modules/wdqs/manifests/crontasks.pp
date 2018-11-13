# == Class: wdqs::crontasks
#
# Installs all the major cron jobs for WDQS
#
# == Parameters:
# - $package_dir:  Directory where the service is installed.
# - $data_dir: Where the data is installed.
# - $log_dir: Directory where the logs go
# - $username: Username owning the service
# - $load_categories: frequency of loading categories
class wdqs::crontasks(
    String $package_dir,
    String $data_dir,
    String $log_dir,
    String $username,
    Enum['none', 'daily', 'weekly'] $load_categories,
) {
    file { '/usr/local/bin/cronUtils.sh':
        ensure => present,
        source => 'puppet:///modules/wdqs/cron/cronUtils.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { '/usr/local/bin/reloadCategories.sh':
        ensure => present,
        source => 'puppet:///modules/wdqs/cron/reloadCategories.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { '/usr/local/bin/loadCategoriesDaily.sh':
        ensure => present,
        source => 'puppet:///modules/wdqs/cron/loadCategoriesDaily.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { '/usr/local/bin/reloadDCAT-AP.sh':
        ensure => present,
        source => 'puppet:///modules/wdqs/cron/reloadDCAT-AP.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    $reload_categories_log = "${log_dir}/reloadCategories.log"
    # the reload-categories cron needs to reload nginx once the categories are up to date
    sudo::user { "${username}-reload-nginx":
      ensure     => present,
      user       => $username,
      privileges => [ 'ALL = NOPASSWD: /bin/systemctl reload nginx' ],
    }

    $ensure_reload_categories = $load_categories ? {
        'weekly' => 'present',
        default  => 'absent',
    }

    $ensure_daily_categories = $load_categories ? {
        'daily' => 'present',
        default => 'absent',
    }

    # Category dumps start on Sat 20:00. By Mon, they should be done.
    # We want random time so that hosts don't reboot at the same time, but we
    # do not want them to be too far from one another.
    cron { 'reload-categories':
        ensure  => $ensure_reload_categories,
        command => "/usr/local/bin/reloadCategories.sh >> ${reload_categories_log} 2>&1",
        user    => $username,
        weekday => 1,
        minute  => fqdn_rand(60),
        hour    => fqdn_rand(2),
    }

    # Categories daily dump starts at 5:00. Currently it is done by 5:05, but just in case
    # it ever takes longer, start at 7:00.
    cron { 'load-categories-daily':
        ensure  => $ensure_daily_categories,
        command => "/usr/local/bin/loadCategoriesDaily.sh >> ${reload_categories_log} 2>&1",
        user    => $username,
        minute  => fqdn_rand(60),
        hour    => 7
    }

    cron { 'reload-dcatap':
        ensure  => present,
        command => "/usr/local/bin/reloadDCAT-AP.sh >> ${log_dir}/dcat.log 2>&1",
        user    => $username,
        weekday => 4,
        minute  => 0,
        hour    => 10,
    }

    logrotate::rule { 'wdqs-reload-categories':
        ensure       => present,
        file_glob    => $reload_categories_log,
        frequency    => 'monthly',
        missing_ok   => true,
        not_if_empty => true,
        rotate       => 3,
        compress     => true,
        create       => "0640 ${username} wikidev",
    }

    logrotate::rule { 'wdqs-reload-dcat':
        ensure       => present,
        file_glob    => "${log_dir}/dcatap.log",
        frequency    => 'monthly',
        missing_ok   => true,
        not_if_empty => true,
        rotate       => 3,
        compress     => true,
        create       => "0640 ${username} wikidev",
    }
}
