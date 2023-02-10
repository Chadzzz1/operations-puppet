class profile::configmaster(
    $conftool_prefix                    = lookup('conftool_prefix'),
    Stdlib::Host $server_name           = lookup('profile::configmaster::server_name'),
    Array[Stdlib::Host] $server_aliases = lookup('profile::configmaster::server_aliases'),
) {
    $real_server_aliases = $server_aliases + [
        'pybal-config',
    ]

    $document_root = '/srv/config-master'
    $protected_uri = '/nda'
    $nda_dir       = "${document_root}${protected_uri}"

    file { [$document_root, $nda_dir]:
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
    }

    file {"${nda_dir}/README.html":
        ensure  => file,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => '<html><head><title>NDA</title><body>Folder containing NDA protected content</body></html>',
    }

    # Dump a list of abuse_networks for NDA users to view
    # unfortunately this does not preserve the comments
    file {"${nda_dir}/abuse_networks.txt":
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => '/etc/ferm/conf.d/00_defs_requestctl',
    }

    file {"${nda_dir}/abuse_networks.yaml":
        ensure  => absent,
    }

    # The contents of these files are managed by puppet-merge, but user
    # gitpuppet can't/shouldn't be able to create files under $document_root.
    # So puppet makes sure the file at least exists, and then puppet-merge
    # can write.
    file { "${document_root}/puppet-sha1.txt":
        ensure => present,
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
        ensure => present,
        owner  => 'gitpuppet',
        group  => 'gitpuppet',
        mode   => '0644',
    }

    # Write pybal pools
    class { '::pybal::web':
        ensure   => present,
        root_dir => $document_root,
        services => wmflib::service::fetch(true),
    }

    # TLS termination
    include profile::tlsproxy::envoy
    httpd::conf { 'configmaster_port':
        content => "Listen 80\n"
    }
    profile::idp::client::httpd::site{ $server_name:
        document_root    => $document_root,
        server_aliases   => $real_server_aliases,
        protected_uri    => $protected_uri,
        vhost_content    => 'profile/configmaster/config-master.conf.erb',
        proxied_as_https => true,
        required_groups  => [
            'cn=ops,ou=groups,dc=wikimedia,dc=org',
            'cn=wmf,ou=groups,dc=wikimedia,dc=org',
            'cn=nda,ou=groups,dc=wikimedia,dc=org',
        ],
    }

    ferm::service { 'pybal_conf-http':
        proto  => 'tcp',
        port   => 80,
        srange => '$PRODUCTION_NETWORKS',
    }

    class { 'ssh::publish_fingerprints':
        document_root => $document_root,
    }
}
