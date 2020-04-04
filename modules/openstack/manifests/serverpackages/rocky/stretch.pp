class openstack::serverpackages::rocky::stretch(
){
    $stretch_bpo_packages = [
      'librados2',
      'librgw2',
      'librbd1',
      'python-rados',
      'python-rbd',
      'ceph-common',
      'python-cephfs',
      'libradosstriper1',
    ]

    apt::pin { 'openstack-rocky-stretch-bpo':
        package  => join($stretch_bpo_packages, ' '),
        pin      => 'release n=stretch-backports',
        priority => '1002',
    }

    # Don't install systemd from stretch-backports or bpo -- T247013
    apt::pin { 'systemd':
        pin      => 'release n=stretch',
        package  => 'systemd libpam-systemd',
        priority => '1001',
    }

    apt::repository { 'openstack-rocky-stretch':
        uri        => 'http://mirrors.wikimedia.org/osbpo',
        dist       => 'stretch-rocky-backports',
        components => 'main',
        source     => false,
        keyfile    => 'puppet:///modules/openstack/serverpackages/osbpo-pubkey.gpg',
        notify     => Exec['openstack-rocky-stretch-apt-upgrade'],
    }

    apt::repository { 'openstack-rocky-stretch-nochange':
        uri        => 'http://mirrors.wikimedia.org/osbpo',
        dist       => 'stretch-rocky-backports-nochange',
        components => 'main',
        source     => false,
        keyfile    => 'puppet:///modules/openstack/serverpackages/osbpo-pubkey.gpg',
        notify     => Exec['openstack-rocky-stretch-apt-upgrade'],
    }

    # ensure apt can see the repo before any further Package[] declaration
    # so this proper repo/pinning configuration applies in the same puppet
    # agent run
    exec { 'openstack-rocky-stretch-apt-upgrade':
        command     => '/usr/bin/apt-get update',
        require     => [Apt::Repository['openstack-rocky-stretch'],
                        Apt::Repository['openstack-rocky-stretch-nochange']],
        subscribe   => [Apt::Repository['openstack-rocky-stretch'],
                        Apt::Repository['openstack-rocky-stretch-nochange']],
        refreshonly => true,
        logoutput   => true,
    }
    Exec['openstack-rocky-stretch-apt-upgrade'] -> Package <| |>
}
