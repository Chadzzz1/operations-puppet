# SPDX-License-Identifier: Apache-2.0
# Class: profile::cloudceph::client:rbd_libvirt
#
# This profile will configure clients for connecting to Ceph rados block storage
# using the native kernel driver or librbd. This includes some extras for integration
# with nova/libvirt/qemu
class profile::cloudceph::client::rbd_libvirt(
    Boolean                    $enable_v2_messenger       = lookup('profile::cloudceph::client::rbd::enable_v2_messenger'),
    Hash[String,Hash]          $mon_hosts                 = lookup('profile::cloudceph::mon::hosts'),
    Hash[String,Hash]          $osd_hosts                 = lookup('profile::cloudceph::osd::hosts'),
    Array[Stdlib::IP::Address] $cluster_networks          = lookup('profile::cloudceph::cluster_networks'),
    Array[Stdlib::IP::Address] $public_networks           = lookup('profile::cloudceph::public_networks'),
    Stdlib::Unixpath           $data_dir                  = lookup('profile::cloudceph::data_dir'),
    String                     $client_name               = lookup('profile::cloudceph::client::rbd::client_name'),
    String                     $cinder_client_name        = lookup('profile::cloudceph::client::rbd::cinder_client_name'),
    String                     $fsid                      = lookup('profile::cloudceph::fsid'),
    String                     $libvirt_rbd_uuid          = lookup('profile::cloudceph::client::rbd::libvirt_rbd_uuid'),
    String                     $libvirt_rbd_cinder_uuid   = lookup('profile::cloudceph::client::rbd::libvirt_rbd_cinder_uuid'),
    String                     $ceph_repository_component = lookup('profile::cloudceph::ceph_repository_component'),
    Ceph::Auth::Conf           $ceph_auth_conf            = lookup('profile::cloudceph::auth::deploy::configuration'),
) {

    class { 'ceph::common':
        home_dir                  => $data_dir,
        ceph_repository_component => $ceph_repository_component,
    }

    class { 'ceph::config':
        cluster_networks    => $cluster_networks,
        enable_libvirt_rbd  => true,
        enable_v2_messenger => $enable_v2_messenger,
        fsid                => $fsid,
        mon_hosts           => $mon_hosts,
        public_networks     => $public_networks,
    }

    if ! $ceph_auth_conf[$client_name] {
        fail("missing '${client_name}' in ceph auth configuration")
    }
    if ! $ceph_auth_conf[$client_name]['keydata'] {
        fail("missing '${client_name}' keydata in ceph auth configuration")
    }

    openstack::nova::libvirt::secret { 'nova-compute':
        keydata      => $ceph_auth_conf[$client_name]['keydata'],
        client_name  => $client_name,
        libvirt_uuid => $libvirt_rbd_uuid,
    }

    if ! $ceph_auth_conf[$cinder_client_name] {
        fail("missing '${cinder_client_name}' in ceph auth configuration")
    }
    if ! $ceph_auth_conf[$cinder_client_name]['keydata'] {
        fail("missing '${cinder_client_name}' keydata in ceph auth configuration")
    }

    openstack::nova::libvirt::secret { 'nova-compute-cinder':
        keydata      => $ceph_auth_conf[$cinder_client_name]['keydata'],
        client_name  => $cinder_client_name,
        libvirt_uuid => $libvirt_rbd_cinder_uuid,
    }

    $mon_host_ips = $mon_hosts.reduce({}) | $memo, $value | {
        $memo + {$value[0] => $value[1]['public']['addr'] }
    }
    $osd_public_host_ips = $osd_hosts.reduce({}) | $memo, $value | {
        $memo + {$value[0] => $value[1]['public']['addr'] }
    }
    class { 'prometheus::node_pinger':
        nodes_to_ping_regular_mtu => $mon_host_ips + $osd_public_host_ips,
    }
}
