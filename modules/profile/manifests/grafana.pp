# @summary Grafana is a dashboarding webapp for Graphite.
# @param secret_key the secret key
# @param admin_password the admin password
# @param config a hash of config settings.  This paramater uses a 'deep' merge strategy
# @param ldap a Hash of ldap servers
# @param wpt_graphite_proxy_port If set  Configure a local Apache which will serve as
#        a reverse proxy for performance-team's Graphite instance.
class profile::grafana (
    Stdlib::Fqdn $domain         = lookup('profile::grafana::domain'),
    String       $secret_key     = lookup('profile::grafana::secret_key'),
    String       $admin_password = lookup('profile::grafana::admin_password'),
    Hash         $config         = lookup('profile::grafana::config'),
    Hash         $ldap           = lookup('profile::grafana::ldap', {'default_value' => undef}),
    Optional[Stdlib::Port] $wpt_graphite_proxy_port = lookup('profile::grafana::wpt_graphite_proxy_port',
                                                            {'default_value' => undef}),
) {

    include profile::backup::host

    include passwords::ldap::production

    include profile::base::firewall

    # This isn't needed by grafana, but is handy for inspecting its database.
    require_package(['sqlite3'])

    $base_config = {
        # Configuration settings for /etc/grafana/grafana.ini.
        # See <http://docs.grafana.org/installation/configuration/>.

        # Only listen on loopback, because we'll have a local Apache
        # instance acting as a reverse-proxy.
        'server'     => {
            http_addr   => '127.0.0.1',
            domain      => $domain,
            protocol    => 'http',
            enable_gzip => true,
        },

        # Grafana needs a database to store users and dashboards.
        # sqlite3 is the default, and it's perfectly adequate.
        'database'   => {
            'type' => 'sqlite3',
            'path' => 'grafana.db',
        },

        'security'   => {
            secret_key       => $secret_key,
            admin_password   => $admin_password,
            disable_gravatar => true,
        },

        # Disabled auth.basic, because it conflicts with auth.proxy.
        # See <https://github.com/grafana/grafana/issues/2357>
        'auth.basic' => {
            enabled => false,
        },

        'auth.proxy' => {
            enabled      => false,
        },

        # Since we require users to be members of a trusted LDAP group
        # membership to log in to Grafana, we can assume all users are
        # trusted, and can assign to them the 'Editor' role (rather
        # than 'Viewer', the default).
        'users'      => {
            auto_assign_org_role => 'Editor',
            allow_org_create     => false,
            allow_sign_up        => false,
        },

        'session'    => {
            provider      => 'file',
            file          => 'sessions.db',
            cookie_secure => true,
        },

        # We don't like it when software phones home.
        # Don't send anonymous usage stats to stats.grafana.org,
        # and don't check for updates automatically.
        'analytics'  => {
            reporting_enabled => false,
            check_for_updates => false,
        },

        # Also, don't allow publishing to raintank.io.
        'snapshots'  => {
            external_enabled => false,
        },
    }
    $end_config = deep_merge($base_config, $config)

    class { '::grafana':
        config => $end_config,
        ldap   => $ldap,
    }

    ferm::service { 'grafana_http':
        proto  => 'tcp',
        port   => '80',
        srange => '$CACHES',
    }

    # Override the default home dashboard with something custom.
    # This will be doable via a preference in the future. See:
    # <https://groups.io/org/groupsio/grafana/thread/home_dashboard_in_grafana_2_0/43631?threado=120>
    file { '/usr/share/grafana/public/dashboards/home.json':
        source  => 'puppet:///modules/grafana/home.json',
        require => Package['grafana'],
        notify  => Service['grafana-server'],
    }

    file { '/usr/share/grafana/public/img/grafana_icon.svg':
        source  => 'puppet:///modules/role/grafana/wikimedia-logo.svg',
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        require => Package['grafana'],
    }

    httpd::site { $domain:
        content => template('profile/apache/sites/grafana.erb'),
        require => Class['::grafana'],
    }

    monitoring::service { 'grafana':
        description   => $domain,
        check_command => "check_http_url!${domain}!/",
        notes_url     => 'https://wikitech.wikimedia.org/wiki/Grafana.wikimedia.org',
    }

    # Configure a local Apache which will serve as a reverse proxy for performance-team's
    # Graphite instance.  That Apache uses our outbound proxies as its own forward proxy
    # for those requests.  Despite being a mouthful, this seems preferable to setting the
    # http_proxy env var for the grafana process itself (and then also needing to set
    # no_proxy for every datasource URL other than the one of the perf-team Graphite).
    # https://phabricator.wikimedia.org/T231870
    # Could be retired if https://github.com/grafana/grafana/issues/15045 is implemented.
    if $wpt_graphite_proxy_port {
        httpd::site { 'proxy-wpt-graphite':
            content => template('profile/apache/sites/grafana-wpt-graphite-proxy.erb'),
        }
    }

    backup::set { 'var-lib-grafana':
        require => Class['::grafana'],
    }

    # https://phabricator.wikimedia.org/T147329
    # We clone this, but need to symlink into the 'dist' directory for plugin to actually work
    git::clone { 'operations/software/grafana/simple-json-datasource':
        ensure    => present,
        branch    => '3.0',
        directory => '/usr/share/grafana/public/app/plugins/datasource/simple-json-datasource',
        require   => Package['grafana'],
    }

    file { '/usr/share/grafana/public/app/plugins/datasource/datasource-plugin-genericdatasource':
        ensure  => link,
        target  => '/usr/share/grafana/public/app/plugins/datasource/simple-json-datasource/dist',
        require => Git::Clone['operations/software/grafana/simple-json-datasource'],
    }

    base::service_auto_restart { 'apache2': }
}
