# == Class role::analytics_cluster::hadoop::worker
#
# filtertags: labs-project-analytics labs-project-math
class role::analytics_cluster::hadoop::worker {
    system::role { 'analytics_cluster::hadoop::worker':
        description => 'Hadoop Worker (DataNode & NodeManager)',
    }

    include ::profile::java
    include ::profile::hadoop::worker
    include ::profile::amd_gpu
    include ::profile::analytics::cluster::users
    include ::profile::kerberos::client
    include ::profile::kerberos::keytabs
    include ::profile::base::firewall
    include ::profile::standard
}
