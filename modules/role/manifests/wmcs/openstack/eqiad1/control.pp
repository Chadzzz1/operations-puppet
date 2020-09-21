class role::wmcs::openstack::eqiad1::control {
    system::role { $name: }
    include ::profile::standard
    include ::profile::base::firewall
    include ::profile::openstack::eqiad1::metrics
    include ::profile::openstack::eqiad1::observerenv
    include ::profile::openstack::eqiad1::rabbitmq
    include ::profile::openstack::eqiad1::keystone::apache
    include ::profile::openstack::eqiad1::keystone::service
    include ::profile::openstack::eqiad1::keystone::fernet_keys
    include ::profile::openstack::eqiad1::envscripts
    include ::profile::openstack::eqiad1::neutron::common
    include ::profile::openstack::eqiad1::neutron::service
    include ::profile::openstack::eqiad1::glance
    include ::profile::ceph::client::rbd_glance
    include ::profile::openstack::eqiad1::nova::common
    include ::profile::openstack::eqiad1::nova::conductor::service
    include ::profile::openstack::eqiad1::nova::scheduler::service
    include ::profile::openstack::eqiad1::nova::api::service
    include ::profile::openstack::eqiad1::nova::placement::service
    include ::profile::openstack::eqiad1::haproxy
    include ::profile::openstack::eqiad1::designate::firewall::api
    include ::profile::prometheus::haproxy_exporter
    include ::profile::ldap::client::labs
    include ::profile::openstack::eqiad1::pdns::dns_floating_ip_updater
    include ::profile::openstack::eqiad1::nova::fullstack::service
    include ::profile::memcached::instance
    include ::profile::openstack::eqiad1::nova::instance_purge
    include ::profile::openstack::eqiad1::galera::node
    include ::profile::openstack::eqiad1::galera::monitoring
    include ::profile::openstack::eqiad1::galera::backup
}
