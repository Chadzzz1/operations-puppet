# SPDX-License-Identifier: Apache-2.0
# == Class logster
# Installs logster package.
# Use logster::job to set up a systemd timer to tail a log file.
class logster {
    package { 'logster':
        ensure => 'installed',
    }
}
