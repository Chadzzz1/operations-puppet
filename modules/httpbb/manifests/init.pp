# == Class httpbb
#
# Installs the httpbb tool for blackbox testing an HTTP server.
#
# == Parameters
# - $install_dir: Directory to install the httpbb binary.
# - $tests_dir: Directory to install test suite YAML files, supplied as
#               httpbb::test_suite resources.
class httpbb(
    Stdlib::Unixpath $install_dir = '/srv/deployment/httpbb',
    Stdlib::Unixpath $tests_dir = '/srv/deployment/httpbb-tests',
){
    require_package('python3-attr', 'python3-clustershell', 'python3-jsonschema', 'python3-requests', 'python3-requests-toolbelt', 'python3-yaml')

    git::clone { 'operations/software/httpbb':
        directory => $install_dir,
        branch    => 'master',
    }

    file { '/usr/local/bin/httpbb':
        ensure  => file,
        content => template('httpbb/httpbb.sh.erb'),
        owner   => 'root',
        group   => 'root',
        mode    => '0555',
    }

    file { $tests_dir:
        ensure => directory,
    }
}
