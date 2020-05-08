# Class: puppetmaster
#
# This class installs a Puppetmaster
#
# Parameters
#    - $bind_address:
#        The IP address Apache will bind to
#    - $verify_client:
#        Whether apache mod_ssl will verify the client (SSLVerifyClient option)
#    - $allow_from:
#        Adds an Allow from statement (order Allow,Deny), limiting access
#        to the passenger service.
#    - $deny_from:
#        Adds a Deny from statement (order Allow,Deny), limiting access
#        to the passenger service.
#    - $config:
#        Hash containing all config settings for the [master] section of
#        puppet.conf (ini-style)
#    - $workers:
#        Array of hashes in the form. If 'loadfactor' is omitted, it is assumed to
#        be equal to 1.
#        An 'offline' parameter is supported to allow fully depooling a host
#        without removing it from the stanza.
#         [{ 'worker' => 'worker1.example.com', loadfactor => '1' }]
#    - $hiera_config:
#        Specifies which file to use for hiera.yaml.  Defaults to $::realm
#    - $is_git_master:
#        If True, the git private repository here will be considered a master
#    - $secure_private:
#        If true, some magic is done to have local repositories and sync between puppetmasters.
#        Otherwise, /etc/puppet/private will be labs/private.git.
#    - $extra_auth_rules:
#        String - extra authentication rules to add before the default policy.
#    - $prevent_cherrypicks:
#        Bool - use git hooks to prevent cherry picking on top of the git repo
#    - $git_user
#        String - name of user who should own the git repositories
#    - $git_group
#        String - name of group which should own the git repositories
#    - $enable_geoip
#        Bool - Provision ::puppetmaster::geoip for serving clients who use
#        the ::geoip::data::puppet class in their manifests
class puppetmaster(
    $server_name='puppet',
    $bind_address='*',
    $verify_client='optional',
    $deny_from=[],
    $server_type='standalone',
    $workers=undef,
    $config={},
    $allow_from = [
        '*.wikimedia.org',
        '*.eqiad.wmnet',
        '*.ulsfo.wmnet',
        '*.esams.wmnet',
        '*.codfw.wmnet',
        '*.eqsin.wmnet',
    ],
    $is_git_master=false,
    $hiera_config=$::realm,
    $secure_private=true,
    $extra_auth_rules='',
    $prevent_cherrypicks=true,
    $git_user='gitpuppet',
    $git_group='gitpuppet',
    Boolean $enable_geoip = true,
    Stdlib::Host $ca_server = $facts['fqdn'],
    Integer[1,2] $ssl_verify_depth = 1
){

    $gitdir = '/var/lib/git'
    $volatiledir = '/var/lib/puppet/volatile'

    # Require /etc/puppet.conf to be in place,
    # so the postinst scripts do the right things.
    class { '::puppetmaster::config':
        config      => $config,
        server_type => $server_type,
    }

    package { [
        'puppet-master',
        'vim-puppet',
        'rails',
        'ruby-json',
        ]:
        ensure  => present,
    }

    class { '::puppetmaster::passenger':
        bind_address  => $bind_address,
        verify_client => $verify_client,
        allow_from    => $allow_from,
        deny_from     => $deny_from,
    }

    $ssl_settings = ssl_ciphersuite('apache', 'compat')

    # path and name change with puppet 4 packages
    $puppetmaster_rack_path = '/usr/share/puppet/rack/puppet-master'

    # Part dependent on the server_type
    case $server_type {
        'frontend': {

            httpd::site { 'puppetmaster.wikimedia.org':
                ensure => absent,
            }

            httpd::site { 'puppetmaster-backend':
                content      => template('puppetmaster/puppetmaster-backend.conf.erb'),
            }
        }
        'backend': {
            httpd::site { 'puppetmaster-backend':
                content => template('puppetmaster/puppetmaster-backend.conf.erb'),
            }
        }
        default: {
            httpd::site { 'puppetmaster.wikimedia.org':
                content => template('puppetmaster/puppetmaster.erb'),
            }
        }
    }

    class { '::puppetmaster::ssl':
        server_name => $server_name,
    }

    class { '::puppetmaster::gitclone':
        secure_private      => $secure_private,
        is_git_master       => $is_git_master,
        prevent_cherrypicks => $prevent_cherrypicks,
        user                => $git_user,
        group               => $git_group,
    }

    include ::puppetmaster::monitoring

    if has_key($config, 'storeconfigs_backend') and $config['storeconfigs_backend'] == 'puppetdb' {
        $has_puppetdb = true
    } else {
        $has_puppetdb = false
    }

    class { '::puppetmaster::scripts' :
        has_puppetdb => $has_puppetdb,
        ca_server    => $ca_server,
    }

    if $enable_geoip {
        class { '::puppetmaster::geoip': }
    }
    include ::puppetmaster::gitpuppet
    include ::puppetmaster::generators

    file { '/etc/puppet/auth.conf':
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('puppetmaster/auth-master.conf.erb'),
    }

    $hiera_source = "puppet:///modules/puppetmaster/${hiera_config}.hiera.yaml"

    # This is required to talk to our custom enc
    require_package('ruby-httpclient')
    class { '::puppetmaster::hiera':
        source => $hiera_source,
    }

    # Small utility to generate ECDSA certs and submit the CSR to the puppet master
    file { '/usr/local/bin/puppet-ecdsacert':
        ensure => present,
        source => 'puppet:///modules/puppetmaster/puppet_ecdsacert.rb',
        mode   => '0550',
        owner  => 'root',
        group  => 'root',
    }
    file { '/usr/local/bin/puppet-wildcardsign':
        ensure => absent,
    }
}
