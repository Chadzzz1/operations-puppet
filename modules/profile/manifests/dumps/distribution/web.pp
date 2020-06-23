class profile::dumps::distribution::web (
    $do_acme = lookup('do_acme'),
    $datadir = lookup('profile::dumps::distribution::basedatadir'),
    $xmldumpsdir = lookup('profile::dumps::distribution::xmldumpspublicdir'),
    $miscdatasetsdir = lookup('profile::dumps::distribution::miscdumpsdir'),
){
    # includes module for bandwidth limits
    class { '::nginx':
        variant => 'extras',
    }

    class { '::sslcert::dhparam': }
    class {'::dumps::web::xmldumps':
        do_acme          => $do_acme,
        datadir          => $datadir,
        xmldumpsdir      => $xmldumpsdir,
        miscdatasetsdir  => $miscdatasetsdir,
        htmldumps_server => 'francium.eqiad.wmnet',
        xmldumps_server  => 'dumps.wikimedia.org',
        webuser          => 'dumpsgen',
        webgroup         => 'dumpsgen',
    }

    # copy web server logs to stat host
    if $do_acme {
      class {'::dumps::web::rsync::nginxlogs':
          dest => 'stat1007.eqiad.wmnet::dumps-webrequest/',
      }
    }

    ferm::service { 'xmldumps_http':
        proto => 'tcp',
        port  => '80',
    }

    ferm::service { 'xmldumps_https':
        proto => 'tcp',
        port  => '443',
    }
}
