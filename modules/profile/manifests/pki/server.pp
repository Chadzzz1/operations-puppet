# @summary configure a PKI sevrver
class profile::pki::server () {
    class {'cfssl':
        ca_key_content  => secret('pki/Wikimedia_ROOT_CA.key'),
        ca_cert_content => file('profile/pki/Wikimedia_ROOT_CA.pem'),
    }
    $names = [{
        'organisation'        => 'Wikimedia Foundation, Inc',
        'organisational_unit' => 'Technolagy',
        'locality'            => 'San Francisco',
        'state'               => 'California',
        'country'             => 'US',
    }]
    cfssl::csr {'Wikimedia ROOT CA':
        key   => {'algo' => 'ecdsa', 'size' => 521},
        names => $names,
        sign  => false,
    }
}
