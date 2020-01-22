class varnish::common(
    $varnish_version=5,
    $fe_runtime_params=[],
    $be_runtime_params=[],
    $log_slow_request_threshold='60.0',
    $logstash_host=undef,
    $logstash_json_lines_port=undef,
) {
    require ::varnish::packages

    # Frontend memory cache sizing
    $mem_gb = $::memorysize_mb / 1024.0

    if ($mem_gb < 90.0) {
        # virtuals, test hosts, etc...
        $fe_mem_gb = 1
    } else {
        # Removing a constant factor before scaling helps with
        # low-memory hosts, as they need more relative space to
        # handle all the non-cache basics.
        $fe_mem_gb = ceiling(0.7 * ($mem_gb - 80.0))
    }

    # Python version
    if os_version('debian == stretch') {
        $python_version = '3.5'
    } elsif os_version('debian == buster') {
        $python_version = '3.7'
    }

    # Mount /var/lib/varnish as tmpfs to avoid Linux flushing mlocked
    # shm memory to disk
    mount { '/var/lib/varnish':
        ensure  => mounted,
        device  => 'tmpfs',
        fstype  => 'tmpfs',
        options => 'noatime,defaults,size=512M',
        pass    => 0,
        dump    => 0,
        require => Class['varnish::packages'],
    }

    file { '/usr/share/varnish/reload-vcl':
        source => 'puppet:///modules/varnish/reload-vcl.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    # Scripts to depool, restart and repool varnish frontends
    file { '/usr/local/sbin/varnish-frontend-restart':
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/varnish/varnish-frontend-restart',
    }

    file { '/usr/local/share/dstat':
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file { '/usr/local/share/dstat/dstat_varnishstat.py':
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/varnish/dstat_varnishstat.py',
        require => File['/usr/local/share/dstat'],
    }

    file { '/usr/local/share/dstat/dstat_varnish_hit.py':
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        source  => 'puppet:///modules/varnish/dstat_varnish_hit.py',
        require => File['/usr/local/share/dstat'],
    }

    # `vlogdump` is a small tool to filter the output of varnishlog
    # See <https://github.com/cosimo/vlogdump> for more.
    file { '/usr/local/bin/vlogdump':
        source => 'puppet:///modules/varnish/vlogdump',
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
    }

    file { '/usr/local/lib/python2.7/dist-packages/varnishprocessor':
        ensure  => absent,
        recurse => true,
        purge   => true,
        force   => true,
    }

    # We are not using varnishncsa, make sure it's stopped
    service { 'varnishncsa':
        ensure => 'stopped',
        enable => false,
    }

    # We don't use varnishlog at all, and it can become an issue, see T135700
    service { 'varnishlog':
        ensure => 'stopped',
    }

    file { '/usr/local/lib/python2.7/dist-packages/varnishapi.py':
        ensure => absent,
    }

    file { '/usr/local/lib/python2.7/dist-packages/varnishlog.py':
        ensure => absent,
    }

    # Install cachestats.py
    file { '/usr/local/lib/python2.7/dist-packages/cachestats.py':
        source => 'puppet:///modules/varnish/cachestats.py',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
    }
}
