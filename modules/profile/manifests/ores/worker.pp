# SPDX-License-Identifier: Apache-2.0
class profile::ores::worker (
    Integer $celery_version = lookup('profile::ores::worker::celery_version', {'default_value' => 5 }),
) {
    require profile::ores::git

    class { '::ores::worker':
        celery_version => $celery_version,
    }
    class { '::profile::prometheus::statsd_exporter':
        relay_address => ''
    }
}
