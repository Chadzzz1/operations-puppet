class ceph::mon (
    Stdlib::Unixpath       $data_dir,
    String                 $fsid,
    Ceph::Auth::ClientAuth $admin_auth,
    Ceph::Auth::ClientAuth $mon_auth,
) {
    # this should have been declared elsewhere
    Ceph::Auth::Keyring['admin'] -> Class['ceph::mon']
    Ceph::Auth::Keyring["mon.${::hostname}"] -> Class['ceph::mon']
    Class['ceph::config'] -> Class['ceph::mon']

    ensure_packages([
      'ceph-mon',
      'ceph-mgr',
    ])

    file { "${data_dir}/mon/ceph-${::hostname}":
        ensure => 'directory',
        owner  => 'ceph',
        group  => 'ceph',
        mode   => '0750',
    }

    # bootstrapping the mon needs a temporal keyring file that contains 2 keyrings.
    # reference: https://docs.ceph.com/en/latest/dev/mon-bootstrap/?highlight=bootstrap#secret-keys

    $temp_keyring = "${data_dir}/tmp/ceph.mon.keyring"
    concat { $temp_keyring:
        owner => 'ceph',
        group => 'ceph',
        mode  => '0600',
    }

    # TODO: is not 100% clear to arturo if this keyring MUST be generated on
    # the fly, i.e, a dummy keyring instead of a pre-recorded one in load_all.yaml
    concat::fragment { 'mon_keyring':
        target  => $temp_keyring,
        source  => ceph::auth::get_keyring_path("mon.${::hostname}", $mon_auth['keyring_path']),
        order   => '01',
        require => Ceph::Auth::Keyring["mon.${::hostname}"],
    }

    concat::fragment { 'admin_keyring':
        target  => $temp_keyring,
        source  => ceph::auth::get_keyring_path('client.admin', $admin_auth['keyring_path']),
        order   => '02',
        require => Ceph::Auth::Keyring['admin'],
    }

    exec { 'ceph-mon-mkfs':
        command => "/usr/bin/ceph-mon --mkfs -i ${::hostname} --fsid ${fsid} --keyring ${temp_keyring}",
        user    => 'ceph',
        creates => "${data_dir}/mon/ceph-${::hostname}/kv_backend",
        require => [Concat[$temp_keyring], File["${data_dir}/mon/ceph-${::hostname}"]],
    }

    service { "ceph-mon@${::hostname}":
        ensure  => running,
        enable  => true,
        require => [Exec['ceph-mon-mkfs'], File['/etc/ceph/ceph.conf']],
    }
}
