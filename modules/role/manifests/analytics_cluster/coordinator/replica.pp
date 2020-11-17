# == Class role::analytics_cluster::coordinator::replica
#
class role::analytics_cluster::coordinator::replica {

    system::role { 'analytics_cluster::coordinator::replica':
        description => 'Analytics Cluster backup/replica host running various Hadoop services (Hive, Meta DB, etc..)'
    }

    include ::profile::analytics::cluster::gitconfig

    include ::profile::java

    include ::profile::analytics::cluster::client

    # This is a Hadoop client, and should
    # have any special analytics system users on it
    # for interacting with HDFS.
    include ::profile::analytics::cluster::users

    include ::profile::analytics::database::meta

    # SQL-like queries to data stored in HDFS
    # include ::profile::hive::metastore
    include ::profile::hive::server

    include ::profile::kerberos::client
    include ::profile::kerberos::keytabs

    include ::profile::standard
    include ::profile::base::firewall
}
