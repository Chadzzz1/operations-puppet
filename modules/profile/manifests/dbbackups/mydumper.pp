# SPDX-License-Identifier: Apache-2.0
# Create mydumper logical backups using the dump_shards.sh hosts
# of all production core (s*, x*) and misc (m*) hosts.
# Do that using a cron job on all backup hosts, all datacenters.
# Note this profile creates the backups, but does not send them
# to bacula or other long-term storage, that is handled by the
# dbbackups::bacula class.
#
# Arguments:
# * enabled: A boolean value that, if false, removes the execution
#            of the systemd timer (defaulting to true for backwards
#            compatiblity)
# * schedule: A string containing the systemd timer's execution
#             schedule definition (defaulting to
#             'Tue *-*-* 00:00:00' for backwards compatibility)

class profile::dbbackups::mydumper (
    Boolean $enabled  = lookup('profile::dbbackups::mydumper::enabled', {default_value => true}),
    String  $schedule = lookup('profile::dbbackups::mydumper::schedule', {default_value => 'Tue *-*-* 00:00:00'}),
) {

    include ::passwords::mysql::dump

    ensure_packages([
        'wmfbackups',  # we now install all software from debian package
        'mydumper',  # mydumper is only a soft dependency, explicitly install it
        'parallel',  # dependency of mini_loader.sh (in addition to a mysql client)
    ])

    group { 'dump':
        ensure => present,
        system => true,
    }

    user { 'dump':
        ensure     => present,
        gid        => 'dump',
        shell      => '/bin/false',
        home       => '/srv/backups',
        system     => true,
        managehome => false,
    }

    # provisional hack to allow for recovery of 10.6 data
    file { '/usr/bin/load_file.sh':
        ensure => present,
        group  => 'root',
        owner  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/profile/dbbackups/load_file.sh',
    }

    file { '/usr/bin/mini_loader.sh':
        ensure => present,
        group  => 'root',
        owner  => 'root',
        mode   => '0755',
        source => 'puppet:///modules/profile/dbbackups/mini_loader.sh',
    }

    file { '/srv/backups':
        ensure => directory,
        owner  => 'dump',
        group  => 'dump',
        mode   => '0711', # o+x so we can mount and check /ongoing
    }

    file { '/srv/backups/dumps':
        ensure  => directory,
        owner   => 'dump',
        group   => 'dump',
        mode    => '0711', # o+x so we can mount and check /ongoing
        require => File['/srv/backups'],
    }

    file { ['/srv/backups/dumps/ongoing',
            '/srv/backups/dumps/latest',
            '/srv/backups/dumps/archive',
        ]:
        ensure  => directory,
        owner   => 'dump',
        group   => 'dump',
        mode    => '0600', # implicitly 0700 for dirs
        require => File['/srv/backups/dumps'],
    }

    $user = $passwords::mysql::dump::user
    $password = $passwords::mysql::dump::pass
    $stats_user = $passwords::mysql::dump::stats_user
    $stats_password = $passwords::mysql::dump::stats_pass
    file { '/etc/wmfbackups/backups.cnf':
        ensure    => present,
        owner     => 'dump',
        group     => 'dump',
        mode      => '0400',
        show_diff => false,
        content   => template("profile/dbbackups/${::hostname}.cnf.erb"),
    }
    # separate file for common statistics db config
    file { '/etc/wmfbackups/statistics.cnf':
        ensure    => present,
        owner     => 'dump',
        group     => 'dump',
        mode      => '0400',
        show_diff => false,
        content   => template('profile/dbbackups/statistics.cnf.erb'),
    }
    # Logging support
    file { '/var/log/mariadb-backups':
        ensure => directory,
        owner  => 'dump',
        group  => 'dump',
        mode   => '0740',
    }

    if ($enabled) {
        $ensure = 'present'
    } else {
        $ensure = 'absent'
    }

    systemd::timer::job { 'dumps-sections':
        ensure        => $ensure,
        description   => 'MariaDB backups',
        command       => '/usr/bin/backup-mariadb --config-file=/etc/wmfbackups/backups.cnf',
        user          => 'dump',
        interval      => { 'start' => 'OnCalendar', 'interval' => $schedule},
        # Ignore any errors to avoid triggering Icinga alerts
        # if one or several of the backups fail.
        # Backup status notifications are handled in the backup check script.
        # Once 820664 has been merged, we will remove ignore_errors,
        # to ensure that we're notified about any other potential errors.
        ignore_errors => true,
    }

    class { 'toil::systemd_scope_cleanup': }  # T265323
}
