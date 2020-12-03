class profile::wmcs::nfs::primary(
  $observer_pass = hiera('profile::openstack::eqiad1::observer_password'),
  $monitor_iface = hiera('profile::wmcs::nfs::primary::monitor_iface', 'eth0'),
  $data_iface    = hiera('profile::wmcs::nfs::primary::data_iface', 'eth1'),
  $backup_servers = hiera('profile::wmcs::nfs::primary::backup_servers'),
  Hash[String, Hash[String, Variant[Integer,String]]] $drbd_resource_config = lookup('profile::wmcs::nfs::primary::drbd_resource_config'),
  Stdlib::Fqdn $standby_server     = lookup('profile::wmcs::nfs::primary_standby'),
  Array[Stdlib::Fqdn] $nfs_cluster = lookup('profile::wmcs::nfs::primary_cluster'),
  Hash[String, Stdlib::IP::Address::V4] $drbd_cluster = lookup('profile::wmcs::nfs::primary::drbd_cluster'),
  Stdlib::IP::Address::V4 $cluster_ip = lookup('profile::wmcs::nfs::primary::cluster_ip'),
  Stdlib::IP::Address::V4 $subnet_gateway_ip = lookup('profile::wmcs::nfs::primary::subnet_gateway_ip'),
) {
    require profile::openstack::eqiad1::clientpackages
    require profile::openstack::eqiad1::observerenv

    $drbd_expected_role = $facts['fqdn'] ? {
        $standby_server => 'secondary',
        default         => 'primary',
    }

    $drbd_ip_address = $drbd_cluster[$facts['hostname']]

    # Determine the actual role from a custom fact.
    if has_key($facts, 'drbd_role') {
        if $facts['drbd_role'].values().unique().length() > 1 {
            $drbd_actual_role = 'inconsistent'
        } else {
            $drbd_actual_role = $facts['drbd_role'].values().unique()[0]
        }
    } else {
        $drbd_actual_role = undef
    }

    class {'labstore':
        nfsd_threads => 300,
    }

    package { [
            'python3-paramiko',
            'python3-pymysql',
        ]:
        ensure => present,
    }

    class {'labstore::backup_keys': }

    sysctl::parameters { 'cloudstore base':
        values   => {
            # Increase TCP max buffer size
            'net.core.rmem_max' => 67108864,
            'net.core.wmem_max' => 67108864,

            # Increase Linux auto-tuning TCP buffer limits
            # Values represent min, default, & max num. of bytes to use.
            'net.ipv4.tcp_rmem' => [ 4096, 87380, 33554432 ],
            'net.ipv4.tcp_wmem' => [ 4096, 65536, 33554432 ],
        },
        priority => 70,
    }

    class {'labstore::fileserver::exports':
        server_vols => ['project', 'home', 'tools-home', 'tools-project'],
        drbd_role   => $drbd_actual_role,
    }

    # Enable RPS to balance IRQs over CPUs
    interface::rps { 'monitor':
        interface => $monitor_iface,
    }

    interface::manual{ 'data':
        interface => $data_iface,
    }

    interface::ip { 'drbd-replication':
        interface => $data_iface,
        address   => $drbd_ip_address,
        prefixlen => '30',
        require   => Interface::Manual['data'],
    }

    $backup_ferm_servers = join($backup_servers, ' ')
    $cluster_ips_ferm = join($drbd_cluster.values(), ' ')
    $nfs_ferm_servers = join($nfs_cluster, ' ')

    # Generate ferm rules for DRBD replication
    $drbd_resource_config.each |String $volume, Hash $volume_config| {
        ferm::service { "drbd-${volume}":
            proto  => 'tcp',
            port   => $volume_config['port'],
            srange => "(${cluster_ips_ferm})",
        }
    }

    ferm::service { 'labstore_nfs_monitor':
        proto  => 'tcp',
        port   => '2049',
        srange => "@resolve((${nfs_ferm_servers}))",
    }

    ferm::service{ 'cloudbackup_ssh':
        proto  => 'tcp',
        port   => '22',
        srange => "@resolve((${backup_ferm_servers}))",
    }

    $drbd_defaults = {
        'drbd_cluster' => $drbd_cluster
    }

    create_resources(labstore::drbd::resource, $drbd_resource_config, $drbd_defaults)

    Interface::Ip['drbd-replication'] -> Labstore::Drbd::Resource[keys($drbd_resource_config)]

    # state managed manually
    service { 'drbd':
        enable => false,
    }

    # state via nfs-manage (TODO: cleanup from jessie deprecation)
    if debian::codename::ge('stretch') {
        service { 'nfs-server':
            enable => false,
        }
        $nfs_start_command = 'systemctl start nfs-server'
        $nfs_stop_command = 'systemctl stop nfs-server'
    } else {
        service { 'nfs-kernel-server':
            enable => false,
        }
        $nfs_start_command = '/usr/sbin/service nfs-kernel-server start'
        $nfs_stop_command = '/usr/sbin/service nfs-kernel-server stop'
    }

    file { '/usr/local/sbin/nfs-manage':
        content => template('profile/wmcs/nfs/nfs-manage.sh.erb'),
        mode    => '0744',
        owner   => 'root',
        group   => 'root',
    }

    class {'labstore::monitoring::exports':
        drbd_role => $drbd_actual_role,
    }
    class {'labstore::monitoring::volumes':
        server_vols => [
            '/srv/tools',
            '/srv/misc'
        ],
        drbd_role   => $drbd_actual_role,
    }
    class {'labstore::monitoring::ldap': }
    class {'labstore::monitoring::interfaces':
        monitor_iface => $monitor_iface,
    }

    class { 'labstore::monitoring::primary':
        drbd_role     => $drbd_expected_role,
        cluster_iface => $monitor_iface,
        cluster_ip    => $cluster_ip,
    }

    file {'/usr/local/sbin/logcleanup':
        source => 'puppet:///modules/labstore/logcleanup.py',
        mode   => '0744',
        owner  => 'root',
        group  => 'root',
    }

    file {'/etc/logcleanup-config.yaml':
        source => 'puppet:///modules/profile/wmcs/nfs/primary/logcleanup-config.yaml',
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
    }

    if($drbd_actual_role == 'primary') {
        class { 'profile::prometheus::node_directory_size':
            directory_size_paths => {
                'misc_home'     => { 'path' => '/srv/misc/shared/*/home', 'filter' => '*/tools/*' },
                'misc_project'  => { 'path' => '/srv/misc/shared/*/project', 'filter' => '*/tools/*' },
                'tools_home'    => { 'path' => '/srv/tools/shared/tools/home/*' },
                'tools_project' => { 'path' => '/srv/tools/shared/tools/project/*' },
            },
        }
    } else {
        # Don't do this if the volumes are not in a "primary" and ready state
        class { 'profile::prometheus::node_directory_size':
            ensure => absent,
        }
    }
}
