# == Class profile::analytics::refinery::job::project_namespace_map
#
# Installs a systemd timer to download the Wikimedia sitematrix project
# namespace map file so that other refinery jobs know about what wiki projects
# exist.
#
class profile::analytics::refinery::job::project_namespace_map(
    Optional[String] $http_proxy = hiera('profile::analytics::refinery::job::project_namespace_map::http_proxy', undef),
    Boolean $monitoring_enabled  = hiera('profile::analytics::refinery::job::project_namespace_map::monitoring_enabled', true),
    Wmflib::Ensure $ensure_timer = lookup('profile::analytics::refinery::job::project_namespace_map::ensure_timer', { 'default_value' => 'present' }),
  ) {
    require ::profile::analytics::refinery

    $systemd_env = {
        'PYTHONPATH' => "\${PYTHONPATH}:${profile::analytics::refinery::path}/python",
    }

    $output_directory = '/wmf/data/raw/mediawiki/project_namespace_map'

    if $http_proxy {
        $http_proxy_option = "-p ${http_proxy}"
    } else {
        $http_proxy_option = ''
    }

    file { '/usr/local/bin/refinery-download-project-namespace-map':
        ensure  => $ensure_timer,
        content => template('profile/analytics/refinery/job/refinery-download-project-namespace-map.sh.erb'),
        mode    => '0550',
        owner   => 'analytics',
        group   => 'analytics',
    }

    systemd::timer::job { 'refinery-download-project-namespace-map':
        ensure                    => $ensure_timer,
        description               => "Periodic download of the Wikimedia sitematrix project's namespace map file",
        command                   => '/usr/local/bin/refinery-download-project-namespace-map',
        interval                  => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-01 00:00:00'
        },
        user                      => 'analytics',
        environment               => $systemd_env,
        monitoring_enabled        => $monitoring_enabled,
        monitoring_contact_groups => 'analytics',
        logging_enabled           => true,
        logfile_basedir           => $::profile::analytics::refinery::log_dir,
        logfile_name              => 'syslog.log',
        logfile_owner             => 'analytics',
        logfile_group             => 'analytics',
        logfile_perms             => 'all',
        syslog_force_stop         => true,
        syslog_identifier         => 'refinery-download-project-namespace-map',
        require                   => File['/usr/local/bin/refinery-download-project-namespace-map'],
    }

}
