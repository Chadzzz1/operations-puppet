# vim: set tabstop=4 shiftwidth=4 softtabstop=4 expandtab textwidth=80 smarttab
# site.pp
# Base nodes

# Node definitions (alphabetic order)

# Ganeti VMs for acme-chief service
node 'acmechief1001.eqiad.wmnet' {
    role(acme_chief)
}

node 'acmechief2001.codfw.wmnet' {
    role(acme_chief)
}

# Ganeti VMs for acme-chief staging environment
node 'acmechief-test1001.eqiad.wmnet' {
    role(acme_chief)
}

node 'acmechief-test2001.codfw.wmnet' {
    role(acme_chief)
}

# The Hadoop master node:
# - primary active NameNode
# - YARN ResourceManager
node 'an-master1001.eqiad.wmnet' {
    role(analytics_cluster::hadoop::master)
}

# The Hadoop (stanby) master node:
# - primary active NameNode
# - YARN ResourceManager
node 'an-master1002.eqiad.wmnet' {
    role(analytics_cluster::hadoop::standby)
}

node 'an-coord1001.eqiad.wmnet' {
    role(analytics_cluster::coordinator)
}

node 'an-launcher1001.eqiad.wmnet' {
    role(analytics_cluster::launcher)
}

# analytics1028-analytics1040 are Hadoop worker nodes.
# These hosts are OOW but they are used as temporary
# Hadoop testing cluster for T211836.
#
# Hadoop Test cluster's master
node 'analytics1028.eqiad.wmnet' {
    role(analytics_test_cluster::hadoop::master)
}

# Hadoop Test cluster's standby master
node 'analytics1029.eqiad.wmnet' {
    role(analytics_test_cluster::hadoop::standby)
}

# Hadoop Test cluster's coordinator
node 'analytics1030.eqiad.wmnet' {
    role(analytics_test_cluster::coordinator)
}

# Hadoop Test cluster's workers
node /analytics10(31|3[3-8]|40).eqiad.wmnet/ {
    role(analytics_test_cluster::hadoop::worker)
}

# Hadoop Test cluster's UIs
node 'analytics1039.eqiad.wmnet' {
    role(analytics_test_cluster::hadoop::ui)
}

# Druid Analytics Test cluster
node 'analytics1041.eqiad.wmnet' {
    role(druid::test_analytics::worker)
}

# analytics1042-analytics1077 are Analytics Hadoop worker nodes.
#
# NOTE:  If you add, remove or move Hadoop nodes, you should edit
# hieradata/common.yaml hadoop_clusters net_topology
# to make sure the hostname -> /datacenter/rack/row id is correct.
# This is used for Hadoop network topology awareness.
node /analytics10(4[2-9]|5[0-9]|6[0-9]|7[0-7]).eqiad.wmnet/ {
    role(analytics_cluster::hadoop::worker)
}

# an-worker1078-1095 are new Hadoop worker nodes.
# T207192
node /an-worker10(7[89]|8[0-9]|9[0-5]).eqiad.wmnet/ {
    role(analytics_cluster::hadoop::worker)
}

# hue.wikimedia.org, yarn.wikimedia.org
node 'analytics-tool1001.eqiad.wmnet' {
    role(analytics_cluster::hadoop::ui)
}

# superset.wikimedia.org
# https://wikitech.wikimedia.org/wiki/Analytics/Systems/Superset
# T212243
node 'analytics-tool1004.eqiad.wmnet' {
    role(analytics_cluster::superset)
}

# Staging environment of superset.wikimedia.org
# https://wikitech.wikimedia.org/wiki/Analytics/Systems/Superset
# T212243
node 'an-tool1005.eqiad.wmnet' {
    role(analytics_cluster::superset::staging)
}

# Analytics Hadoop client for the Testing cluster
# T226844
node 'an-tool1006.eqiad.wmnet' {
    role(analytics_test_cluster::client)
}

# turnilo.wikimedia.org
# https://wikitech.wikimedia.org/wiki/Analytics/Systems/Turnilo-Pivot
node 'an-tool1007.eqiad.wmnet' {
    role(analytics_cluster::turnilo)
}

# Analytics/Search instance of Apache Airflow
node 'an-airflow1001.eqiad.wmnet' {
    role(search::airflow)
}

# New Analytics Zookepeer cluster - T227025
# Not yet taking traffic for the Hadoop cluster.
node /an-conf100[1-3]\.eqiad\.wmnet/ {
    role(analytics_cluster::zookeeper)
}


# Analytics Presto nodes.
node /^an-presto100[1-5]\.eqiad\.wmnet$/ {
    role(analytics_cluster::presto::server)
}

# new APT repositories (NOT DHCP/TFTP)
node /^apt[12]001\.wikimedia\.org/ {
    role(apt_repo)
}

# Analytics Query Service
node /aqs100[456789]\.eqiad\.wmnet/ {
    role(aqs)
}

# New Archiva host (replacement of meitnerium).
# T192639
node 'archiva1001.wikimedia.org' {
    role(archiva)
}

node 'auth1002.eqiad.wmnet' {
    role(test)
}

node 'auth2001.codfw.wmnet' {
    role(test)
}

node /^authdns[12]001\.wikimedia\.org$/ {
    role(dns::auth)
}

# Primary bacula director and storage daemon
node 'backup1001.eqiad.wmnet' {
    role(backup)
}
# eqiad storage daemon and backup generation for ES databases
node 'backup1002.eqiad.wmnet' {
    role(mariadb::content_backups)
}

# codfw storage daemon
node 'backup2001.codfw.wmnet' {
    role(backup::offsite)
}
# codfw storage daemon and backup generation for ES databases
node 'backup2002.codfw.wmnet' {
    role(mariadb::content_backups)
}

# Bastion in Virginia
node 'bast1002.wikimedia.org' {
    role(bastionhost::general)

}

# Bastion in Texas - (T196665, replaced bast2001)
node 'bast2002.wikimedia.org' {
    role(bastionhost::general)

}

# Bastion in the Netherlands (replaced bast3002)
node 'bast3004.wikimedia.org' {
    role(bastionhost::pop)
}

# Bastion in California
node 'bast4002.wikimedia.org' {
    role(bastionhost::pop)

}

node 'bast5001.wikimedia.org' {
    role(bastionhost::pop)

}

node 'centrallog1001.eqiad.wmnet', 'centrallog2001.codfw.wmnet' {
    role(syslog::centralserver)
}

# system for censorship monitoring scripts (T239250)
node 'cescout1001.eqiad.wmnet' {
    role(cescout)
}

node /^cloudceph200[123]-dev\.wikimedia\.org/ {
    role(insetup)
}

node /^cloudstore100[89]\.wikimedia\.org/ {
    role(wmcs::nfs::secondary)
}

# All gerrit servers (swap master status in hiera)
node 'gerrit1001.wikimedia.org', 'gerrit2001.wikimedia.org' {
    role(gerrit)
}

# temp. Gerrit machine for testing 2.16 upgrade (T239151)
node 'gerrit1002.wikimedia.org' {
    role(gerrit)
}

# Zookeeper and Etcd discovery service nodes in eqiad
node /^conf100[456]\.eqiad\.wmnet$/ {
    role(configcluster_stretch)
}

# Zookeeper and Etcd discovery service nodes in codfw
node /^conf200[123]\.codfw\.wmnet$/ {
    role(configcluster)
}

# CI master / CI standby (switch in Hiera)
node /^(contint1001|contint2001)\.wikimedia\.org$/ {
    role(ci::master)

}

node /^cp10(7[579]|8[13579])\.eqiad\.wmnet$/ {
    role(cache::text)
}

node /^cp10(7[68]|8[02468]|90)\.eqiad\.wmnet$/ {
    role(cache::upload)
}

node /^cp20(2[79]|3[13579]|41)\.codfw\.wmnet$/ {
    role(cache::text)
}

node /^cp20(28|3[02468]|4[02])\.codfw\.wmnet$/ {
    role(cache::upload)
}

# Actual spares for now, in case of need for cp cluster before next
# procurements arrive
node /^cp20(0[39]|15|21)\.codfw\.wmnet$/ {
    role(test)
}

#
# esams caches
#

node /^cp30(5[02468]|6[024])\.esams\.wmnet$/ {
    role(cache::text)
}

node /^cp30(5[13579]|6[135])\.esams\.wmnet$/ {
    role(cache::upload)
}

#
# ulsfo caches
#

node /^cp402[1-6]\.ulsfo\.wmnet$/ {
    role(cache::upload)
}

node /^cp40(2[789]|3[012])\.ulsfo\.wmnet$/ {
    role(cache::text)
}

#
# eqsin caches
#

node /^cp500[1-6]\.eqsin\.wmnet$/ {
    role(cache::upload)
}

node /^cp50(0[789]|1[012])\.eqsin\.wmnet$/ {
    role(cache::text)
}

node /^cumin[12]001\.(eqiad|codfw)\.wmnet$/ {
    role(cluster::management)
}

# MariaDB 10

# s1 (enwiki) core production dbs on eqiad
# eqiad master
node 'db1083.eqiad.wmnet' {
    role(mariadb::core)
}
# eqiad replicas
# See also db1099 and db1105 below
node /^db1(080|089|106|107|118|119|134)\.eqiad\.wmnet/ {
    role(mariadb::core)
}

# s1 (enwiki) core production dbs on codfw
# codfw master
node 'db2112.codfw.wmnet' {
    role(mariadb::core)
}

# codfw replicas
# See also db2085 and db2088 below
node /^db2(071|072|092|103|116|130)\.codfw\.wmnet/ {
    role(mariadb::core)
}

# s2 (large wikis) core production dbs on eqiad
# eqiad master
node 'db1122.eqiad.wmnet' {
    role(mariadb::core)
}

# eqiad replicas
# See also db1090, db1103, db1105, db1146 below
node /^db1(074|076|129)\.eqiad\.wmnet/ {
    role(mariadb::core)
}

# s2 (large wikis) core production dbs on codfw
# codfw master
node 'db2107.codfw.wmnet' {
    role(mariadb::core)
}

# codfw replicas
# See also db2088, db2091 and db2138 below
node /^db2(104|108|125|126)\.codfw\.wmnet/ {
    role(mariadb::core)
}

# s3 (default) core production dbs on eqiad
# Lots of tables!
# eqiad master
node 'db1123.eqiad.wmnet' {
    role(mariadb::core)
}

# eqiad replicas
node /^db1(075|078|112)\.eqiad\.wmnet/ {
    role(mariadb::core)
}

# s3 (default) core production dbs on codfw
# codfw master
node 'db2105.codfw.wmnet' {
    role(mariadb::core)
}

# codfw replicas
node /^db2(074|109|127)\.codfw\.wmnet/ {
    role(mariadb::core)
}

# s4 (commons) core production dbs on eqiad
# eqiad master
node 'db1081.eqiad.wmnet' {
    role(mariadb::core)
}

# eqiad replicas
# See also db1097, db1103, db1144 and db1146 below
node /^db1(084|091|121|138|142|143|147|149)\.eqiad\.wmnet/ {
    role(mariadb::core)
}

# s4-test hosts on eqiad
node /^db1(077)\.eqiad\.wmnet/ {
    role(mariadb::core_test)
}

# s4 (commons) core production dbs on codfw
# codfw master
node 'db2090.codfw.wmnet' {
    role(mariadb::core)
}

# replacement codfw master T252985
node 'db2140.codfw.wmnet' {
    role(mariadb::core)
}

# codfw replicas
# See also db2084, db2091, db2137 and db2138 below
node /^db2(073|106|110|119|136)\.codfw\.wmnet/ {
    role(mariadb::core)
}

# s5 (dewiki and others) core production dbs on eqiad
# eqiad master
node 'db1100.eqiad.wmnet' {
    role(mariadb::core)
}

# eqiad replicas
# See also db1096, db1097, db1113 and db1144 below
node /^db1(082|110|130)\.eqiad\.wmnet/ {
    role(mariadb::core)
}

# s5 (dewiki and others) core production dbs on codfw
# codfw master
node 'db2123.codfw.wmnet' {
    role(mariadb::core)
}

# codfw replicas
# See also db2084, db2089 and db2137 below
node /^db2(075|111|113|128)\.codfw\.wmnet/ {
    role(mariadb::core)
}

# s6 core production dbs on eqiad
# eqiad master
node 'db1131.eqiad.wmnet' {
    role(mariadb::core)
}

# eqiad replicas
# See also db1096, db1098 and db1113 below
node /^db1(085|088|093)\.eqiad\.wmnet/ {
    role(mariadb::core)
}

# s6 core production dbs on codfw
# codfw master
node 'db2129.codfw.wmnet' {
    role(mariadb::core)
}

# codfw replicas
# See also db2087 and db2089 below
node /^db2(076|114|117|124)\.codfw\.wmnet/ {
    role(mariadb::core)
}

# s7 (centralauth, meta et al.) core production dbs on eqiad
# eqiad master
node 'db1086.eqiad.wmnet' {
    role(mariadb::core)
}

# eqiad replicas
# See also db1090, db1098 and db1101 below
node /^db1(069|079|094|136)\.eqiad\.wmnet/ {
    role(mariadb::core)
}

# s7 (centralauth, meta et al.) core production dbs on codfw
# codfw master
node 'db2118.codfw.wmnet' {
    role(mariadb::core)
}

# codfw replicas
# See also db2086 and db2087 below
node /^db2(077|120|121|122)\.codfw\.wmnet/ {
    role(mariadb::core)
}

# s8 (wikidata) core production dbs on eqiad
# eqiad master
node 'db1109.eqiad.wmnet' {
    role(mariadb::core)
}

# eqiad replicas
# See also db1099 and db1101 below
node /^db1(092|087|104|111|114|126)\.eqiad\.wmnet/ {
    role(mariadb::core)
}

# s8 (wikidata) core production dbs on codfw
# codfw master
node 'db2079.codfw.wmnet' {
    role(mariadb::core)
}

# codfw replicas
# See also db2085 and db2086 below
node /^db20(80|81|82|83)\.codfw\.wmnet/ {
    role(mariadb::core)
}

# hosts with multiple shards
node /^db1(090|096|097|098|099|101|103|105|113|144|146)\.eqiad\.wmnet/ {
    role(mariadb::core_multiinstance)
}
node /^db2(084|085|086|087|088|089|091|137|138)\.codfw\.wmnet/ {
    role(mariadb::core_multiinstance)
}

# eqiad replicas to be installed T251614
node /^db11(45|48)\.eqiad\.wmnet/ {
    role(spare::system)
}

## x1 shard
# eqiad
# x1 eqiad master
node 'db1120.eqiad.wmnet' {
    role(mariadb::core)
}

node 'db1127.eqiad.wmnet' {
    role(mariadb::core)
}

node 'db1137.eqiad.wmnet' {
    role(mariadb::core)
}



# codfw
# x1 codfw master
node 'db2096.codfw.wmnet' {
    role(mariadb::core)
}

# x1 codfw slaves
node /^db2(115|131)\.codfw\.wmnet/ {
    role(mariadb::core)
}

## m1 shard

# See also multiinstance misc hosts db1117 and db2078 below
node 'db1135.eqiad.wmnet' {
    class { '::role::mariadb::misc':
        shard  => 'm1',
        master => true,
    }
}

node 'db2132.codfw.wmnet' {
    class { '::role::mariadb::misc':
        shard  => 'm1',
    }
}

## m2 shard

# See also multiinstance misc hosts db1117 and db2078 below

node 'db1132.eqiad.wmnet' {
    class { '::role::mariadb::misc':
        shard  => 'm2',
        master => true,
    }
}

node 'db2133.codfw.wmnet' {
    class { '::role::mariadb::misc':
        shard  => 'm2',
    }
}

## m3 shard

# See also multiinstance misc hosts db1117 and db2078 below

node 'db1128.eqiad.wmnet' {
    class { '::role::mariadb::misc::phabricator':
        master => true,
    }
}


# codfw
node 'db2134.codfw.wmnet' {
    role(mariadb::misc::phabricator)
}

## Eventlogging shard

node 'db1108.eqiad.wmnet' {
    role(mariadb::misc::eventlogging::replica)
}

## m5 shard

# See also multiinstance misc hosts db1117 and db2078 below

node 'db1133.eqiad.wmnet' {
    class { '::role::mariadb::misc':
        shard  => 'm5',
        master => true,
    }
}

node /^db2(135)\.codfw\.wmnet/ {
    class { '::role::mariadb::misc':
        shard => 'm5',
    }
}

# misc multiinstance
node 'db1117.eqiad.wmnet' {
    role(mariadb::misc::multiinstance)
}
node 'db2078.codfw.wmnet' {
    role(mariadb::misc::multiinstance)
}

# sanitarium hosts
node /^db1(124|125)\.eqiad\.wmnet/ {
    role(mariadb::sanitarium_multiinstance)
}

node /^db2(094|095)\.codfw\.wmnet/ {
    role(mariadb::sanitarium_multiinstance)
}

# tendril db
node 'db1115.eqiad.wmnet' {
    role(mariadb::misc::tendril)
}

# Zarcillo db / standby tendril host
node 'db2093.codfw.wmnet' {
    role(mariadb::misc::zarcillo)
}

# eqiad backup sources
node 'db1095.eqiad.wmnet' {
    role(mariadb::dbstore_multiinstance)
}

node 'db1102.eqiad.wmnet' {
    role(mariadb::dbstore_multiinstance)
}

node 'db1116.eqiad.wmnet' {
    role(mariadb::dbstore_multiinstance)
}

node 'db1139.eqiad.wmnet' {
    role(mariadb::dbstore_multiinstance)
}
node 'db1140.eqiad.wmnet' {
    role(mariadb::dbstore_multiinstance)
}

# codfw backup sources

node 'db2097.codfw.wmnet' {
    role(mariadb::dbstore_multiinstance)
}
node 'db2098.codfw.wmnet' {
    role(mariadb::dbstore_multiinstance)
}
node 'db2099.codfw.wmnet' {
    role(mariadb::dbstore_multiinstance)
}
node 'db2100.codfw.wmnet' {
    role(mariadb::dbstore_multiinstance)
}
node 'db2101.codfw.wmnet' {
    role(mariadb::dbstore_multiinstance)
}
node 'db2139.codfw.wmnet' {
    role(mariadb::dbstore_multiinstance)
}

node 'db2102.codfw.wmnet' {
    role(mariadb::core_test)
}

# Analytics production replicas
node /^dbstore100(3|4|5)\.eqiad\.wmnet$/ {
    role(mariadb::dbstore_multiinstance)
}


# database-provisioning and short-term/postprocessing backups servers

# eqiad ones pending full setup
node 'dbprov1001.eqiad.wmnet' {
    role(mariadb::backups)
}
node 'dbprov1002.eqiad.wmnet' {
    role(mariadb::backups)
}
node 'dbprov2001.codfw.wmnet' {
    role(mariadb::backups)
}
node 'dbprov2002.codfw.wmnet' {
    role(mariadb::backups)
}

# Active eqiad proxies for misc databases
node /^dbproxy10(03|08|12|13|14|15|16|17|21)\.eqiad\.wmnet$/ {
    role(mariadb::proxy::master)
}

# Passive codfw proxies for misc databases
node /^dbproxy20(01|02|03)\.codfw\.wmnet$/ {
    role(mariadb::proxy::master)
}


# labsdb proxies (controling replica service dbs)
# analytics proxy
node 'dbproxy1018.eqiad.wmnet' {
    role(mariadb::proxy::master)
}

# web proxy
node 'dbproxy1019.eqiad.wmnet' {
    role(mariadb::proxy::replicas)
}

# new dbproxy hosts to be pressed into service by DBA team T202367
node /^dbproxy10(20)\.eqiad\.wmnet$/ {
    role(insetup)
}

# new dbproxy hosts to be productionized T223492
node /^dbproxy200[4]\.codfw\.wmnet$/ {
    role(insetup)
}

node /^dbmonitor[12]001\.wikimedia\.org$/ {
    role(tendril)
}

node /^debmonitor[12]001\.(codfw|eqiad)\.wmnet$/ {
    role(debmonitor::server)
}

# Debian package/docker images building host in production (Buster)
node 'deneb.codfw.wmnet' {
    role(builder)
}

node /^dns[12345]00[12]\.wikimedia\.org$/ {
    role(dnsbox)
}

# https://doc.wikimedia.org (T211974)
node 'doc1001.eqiad.wmnet' {
    role(doc)
}

# Druid analytics-eqiad (non public) servers.
# These power internal backends and queries.
# https://wikitech.wikimedia.org/wiki/Analytics/Data_Lake#Druid
node /^druid100[123]\.eqiad\.wmnet$/ {
    role(druid::analytics::worker)
}
node /^an-druid100[12]\.eqiad\.wmnet$/ {
    role(druid::analytics::worker)
}

# Druid public-eqiad servers.
# These power AQS and wikistats 2.0 and contain non sensitive datasets.
# https://wikitech.wikimedia.org/wiki/Analytics/Data_Lake#Druid
node /^druid100[4-8]\.eqiad\.wmnet$/ {
    role(druid::public::worker)
}

# nfs server for xml dumps generation, also rsyncs xml dumps
# data to fallback nfs server(s)
node /^dumpsdata1001\.eqiad\.wmnet$/ {
    role(dumps::generation::server::xmldumps)
}

# nfs server for misc dumps generation, also rsyncs misc dumps
node /^dumpsdata1002\.eqiad\.wmnet$/ {
    role(dumps::generation::server::misccrons)
}

# fallback nfs server for dumps generation, also
# will rsync data to web servers
node /^dumpsdata1003\.eqiad\.wmnet$/ {
    role(dumps::generation::server::xmlfallback)
}

node /^elastic103[2-9]\.eqiad\.wmnet/ {
    role(elasticsearch::cirrus)
}
node /^elastic10[4-5][0-9]\.eqiad\.wmnet/ {
    role(elasticsearch::cirrus)
}

node /^elastic106[0-7]\.eqiad\.wmnet/ {
    role(elasticsearch::cirrus)
}

node /^elastic202[5-9]\.codfw\.wmnet/ {
    role(elasticsearch::cirrus)
}

node /^elastic20[3-5][0-9]\.codfw\.wmnet/ {
    role(elasticsearch::cirrus)
}

node 'elastic2060.codfw.wmnet' {
    role(elasticsearch::cirrus)
}

# External Storage, Shard 1 (es1) databases

## eqiad servers
node /^es101[268]\.eqiad\.wmnet/ {
    role(mariadb::core)
}

## codfw servers
node /^es201[123]\.codfw\.wmnet/ {
    role(mariadb::core)
}

# External Storage, Shard 2 (es2) databases

## eqiad servers
node 'es1015.eqiad.wmnet' {
    role(mariadb::core)
}

node /^es101[13]\.eqiad\.wmnet/ {
    role(mariadb::core)
}

## codfw servers
node 'es2016.codfw.wmnet' {
    role(mariadb::core)
}

node /^es201[45]\.codfw\.wmnet/ {
    role(mariadb::core)
}

# External Storage, Shard 3 (es3) databases

## eqiad servers
node 'es1017.eqiad.wmnet' {
    role(mariadb::core)
}

node /^es101[49]\.eqiad\.wmnet/ {
    role(mariadb::core)
}

## codfw servers
node 'es2017.codfw.wmnet' {
    role(mariadb::core)
}

node /^es201[89]\.codfw\.wmnet/ {
    role(mariadb::core)
}

# External Storage, Shard 4 (es4) databases
## eqiad servers
# master
node 'es1020.eqiad.wmnet' {
    role(mariadb::core)
}

# slaves
node 'es1021.eqiad.wmnet' {
    role(mariadb::core)
}

node 'es1022.eqiad.wmnet' {
    role(mariadb::core)
}

## codfw servers
# master
node 'es2020.codfw.wmnet' {
    role(mariadb::core)
}

node /^es202[12]\.codfw\.wmnet/ {
    role(mariadb::core)
}

# External Storage, Shard 5 (es5) databases
## eqiad servers
# master
node 'es1023.eqiad.wmnet' {
    role(mariadb::core)
}

# slaves
node 'es1024.eqiad.wmnet' {
    role(mariadb::core)
}

node 'es1025.eqiad.wmnet' {
    role(mariadb::core)
}

## codfw servers
# master
node 'es2023.codfw.wmnet' {
    role(mariadb::core)
}

node /^es202[45]\.codfw\.wmnet/ {
    role(mariadb::core)
}

node /^failoid[12]001\.(eqiad|codfw)\.wmnet$/ {
    role(failoid)
}

# Backup system, see T176505.
# This is a reserved system. Ask Otto or Faidon.
node 'flerovium.eqiad.wmnet' {
    role(analytics_cluster::hadoop::client)
}

node 'flowspec1001.eqiad.wmnet' {
    role(flowspec)
}

# Backup system, see T176506.
# This is a reserved system. Ask Otto or Faidon.
node 'furud.codfw.wmnet' {
    role(analytics_cluster::hadoop::client)
}

# Etcd cluster for kubernetes
# TODO: Rename the eqiad etcds to the codfw etcds naming scheme
node /^etcd100[123]\.(eqiad|codfw)\.wmnet$/ {
    role(etcd::kubernetes)
}

# Etcd clusters for kubernetes, v3
node /^kubetcd[12]00[456]\.(eqiad|codfw)\.wmnet$/ {
    role(etcd::v3::kubernetes)
}

# Etcd cluster for kubernetes staging, v3
node /^kubestagetcd100[456]\.eqiad\.wmnet$/ {
    role(etcd::v3::kubernetes::staging)
}

# kubernetes masters
node /^(acrab|acrux|argon|chlorine)\.(eqiad|codfw)\.wmnet$/ {
    role(kubernetes::master)
}

# kubernetes staging master
node 'neon.eqiad.wmnet' {
    role(kubernetes::staging::master)
}

# Etherpad on buster (virtual machine)
node 'etherpad1002.eqiad.wmnet' {
    role(etherpad)
}

# Receives log data from Kafka processes it, and broadcasts
# to Kafka Schema based topics.
node 'eventlog1002.eqiad.wmnet' {
    role(eventlogging::analytics)
}

# virtual machine for mailman list server
node 'fermium.wikimedia.org' {
    role(lists)
}

node 'lists1001.wikimedia.org' {
    role(lists)
}

# HTML dumps from Restbase
node 'francium.eqiad.wmnet' {
    role(dumps::web::htmldumps)
}

# Ganeti virtualization hosts
node /^ganeti[12]00[0-8]\.(codfw|eqiad)\.wmnet$/ {
    role(ganeti)
}

# new Ganeti hosts - replacing ganeti100[1-4] (T228924)
node /^ganeti(1009|101[0-2])\.eqiad\.wmnet$/ {
    role(insetup)
}

# new Ganeti hosts - expansion (T228924)
node /^ganeti101[3-8]\.eqiad\.wmnet$/ {
    role(insetup)
}

# CI Ganeti nodes (T228926)
node /^ganeti10(19|2[012])\.eqiad\.wmnet$/ {
    role(insetup)
}

# new Ganeti hosts - expansion (T224603)
node /^ganeti20(09|1[0-9]|2[0-4])\.codfw\.wmnet$/ {
    role(insetup)
}

node /^ganeti300[123]\.esams\.wmnet$/ {
    role(ganeti)
}

node /^ganeti400[123]\.ulsfo\.wmnet$/ {
    role(ganeti)
}

node /^ganeti500[123]\.eqsin\.wmnet$/ {
    role(ganeti)
}

# Virtual machines for Grafana 6.x (T220838, T244357)
node 'grafana1002.eqiad.wmnet' {
    role(grafana)
}

node 'grafana2001.codfw.wmnet' {
    role(grafana)
}

# Old backup storage and active director: substituted by backup1001
node 'helium.eqiad.wmnet' {
    role(backup::offsite)
}

# Old bacula storage replica: substituted by backup2001
node 'heze.codfw.wmnet' {
    role(backup::offsite)
}

# new host that needs to be turned over to service owner
node 'htmldumper1001.eqiad.wmnet' {
    role(dumps::web::htmldumps)
}

# irc.wikimedia.org
node 'kraz.wikimedia.org' {
    role(mw_rc_irc)
}

# Replacement of irc.wikimedia.org
# see T232483
node 'irc2001.wikimedia.org' {
    role(mediawiki::irc_events)
}

# cloudservices1003/1004 hosts openstack-designate
# and the powerdns auth and recursive services for instances in eqiad1.
node /^cloudservices100[34]\.wikimedia\.org$/ {
    role(wmcs::openstack::eqiad1::services)
}

node 'cloudweb2001-dev.wikimedia.org' {
    role(wmcs::openstack::codfw1dev::cloudweb)
}

node /^cloudnet200[23]-dev\.codfw\.wmnet$/ {
    role(wmcs::openstack::codfw1dev::net)
}

node /^labtestvirt2003\.codfw\.wmnet$/ {
    role(spare::system)
}

node 'clouddb2001-dev.codfw.wmnet' {
    role(wmcs::openstack::codfw1dev::db)
}

node 'cloudcontrol2003-dev.wikimedia.org' {
    role(wmcs::openstack::codfw1dev::control)
}

node 'cloudcontrol2004-dev.wikimedia.org' {
    role(wmcs::openstack::codfw1dev::control)
}

node 'labtestpuppetmaster2001.wikimedia.org' {
    role(wmcs::openstack::codfw1dev::puppetmaster::frontend)
}

node 'cloudservices2002-dev.wikimedia.org' {
    role(wmcs::openstack::codfw1dev::services)
}

node 'cloudservices2003-dev.wikimedia.org' {
    role(wmcs::openstack::codfw1dev::services)
}

node /labweb100[12]\.wikimedia\.org/ {
    role(wmcs::openstack::eqiad1::labweb)

}

# Primary graphite host
node 'graphite1004.eqiad.wmnet' {
    role(graphite::production)
    # TODO: move the roles below to ::role::alerting::host
    include ::role::graphite::alerts
    include ::role::elasticsearch::alerts
}

# Standby graphite host
node 'graphite2003.codfw.wmnet' {
    role(graphite::production)
}

node /^idp[12]001\.wikimedia\.org$/ {
    role(idp)
}

# IDP staging servers
node /^idp-test[12]001\.wikimedia\.org$/ {
    role(idp_test)
}

# TFTP/DHCP/webproxy but NOT APT repo (T224576)
node /^install[12]003\.wikimedia\.org$/ {
    role(installserver::light)
}

# new icinga systems, replaced einsteinium and tegmen (T201344, T208824)
node /^icinga[12]001\.wikimedia\.org$/ {
    role(alerting_host)
}

# Phabricator
node /^(phab1001\.eqiad|phab2001\.codfw)\.wmnet$/ {
    role(phabricator)
}

node /kafka-main100[4-5]\.eqiad\.wmnet/ {
    role(insetup)
}

node /kafka-main100[123]\.eqiad\.wmnet/ {
    role(kafka::main)
}

node /kafka-main200[123]\.codfw\.wmnet/ {
    role(kafka::main)
}

node /kafka-main200[4-5]\.codfw\.wmnet/ {
    role(insetup)
}

# kafka-jumbo is a large general purpose Kafka cluster.
# This cluster exists only in eqiad, and serves various uses, including
# mirroring all data from the main Kafka clusters in both main datacenters.
node /^kafka-jumbo100[1-9]\.eqiad\.wmnet$/ {
    role(kafka::jumbo::broker)
}

# Kafka Burrow Consumer lag monitoring (T187901, T187805)
node /kafkamon[12]001\.(codfw|eqiad)\.wmnet/ {
    role(kafka::monitoring)
}

# virtual machines for misc. applications and static sites
# replaced miscweb1001/2001 in T247648 and bromine/vega in T247650
#
# profile::wikimania_scholarships      # https://scholarships.wikimedia.org/
# profile::iegreview                   # https://iegreview.wikimedia.org
# profile::racktables                  # https://racktables.wikimedia.org
# profile::microsites::annualreport    # https://annual.wikimedia.org
# profile::microsites::static_bugzilla # https://static-bugzilla.wikimedia.org
# profile::microsites::static_rt       # https://static-rt.wikimedia.org
# profile::microsites::transparency    # https://transparency.wikimedia.org
# profile::microsites::research        # https://research.wikimedia.org (T183916)
# profile::microsites::design          # https://design.wikimedia.org (T185282)
# profile::microsites::sitemaps        # https://sitemaps.wikimedia.org
# profile::microsites::bienvenida      # https://bienvenida.wikimedia.org (T207816)
# profile::microsites::wikiworkshop    # https://wikiworkshop.org (T242374)
# profile::microsites::static_codereview # https://static-codereview.wikimedia.org (T243056)

node 'miscweb1002.eqiad.wmnet', 'miscweb2002.codfw.wmnet' {
    role(webserver_misc_apps)
}

# This node will eventually replace kerberos1001
# It is part of the Kerberos eqiad/codfw infrastructure.
node 'krb1001.eqiad.wmnet' {
    role(kerberos::kdc)
}

# Kerberos KDC in codfw, replicates from krb1001
# It is part of the Kerberos eqiad/codfw infrastructure.
node 'krb2001.codfw.wmnet' {
    role(kerberos::kdc)
}

# new kubernetes nodes T241850
node /^kubernetes10(0[7-9]|1[0-4])\.eqiad\.wmnet/ {
    role(insetup)
}

node /kubernetes[12]00[1-6]\.(codfw|eqiad)\.wmnet/ {
    role(kubernetes::worker)
}

node /kubestage100[12]\.eqiad\.wmnet/ {
    role(kubernetes::staging::worker)
}

# codfw new kubernetes nodes T252185
node /kubernetes20(0[7-9]|1[0-4])\.codfw\.wmnet/ {
    role(kubernetes::worker)
}

# codfw new kubernetes staging nodes T252185
node /kubestasge200[12]\.codfw\.wmnet/ {
    role(insetup)
}

node 'cloudcontrol2001-dev.wikimedia.org' {
    role(wmcs::openstack::codfw1dev::control)
}

node /cloudvirt200[1-3]-dev\.codfw\.wmnet/ {
    role(wmcs::openstack::codfw1dev::virt)
}

# WMCS Graphite and StatsD hosts
node /cloudmetrics100[1-2]\.eqiad\.wmnet/ {
    role(wmcs::monitoring)
}

node /^cloudcontrol100[3-5]\.wikimedia\.org$/ {
    role(wmcs::openstack::eqiad1::control)
}

# new systems deployment in process T225320
node /^cloudcephmon100[1-3]\.wikimedia\.org$/ {
    role(wmcs::ceph::mon)
}

# new systems deployment in process T225320
node /^cloudcephosd100[1-3]\.wikimedia\.org$/ {
    role(wmcs::ceph::osd)
}

# New systems to be placed into service by cloud team via T194186
node /^cloudelastic100[1-4]\.wikimedia\.org$/ {
    role(elasticsearch::cloudelastic)
}

# New systems to be placed into service in T249062
node /^cloudelastic100[5-6]\.wikimedia\.org$/ {
    role(insetup)
}

node /^cloudnet100[3-4]\.eqiad\.wmnet$/ {
    role(wmcs::openstack::eqiad1::net)
}

## labsdb dbs
node 'labsdb1009.eqiad.wmnet' {
    role(labs::db::wikireplica_web)
}
node 'labsdb1010.eqiad.wmnet' {
    role(labs::db::wikireplica_web)
}
node /(labsdb1011|db1141)\.eqiad\.wmnet$/ {
    role(labs::db::wikireplica_analytics)
}

node 'labsdb1012.eqiad.wmnet'{
    role(labs::db::wikireplica_analytics::dedicated)
}

node /labstore100[45]\.eqiad\.wmnet/ {
    role(wmcs::nfs::primary)
    # Do not enable yet
    # include ::profile::base::firewall
}

# The following nodes pull data periodically
# from the Analytics Hadoop cluster. Every new
# host needs a kerberos keytab generated,
# according to the details outlined in the
# role's hiera configuration.
node /labstore100[67]\.wikimedia\.org/ {
    role(dumps::distribution::server)
}

# During upgrades and transitions, this will
#  duplicate the work of labstore1003 (but on
#  a different day of the week)
node 'cloudbackup2001.codfw.wmnet' {
    role(wmcs::nfs::primary_backup::tools)
}

# During upgrades and transitions, this will
#  duplicate the work of labstore1004 (but on
#  a different day of the week)
node 'cloudbackup2002.codfw.wmnet' {
    role(wmcs::nfs::primary_backup::misc)
}

# LDAP servers with a replica of OIT's user directory (used by mail servers)
node /^ldap-corp[1-2]001\.wikimedia\.org$/ {
    role(openldap::corp)
}

# Read-only ldap replicas in eqiad, these were setup with a non-standard naming
# scheme and will be renamed the next time they are reimaged (e.g. for the
# buster upgrade)
node /^ldap-eqiad-replica0[1-2]\.wikimedia\.org$/ {
    role(openldap::replica)
}

# Read-only ldap replicas in codfw
node /^ldap-replica200[1-2]\.wikimedia\.org$/ {
    role(openldap::replica)
}

node /^logstash101[0-2]\.eqiad\.wmnet$/ {
    role(logstash::elasticsearch)
    include ::role::kafka::logging # lint:ignore:wmf_styleguide
}

# ELK 7 ES only SSD backends (no kafka-logging brokers)
node /^logstash[12]02[6-9]\.(eqiad|codfw)\.wmnet$/ {
    role(logstash::elasticsearch7)
}

# ELK 7 ES only HDD backends (no kafka-logging brokers)
node /^logstash[12]02[0-2]\.(eqiad|codfw)\.wmnet$/ {
    role(logstash::elasticsearch7)
}

# ELK 7 logstash collectors (Ganeti)
node /^logstash[12]02[345]\.(eqiad|codfw)\.wmnet$/ {
    role(logstash7)
}

# eqiad logstash collectors (Ganeti)
node /^logstash100[7-9]\.eqiad\.wmnet$/ {
    role(logstash)
    include ::lvs::realserver
}

# codfw logstash kafka/elasticsearch
node /^logstash200[1-3]\.codfw\.wmnet$/ {
    role(logstash::elasticsearch)
    # Remove kafka::logging role after dedicated logging kafka hardware is online
    include ::role::kafka::logging # lint:ignore:wmf_styleguide
}

# codfw logstash collectors (Ganeti)
node /^logstash200[4-6]\.codfw\.wmnet$/ {
    role(logstash)
    include ::lvs::realserver # lint:ignore:wmf_styleguide
}

node /lvs101[3456]\.eqiad\.wmnet/ {
    role(lvs::balancer)
}

# codfw lvs
node /lvs200[789]\.codfw\.wmnet/ {
    role(lvs::balancer)
}

node 'lvs2010.codfw.wmnet' {
    role(lvs::balancer)
}

# ESAMS lvs servers
node /^lvs300[567]\.esams\.wmnet$/ {
    role(lvs::balancer)
}

# ULSFO lvs servers
node /^lvs400[567]\.ulsfo\.wmnet$/ {
    role(lvs::balancer)
}

# EQSIN lvs servers
node /^lvs500[123]\.eqsin\.wmnet$/ {
    role(lvs::balancer)
}

node /^maps100[1-3]\.eqiad\.wmnet/ {
    role(maps::slave)
}

node 'maps1004.eqiad.wmnet' {
    role(maps::master)
}

node /^maps200[1-3]\.codfw\.wmnet/ {
    role(maps::slave)
}

node 'maps2004.codfw.wmnet' {
    role(maps::master)
}

node 'matomo1001.eqiad.wmnet' {
    role(piwik)
}

node /^mc10(19|2[0-9]|3[0-6])\.eqiad\.wmnet/ {
    role(mediawiki::memcached)
}

node /^mc20(19|2[0-9]|3[0-6])\.codfw\.wmnet/ {
    role(mediawiki::memcached)
}

node /^mc-gp100[1-3]\.eqiad\.wmnet/ {
    role(mediawiki::memcached::gutter)
}

node /^mc-gp200[1-3]\.codfw\.wmnet/ {
    role(mediawiki::memcached::gutter)
}

# OTRS - ticket.wikimedia.org
node 'mendelevium.eqiad.wmnet' {
    role(otrs)
}

# RT, replaced ununpentium
node 'moscovium.eqiad.wmnet' {
    role(requesttracker)
}

node /^ms-fe1005\.eqiad\.wmnet$/ {
    role(swift::proxy)
    include ::role::swift::stats_reporter
    include ::role::swift::swiftrepl # lint:ignore:wmf_styleguide
    include ::lvs::realserver
}

node /^ms-fe100[6-8]\.eqiad\.wmnet$/ {
    role(swift::proxy)
    include ::lvs::realserver
}

node /^ms-be10(19|[2345][0-9])\.eqiad\.wmnet$/ {
    role(swift::storage)
}

node /^ms-fe2005\.codfw\.wmnet$/ {
    role(swift::proxy)
    include ::role::swift::stats_reporter
    include ::role::swift::swiftrepl # lint:ignore:wmf_styleguide
    include ::lvs::realserver
}

node /^ms-fe200[6-8]\.codfw\.wmnet$/ {
    role(swift::proxy)
    include ::lvs::realserver
}

node /^ms-be20(1[6-9]|[2345][0-9])\.codfw\.wmnet$/ {
    role(swift::storage)
}


## MEDIAWIKI APPLICATION SERVERS

## DATACENTER: EQIAD

# Debug servers
node /^mwdebug100[12]\.eqiad\.wmnet$/ {
    role(mediawiki::canary_appserver)
}

# Appservers (serving normal website traffic)

# Row A

# mw1261 - mw1266 are in rack A5
node /^mw126[1-5]\.eqiad\.wmnet$/ {
    role(mediawiki::canary_appserver)
}
node /^mw1266\.eqiad\.wmnet$/ {
    role(mediawiki::appserver)
}

# mw1267 - mw1275 are in rack A7
node /^mw12(6[7-9]|7[0-5])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver)
}

# rack A5
node /^mw13(8[579]|91)\.eqiad\.wmnet$/ {
    role(mediawiki::appserver)
}

# Row B

# rack B3 and B5
node /^mw1(39[3579]|40[13])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver)
}

# Row C

# Rack C3
node /^mw140[57]\.eqiad\.wmnet$/ {
    role(mediawiki::appserver)
}

# mw1319-33 are in rack C6
node /^mw13(19|2[0-9]|3[0-3])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver)
}

# Rack C8
node /^mw14(09|1[13])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver)
}

# Row D

#mw1349-mw1355 are in rack D1
node /^mw13(49|5[0-5])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver)
}

#mw1363 is in rack D3
node /^mw1363\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

#mw1364-mw1365 are in rack D3
node /^mw136[45]\.eqiad\.wmnet$/ {
    role(mediawiki::appserver)
}

#mw1366-mw1373 are in rack D6
node /^mw13(6[6-9]|7[0-3])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver)
}

#mw1374-mw1382 are in rack D6
node /^mw13(7[4-9]|8[0-2])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

#mw1383 is in rack D8
node /^mw1383\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

#mw1384 is in rack D8
node /^mw1384\.eqiad\.wmnet$/ {
    role(mediawiki::appserver)
}

# API (serving api traffic)

# Row A

# mw1276 - mw1283 are in rack A7
node /^mw127[6-9]\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::canary_api)
}
node /^mw128[1-3]\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# mw1312 is in rack A6
node 'mw1312.eqiad.wmnet' {
    role(mediawiki::appserver::api)
}

# rack A5
node /^mw13(8[68]|9[02])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# Row B

# mw1284-1290,mw1297 are in rack B6
node /^mw12(8[4-9]|9[07])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# mw1313-17 are in rack B7
node /^mw13(1[3-7])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# rack B3 and B5
node /^mw1(39[468]|40[024])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# Row C

# mw1339-48 are in rack C6
node /^mw13(39|4[0-8])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# Rack C3
node /^mw1406\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# Rack C8
node /^mw14(08|1[02])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# Row D

# mw1356-mw1362 are in rack D1
node /^mw13(5[6-9]|6[0-2])\.eqiad\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# mediawiki maintenance server (cron jobs)
# replaced mwmaint1001 (T201343) which replaced terbium (T192185)
node 'mwmaint1002.eqiad.wmnet', 'mwmaint2001.codfw.wmnet' {
    role(mediawiki::maintenance)
}

# Jobrunners (now mostly used via changepropagation as a LVS endpoint)

# Row A

# mw1307-mw1311 are in rack A6
node /^mw13(0[7-9]|1[01])\.eqiad\.wmnet$/ {
    role(mediawiki::jobrunner)
}

# Row B

# mw1293-6,mw1298-mw1306 are in rack B6
node /^mw1(29[345689]|30[0-6])\.eqiad\.wmnet$/ {
    role(mediawiki::jobrunner)
}

# Rack B7
node 'mw1318.eqiad.wmnet' {
    role(mediawiki::jobrunner)
}

# Row C

# mw1334-mw1338 are in rack C6
node /^mw133[4-8]\.eqiad\.wmnet$/ {
    role(mediawiki::jobrunner)
}

## DATACENTER: CODFW

# Debug servers
# mwdebug2001 is in row A, mwdebug2002 is in row B
node /^mwdebug200[12]\.codfw\.wmnet$/ {
    role(mediawiki::canary_appserver)
}


# Appservers

# Row A

# mw2224-38 are in rack A3
# mw2239-42 are in rack A4
node /^mw22(2[4-9]|3[0-9]|4[0-2])\.codfw\.wmnet$/ {
    role(mediawiki::appserver)
}

#mw2291-2300 are in rack A3
node /^mw2(29[1-9]|300)\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# rack A6
node /^mw230[13579]\.codfw\.wmnet$/ {
    role(mediawiki::appserver)
}

# Row B

#mw2254-2258 are in rack B3
node /^mw225[4-8]\.codfw\.wmnet$/ {
    role(mediawiki::appserver)
}

#mw2268-70 are in rack B3
node /^mw22(6[8-9]|70)\.codfw\.wmnet$/ {
    role(mediawiki::appserver)
}

#mw2310-2316 are in rack B3
node /^mw23(1[0-6])\.codfw\.wmnet$/ {
    role(mediawiki::appserver)
}

#mw2317-24 are in rack B3
node /^mw23(1[7-9]|2[0-4])\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# rack B6
node /^mw23(2[579]|3[13])\.codfw\.wmnet$/ {
    role(mediawiki::appserver)
}

# rack C6
node /^mw23(5[13579]|6[135])\.codfw\.wmnet$/ {
    role(mediawiki::appserver)
}

# Row C

# mw2173-mw2186 are in rack C3
node /^mw21(7[3-9]|8[0-6])\.codfw\.wmnet$/ {
    role(mediawiki::appserver)
}

# mw2187-mw2199 are in rack C4

node /^mw21(8[7-8])\.codfw\.wmnet$/ {
    role(mediawiki::canary_appserver)
}

node /^mw21(89|9[0-9])\.codfw\.wmnet$/ {
    role(mediawiki::appserver)
}

# Row D

# rack D3

node /^mw2(27[12])\.codfw\.wmnet$/ {
    role(mediawiki::canary_appserver)
}


node /^mw2(27[3-7]|36[79]|37[135])\.codfw\.wmnet$/ {
    role(mediawiki::appserver)
}

# Api

# Row A

# mw2215-2223 are in rack A3

node /^mw22(1[56])\.codfw\.wmnet$/ {
    role(mediawiki::appserver::canary_api)
}

node /^mw22(1[7-9]|2[0123])\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# rack A6
node /^mw230[2468]\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# mw2244-mw2245,mw2251-2253 are rack A4

node /^mw22(4[45])\.codfw\.wmnet$/ {
    role(mediawiki::appserver::canary_api)
}

node /^mw22(5[1-3])\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# Row B

# mw2135-2147 are in rack B4
node /^mw21([3][5-9]|4[0-7])\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# mw2261-mw2262 are in rack B3
node /^mw226[1-2]\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# rack B6
node /^mw23(2[68]|3[024])\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# Row C

# mw2200-2212,mw2214 are in rack C4
node /^mw22(0[0-9]|1[0124])\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# rack C6
node /^mw23(5[02468]|6[024])\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# Row D

# rack D3
node /^mw23(6[68]|7[0246])\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

#mw2283-90 are in rack D4
node /^mw22(8[3-9]|90)\.codfw\.wmnet$/ {
    role(mediawiki::appserver::api)
}

# Jobrunners

# Row A

# mw2243, mw2246-mw2250 are in rack A4

# jobrunner canaries
node /^mw22(49|50)\.codfw\.wmnet$/ {
    role(mediawiki::jobrunner)
}

# jobrunners
node /^mw22(4[3678])\.codfw\.wmnet$/ {
    role(mediawiki::jobrunner)
}

# Row B

# mw2259-60 are in rack B3
node /^mw22(59|60)\.codfw\.wmnet$/ {
    role(mediawiki::jobrunner)
}

# mw2263-7 are in rack B3
node /^mw226[3-7]\.codfw\.wmnet$/ {
    role(mediawiki::jobrunner)
}

# Row C

# Row D

# mw2278-80 are in rack D3, mw2281-2 are in rack D4
node /^mw22(7[8-9]|8[0-2])\.codfw\.wmnet$/ {
    role(mediawiki::jobrunner)
}

## END MEDIAWIKI APPLICATION SERVERS

# mw logging host codfw
node 'mwlog2001.codfw.wmnet' {
    role(logging::mediawiki::udp2log)
}

# mw logging host eqiad
node 'mwlog1001.eqiad.wmnet' {
    role(logging::mediawiki::udp2log)
}

node 'mx1001.wikimedia.org' {
    role(mail::mx)

    interface::alias { 'wiki-mail-eqiad.wikimedia.org':
        ipv4 => '208.80.154.91',
        ipv6 => '2620:0:861:3:208:80:154:91',
    }
}

node 'mx2001.wikimedia.org' {
    role(mail::mx)

    interface::alias { 'wiki-mail-codfw.wikimedia.org':
        ipv4 => '208.80.153.46',
        ipv6 => '2620:0:860:2:208:80:153:46',
    }
}

# ncredir instances
node /^ncredir100[12]\.eqiad\.wmnet$/ {
    role(ncredir)
}

node /^ncredir200[12]\.codfw\.wmnet$/ {
    role(ncredir)
}

node /^ncredir300[12]\.esams\.wmnet$/ {
    role(ncredir)
}

node /^ncredir400[12]\.ulsfo\.wmnet$/ {
    role(ncredir)
}

node /^ncredir500[12]\.eqsin\.wmnet$/ {
    role(ncredir)
}

# SWAP (Jupyter Notebook) Servers with Analytics Cluster Access
node /notebook100[34].eqiad.wmnet/ {
    role(swap)
}

node /^netbox(1001|2001)\.wikimedia\.org$/ {
    role(netbox::frontend)
}

node /^netboxdb(1001|2001)\.(eqiad|codfw)\.wmnet$/ {
    role(netbox::database)
}

# network monitoring tools, stretch (T125020, T166180)
node /^netmon(1002|2001)\.wikimedia\.org$/ {
    role(netmon)
}

# Network insights (netflow/pmacct, etc.)
node /^netflow[1-5]001\.(eqiad|codfw|ulsfo|esams|eqsin)\.wmnet$/ {
    role(netinsights)
}

node /^ores[12]00[1-9]\.(eqiad|codfw)\.wmnet$/ {
    role(ores)
}

node /orespoolcounter[12]00[34]\.(codfw|eqiad)\.wmnet/ {
    role(orespoolcounter)
}

node /^oresrdb100[12]\.eqiad\.wmnet$/ {
    role(ores::redis)
}

node /^oresrdb200[12]\.codfw\.wmnet$/ {
    role(ores::redis)
}

# new OTRS machine to replace mendelevium
node 'otrs1001.eqiad.wmnet' {
    role(insetup)
}

# Wikidough, experimental (T252132)
node 'malmok.wikimedia.org' {
    role(wikidough)
}

# parser cache databases
# eqiad
# pc1
node /^pc10(07|10)\.eqiad\.wmnet$/ {
    role(mariadb::parsercache)
}
# pc2
node /^pc10(08)\.eqiad\.wmnet$/ {
    role(mariadb::parsercache)
}
# pc3
node /^pc10(09)\.eqiad\.wmnet$/ {
    role(mariadb::parsercache)
}

# codfw
# pc1
node /^pc20(07|10)\.codfw\.wmnet$/ {
    role(mariadb::parsercache)
}
# pc2
node /^pc20(08)\.codfw\.wmnet$/ {
    role(mariadb::parsercache)
}
# pc3
node /^pc20(09)\.codfw\.wmnet$/ {
    role(mariadb::parsercache)
}

# new parsoid nodes (T243112)
node /^parse20(0[1-9]|1[0-9]|20)\.codfw\.wmnet$/ {
    role(insetup)
}

# virtual machines for https://wikitech.wikimedia.org/wiki/Ping_offload
node /^ping[123]001\.(eqiad|codfw|esams)\.wmnet$/ {
    role(ping_offload)
}

# virtual machines hosting https://wikitech.wikimedia.org/wiki/Planet.wikimedia.org
node /^planet[12]002\.(eqiad|codfw)\.wmnet$/ {
    role(planet)
}

node /poolcounter[12]00[345]\.(codfw|eqiad)\.wmnet/ {
    role(poolcounter::server)
}

node /^prometheus200[34]\.codfw\.wmnet$/ {
    role(prometheus)
}

node /^prometheus100[34]\.eqiad\.wmnet$/ {
    role(prometheus)
}

node /^proton[12]00[12]\.(eqiad|codfw)\.wmnet$/ {
    role(proton)

}

node /^puppetmaster[12]001\.(codfw|eqiad)\.wmnet$/ {
    role(puppetmaster::frontend)
}

node /^puppetmaster[12]00[23]\.(codfw|eqiad)\.wmnet$/ {
    role(puppetmaster::backend)
}

node /^puppetboard[12]001\.(codfw|eqiad)\.wmnet$/ {
    role(puppetboard)
}

node /^puppetdb[12]002\.(codfw|eqiad)\.wmnet$/ {
    role(puppetmaster::puppetdb)
}

# pybal-test200X VMs are used for pybal testing/development
node /^pybal-test200[123]\.codfw\.wmnet$/ {
    role(pybaltest)
}

# New rdb servers T206450
node /^rdb100[59]\.eqiad\.wmnet$/ {
    role(redis::misc::master)
}

node /^(rdb1006|rdb1010)\.eqiad\.wmnet$/ {
    role(redis::misc::slave)
}

node /^rdb200[35]\.codfw\.wmnet$/ {
    role(redis::misc::master)
}
node /^rdb200[46]\.codfw\.wmnet$/ {
    role(redis::misc::slave)
}

node /^registry[12]00[12]\.(eqiad|codfw)\.wmnet$/ {
    role(docker_registry_ha::registry)
}


# https://releases.wikimedia.org - VMs for releases (mediawiki and other)
# https://releases-jenkins.wikimedia.org - for releases admins
node /^releases[12]001\.(codfw|eqiad)\.wmnet$/ {
    role(releases)
}

node /^relforge100[1-2]\.eqiad\.wmnet/ {
    role(elasticsearch::relforge)
}

# restbase eqiad cluster
node /^restbase10(1[6-9]|2[0-7])\.eqiad\.wmnet$/ {
    role(restbase::production)
}

# new restbase nodes (T241784)
node /^restbase10(2[8-9]|3[0])\.eqiad\.wmnet$/ {
    role(insetup)
}

# restbase codfw cluster
node /^restbase20(09|1[0-9]|2[0-3])\.codfw\.wmnet$/ {
    role(restbase::production)
}

# cassandra/restbase dev cluster
node /^restbase-dev100[4-6]\.eqiad\.wmnet$/ {
    role(restbase::dev_cluster)
}

# virtual machines for https://wikitech.wikimedia.org/wiki/RPKI#Validation
node /^rpki[12]001\.(eqiad|codfw)\.wmnet$/ {
    role(rpkivalidator)
}

# T252210
node 'peek2001.codfw.wmnet' {
    role(peek)
}

# people.wikimedia.org, for all shell users
# buster VM. replaced people1001 (T247649)
node 'people1002.eqiad.wmnet' {
    role(microsites::peopleweb)
}

# scandium is a parsoid regression test server. it replaced ruthenium.
# https://www.mediawiki.org/wiki/Parsoid/Round-trip_testing
# Right now, both rt-server and rt-clients run on the same node
# But, we are likely going to split them into different boxes soon.
node 'scandium.eqiad.wmnet' {
    role(parsoid::testing)
}

node /schema[12]00[12].(eqiad|codfw).wmnet/ {
    role(eventschemas::service)
}

# new sessionstore servers via T209393 & T209389
node /sessionstore[1-2]00[1-3].(eqiad|codfw).wmnet/ {
    role(sessionstore)
}

# Services 'B'
node /^scb[12]00[123456]\.(eqiad|codfw)\.wmnet$/ {
    role(scb)

}

# Codfw, eqiad ldap servers, aka ldap-$::site
node /^(seaborgium|serpens)\.wikimedia\.org$/ {
    role(openldap::labs)
}

node 'sodium.wikimedia.org' {
    role(mirrors)
}

node 'thorium.eqiad.wmnet' {
    # thorium is used to host public Analytics websites like:
    # - https://stats.wikimedia.org (Wikistats)
    # - https://analytics.wikimedia.org (Analytics dashboards and datasets)
    # - https://datasets.wikimedia.org (deprecated, redirects to analytics.wm.org/datasets/archive)
    #
    # For a complete and up to date list please check the
    # related role/module.
    #
    # This node is not intended for data processing.
    role(analytics_cluster::webserver)
}

# The hosts contain all the tools and libraries to access
# the Analytics Cluster services.
node /^stat100[4-8]\.eqiad\.wmnet/ {
    role(statistics::explorer)
}

# NOTE: new snapshot hosts must also be manually added to
# hieradata/common.yaml:dumps_nfs_clients for dump nfs mount,
# hieradata/common/scap/dsh.yaml for mediawiki installation,
# and to hieradata/hosts/ if running dumps for enwiki or wikidata.
node /^snapshot100[569]\.eqiad\.wmnet/ {
    role(dumps::generation::worker::dumper)
}
node /^snapshot1007\.eqiad\.wmnet/ {
    role(dumps::generation::worker::dumper_monitor)
}
node /^snapshot1008\.eqiad\.wmnet/ {
    role(dumps::generation::worker::dumper_misc_crons_only)
}
node /^snapshot1010\.eqiad\.wmnet/ {
    role(dumps::generation::worker::testbed)
}

# test nodes for akosiaris and moritzm
node /^sretest100[1-2]\.eqiad\.wmnet$/ {
    role(insetup)
}

# Used for various d-i tests
node 'theemin.codfw.wmnet' {
    role(test)
}

node /^thanos-be200[1234]\.codfw\.wmnet/ {
    role(thanos::backend)
}

node /^thanos-fe200[123]\.codfw\.wmnet/ {
    role(thanos::frontend)
}

# Thumbor servers for MediaWiki image scaling
node /^thumbor100[1234]\.eqiad\.wmnet/ {
    role(thumbor::mediawiki)
}

node /^thumbor200[1234]\.codfw\.wmnet/ {
    role(thumbor::mediawiki)
}

# deployment servers
node 'deploy1001.eqiad.wmnet', 'deploy2001.codfw.wmnet' {
    role(deployment_server)
}

# test system for performance team (T117888)
node 'tungsten.eqiad.wmnet' {
    role(xhgui::app)
}

# new url-downloaders (T224551)
# https://wikitech.wikimedia.org/wiki/Url-downloader
node /^urldownloader[12]00[12]\.wikimedia\.org/ {
    role(url_downloader)
}

# To see cloudvirt nodes active in the scheduler look at hiera:
#  key: profile::openstack::eqiad1::nova::scheduler_pool
# We try to keep a few empty as emergency fail-overs
#  or transition hosts for maintenance to come
node /^cloudvirt100[1-3,5,7-9]\.eqiad\.wmnet$/ {
    role(wmcs::openstack::eqiad1::virt)
}
node /^cloudvirt10[1-3][0-9]\.eqiad\.wmnet$/ {
    role(wmcs::openstack::eqiad1::virt)
}

# cloudvirts using Ceph backend storage
# https://wikitech.wikimedia.org/wiki/Portal:Cloud_VPS/Admin/Ceph
node /^cloudvirt100[4,6]\.eqiad\.wmnet$/ {
    role(wmcs::openstack::eqiad1::virt_ceph)
}


# Private virt hosts for wdqs T221631
node /^cloudvirt-wdqs100[123]\.eqiad\.wmnet$/ {
    role(wmcs::openstack::eqiad1::virt)
}

# Wikidata query service
node /^wdqs100[4-7]\.eqiad\.wmnet$/ {
    role(wdqs)
}

node /^wdqs101[1-3]\.eqiad\.wmnet$/ {
    role(insetup)
}

node /^wdqs200[1237]\.codfw\.wmnet$/ {
    role(wdqs)
}

# Wikidata query service internal
node /^wdqs100[38]\.eqiad\.wmnet$/ {
    role(wdqs::internal)
}

node /^wdqs200[4568]\.codfw\.wmnet$/ {
    role(wdqs::internal)
}

# production roles to be assigned (T242301)
node /^wdqs200[7-8]\.codfw\.wmnet$/ {
    role(insetup)
}

# Wikidata query service automated deployment
node 'wdqs1009.eqiad.wmnet' {
    role(wdqs::autodeploy)
}

# Wikidata query service test
node 'wdqs1010.eqiad.wmnet' {
    role(wdqs::test)
}

node 'weblog1001.eqiad.wmnet'
{
    role(logging::webrequest::ops)
}

# VMs for performance team replacing hafnium (T179036)
node /^webperf[12]001\.(codfw|eqiad)\.wmnet/ {
    role(webperf::processors_and_site)
}

# VMs for performance team profiling tools (T194390)
node /^webperf[12]002\.(codfw|eqiad)\.wmnet/ {
    role(webperf::profiling_tools)
}

# https://www.mediawiki.org/wiki/Parsoid
node /^wtp10(2[5-9]|[34][0-9])\.eqiad\.wmnet$/ {
    role(parsoid)
}

node /^wtp20(0[1-9]|1[0-9]|2[0-4])\.codfw\.wmnet$/ {
    role(parsoid)
}

node 'xhgui1001.eqiad.wmnet', 'xhgui2001.codfw.wmnet' {
    role(xhgui::app)
}

node default {
    if $::realm == 'production' {
        fail('No puppet role has been assigned to this node.')
    } else {
        # Require instead of include so we get NFS and other
        # base things setup properly
        require ::role::wmcs::instance
    }
}
