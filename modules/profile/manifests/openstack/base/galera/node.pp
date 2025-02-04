class profile::openstack::base::galera::node(
    Integer                $server_id              = lookup('profile::openstack::base::galera::server_id'),
    Boolean                $enabled                = lookup('profile::openstack::base::galera::enabled'),
    Stdlib::Port           $listen_port            = lookup('profile::openstack::base::galera::listen_port'),
    String                 $prometheus_db_pass     = lookup('profile::openstack::base::galera::prometheus_db_pass'),
    Array[Stdlib::Fqdn]    $openstack_controllers  = lookup('profile::openstack::base::openstack_controllers'),
    Array[Stdlib::Fqdn]    $designate_hosts        = lookup('profile::openstack::base::designate_hosts'),
    Array[Stdlib::Fqdn]    $labweb_hosts           = lookup('profile::openstack::base::labweb_hosts'),
    Array[Stdlib::Fqdn]    $cinder_backup_nodes    = lookup('profile::openstack::base::cinder::backup::nodes'),
    Array[Stdlib::Fqdn]    $haproxy_nodes          = lookup('profile::openstack::base::haproxy_nodes'),
    Array[Stdlib::Fqdn]    $cinder_volume_nodes    = lookup('profile::openstack::base::cinder_volume_nodes'),
) {
    $socket = '/var/run/mysqld/mysqld.sock'
    $datadir = '/srv/sqldata'
    file { $datadir:
        ensure => directory,
        owner  => 'mysql',
        group  => 'mysql',
        mode   => '0755',
    }

    class {'::galera':
        cluster_nodes => $openstack_controllers,
        server_id     => $server_id,
        enabled       => $enabled,
        port          => $listen_port,
        datadir       => $datadir,
        socket        => $socket,
    }

    # 4567, replication
    # 4568, incremental state transfer
    # 4444, state snapshot transfer
    ferm::service { 'galera-cluster':
        proto  => 'tcp',
        port   => '(4567 4568 4444)',
        srange => "(@resolve((${openstack_controllers.join(' ')})))",
    }

    # 9990 for the nodecheck service
    ferm::service { 'galera-backend':
        proto  => 'tcp',
        port   => "(${listen_port} 9990)",
        srange => "@resolve((${haproxy_nodes.join(' ')}))",
    }

    # TODO: move to haproxy/cloudlb profiles
    # Database access from each db node, HA-proxy, designate, web hosts
    ferm::service { 'galera-access':
        proto  => 'tcp',
        port   => 3306,
        srange => "(@resolve((${openstack_controllers.join(' ')} ${designate_hosts.join(' ')} ${cinder_backup_nodes.join(' ')} ${cinder_volume_nodes.join(' ')} ${labweb_hosts.join(' ')})))",
    }

    nrpe::monitor_service { 'check_galera_mariadbd_process':
        ensure        => $enabled.bool2str('present', 'absent'),
        description   => 'mysql (galera) process',
        nrpe_command  => '/usr/lib/nagios/plugins/check_procs -c 1:1 -C mariadbd',
        contact_group => 'wmcs-bots',
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Portal:Cloud_VPS/Admin/Troubleshooting',
    }

    prometheus::mysqld_exporter { 'default':
        client_password => $prometheus_db_pass,
        client_socket   => $socket,
    } -> service { 'prometheus-mysqld-exporter':
        ensure => 'running',
    }

    openstack::db::project_grants { 'prometheus':
        privs        => 'REPLICATION CLIENT, PROCESS',
        access_hosts => $openstack_controllers,
        db_name      => '*',
        db_user      => 'prometheus',
        db_pass      => $prometheus_db_pass,
        project_name => 'prometheus',
    }

    openstack::db::project_grants { 'prometheus_performance':
        privs        => 'SELECT',
        access_hosts => $openstack_controllers,
        db_name      => 'performance_schema',
        db_user      => 'prometheus',
        db_pass      => $prometheus_db_pass,
        project_name => 'prometheus',
    }

    # nodechecker service -- should be able to run as prometheus user
    # This is a flask app that replies
    # with a 200 or error so we get a real healthcheck for haproxy
    file { '/var/log/nodecheck':
        ensure => directory,
        owner  => 'prometheus',
        group  => 'prometheus',
        mode   => '0755',
    }
    logrotate::conf { 'nodecheck':
        ensure => present,
        source => 'puppet:///modules/profile/openstack/base/galera/nodecheck_logrotate.conf',
    }
    file { '/usr/local/sbin/galera-nodecheck.py':
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/profile/openstack/base/galera/galera-nodecheck.py',
    }

    systemd::service {'galera_nodecheck':
        ensure  => 'present',
        content => systemd_template('wmcs/galera/galera-nodecheck'),
    }
}
