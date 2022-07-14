class profile::openstack::codfw1dev::rabbitmq(
    Array[Stdlib::Fqdn] $openstack_controllers = lookup('profile::openstack::codfw1dev::openstack_controllers'),
    Array[Stdlib::Fqdn] $rabbitmq_nodes = lookup('profile::openstack::codfw1dev::rabbitmq_nodes'),
    $monitor_user = lookup('profile::openstack::codfw1dev::rabbit_monitor_user'),
    $monitor_password = lookup('profile::openstack::codfw1dev::rabbit_monitor_pass'),
    $cleanup_password = lookup('profile::openstack::codfw1dev::rabbit_cleanup_pass'),
    $file_handles = lookup('profile::openstack::codfw1dev::rabbit_file_handles'),
    Array[Stdlib::Fqdn] $designate_hosts = lookup('profile::openstack::codfw1dev::designate_hosts'),
    String $nova_rabbit_user = lookup('profile::openstack::base::nova::rabbit_user'),
    String $nova_rabbit_password = lookup('profile::openstack::codfw1dev::nova::rabbit_pass'),
    String $neutron_rabbit_user = lookup('profile::openstack::base::neutron::rabbit_user'),
    String $neutron_rabbit_password = lookup('profile::openstack::codfw1dev::neutron::rabbit_pass'),
    String $trove_guest_rabbit_user = lookup('profile::openstack::base::trove::trove_guest_rabbit_user'),
    String $trove_guest_rabbit_pass = lookup('profile::openstack::codfw1dev::trove::trove_guest_rabbit_pass'),
    $rabbit_erlang_cookie = lookup('profile::openstack::codfw1dev::rabbit_erlang_cookie'),
    Optional[String] $rabbit_cfssl_label = lookup('profile::openstack::codfw1dev::rabbitmq::rabbit_cfssl_label', {default_value => undef}),
    Array[Stdlib::Fqdn] $cinder_backup_nodes   = lookup('profile::openstack::codfw1dev::cinder::backup::nodes'),
){

    class {'::profile::openstack::base::rabbitmq':
        openstack_controllers   => $openstack_controllers,
        rabbitmq_nodes          => $rabbitmq_nodes,
        monitor_user            => $monitor_user,
        monitor_password        => $monitor_password,
        cleanup_password        => $cleanup_password,
        file_handles            => $file_handles,
        designate_hosts         => $designate_hosts,
        nova_rabbit_user        => $nova_rabbit_user,
        nova_rabbit_password    => $nova_rabbit_password,
        neutron_rabbit_user     => $neutron_rabbit_user,
        neutron_rabbit_password => $neutron_rabbit_password,
        trove_guest_rabbit_user => $trove_guest_rabbit_user,
        trove_guest_rabbit_pass => $trove_guest_rabbit_pass,
        rabbit_erlang_cookie    => $rabbit_erlang_cookie,
        rabbit_cfssl_label      => $rabbit_cfssl_label,
        cinder_backup_nodes     => $cinder_backup_nodes,
    }
    contain '::profile::openstack::base::rabbitmq'
}
