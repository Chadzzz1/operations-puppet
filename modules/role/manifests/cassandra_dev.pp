# SPDX-License-Identifier: Apache-2.0

# == Class role::cassandra_dev
#
# Configures the cassandra-dev cluster
class role::cassandra_dev {

    system::role { 'cassandra_dev':
        description => 'Development & test storage service'
    }

    include ::profile::base::firewall
    include ::profile::base::production
    include ::profile::cassandra_dev
    include ::profile::cassandra
}
