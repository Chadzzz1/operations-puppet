# == Class profile::hadoop::common
#
# Configures Hadoop common configuration, the baseline for all the other
# services/daemons/clients. This includes the Hadoop client packages as well.
# The main goal of this profile is to keep all the Hadoop cluster daemons/clients
# in sync with one single configuration.
#
# This profile uses some defaults that are good for a generic use case, like
# testing in labs, but probably not for production.
#
# == Parameters
#
#  [*zookeeper_clusters*]
#    List of available/configured Zookeeper clusters and their properties.
#
#  [*hadoop_clusters*]
#    List of available/configured Hadoop clusters and their properties.
#
#  [*hadoop_cluster_name*]
#    The Hadoop cluster name to pick up config properties from.
#    Default: 'cdh'
#
#  [*config_override*]
#    Hash of Hadoop properties that override the ones defined in the
#    hadoop_clusters's variable configuration.
#    Default: {}
#
# == Hadoop properties
#
#  These properties can be added to either hadoop_clusters or config_override's
#  hashes, and they configure specific Hadoop functionality.
#
#  [*zookeeper_cluster_name*]
#    The zookeeper cluster name to use.
#
#  [*resourcemanager_hosts*]
#    List of hostnames acting as Yarn Resource Managers for the cluster.
#
#  [*cluster_name*]
#    Name of the Hadoop cluster.
#
#  [*namenode_hosts*]
#    List of hostnames acting as HDFS Namenodes for the cluster.
#
#  [*journalnode_hosts*]
#    List of hostnames acting as HDFS Journalnodes for the cluster.
#
#  [*datanode_mounts*]
#    List of file system partitions to use on each Hadoop worker for HDFS.
#    Default: undef
#
#  [*datanode_volumes_failed_tolerated*]
#    Number of disk/volume failures tolerated by the datanode before
#    shutting down.
#    Default: undef
#
#  [*hdfs_trash_checkpoint_interval*]
#    Number of minutes to wait before creating a trash checkpoint directory
#    in each home directory.
#    Default: undef
#
#  [*hdfs_trash_interval*]
#    Number of minutes to wait before considering a trash checkpoint stale/old
#    and hence eligible for deletion. This parameter enables the HDFS trash
#    functionality even without setting hdfs_trash_checkpoint_interval, but
#    keep in mind that its default value for hadoop will be 0 (every time the
#    checkpointer runs it creates a new checkpoint out of current and removes
#    checkpoints created more than hdfs_trash_interval minutes ago).
#    Default: undef
#
#  [*mapreduce_reduce_shuffle_parallelcopies*]
#    Map-reduce specific setting.
#    Default: undef
#
#  [*mapreduce_task_io_sort_mb*]
#    Map-reduce specific setting.
#    Default: undef
#
#  [*mapreduce_task_io_sort_factor*]
#    Map-reduce specific setting.
#    Default: undef
#
#  [*mapreduce_map_memory_mb*]
#    Map container reserved memory.
#    Default: undef
#
#  [*mapreduce_map_java_opts*]
#    Map container JVM ops settings.
#    Default: undef
#
#  [*mapreduce_reduce_memory_mb*]
#    Reduce container reserved memory.
#    Default: undef
#
#  [*mapreduce_reduce_java_opts*]
#    Reduce container JVM ops settings.
#    Default: undef
#
#  [*yarn_heapsize*]
#    Yarn Node and Resource Manager max heap size.
#    Default: undef
#
#  [*yarn_nodemanager_opts*]
#    Yarn Node Manager JVM opts.
#    Default: undef
#
#  [*yarn_resourcemanager_opts*]
#    Yarn Resource Manager JVM opts.
#    Default: undef
#
#  [*hadoop_heapsize*]
#    HDFS daemons maximum heapsize.
#    Default: undef
#
#  [*hadoop_datanode_opts*]
#    HDFS datanode JVM opts.
#    Default: undef
#
#  [*hadoop_journalnode_opts*]
#    HDFS journalnode JVM opts.
#    Default: undef
#
#  [*hadoop_namenode_opts*]
#    JVM opts to pass to the HDFS Namenode daemon.
#    If you change these values please check profile::hadoop::*::namenode_heapsize
#    since some alarms need to be tuned in the master/standby config too.
#    Default: undef
#
#  [*yarn_app_mapreduce_am_resource_mb*]
#    Yarn Application Master container size (Mb).
#    Default: undef
#
#  [*yarn_app_mapreduce_am_command_opts*]
#    Yarn Application Master JVM opts.
#    Default: undef
#
#  [*mapreduce_history_java_opts*]
#    Map-reduce History server JVM opts.
#    Default: undef
#
#  [*yarn_scheduler_minimum_allocation_vcores*]
#    Yarn scheduler specific setting.
#    Default: undef
#
#  [*yarn_scheduler_maximum_allocation_vcores*]
#    Yarn scheduler specific setting.
#    Default: undef
#
#  [*yarn_nodemanager_os_reserved_memory_mb*]
#    Map-reduce specific setting. If set, yarn_nodemanager_resource_memory_mb will
#    be set as total_memory_on_host - yarn_nodemanager_os_reserved_memory_mb.
#    Default: undef
#
#  [*yarn_scheduler_minimum_allocation_mb*]
#    Yarn scheduler specific setting.
#    Default: undef
#
#  [*yarn_scheduler_maximum_allocation_mb*]
#    Yarn scheduler specific setting.  If not set, but reserved_memory_mb and total_memory_mb are,
#    This will be set to total_memory_mb - reserved_memory_mb.
#    Default: undef
#
#  [*java_home*]
#    Sets the JAVA_HOME env. variable in hadoop-env.sh
#
#  [*net_topology*]
#    A mapping of FQDN hostname to 'rack'.  This will be used by net-topology.py.erb
#    to render a script that will be used for Hadoop node rack awareness.
#
class profile::hadoop::common (
    $zookeeper_clusters = hiera('zookeeper_clusters'),
    $hadoop_clusters    = hiera('hadoop_clusters'),
    $cluster_name       = hiera('profile::hadoop::common::hadoop_cluster_name'),
    $config_override    = hiera('profile::hadoop::common::config_override', {}),
) {

    # Properties that are not meant to have undef as default value (a hash key
    # without a correspondent value returns undef) should be listed in here.
    $hadoop_default_config = {
        'java_home'    => '/usr/lib/jvm/java-8-openjdk-amd64/jre',

    }

    # The final Hadoop configuration is obtained merging three hashes:
    # 1) Hadoop properties with a default value different than undef
    # 2) Hadoop properies meant to be shared among all Hadoop daemons/services
    # 3) Hadoop properties that might get overridden by specific Hadoop role/profiles.
    $hadoop_config = $hadoop_default_config + $hadoop_clusters[$cluster_name] + $config_override

    $zookeeper_cluster_name                   = $hadoop_config['zookeeper_cluster_name']
    $yarn_resourcemanager_zk_timeout_ms       = $hadoop_config['yarn_resourcemanager_zk_timeout_ms']
    $resourcemanager_hosts                    = $hadoop_config['resourcemanager_hosts']
    $namenode_hosts                           = $hadoop_config['namenode_hosts']
    $journalnode_hosts                        = $hadoop_config['journalnode_hosts']
    $datanode_mounts                          = $hadoop_config['datanode_mounts']
    $datanode_volumes_failed_tolerated        = $hadoop_config['datanode_volumes_failed_tolerated']
    $hdfs_trash_checkpoint_interval           = $hadoop_config['hdfs_trash_checkpoint_interval']
    $hdfs_trash_interval                      = $hadoop_config['hdfs_trash_interval']
    $mapreduce_reduce_shuffle_parallelcopies  = $hadoop_config['mapreduce_reduce_shuffle_parallelcopies']
    $mapreduce_task_io_sort_mb                = $hadoop_config['mapreduce_task_io_sort_mb']
    $mapreduce_task_io_sort_factor            = $hadoop_config['mapreduce_task_io_sort_factor']
    $mapreduce_map_memory_mb                  = $hadoop_config['mapreduce_map_memory_mb']
    $mapreduce_map_java_opts                  = $hadoop_config['mapreduce_map_java_opts']
    $mapreduce_reduce_memory_mb               = $hadoop_config['mapreduce_reduce_memory_mb']
    $mapreduce_reduce_java_opts               = $hadoop_config['mapreduce_reduce_java_opts']
    $yarn_heapsize                            = $hadoop_config['yarn_heapsize']
    $yarn_nodemanager_opts                    = $hadoop_config['yarn_nodemanager_opts']
    $yarn_resourcemanager_opts                = $hadoop_config['yarn_resourcemanager_opts']
    $hadoop_heapsize                          = $hadoop_config['hadoop_heapsize']
    $hadoop_datanode_opts                     = $hadoop_config['hadoop_datanode_opts']
    $hadoop_journalnode_opts                  = $hadoop_config['hadoop_journalnode_opts']
    $hadoop_namenode_opts                     = $hadoop_config['hadoop_namenode_opts']
    $yarn_app_mapreduce_am_resource_mb        = $hadoop_config['yarn_app_mapreduce_am_resource_mb']
    $yarn_app_mapreduce_am_command_opts       = $hadoop_config['yarn_app_mapreduce_am_command_opts']
    $mapreduce_history_java_opts              = $hadoop_config['mapreduce_history_java_opts']
    $yarn_scheduler_minimum_allocation_vcores = $hadoop_config['yarn_scheduler_minimum_allocation_vcores']
    $yarn_scheduler_maximum_allocation_vcores = $hadoop_config['yarn_scheduler_maximum_allocation_vcores']
    $yarn_nodemanager_resource_memory_mb      = $hadoop_config['yarn_nodemanager_os_reserved_memory_mb'] ? {
            undef   => undef,
            default => floor($facts['memorysize_mb']) - $hadoop_config['yarn_nodemanager_os_reserved_memory_mb'],
    }
    $yarn_scheduler_minimum_allocation_mb     = $hadoop_config['yarn_scheduler_minimum_allocation_mb']
    $yarn_scheduler_maximum_allocation_mb     = $hadoop_config['yarn_scheduler_maximum_allocation_mb']
    $java_home                                = $hadoop_config['java_home']
    $core_site_extra_properties               = $hadoop_config['core_site_extra_properties'] ? {
        undef   => {},
        default => $hadoop_config['core_site_extra_properties'],
    }
    $yarn_site_extra_properties               = $hadoop_config['yarn_site_extra_properties'] ? {
        undef   => {},
        default => $hadoop_config['yarn_site_extra_properties'],
    }
    $hdfs_site_extra_properties               = $hadoop_config['hdfs_site_extra_properties'] ? {
        undef   => {},
        default => $hadoop_config['hdfs_site_extra_properties'],
    }
    $mapred_site_extra_properties             = $hadoop_config['mapred_site_extra_properties'] ? {
        undef   => {},
        default => $hadoop_config['mapred_site_extra_properties'],
    }
    $ssl_server_config                        = $hadoop_config['ssl_server_config']
    $ssl_client_config                        = $hadoop_config['ssl_client_config']
    $yarn_nm_container_executor_config        = $hadoop_config['yarn_nodemanager_container_executor_config']

    # Include Wikimedia's thirdparty/cloudera apt component
    # as an apt source on all Hadoop hosts.  This is needed
    # to install CDH packages from our apt repo mirror.
    require ::profile::cdh::apt

    # Need Java before Hadoop is installed.
    require ::profile::java::analytics

    # Force apt-get update to run before we try to install packages.
    # CDH Packages are in the thirdparty/cloudera apt component,
    # and are made available by profile::cdh::apt.
    Class['::profile::cdh::apt'] -> Exec['apt-get update'] -> Class['::cdh::hadoop']

    $hadoop_var_directory                     = '/var/lib/hadoop'
    $hadoop_name_directory                    = "${hadoop_var_directory}/name"
    $hadoop_data_directory                    = "${hadoop_var_directory}/data"
    $hadoop_journal_directory                 = "${hadoop_var_directory}/journal"

    $zookeeper_hosts = keys($zookeeper_clusters[$zookeeper_cluster_name]['hosts'])

    # If specified, this will be rendered into the net-topology.py.erb script.
    $net_topology = $hadoop_config['net_topology']
    $net_topology_script_content = $net_topology ? {
        undef   => undef,
        default => template('profile/hadoop/net-topology.py.erb'),
    }

    $core_site_extra_properties_default = {
        # Allow superset running as 'superset' user on thorium.eqiad.wmnet
        # to run jobs as users in the analytics-users and analytics-privatedata-users groups.
        'hadoop.proxyusers.superset.hosts'  => 'thorium.eqiad.wmnet',
        'hadoop.proxyusers.superset.groups' => 'analytics-users,analytics-privatedata-users',
    }

    $yarn_site_extra_properties_default = {
        # Enable FairScheduler preemption. This will allow the essential queue
        # to preempt non-essential jobs.
        'yarn.scheduler.fair.preemption'                                                => true,
        # Let YARN wait for at least 1/3 of nodes to present scheduling
        # opportunties before scheduling a job for certain data
        # on a node on which that data is not present.
        'yarn.scheduler.fair.locality.threshold.node'                                   => '0.33',
        # After upgrading to CDH 5.4.0, we are encountering this bug:
        # https://issues.apache.org/jira/browse/MAPREDUCE-5799
        # This should work around the problem.
        'yarn.app.mapreduce.am.env'                                                     => 'LD_LIBRARY_PATH=/usr/lib/hadoop/lib/native',
        # The default of 90.0 for this was marking older dells as unhealthy when they still
        # had 2TB of space left.  99% will mark them at unhealthy with they still have
        # > 200G free.
        'yarn.nodemanager.disk-health-checker.max-disk-utilization-per-disk-percentage' => '99.0',
    }

    $hdfs_site_extra_properties_default = {}
    $mapred_site_extra_properties_default = {}

    class { '::cdh::hadoop':
        # Default to using running resourcemanager on the same hosts
        # as the namenodes.
        resourcemanager_hosts                       => $resourcemanager_hosts,
        zookeeper_hosts                             => $zookeeper_hosts,
        yarn_resourcemanager_zk_timeout_ms          => $yarn_resourcemanager_zk_timeout_ms,
        dfs_name_dir                                => [$hadoop_name_directory],
        dfs_journalnode_edits_dir                   => $hadoop_journal_directory,
        dfs_datanode_failed_volumes_tolerated       => $datanode_volumes_failed_tolerated,
        fs_trash_checkpoint_interval                => $hdfs_trash_checkpoint_interval,
        fs_trash_interval                           => $hdfs_trash_interval,

        cluster_name                                => $cluster_name,
        namenode_hosts                              => $namenode_hosts,
        journalnode_hosts                           => $journalnode_hosts,

        datanode_mounts                             => $datanode_mounts,

        yarn_heapsize                               => $yarn_heapsize,
        hadoop_heapsize                             => $hadoop_heapsize,

        yarn_nodemanager_opts                       => $yarn_nodemanager_opts,
        yarn_resourcemanager_opts                   => $yarn_resourcemanager_opts,
        hadoop_namenode_opts                        => $hadoop_namenode_opts,
        hadoop_datanode_opts                        => $hadoop_datanode_opts,
        hadoop_journalnode_opts                     => $hadoop_journalnode_opts,
        mapreduce_history_java_opts                 => $mapreduce_history_java_opts,

        yarn_app_mapreduce_am_resource_mb           => $yarn_app_mapreduce_am_resource_mb,
        yarn_app_mapreduce_am_command_opts          => $yarn_app_mapreduce_am_command_opts,
        yarn_nodemanager_resource_memory_mb         => $yarn_nodemanager_resource_memory_mb,
        yarn_scheduler_minimum_allocation_mb        => $yarn_scheduler_minimum_allocation_mb,
        yarn_scheduler_maximum_allocation_mb        => $yarn_scheduler_maximum_allocation_mb,
        yarn_scheduler_minimum_allocation_vcores    => $yarn_scheduler_minimum_allocation_vcores,
        yarn_scheduler_maximum_allocation_vcores    => $yarn_scheduler_maximum_allocation_vcores,

        dfs_block_size                              => 268435456, # 256 MB
        io_file_buffer_size                         => 131072,

        # Turn on Snappy compression by default for maps and final outputs
        mapreduce_intermediate_compression_codec    => 'org.apache.hadoop.io.compress.SnappyCodec',
        mapreduce_output_compression                => true,
        mapreduce_output_compression_codec          => 'org.apache.hadoop.io.compress.SnappyCodec',
        mapreduce_output_compression_type           => 'BLOCK',

        mapreduce_job_reuse_jvm_num_tasks           => 1,

        mapreduce_reduce_shuffle_parallelcopies     => $mapreduce_reduce_shuffle_parallelcopies,
        mapreduce_task_io_sort_mb                   => $mapreduce_task_io_sort_mb,
        mapreduce_task_io_sort_factor               => $mapreduce_task_io_sort_factor,
        mapreduce_map_memory_mb                     => $mapreduce_map_memory_mb,
        mapreduce_map_java_opts                     => $mapreduce_map_java_opts,
        mapreduce_reduce_memory_mb                  => $mapreduce_reduce_memory_mb,
        mapreduce_reduce_java_opts                  => $mapreduce_reduce_java_opts,

        net_topology_script_content                 => $net_topology_script_content,

        # This needs to be set in order to use Impala
        dfs_datanode_hdfs_blocks_metadata_enabled   => true,

        # Use fair-scheduler.xml.erb to define FairScheduler queues.
        fair_scheduler_template                     => 'profile/hadoop/fair-scheduler.xml.erb',

        # Yarn App Master possible port ranges
        yarn_app_mapreduce_am_job_client_port_range => '55000-55199',

        core_site_extra_properties                  => $core_site_extra_properties_default + $core_site_extra_properties,
        yarn_site_extra_properties                  => $yarn_site_extra_properties_default + $yarn_site_extra_properties,
        hdfs_site_extra_properties                  => $hdfs_site_extra_properties_default + $hdfs_site_extra_properties,
        mapred_site_extra_properties                => $mapred_site_extra_properties_default + $mapred_site_extra_properties,

        ssl_client_config                           => $ssl_client_config,
        ssl_server_config                           => $ssl_server_config,

        yarn_nodemanager_container_executor_config  => $yarn_nm_container_executor_config,

        java_home                                   => $java_home,
    }


    if $::realm == 'labs' {
        # Hadoop directories in labs should be created by puppet.
        # This conditional could be added to each worker,master,standby
        # classes, but since it doesn't hurt to have these directories
        # in labs, and since I don't want to add the $::realm conditionals
        # in each class, I do it here.
        file { [
            $hadoop_var_directory,
            $hadoop_data_directory,
        ]:
            ensure => 'directory',
            before => Class['cdh::hadoop'],
        }
    }
}
