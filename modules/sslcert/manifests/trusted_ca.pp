# @summary Deploy a .pem file containing the WMF's internal Root CA crts.
#          Create a .p12 truststore if needed.
# @param trusted_certs a list of certificate files to add to the tristed cert store
# @param p12_truststore_path location on the fs where to create the .p12 truststore
# @param jks_truststore_path location on the fs where to create the .jks truststore
# @param owner user set as owner of the files to be created
# @param group group set as group-owner of the files to be created
class sslcert::trusted_ca (
    Wmflib::Ensure                   $ensure              = 'present',
    String                           $truststore_password = 'changeit',
    String                           $owner               = 'root',
    String                           $group               = 'root',
    Boolean                          $include_bundle_jks  = false,
    Optional[Sslcert::Trusted_certs] $trusted_certs       = undef,
) {

    contain sslcert

    if $trusted_certs {
        $trusted_ca_path = $trusted_certs['bundle']
        $jks_truststore_path = $include_bundle_jks ? {
            true    => "${sslcert::localcerts}/wmf-java-cacerts",
            default => undef,
        }
        if 'package' in $trusted_certs {
            ensure_packages($trusted_certs['package'])
            $res_subscribe = Package[$trusted_certs['package']]
        } else {
            $trusted_certs['certs'].each |$cert| {
                # The following file resources is only used so we no when the source
                # file changes and thus know when to notify the exec and rebuild the bundle
                file { "${sslcert::localcerts}/${cert.basename}":
                    ensure => file,
                    owner  => $owner,
                    group  => $group,
                    mode   => '0444',
                    source => $cert,
                    notify => Exec['generate trusted_ca'],
                }
            }
            exec { 'generate trusted_ca':
                command     => "/bin/cat ${trusted_certs['certs'].join(' ')} > ${trusted_ca_path}",
                refreshonly => true,
                user        => $owner,
                group       => $group,
            }
            $res_subscribe = Exec['generate trusted_ca']

            # Ensure readability for user/group/others of the cert bundle.
            file { $trusted_ca_path:
                ensure => file,
                owner  => $owner,
                group  => $group,
                mode   => '0644',
            }
        }
        $trusted_certs['certs'].each |$cert| {
            if $include_bundle_jks {
                $cert_basename = '.pem' in $cert.basename ? {
                    true  => $cert.basename('.pem'),
                    false => $cert.basename('.crt'),
                }
                java::cacert { $cert_basename:
                    ensure        => $ensure,
                    owner         => $owner,
                    path          => $cert,
                    storepass     => $truststore_password,
                    keystore_path => $jks_truststore_path,
                    subscribe     => $res_subscribe,
                }
                Class['java'] -> Java::Cacert[$cert_basename]
            }
        }
    } else {
        $trusted_ca_path = $facts['puppet_config']['localcacert']
        $jks_truststore_path = $include_bundle_jks ? {
            true    => '/etc/ssl/certs/java/cacerts',
            default => undef,
        }
    }
}
