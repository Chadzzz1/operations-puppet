# == Class role::analytics_cluster::coordinator
#
# This role includes Oozie and Hive servers, as well as a MySQL instance
# that stores meta data associated with those and other
# Analytics Cluster services.
#
# This role is a launch pad for various cron based Hadoop jobs.
# Many ingestion jobs need a starting point.  Oozie is a great
# Hadoop job scheduler, but it is not better than cron
# for some jobs that need to be launched at regular time
# intervals.  Cron is used for those.  These crons
# do not use local resources, instead, they launch
# Hadoop jobs that run throughout the cluster.
#
# This roles sets up a node responsible to coordinate and orchestrate
# a Hadoop cluster equipped with tools like Camus, Hive, Oozie and
# the Analytics Refinery.
#
class role::analytics_cluster::coordinator {

    system::role { 'analytics_cluster::coordinator':
        description => 'Analytics Cluster host running various Hadoop services (Hive, Camus, Oozie, ..) and maintenance scripts'
    }

    include ::profile::analytics::cluster::gitconfig

    include ::profile::analytics::cluster::client
    include ::profile::analytics::database::meta

    # This is a Hadoop client, and should
    # have any special analytics system users on it
    # for interacting with HDFS.
    include ::profile::analytics::cluster::users

    # Back up analytics-meta MySQL instance
    # to an-master1002.
    include ::profile::analytics::database::meta::backup

    # SQL-like queries to data stored in HDFS
    include ::profile::hive::metastore
    include ::profile::hive::server
    include ::profile::hive::metastore::database

    # (Faster) SQL-like queries to data stored in HDFS and elsewhere
    # coordinator only runs the Presto server as a coordinator process.
    # The actual workers are configured in the presto::server role.
    # This node is marked as a coordinator in hiera.
    include ::profile::presto::server

    # The Hadoop job scheduler
    include ::profile::oozie::server
    include ::profile::oozie::server::database

    # Include a cron job to run hdfs balancer.
    include ::profile::hadoop::balancer

    # Various crons that launch Hadoop jobs.
    include ::profile::analytics::refinery
    include ::profile::analytics::cluster::repositories::statistics

    # Camus crons import data into
    # from Kafka into HDFS.
    include ::profile::analytics::refinery::job::camus
    include ::profile::analytics::refinery::job::data_check
    include ::profile::analytics::refinery::job::data_purge
    include ::profile::analytics::refinery::job::druid_load
    include ::profile::analytics::refinery::job::project_namespace_map
    include ::profile::analytics::refinery::job::sqoop_mediawiki
    include ::profile::analytics::refinery::job::refine

    # Include a cron to clean HDFS /tmp dir.
    include ::profile::analytics::refinery::job::hdfs_cleaner

    include ::profile::kerberos::keytabs

    include ::profile::standard
    include ::profile::base::firewall
}
