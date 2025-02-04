class profile::configmaster (
    $conftool_prefix                    = lookup('conftool_prefix'),
    Stdlib::Host $server_name           = lookup('profile::configmaster::server_name'),
    Array[Stdlib::Host] $server_aliases = lookup('profile::configmaster::server_aliases'),
    Boolean             $enable_nda     = lookup('profile::configmaster::enable_nda'),
) {
    $real_server_aliases = $server_aliases + [
        'pybal-config',
    ]

    $document_root = '/srv/config-master'
    $protected_uri = '/nda'
    $nda_dir       = "${document_root}${protected_uri}"
    $vhost_settings = { 'enable_nda' => $enable_nda }

    file { $document_root:
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    # gitpuppet can't/shouldn't be able to create files under $document_root.
    # So puppet makes sure the file at least exists, and then puppet-merge
    # can write.
    file { "${document_root}/puppet-sha1.txt":
        ensure => file,
        owner  => 'gitpuppet',
        group  => 'gitpuppet',
        mode   => '0644',
    }

    # copy mediawiki conftool-state file to configmaster so we can fetch it
    # from pcc and pontoon.
    file { "${document_root}/mediawiki.yaml":
        ensure => file,
        source => '/etc/conftool-state/mediawiki.yaml',
    }

    file { "${document_root}/labsprivate-sha1.txt":
        ensure => file,
        owner  => 'gitpuppet',
        group  => 'gitpuppet',
        mode   => '0644',
    }

    # Write pybal pools
    class { 'pybal::web':
        ensure   => present,
        root_dir => $document_root,
        services => wmflib::service::fetch(true),
    }

    class { 'ssh::publish_fingerprints':
        document_root => $document_root,
    }

    # TLS termination
    include profile::tlsproxy::envoy
    httpd::conf { 'configmaster_port':
        content => "Listen 80\n",
    }

    file {
        default:
            ensure => stdlib::ensure($enable_nda, file),
            owner  => 'root',
            group  => 'root',
            mode   => '0444';
        "${nda_dir}/abuse_networks.txt": ;
        "${nda_dir}/README.html":
            content => '<html><head><title>NDA</title><body>Folder containing NDA protected content</body></html>';
        $nda_dir:
            ensure => stdlib::ensure($enable_nda, directory),
            mode   => '0755';
    }

    if $enable_nda {
        File["${nda_dir}/abuse_networks.txt"] {
            source => '/etc/ferm/conf.d/00_defs_requestctl'
        }
        profile::idp::client::httpd::site { $server_name:
            document_root    => $document_root,
            server_aliases   => $real_server_aliases,
            protected_uri    => $protected_uri,
            vhost_content    => 'profile/configmaster/config-master.conf.erb',
            proxied_as_https => true,
            vhost_settings   => $vhost_settings,
            required_groups  => [
                'cn=ops,ou=groups,dc=wikimedia,dc=org',
                'cn=wmf,ou=groups,dc=wikimedia,dc=org',
                'cn=nda,ou=groups,dc=wikimedia,dc=org',
            ],
        }
    } else {
        $virtual_host = $server_name
        httpd::site { 'config-master':
            ensure   => present,
            priority => 50,
            content  => template('profile/configmaster/config-master.conf.erb'),
        }
    }
    # The contents of these files are managed by puppet-merge, but user
    ferm::service { 'pybal_conf-http':
        proto  => 'tcp',
        port   => 80,
        srange => '$PRODUCTION_NETWORKS',
    }
}
