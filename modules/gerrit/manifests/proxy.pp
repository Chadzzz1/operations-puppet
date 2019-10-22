# sets up a TLS proxy for Gerrit
class gerrit::proxy(
    Stdlib::Ipv4 $ipv4,
    Stdlib::Fqdn $host                           = $::gerrit::host,
    Boolean $replica                             = false,
    Boolean $maint_mode                          = false,
    Hash $cache_text_nodes                       = $::gerrit::cache_text_nodes,
    Boolean $use_acmechief                       = false,
    Optional[Stdlib::Ipv6] $ipv6,
    Optional[Array[Stdlib::Fqdn]] $replica_hosts   = $::gerrit::reploca_hosts,
    ) {

    if $replica {
        $tls_host = $replica_hosts[0]
    } else {
        $tls_host = $host
    }

    monitoring::service { 'https':
        description   => 'HTTPS',
        check_command => "check_ssl_on_host_port_letsencrypt!${tls_host}!${tls_host}!443",
        contact_group => 'admins,gerrit',
        notes_url     => 'https://phabricator.wikimedia.org/project/view/330/',
    }

    $ssl_settings = ssl_ciphersuite('apache', 'mid', true)

    httpd::site { $tls_host:
        content => template('gerrit/apache.erb'),
    }

    # Let Apache only listen on the service IP.
    file { '/etc/apache2/ports.conf':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('gerrit/apache.ports.conf.erb'),
    }

    $robots = ['User-Agent: *', 'Disallow: /g', 'Disallow: /r/plugins/gitiles', 'Crawl-delay: 1']
    file { '/var/www/robots.txt':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => inline_template("<%= @robots.join('\n') %>"),
    }

    # Error page stuff
    file { '/var/www/error.html':
        ensure  => present,
        owner   => 'root',
        group   => 'root',
        mode    => '0444',
        content => template('gerrit/error.html.erb'),
    }
    file { '/var/www/page-bkg.cache.jpg':
        ensure => 'link',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        target => '/var/lib/gerrit2/review_site/static/page-bkg.cache.jpg',
    }
    file { '/var/www/wikimedia-codereview-logo.cache.png':
        ensure => 'link',
        owner  => 'root',
        group  => 'root',
        mode   => '0444',
        source => '/var/lib/gerrit2/review_site/static/wikimedia-codereview-logo.cache.png',
    }
}
