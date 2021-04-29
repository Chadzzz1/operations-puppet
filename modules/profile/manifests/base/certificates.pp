# The puppet_ca_content variable here is intended to be used temporarily to assist with a puppetmaster
# switch. You can set it at the same time as changing an agent's puppetmaster, obviously using the CA of
# the new puppetmaster, and on the agent's last run with the old puppetmaster, it will replace the CA file
# with the new one. This will make it able to talk to the new puppetmaster on its next run.
# A puppetmaster's CA cert can be found at /var/lib/puppet/server/ssl/certs/ca.pem
class profile::base::certificates (
    Hash             $puppet_ca_content = lookup('profile::base::certificates::puppet_ca_content'),
    Array[String[1]] $wmf_intermidiates = lookup('profile::base::certificates::wmf_intermidiates'),
    Optional[String] $puppetmaster_key  = lookup('puppetmaster'),
) {
    include ::sslcert

    sslcert::ca { 'wmf_ca_2017_2020':
        source  => 'puppet:///modules/base/ca/wmf_ca_2017_2020.crt',
    }
    sslcert::ca { 'RapidSSL_SHA256_CA_-_G3':
        source  => 'puppet:///modules/base/ca/RapidSSL_SHA256_CA_-_G3.crt',
    }
    sslcert::ca { 'DigiCert_High_Assurance_CA-3':
        source  => 'puppet:///modules/base/ca/DigiCert_High_Assurance_CA-3.crt',
    }
    sslcert::ca { 'DigiCert_SHA2_High_Assurance_Server_CA':
        source => 'puppet:///modules/base/ca/DigiCert_SHA2_High_Assurance_Server_CA.crt',
    }
    sslcert::ca { 'GlobalSign_Organization_Validation_CA_-_SHA256_-_G2':
        source  => 'puppet:///modules/base/ca/GlobalSign_Organization_Validation_CA_-_SHA256_-_G2.crt',
    }
    sslcert::ca { 'GlobalSign_RSA_OV_SSL_CA_2018.crt':
        source  => 'puppet:///modules/base/ca/GlobalSign_RSA_OV_SSL_CA_2018.crt',
    }
    sslcert::ca { 'GlobalSign_ECC_OV_SSL_CA_2018.crt':
        source  => 'puppet:///modules/base/ca/GlobalSign_ECC_OV_SSL_CA_2018.crt',
    }
    # This is a cross-sign for the above GlobalSign_ECC_OV_SSL_CA_2018 to reach
    # the more-widely-known R3 root instead of its default R5 root.
    sslcert::ca { 'GlobalSign_ECC_Root_CA_R5_R3_Cross.crt':
        source  => 'puppet:///modules/base/ca/GlobalSign_ECC_Root_CA_R5_R3_Cross.crt',
    }
    sslcert::ca { 'Wikimedia_Internal_Root_CA':
        source => 'puppet:///modules/profile/pki/ROOT/Wikimedia_Internal_Root_CA.pem',
    }
    $wmf_intermidiates.each |$ca| {
        sslcert::ca { $ca:
            source => "puppet:///modules/profile/pki/intermediates/${ca}.pem",
        }
    }



    if has_key($puppet_ca_content, $puppetmaster_key) {
        exec { 'clear-old-puppet-ssl':
            command     => "/bin/bash -c '/bin/mv /var/lib/puppet/ssl /var/lib/puppet/ssl.\$(/bin/date +%Y-%m-%dT%H:%M)'",
            refreshonly => true,
        }
        sslcert::ca { 'Puppet_Internal_CA':
            content => $puppet_ca_content[$puppetmaster_key],
            notify  => Exec['clear-old-puppet-ssl'],
        }
    } else {
        $puppet_ssl_dir = puppet_ssldir()
        sslcert::ca { 'Puppet_Internal_CA':
            source => "${puppet_ssl_dir}/certs/ca.pem",
        }
    }

    # install all CAs before generating certificates
    Sslcert::Ca <| |> -> Sslcert::Certificate<| |>
}
