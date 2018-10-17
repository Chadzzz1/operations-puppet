# == Class profile::hadoop::balancer
#
# Runs hdfs balancer periodically to keep data balanced across all DataNodes
#
class profile::hadoop::balancer {
    require ::profile::hadoop::common

    file { '/usr/local/bin/hdfs-balancer':
        source => 'puppet:///modules/profile/hadoop/hdfs-balancer',
        mode   => '0754',
        owner  => 'hdfs',
        group  => 'hdfs',
    }

    # logrotate HDFS balancer's log files
    logrotate::conf { 'hdfs_balancer':
        ensure => absent,
        source => 'puppet:///modules/profile/hadoop/hdfs_balancer.logrotate',
    }

    cron { 'hdfs-balancer':
        ensure  => absent,
        command => '/usr/local/bin/hdfs-balancer >> /var/log/hadoop-hdfs/balancer.log 2>&1',
        user    => 'hdfs',
        # Every day at 6am UTC.
        minute  => 0,
        hour    => 6,
        require => File['/usr/local/bin/hdfs-balancer'],
    }

    profile::analytics::systemd_timer { 'hdfs-balancer':
        description     => 'Run the HDFS balancer script to keep HDFS blocks replicated in the most redundant and efficient way.',
        command         => '/usr/local/bin/hdfs-balancer',
        interval        => '*-*-* 06:00:00',
        logfile_name    => 'balancer.log',
        logfile_basedir => '/var/log/hadoop-hdfs',
        require         => File['/usr/local/bin/hdfs-balancer'],
    }
}
