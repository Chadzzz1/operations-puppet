# SPDX-License-Identifier: Apache-2.0
# @summary create the filesystems and mount points for swift storage
# @param swift_storage_dir the base directory for swift storage
class profile::swift::storage::configure_disks (
    Stdlib::Unixpath $swift_storage_dir = lookup('profile::swift::storage::configure_disks::swift_storage_dir'),
) {
    if !$facts.has_key('swift_disks') {
        fail('unable to find swift_disk fact')
    }
    ['accounts', 'container'].each |$storage_type| {
        unless $facts['swift_disks'][$storage_type].size == 2 {
            fail("Not enough ${storage_type} partitions")
        }
        $facts['swift_disks'][$storage_type].sort.each |$idx, $partition| {
            $partition_path = "/dev/disk/by-path/${partition}"
            $mount_point = "${swift_storage_dir}/${$storage_type}${idx}"
            swift::mount_filesystem { $partition_path:
                mount_point => $mount_point,
            }
        }
    }
    ensure_packages(['xfsprogs', 'parted'])

    # TODO: why start at 1M, copied from swift::init_device
    $parted_script = 'mklabel gpt mkpart primary 1M 100%'
    $facts['swift_disks']['objects'].each |$idx, $drive| {
        $device_path = "/dev/disk/by-path/${drive}"
        $partition_path = "${device_path}-part1"
        $swift_path = "${swift_storage_dir}/${drive}-part1"

        exec { "parted-${drive}":
            command => "/usr/sbin/parted --script --align optimal ${device_path} -- ${parted_script}",
            creates => $partition_path,
        }
        # rebuild everything to switch to this new way.
        exec { "mkfs-${drive}":
            # Disable free inode b-tree, see T199198
            command => "/usr/sbin/mkfs -t xfs -m crc=1 -m finobt=0 -i size=512 ${partition_path}",
            unless  => "/usr/sbin/blkid -o value -s TYPE ${partition_path} | /usr/bin/grep -qE '\\bxfs\\b'",
            require => [
                Package['xfsprogs'],
                Exec["parted-${drive}"],
            ],
        }
        $mount_point = "${swift_storage_dir}/objects${idx}"
        swift::mount_filesystem { $partition_path:
            mount_point => $mount_point,
            require     => Exec["mkfs-${drive}"],
        }
    }
}
