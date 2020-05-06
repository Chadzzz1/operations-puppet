class kubeadm::docker (
) {
    $packages = [
        'docker-ce',
        'docker-ce-cli',
    ]

    kubeadm::package_from_component { 'docker':
        packages => $packages,
    }

    # I think this is unused? It is called for specifically in Kubernetes docs.  Don't know why.
    file { '/etc/systemd/system/docker.service.d':
        ensure => 'directory',
    }

    service { 'docker':
        ensure => 'running'
    }

    file { '/etc/docker/daemon.json':
        source  => 'puppet:///modules/toolforge/docker-config.json',
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        notify  => Service['docker'],
        require => Package['docker-ce'],
    }
}
