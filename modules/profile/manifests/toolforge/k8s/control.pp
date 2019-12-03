class profile::toolforge::k8s::control(
    Array[Stdlib::Fqdn] $etcd_hosts = lookup('profile::toolforge::k8s::etcd_nodes',     {default_value => ['localhost']}),
    Stdlib::Fqdn        $apiserver  = lookup('profile::toolforge::k8s::apiserver_fqdn', {default_value => 'k8s.example.com'}),
    String              $node_token = lookup('profile::toolforge::k8s::node_token',     {default_value => 'example.token'}),
    String              $calico_version = lookup('profile::toolforge::k8s::calico_version', {default_value => 'v3.8.0'}),
) {
    require profile::toolforge::k8s::preflight_checks

    # use puppet certs to contact etcd
    $k8s_etcd_cert_pub  = '/etc/kubernetes/pki/puppet_etcd_client.crt'
    $k8s_etcd_cert_priv = '/etc/kubernetes/pki/puppet_etcd_client.key'
    $k8s_etcd_cert_ca   = '/etc/kubernetes/pki/puppet_ca.pem'
    $puppet_cert_pub    = "/var/lib/puppet/ssl/certs/${::fqdn}.pem"
    $puppet_cert_priv   = "/var/lib/puppet/ssl/private_keys/${::fqdn}.pem"
    $puppet_cert_ca     = '/var/lib/puppet/ssl/certs/ca.pem'

    file { '/etc/kubernetes/pki':
        ensure => directory,
        mode   => '0755',
        owner  => 'root',
        group  => 'root',
    }
    file { $k8s_etcd_cert_pub:
        ensure    => present,
        source    => "file://${puppet_cert_pub}",
        show_diff => false,
        owner     => 'root',
        group     => 'root',
        mode      => '0444',
    }
    file { $k8s_etcd_cert_priv:
        ensure    => present,
        source    => "file://${puppet_cert_priv}",
        show_diff => false,
        owner     => 'root',
        group     => 'root',
        mode      => '0400',
    }
    file { $k8s_etcd_cert_ca:
        ensure => present,
        source => "file://${puppet_cert_ca}",
    }

    class { 'toolforge::k8s::kubeadm': }

    $pod_subnet = '192.168.0.0/16'
    class { 'toolforge::k8s::kubeadm_init_yaml':
        etcd_hosts         => $etcd_hosts,
        apiserver          => $apiserver,
        pod_subnet         => $pod_subnet,
        node_token         => $node_token,
        k8s_etcd_cert_pub  => $k8s_etcd_cert_pub,
        k8s_etcd_cert_priv => $k8s_etcd_cert_priv,
        k8s_etcd_cert_ca   => $k8s_etcd_cert_ca,
    }

    class { 'toolforge::k8s::calico_yaml':
        pod_subnet     => $pod_subnet,
        calico_version => $calico_version,
    }

    class { '::toolforge::k8s::calico_workaround': }

    class { '::toolforge::k8s::nginx_ingress_yaml': }

    class { '::toolforge::k8s::admin_scripts': }

    class { '::toolforge::k8s::prometheus_metrics_yaml': }
}
