class profile::kubernetes::deployment_server::mediawiki::release (
    Hash[String, Profile::Mediawiki_deployment] $mw_releases = lookup('profile::kubernetes::deployment_server::mediawiki::release::mw_releases'),
    Stdlib::Unixpath $general_dir = lookup('profile::kubernetes::deployment_server::global_config::general_dir', {default_value => '/etc/helmfile-defaults'}),
) {
    $kubernetes_release_dir = "${general_dir}/mediawiki/release"
    file { $kubernetes_release_dir:
        ensure => directory,
        owner  => 'mwbuilder',
        group  => 'mwdeploy',
        mode   => '0775',
    }

    # Initialize the git repository if not present.
    # The repositories should be kept in sync via scap sync-masters.
    exec { '/usr/bin/git init':
        cwd     => $kubernetes_release_dir,
        creates => "${kubernetes_release_dir}/.git",
        user    => 'mwbuilder',
        group   => 'mwdeploy'
    }

    # Although it can be recreated somehow by scap, we don't want
    # to lose history.
    backup::set { 'mediawiki-k8s-releases-repository': }

    # Mediawiki deployment configuration
    file { "${general_dir}/mediawiki-deployments.yaml":
        ensure  => present,
        content => to_yaml($mw_releases),
        owner   => 'root',
        group   => 'root',
    }
}
