# == Class profile::tlsproxy::envoy
#
# Sets up TLS termination using the envoy proxy.
#
# === Examples
# Example hiera setups for common use-cases.
#
# Set up a global TLS proxy to apache listening on TCP port 444.
#   profile::envoy::ensure: present
#   profile::tlsproxy::envoy::sni_support: no
#   profile::tlsproxy::envoy::tls_port: 444
#   profile::tlsproxy::envoy::services:
#      - server_names: ['*']
#        port: 80
#   profile::tlsproxy::envoy::global_cert_name: "appserver"
#
# Set up a TLS proxy to multiple backend services, with sni support
# The "virtual host" for '*.test' doesn't have a cert_name, so it will
# only be served with the global certificate.
#
#   profile::envoy::ensure: present
#   profile::tlsproxy::envoy::sni_support: yes
#   profile::tlsproxy::envoy::services:
#      - server_names: ['service1', '*.service1.production']
#        port: 8080
#        cert_name: 'service1'
#      - server_names: ['service2', '*.service2.production']
#        port: 8081
#        cert_name: 'service2'
#      - server_names: ['*.test']
#        port: 9999
#   profile::tlsproxy::envoy::global_cert_name: "appserver"
#
class profile::tlsproxy::envoy(
    Wmflib::Ensure $ensure = lookup('profile::envoy::ensure'),
    Enum['strict', 'yes', 'no'] $sni_support = lookup('profile::tlsproxy::envoy::sni_support'),
    Stdlib::Port $tls_port = lookup('profile::tlsproxy::envoy::tls_port', { 'default_value' => 443 }),
    Array[Struct[
        {
        'server_names' => Array[Variant[Stdlib::Fqdn, Enum['*']]],
        'port' => Stdlib::Port,
        'cert_name' => Optional[String]
        }
    ]] $services = lookup('profile::tlsproxy::envoy::services'),
    Optional[String] $global_cert_name = lookup('profile::tlsproxy::envoy::global_cert_name', {'default_value' => undef}),
    Optional[Boolean] $websockets = lookup('profile::tlsproxy::envoy::websockets', {'default_value' => false}),

) {
    require ::profile::envoy
    if os_version('debian jessie') and $tls_port !~ Stdlib::Port::Unprivileged {
            fail('Envoy can only work with unprivileged ports under jessie.')
    }

    # ensure all the needed certs are present. Given these are internal services,
    # we want certs declared with the traditional sslcert for now.
    $services.each |$service| {
        $certname = $service['cert_name']
        if $service['cert_name'] {
            sslcert::certificate { $service['cert_name']:
                ensure => $ensure,
                group  => 'envoy',
                notify => Service['envoyproxy.service'],
            }
        }
    }
    $upstreams = $services.map |$service| {
        $certname = $service['cert_name']
        if $certname and $sni_support != 'no' {
            $cert = "/etc/ssl/localcerts/${service['cert_name']}.crt"
            $key = "/etc/ssl/private/${service['cert_name']}.key"
        } else {
            $cert = undef
            $key = undef
        }
        # This is the variable that's returned to the map.
        $upstream = {
            'server_names'  => $service['server_names'],
            'cert_path'     => $cert,
            'key_path'      => $key,
            'upstream_port' => $service['port'],
        }
    }

    if $sni_support == 'strict' {
        $global_cert_path = undef
        $global_key_path = undef
    }
    else {
        unless $global_cert_name {
            fail('If you want non-sni TLS to be supported, you need to define profile::tlsproxy::envoy::global_cert_name')
        }
        sslcert::certificate { $global_cert_name:
            ensure => $ensure,
            group  => 'envoy',
            notify => Service['envoyproxy.service'],
        }
        $global_cert_path = "/etc/ssl/localcerts/${global_cert_name}.crt"
        $global_key_path = "/etc/ssl/private/${global_cert_name}.key"
    }

    if $ensure == 'present' {
        envoyproxy::tls_terminator{ "${tls_port}": # lint:ignore:only_variable_string
            upstreams        => $upstreams,
            access_log       => false,
            websockets       => $websockets,
            global_cert_path => $global_cert_path,
            global_key_path  => $global_key_path,
        }
        ferm::service { 'envoy_tls_termination':
            proto   => 'tcp',
            notrack => true,
            port    => $tls_port,
        }
    }
}
