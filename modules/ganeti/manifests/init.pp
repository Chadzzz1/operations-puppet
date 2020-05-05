# Class ganeti
#
# Install ganeti
#
# Parameters:
#   with_drbd: Boolean. Indicates if drbd should be configured. Defaults to true
#
# Actions:
#   Install ganeti and configure modules/LVM. Does NOT initialize a cluster
#
# Requires:
#
# Sample Usage
#   include ganeti
class ganeti(
    $with_drbd=true
    ) {
    include ::ganeti::kvm

    # We're not using ganeti-instance-debootstrap to create images (we PXE-boot
    # the same images we use for baremetal servers), but /usr/share/ganeti/os/debootstrap
    # is needed as an OS provider for "gnt-instance add"
    package { [
            'ganeti',
            'drbd-utils',
            'ovmf',
            'ganeti-instance-debootstrap',
            ] :
        ensure => installed,
    }

    if $with_drbd {
        kmod::options { 'drbd':
            options => 'minor_count=128 usermode_helper=/bin/true',
        }

        # Enable drbd
        kmod::module { 'drbd':
            ensure => 'present',
        }

        # Disable the systemd service shipped with the drbd package. Ganeti handles
        # DRBD on its own
        service { 'drbd':
            ensure => 'stopped',
            enable => false,
        }
    }

    # Enable vhost_net
    kmod::module { 'vhost_net':
        ensure => 'present',
    }

    # lvm.conf
    # Note: We deviate from the default lvm.conf to change the filter config to
    # not include all block devices. TODO: Do it via augeas
    file { '/etc/lvm/lvm.conf' :
        ensure => present,
        owner  => 'root',
        group  => 'root',
        mode   => '0644',
        source => 'puppet:///modules/ganeti/lvm.conf',
    }

    # Deploy defaults (for now, configuring RAPI) and the certificates for RAPI.
    # Potential fixme: We don't restart the daemon here since it's not independent
    # and this file configures other aspects of Ganeti. Manually restart ganeti
    # on the target hosts after changes are merged.
    $certname = "ganeti01.svc.${::site}.wmnet"
    file { '/etc/default/ganeti':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0644',
        content => template('ganeti/etc_default_ganeti.erb')
    }
    sslcert::certificate { $certname:
        ensure     => present,
        group      => 'gnt-admin',
        use_cergen => true,
    }
}
