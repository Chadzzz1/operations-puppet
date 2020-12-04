# Title should match the cfssl::signer title
define cfssl::ocsp (
    Stdlib::Fqdn                $common_name     = $facts['fqdn'],
    Stdlib::IP::Address         $listen_addr      = '127.0.0.1',
    Stdlib::Port                $listen_port      = 8889,
    Cfssl::Loglevel             $log_level        = 'info',
    Pattern[/\d+h/]             $refresh_interval = '96h',
    Array[Stdlib::Host]         $additional_names = [],
    Optional[Stdlib::Unixpath]  $responses_file   = undef,
    Optional[Stdlib::Unixpath]  $db_conf_file     = undef,
    Optional[Sensitive[String]] $key_content      = undef,
    Optional[String]            $cert_content     = undef,
    Optional[Stdlib::Unixpath]  $ca_file          = undef,
) {
    include cfssl
    include cfssl::client

    $safe_title     = $title.regsubst('\W', '_', 'G')
    $outdir         = "${cfssl::ssl_dir}/ocsp"
    $refresh_timer  = "cfssl-ocsprefresh-${safe_title}"
    $serve_service  = "cfssl-ocspserve@${safe_title}"
    $safe_cert_name = "OCSP ${title} ${common_name}".regsubst('[^\w\-]', '_', 'G')
    $key_path       = "${outdir}/${safe_cert_name}-key.pem"
    $cert_path      = "${outdir}/${safe_cert_name}.pem"

    $_db_conf_file   = pick($db_conf_file, "${cfssl::conf_dir}/db.conf")
    $_ca_file        = pick($ca_file, "${cfssl::conf_dir}/ca/ca.pem")
    $_responses_file = pick($responses_file, "${cfssl::ocsp_dir}/${safe_title}.ocsp")

    if ($key_content and !$cert_content) or ($cert_content and !$key_content) {
        fail('you must provide either both or neither key/cert_content')
    } elsif $key_content and $cert_content {

        file {$cert_path:
            owner   => 'root',
            group   => 'root',
            mode    => '0444',
            content => $cert_content,
            notify  => Service[$serve_service],
            #before  => Systemd::Timer::Job[$refresh_timer],
        }
        file {$key_path:
            owner     => 'root',
            group     => 'root',
            mode      => '0400',
            show_diff => false,
            content   => $key_content,
            notify    => Service[$serve_service],
            #before    => Systemd::Timer::Job[$refresh_timer],
        }
    } else {
        cfssl::cert{$safe_cert_name:
            common_name   => $common_name,
            label         => $safe_title,
            hosts         => $additional_names,
            profile       => 'ocsp',
            outdir        => $outdir,
            signer_config => {'config_file' => $cfssl::client::conf_file},
            tls_cert      => $facts['puppet_config']['hostcert'],
            tls_key       => $facts['puppet_config']['hostprivkey'],
            notify        => Service[$serve_service],
            #before        => Systemd::Timer::Job[$refresh_timer],
        }
    }
    $refresh_command = @("CMD"/L)
    /usr/local/sbin/cfssl-ocsprefresh \
        --responder-cert ${cert_path} --responder-key ${key_path} \
        --ca-file ${_ca_file} --responses_file ${_responses_file} \
        --restart-service ${serve_service} ${safe_title}
    | CMD

    systemd::service{$serve_service:
        ensure  => present,
        content => template('cfssl/cfssl-ocspserve.service.erb'),
        restart => true,
    }
    #systemd::timer::job{$refresh_timer:
    #    ensure   => present,
    #    user     => 'root',
    #    interval => {'start' => 'OnUnitInactiveSec', 'interval' => '1h'},
    #    command  => $refresh_command,
    #}
}
