# SPDX-License-Identifier: Apache-2.0
# == Class profile::analytics::refinery::job::import_commons_mediainfo_dumps
# Schedules imports of commons mediainfo dumps (ttl) to hadoop.
#
# NOTE: This class assumes the xmldatadumps folder under which public dumps
# can be found is mounted under /mnt/data, and that hdfs-rsync is installed
#

class profile::analytics::refinery::job::import_commons_mediainfo_dumps (
    Wmflib::Ensure $ensure_timers = lookup('profile::analytics::refinery::job::import_commons_mediainfo_dumps::ensure_timers', { 'default_value' => 'present' }),
) {

    $mediainfo_local_source = '/mnt/data/xmldatadumps/public/other/wikibase/commonswiki/'
    # Import mediainfo-ttl dumps
    profile::analytics::refinery::job::import_wikibase_dumps_config { 'refinery-import-commons-mediainfo-ttl-dumps':
        ensure            => $ensure_timers,
        include_pattern   => '/*/*-mediainfo.ttl.bz2',
        local_source      => $mediainfo_local_source,
        hdfs_destination  => '/wmf/data/raw/commons/dumps/mediainfo-ttl',
        timer_description => 'Schedules daily an hdfs-rsync of the commons mediainfo-ttl dumps into HDFS',
        timer_interval    => '*-*-* 02:30:00',
    }

    # Import mediainfo-json dumps
    profile::analytics::refinery::job::import_wikibase_dumps_config { 'refinery-import-commons-mediainfo-json-dumps':
        ensure            => $ensure_timers,
        include_pattern   => '/*/*-mediainfo.json.bz2',
        local_source      => $mediainfo_local_source,
        hdfs_destination  => '/wmf/data/raw/commons/dumps/mediainfo-json',
        timer_description => 'Schedules daily an hdfs-rsync of the commons mediainfo-json dumps into HDFS',
        timer_interval    => '*-*-* 03:00:00',
    }
}
