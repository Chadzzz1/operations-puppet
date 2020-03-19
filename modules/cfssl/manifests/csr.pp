# @summary a resource for creating csr json files
define cfssl::csr (
    Cfssl::Key                    $key,
    Array[Cfssl::Name]            $names,
    Boolean                       $sign  = true,
    Optional[Array[Stdlib::Host]] $hosts = [],
) {
    include cfssl

    if $key['algo'] == 'rsa' and $key['size'] < 2048 {
        fail('RSA keys must be at least 2048 bytes')
    }
    $safe_title = $title.regsubst('[^\w\-]', '_', 'G')
    $csr_file = "${cfssl::csr_dir}/${safe_title}.csr"
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
        'CN'    => $title,
        'hosts' => $hosts,
        'key'   => $key,
        'names' => $_names,
    }
    file{$csr_file:
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0400',
        content => $csr.to_json_pretty()
    }
    if $sign {
        exec{"Sign ${csr_file}":
            command => "/usr/bin/cfssl sign -ca ${cfssl::ca_file} -ca-key ${cfssl::ca_key_file} ${csr_file}"
        }
    }
}
