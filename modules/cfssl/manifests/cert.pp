# @summary a resource for creating csr json files
define cfssl::cert (
    Cfssl::Signer_config          $signer_config,
    String                        $common_name   = $title,
    Array[Cfssl::Name]            $names         = [],
    Cfssl::Key                    $key           = {'algo' => 'ecdsa', 'size' => 521},
    Wmflib::Ensure                $ensure        = 'present',
    String                        $owner         = 'root',
    String                        $group         = 'root',
    Boolean                       $auto_renew    = true,
    Integer[1800]                 $renew_seconds = 604800,  # 1 week
    Optional[String]              $label         = undef,
    Optional[String]              $profile       = undef,
    Optional[Stdlib::Unixpath]    $outdir        = undef,
    Optional[Stdlib::Unixpath]    $tls_cert      = undef,
    Optional[Stdlib::Unixpath]    $tls_key       = undef,
    Optional[Array[Stdlib::Host]] $hosts         = [],

) {
    include cfssl

    if $key['algo'] == 'rsa' and $key['size'] < 2048 {
        fail('RSA keys must be either 2048, 4096 or 8192 bits')
    }
    if $key['algo'] == 'ecdsa' and $key['size'] > 2048 {
        fail('ECDSA keys must be either 256, 384 or 521 bits')
    }
    $ensure_file = $ensure ? {
        'present' => 'file',
        default   => $ensure,
    }

    $safe_title = $title.regsubst('[^\w\-]', '_', 'G')
    $csr_json_path = "${cfssl::csr_dir}/${safe_title}.csr"
    $_outdir   = $outdir ? {
        undef   => "${cfssl::ssl_dir}/${safe_title}",
        default => $outdir,
    }

    $_names = $names.map |Cfssl::Name $name| {
        {
            'C'  => $name['country'],
            'L'  => $name['locality'],
            'O'  => $name['organisation'],
            'OU' => $name['organisational_unit'],
            'S'  => $name['state'],
        }
    }
    $csr = {
        'CN'    => $common_name,
        'hosts' => $hosts,
        'key'   => $key,
        'names' => $_names,
    }
    file{$csr_json_path:
        ensure  => $ensure_file,
        owner   => 'root',
        group   => 'root',
        mode    => '0400',
        content => $csr.to_json_pretty()
    }
    unless defined(File[$_outdir]) {
        file {$_outdir:
            ensure  => stdlib::ensure($ensure, 'directory'),
            owner   => $owner,
            group   => $group,
            mode    => '0440',
            recurse => true,
            purge   => true,
        }
    }
    $tls_config = ($tls_cert and $tls_key) ? {
        true    => "-mutual-tls-client-cert ${tls_cert} -mutual-tls-client-key ${tls_key}",
        default => '',
    }
    $_label = $label ? {
        undef   => '',
        default => "-label ${label}",
    }
    $_profile = $profile ? {
        undef   => '',
        default => "-profile ${profile}",
    }
    $signer_args = $signer_config ? {
        Stdlib::HTTPUrl              => "-remote ${signer_config} ${tls_config} ${_label}",
        Cfssl::Signer_config::Client => "-config ${signer_config['config_file']} ${tls_config} ${_label}",
        default                      => @("SIGNER_ARGS"/L)
            -ca=${signer_config['config_dir']}/ca/ca.pem \
            -ca-key=${signer_config['config_dir']}/ca/ca_key.pem \
            -config=${signer_config['config_dir']}/cfssl.conf \
            | SIGNER_ARGS
    }
    $cert_path = "${_outdir}/${safe_title}.pem"
    $key_path = "${_outdir}/${safe_title}-key.pem"
    $csr_pem_path = "${_outdir}/${safe_title}.csr"
    $gen_command = @("GEN_COMMAND"/L)
        /usr/bin/cfssl gencert ${signer_args} ${_profile} ${csr_json_path} \
        | /usr/bin/cfssljson -bare ${_outdir}/${safe_title}
        | GEN_COMMAND
    $sign_command = @("SIGN_COMMAND"/L)
        /usr/bin/cfssl sign ${signer_args} ${_profile} ${csr_pem_path} \
        | /usr/bin/cfssljson -bare ${_outdir}/${safe_title}
        | SIGN_COMMAND

    # TODO: would be nice to check its signed with the correct CA
    $test_command = @("TEST_COMMAND"/L)
        /usr/bin/test \
        "$(/usr/bin/openssl x509 -in ${cert_path} -noout -pubkey 2>&1)" == \
        "$(/usr/bin/openssl pkey -pubout -in ${key_path} 2>&1)"
        | TEST_COMMAND
    if $ensure == 'present' {
        exec{"Generate cert ${title}":
            command => $gen_command,
            unless  => $test_command,
        }
        if $auto_renew {
            exec {"renew certificate - ${title}":
                command => $sign_command,
                unless  => "/usr/bin/openssl x509 -in ${cert_path} -checkend ${renew_seconds}",
                require => Exec["Generate cert ${title}"]
            }
        }
    }

    file{[$cert_path, $key_path, $csr_pem_path]:
        ensure => $ensure_file,
        owner  => $owner,
        group  => $group,
        mode   => '0440',
    }
}
