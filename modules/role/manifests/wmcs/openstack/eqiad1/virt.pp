class role::wmcs::openstack::eqiad1::virt {
    system::role { $name: }
    include ::standard
    # include ::profile::base::firewall
    include ::profile::openstack::eqiad1::clientlib
    include ::profile::openstack::eqiad1::observerenv
    include ::profile::openstack::eqiad1::nova::common
    #include ::profile::openstack::eqiad1::nova::compute::service
}
