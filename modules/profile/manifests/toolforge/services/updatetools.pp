class profile::toolforge::services::updatetools(
    $active_node = hiera('profile::toolforge::services::active_node'),
) {
    require_package('python-mysqldb')

    file { '/usr/local/bin/updatetools':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/profile/toolforge/services/updatetools',
    }

    systemd::service { 'updatetools':
        ensure         => present,
        content        => systemd_template('updatetools'),
        restart        => true,
        override       => false,
        require        => File['/usr/local/bin/updatetools'],
        service_params => {
            ensure     => ensure_service($::fqdn == $active_node),
        },
        subscribe      => [
            File['/usr/local/bin/updatetools'],
        ],
    }
}
