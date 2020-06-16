class profile::openstack::eqiad1::galera::monitoring(
    Integer             $nodecount             = lookup('profile::openstack::eqiad1::galera::node_count'),
    Stdlib::Port        $port                  = lookup('profile::openstack::eqiad1::galera::listen_port'),
    String              $test_username         = lookup('profile::openstack::eqiad1::galera::test_username'),
    String              $test_password         = lookup('profile::openstack::eqiad1::galera::test_password'),
){
    # Bypass haproxy and check the backend mysqld port directly. We want to notice
    #  degraded service even if the haproxy'd front end is holding up.
    monitoring::service { 'galera':
        description   => 'WMCS Galera Cluster',
        check_command => "check_galera!${nodecount}!${port}!${test_username}!${test_password}",
        critical      => true,
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Portal:Cloud_VPS/Admin/Troubleshooting',
        contact_group => 'wmcs-team,admins',
    }
}
