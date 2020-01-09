define varnish::instance(
    $layer,
    $vcl_config,
    $ports,
    $admin_port,
    $instance_name='',
    $vcl = '',
    $storage='-s malloc,1G',
    $jemalloc_conf=undef,
    $app_directors={},
    $app_def_be_opts={},
    $cache_route='',
    $backend_caches={},
    $extra_vcl = [],
    $separate_vcl = [],
    $wikimedia_nets = [],
    $wikimedia_trust = [],
) {

    include ::varnish::common

    if $instance_name == '' {
        $instancesuffix = ''
        $instance_opt = ''
    }
    else {
        $instancesuffix = "-${instance_name}"
        $instance_opt = "-n ${instance_name}"
    }

    $reload_vcl_opts = varnish::reload_vcl_opts($vcl_config['varnish_probe_ms'],
                                                $separate_vcl,
                                                $instance_name,
                                                $vcl)

    # Install VCL include files shared by all instances
    require ::varnish::common::vcl

    $extra_vcl_variable_to_make_puppet_parser_happy = suffix($extra_vcl, " ${instancesuffix}")
    varnish::wikimedia_vcl { $extra_vcl_variable_to_make_puppet_parser_happy:
        cache_route        => $cache_route,
        generate_extra_vcl => true,
        vcl_config         => $vcl_config,
        before             => Service["varnish${instancesuffix}"],
    }

    # Write the dynamic backend caches configuration, if we need it
    if $instance_name == '' {
        $inst = 'backend'
        $runtime_parameters = $::varnish::common::be_runtime_params
    } else {
        $inst = $instance_name
        $runtime_parameters = $::varnish::common::fe_runtime_params
    }

    # Raise an icinga critical if the Varnish child process has been started
    # more than once; that means it has died unexpectedly.
    $prometheus_labels = "instance=~\"${::hostname}:.*\",layer=\"${inst}\""

    monitoring::check_prometheus { "varnish-${inst}-check-child-start":
        description     => "Varnish ${inst} child restarted",
        dashboard_links => ["https://grafana.wikimedia.org/dashboard/db/varnish-machine-stats?panelId=66&fullscreen&orgId=1&var-server=${::hostname}&var-datasource=${::site} prometheus/ops"],
        query           => "scalar(varnish_mgt_child_start{${prometheus_labels}})",
        method          => 'gt',
        warning         => 1,
        critical        => 1,
        prometheus_url  => "http://prometheus.svc.${::site}.wmnet/ops",
        notes_link      => 'https://wikitech.wikimedia.org/wiki/Varnish',
    }

    $runtime_params = join(prefix($runtime_parameters, '-p '), ' ')

    array_concat([$vcl], $separate_vcl).each |String $vcl_name| {
        varnish::wikimedia_vcl { "/etc/varnish/wikimedia-common_${vcl_name}.inc.vcl":
            template_path   => "${module_name}/vcl/wikimedia-common.inc.vcl.erb",
            vcl_config      => $vcl_config,
            cache_route     => $cache_route,
            backend_caches  => $backend_caches,
            inst            => $inst,
            app_directors   => $app_directors,
            app_def_be_opts => $app_def_be_opts,
            is_separate_vcl => $vcl_name in $separate_vcl,
            wikimedia_nets  => $wikimedia_nets,
            wikimedia_trust => $wikimedia_trust,
        }

        varnish::wikimedia_vcl { "/etc/varnish/wikimedia_${vcl_name}.vcl":
            require         => File["/etc/varnish/${vcl_name}.inc.vcl"],
            template_path   => "${module_name}/vcl/wikimedia-${layer}.vcl.erb",
            vcl_config      => $vcl_config,
            cache_route     => $cache_route,
            backend_caches  => $backend_caches,
            vcl             => $vcl_name,
            app_directors   => $app_directors,
            app_def_be_opts => $app_def_be_opts,
            is_separate_vcl => $vcl_name in $separate_vcl,
        }

        # These versions of wikimedia-common_${vcl_name}.vcl and wikimedia_${vcl_name}.vcl
        # are exactly the same as those under /etc/varnish but without any
        # backends defined. The goal is to make it possible to run the VTC test
        # files under /usr/share/varnish/tests without having to modify any VCL
        # file by hand.
        varnish::wikimedia_vcl { "/usr/share/varnish/tests/wikimedia-common_${vcl_name}.inc.vcl":
            require         => File['/usr/share/varnish/tests'],
            varnish_testing => true,
            template_path   => "${module_name}/vcl/wikimedia-common.inc.vcl.erb",
            vcl_config      => $vcl_config,
            cache_route     => $cache_route,
            backend_caches  => $backend_caches,
            inst            => $inst,
            app_directors   => $app_directors,
            app_def_be_opts => $app_def_be_opts,
            is_separate_vcl => $vcl_name in $separate_vcl,
            wikimedia_nets  => $wikimedia_nets,
            wikimedia_trust => $wikimedia_trust,
        }

        varnish::wikimedia_vcl { "/usr/share/varnish/tests/wikimedia_${vcl_name}.vcl":
            require         => File['/usr/share/varnish/tests'],
            varnish_testing => true,
            template_path   => "${module_name}/vcl/wikimedia-${layer}.vcl.erb",
            vcl_config      => $vcl_config,
            cache_route     => $cache_route,
            backend_caches  => $backend_caches,
            vcl             => $vcl_name,
            app_directors   => $app_directors,
            app_def_be_opts => $app_def_be_opts,
            is_separate_vcl => $vcl_name in $separate_vcl,
        }

        varnish::wikimedia_vcl { "/etc/varnish/${vcl_name}.inc.vcl":
            template_path  => "varnish/${vcl_name}.inc.vcl.erb",
            notify         => Exec["load-new-vcl-file${instancesuffix}"],
            vcl_config     => $vcl_config,
            cache_route    => $cache_route,
            backend_caches => $backend_caches,
        }

        varnish::wikimedia_vcl { "/usr/share/varnish/tests/${vcl_name}.inc.vcl":
            require         => File['/usr/share/varnish/tests'],
            varnish_testing => true,
            template_path   => "varnish/${vcl_name}.inc.vcl.erb",
            vcl_config      => $vcl_config,
            cache_route     => $cache_route,
            backend_caches  => $backend_caches,
        }
    }

    if ($inst == 'backend') {
        # -sfile needs CAP_DAC_OVERRIDE and CAP_FOWNER too
        $capabilities = 'CAP_SETUID CAP_SETGID CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER'
    } else {
        # varnish frontend needs CAP_NET_BIND_SERVICE as it binds to port 80
        $capabilities = 'CAP_SETUID CAP_SETGID CAP_CHOWN CAP_NET_BIND_SERVICE'
    }

    # Array of VCL files required by Varnish systemd::service.
    # load-new-vcl-file below subscribes to these too, reload-vcl needs to be
    # run when they change.
    $vcl_files = array_concat([
        File["/etc/varnish/${vcl}.inc.vcl"],
        File["/etc/varnish/wikimedia_${vcl}.vcl"],
        File["/etc/varnish/wikimedia-common_${vcl}.inc.vcl"],
        File[suffix(prefix($extra_vcl, '/etc/varnish/'),'.inc.vcl')],
    ], $separate_vcl.map |$vcl_name| {
        [ File["/etc/varnish/wikimedia_${vcl_name}.vcl"],
          File["/etc/varnish/wikimedia-common_${vcl_name}.inc.vcl"] ]
    })

    systemd::service { "varnish${instancesuffix}":
        content        => systemd_template('varnish'),
        service_params => {
            tag     => 'varnish_instance',
            enable  => true,
            require => array_concat([
                Package['varnish'],
                Mount['/var/lib/varnish'],
            ], $vcl_files),
        },
    }

    systemd::service { "varnish${instancesuffix}-slowlog":
        ensure         => present,
        content        => systemd_template('varnishslowlog'),
        restart        => true,
        service_params => {
            require => Service["varnish${instancesuffix}"],
            enable  => true,
        },
        require        => File['/usr/local/bin/varnishslowlog'],
        subscribe      => [
            File['/usr/local/bin/varnishslowlog'],
            File["/usr/local/lib/python${::varnish::common::python_version}/dist-packages/wikimedia_varnishlogconsumer.py"],
        ]
    }

    base::service_auto_restart { "varnish${instancesuffix}-slowlog": }

    systemd::service { "varnish${instancesuffix}-hospital":
        ensure         => present,
        content        => systemd_template('varnishospital'),
        restart        => true,
        service_params => {
            require => Service["varnish${instancesuffix}"],
            enable  => true,
        },
        subscribe      => [
            File['/usr/local/bin/varnishospital'],
            File["/usr/local/lib/python${::varnish::common::python_version}/dist-packages/wikimedia_varnishlogconsumer.py"],
        ]
    }

    base::service_auto_restart { "varnish${instancesuffix}-hospital": }

    systemd::service { "varnish${instancesuffix}-fetcherr":
        ensure         => present,
        content        => systemd_template('varnishfetcherr'),
        restart        => true,
        service_params => {
            require => Service["varnish${instancesuffix}"],
            enable  => true,
        },
        subscribe      => [
            File['/usr/local/bin/varnishfetcherr'],
            File["/usr/local/lib/python${::varnish::common::python_version}/dist-packages/wikimedia_varnishlogconsumer.py"],
        ]
    }

    base::service_auto_restart { "varnish${instancesuffix}-fetcherr": }

    # This mechanism with the touch/rm conditionals in the pair of execs
    #   below should ensure that reload-vcl failures are retried on
    #   future puppet runs until they succeed.
    $vcl_failed_file = "/var/tmp/reload-vcl-failed${instancesuffix}"

    exec { "load-new-vcl-file${instancesuffix}":
        require     => Service["varnish${instancesuffix}"],
        subscribe   => array_concat([
                Class['varnish::common::vcl'],
                Class['varnish::common::errorpage'],
                Class['varnish::common::browsersec'],
            ], $vcl_files),
        command     => "/usr/share/varnish/reload-vcl ${reload_vcl_opts} || (touch ${vcl_failed_file}; false)",
        unless      => "test -f ${vcl_failed_file}",
        path        => '/bin:/usr/bin',
        refreshonly => true,
    }

    exec { "retry-load-new-vcl-file${instancesuffix}":
        require => Exec["load-new-vcl-file${instancesuffix}"],
        command => "/usr/share/varnish/reload-vcl ${reload_vcl_opts} && (rm ${vcl_failed_file}; true)",
        onlyif  => "test -f ${vcl_failed_file}",
        path    => '/bin:/usr/bin',
    }

    # TODO/puppet4: convert this to be a define that uses instance name as title and ports as a parameter
    # to allow having non-strigified port numbers.
    varnish::monitoring::instance { $ports:
        instance => $title,
    }
}
