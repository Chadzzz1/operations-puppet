class role::wmcs::openstack::labtestn::services {
    system::role { $name: }
    include ::standard
    include ::profile::base::firewall
    include ::profile::openstack::labtestn::cloudrepo
    include ::profile::openstack::labtestn::pdns::auth::db
    include ::profile::openstack::labtestn::pdns::auth::service
    include ::profile::openstack::labtestn::pdns::recursor::service
    include ::profile::openstack::labtestn::designate::service
}
