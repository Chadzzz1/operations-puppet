# == Class: scap
#
# Common role for scap masters and targets
#
# == Parameters:
#  [*deployment_server*]
#    Server that provides git repositories for scap3. Default 'deployment'.
#
#  [*wmflabs_master*]
#    Master scap rsync host in the wmflabs domain.
#    Default 'deployment-deploy01.deployment-prep.eqiad.wmflabs'.
class scap (
    $deployment_server = 'deployment',
    $wmflabs_master = 'deployment-deploy01.deployment-prep.eqiad.wmflabs',
    $version = 'present',
    Stdlib::Port::Unprivileged $php7_admin_port = 9181,
) {
    require git::lfs

    package { 'scap':
        ensure => $version,
    }

    file { '/etc/scap.cfg':
        content => template('scap/scap.cfg.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
    }

    require_package([
        'python-psutil',
        'python-netifaces',
        'python-yaml',
        'python-requests',
        'python-jinja2',
    ])
}
