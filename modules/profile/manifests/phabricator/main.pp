# SPDX-License-Identifier: Apache-2.0
# phabricator instance
#
class profile::phabricator::main (
    String                      $domain             = lookup('phabricator_domain',
                                                      { 'default_value' => 'phabricator.wikimedia.org' }),
    String                      $altdom             = lookup('phabricator_altdomain',
                                                      { 'default_value' => 'phab.wmfusercontent.org' }),
    Stdlib::Fqdn                $mysql_master       = lookup('phabricator::mysql::master',
                                                      { 'default_value' => 'localhost' }),
    String                      $mysql_master_port  = lookup('phabricator::mysql::master::port',
                                                      { 'default_value' => '3306' }),
    String                      $mysql_slave        = lookup('phabricator::mysql::slave',
                                                      { 'default_value' => 'localhost' }),
    String                      $mysql_slave_port   = lookup('phabricator::mysql::slave::port',
                                                      { 'default_value' => '3323' }),
    Stdlib::Unixpath            $phab_root_dir      = lookup('phabricator_root_dir',
                                                      { 'default_value' => '/srv/phab'}),
    String                      $deploy_target      = lookup('phabricator_deploy_target',
                                                      { 'default_value' => 'phabricator/deployment'}),
    Optional[String]            $deploy_user        = lookup('phabricator_deploy_user',
                                                      { 'default_value' => 'phab-deploy' }),
    Optional[String]            $phab_app_user      = lookup('phabricator_app_user',
                                                      { 'default_value' => undef }),
    Optional[String]            $phab_app_pass      = lookup('phabricator_app_pass',
                                                      { 'default_value' => undef }),
    Optional[String]            $phab_daemons_user  = lookup('phabricator_daemons_user',
                                                      { 'default_value' => undef }),
    Optional[String]            $phab_manifest_user = lookup('phabricator_manifest_user',
                                                      { 'default_value' => undef }),
    Optional[String]            $phab_manifest_pass = lookup('phabricator_manifest_pass',
                                                      { 'default_value' => undef }),
    Optional[String]            $phab_daemons_pass  = lookup('phabricator_daemons_pass',
                                                      { 'default_value' => undef }),
    Optional[String]            $phab_mysql_admin_user=
                                                      lookup('phabricator_admin_user',
                                                      { 'default_value' => undef }),
    Optional[String]            $phab_mysql_admin_pass =
                                                      lookup('phabricator_admin_pass',
                                                      { 'default_value' => undef }),
    Stdlib::Fqdn                $phab_diffusion_ssh_host=
                                                      lookup('phabricator_diffusion_ssh_host',
                                                      { 'default_value' => 'git-ssh.wikimedia.org' }),
    Boolean                     $enable_vcs         = lookup('phabricator::vcs::enable',
                                                      { 'default_value' => false }),
    Boolean                     $use_lvs            = lookup('profile::phabricator::main::use_lvs',
                                                      { 'default_value' => false }),
    Optional[Stdlib::IP::Address::V4] $vcs_ip_v4    = lookup('phabricator::vcs::address::v4',
                                                      { 'default_value' => undef }),
    Optional[Stdlib::IP::Address::V6] $vcs_ip_v6    = lookup('phabricator::vcs::address::v6',
                                                      { 'default_value' => undef }),
    Array                       $cluster_search     = lookup('phabricator_cluster_search'),
    Optional[String]            $active_server      = lookup('phabricator_server',
                                                      { 'default_value' => undef }),
    Array                       $phabricator_servers= lookup('phabricator_servers',
                                                      { 'default_value' => undef }),
    Boolean                     $logmail            = lookup('phabricator_logmail',
                                                      { 'default_value' => false }),
    Boolean                     $aphlict_enabled    = lookup('phabricator_aphlict_enabled',
                                                      { 'default_value' => false }),
    Boolean                     $aphlict_ssl        = lookup('phabricator_aphlict_enable_ssl',
                                                      { 'default_value' => false }),
    Optional[Stdlib::Unixpath]  $aphlict_cert       = lookup('phabricator_aphlict_cert',
                                                      { 'default_value' => undef }),
    Optional[Stdlib::Unixpath]  $aphlict_key        = lookup('phabricator_aphlict_key',
                                                      { 'default_value' => undef }),
    Optional[Stdlib::Unixpath]  $aphlict_chain      = lookup('phabricator_aphlict_chain',
                                                      { 'default_value' => undef }),
    Hash                        $rate_limits        = lookup('profile::phabricator::main::rate_limits',
                                                      { 'default_value' => {
                                                            'request' => 0,
                                                            'connection' => 0}
                                                      }),
    Integer                     $phd_taskmasters    = lookup('phabricator_phd_taskmasters',
                                                      { 'default_value' => 10 }),
    Integer                     $opcache_validate   = lookup('phabricator_opcache_validate',
                                                      { 'default_value' => 0 }),
    String                      $timezone           = lookup('phabricator_timezone',
                                                      { 'default_value' => 'UTC' }),
    Boolean                     $dump_enabled       = lookup('profile::phabricator::main::dump_enabled',
                                                      { 'default_value' => false }),

    String                      $http_srange        = lookup('profile::phabricator::main::http_srange'),

    Boolean                     $manage_scap_user   = lookup('profile::phabricator::main::manage_scap_user',
                                                      { 'default_value' => true }),
    Array[Stdlib::Fqdn]         $dumps_rsync_clients = lookup('profile::phabricator::main::dumps_rsync_clients'),
    String                      $gitlab_api_key     = lookup('profile::phabricator::main::gitlab_api_key',
                                                      { 'default_value' => '' }),
    Stdlib::Unixpath            $database_datadir   = lookup('profile::phabricator::main::database_datadir',
                                                      {default_value => '/var/lib/mysql'}),
) {

    $mail_alias = $::realm ? {
        'production' => 'wikimedia.org',
        default      => 'wmflabs.org',
    }

    mailalias { 'root':
        recipient => "root@${mail_alias}",
    }

    # in cloud, use a local db server
    if $::realm == 'labs' {
        class { 'profile::mariadb::generic_server':
            datadir => $database_datadir,
        }
    }

    include passwords::phabricator
    include passwords::mysql::phabricator

    # things configured differently if we are on the
    # active "phabricator_server" defined in Hiera
    if $::fqdn == $active_server {
        $ferm_ensure = 'present'
        if $aphlict_enabled {
            $aphlict_ensure = 'present'
        } else {
            $aphlict_ensure = 'absent'
        }
        $mysql_host = $mysql_master
        $mysql_port = $mysql_master_port
        systemd::unmask { 'phd.service': }
        $phd_service_ensure = 'running'
        $phd_service_enable = true
    } else {
        $ferm_ensure = 'absent'
        $aphlict_ensure = 'absent'
        $mysql_host = $mysql_slave
        $mysql_port = $mysql_slave_port
        $phd_service_ensure = 'stopped'
        $phd_service_enable = false
        systemd::mask { 'phd.service': }
    }

    # in prod we just open port 80 for deployment_hosts for testing, caching layer speaks TLS to envoy
    # in cloud we need to also open it for proxies which don't speak TLS to backends
    ferm::service { 'phabmain_http':
        ensure => present,
        proto  => 'tcp',
        port   => '80',
        srange => $http_srange,
    }

    if $aphlict_enabled {
        $notification_servers = [
            {
                'type'      => 'client',
                'host'      => $domain,
                'port'      => 22280,
                'protocol'  => 'https',
            },
            {
                'type'      => 'admin',
                'host'      => 'localhost',
                'port'      => 22281,
                'protocol'  => 'http',
            }
        ]
    } else {
        $notification_servers = []
    }

    # logmail must be explictly enabled in Hiera with 'phabricator_logmail: true'
    # to avoid duplicate mails from labs and standby (T173297)
    $logmail_ensure = $logmail ? {
        true    => 'present',
        default => 'absent',
    }

    if $phab_app_user == undef {
        $app_user = $passwords::mysql::phabricator::app_user
    } else {
        $app_user = $phab_app_user
    }
    if $phab_app_pass == undef {
        $app_pass = $passwords::mysql::phabricator::app_pass
    } else {
        $app_pass = $phab_app_pass
    }

    # As of T146055: phd_user and phd_pass exist to separate privileges. phd_user could eventually
    # be granted less or different privs in mysql as compared to app_user.
    # phd could also run on a different hardware from the web frontend.
    if $phab_daemons_user == undef {
        $daemons_user = $passwords::mysql::phabricator::phd_user
    } else {
        $daemons_user = $phab_daemons_user
    }
    if $phab_daemons_pass == undef {
        $daemons_pass = $passwords::mysql::phabricator::phd_pass
    } else {
        $daemons_pass = $phab_daemons_pass
    }

    if $phab_manifest_user == undef {
        $manifest_user = $passwords::mysql::phabricator::manifest_user
    } else {
        $manifest_user = $phab_manifest_user
    }
    if $phab_manifest_pass == undef {
        $manifest_pass = $passwords::mysql::phabricator::manifest_pass
    } else {
        $manifest_pass = $phab_manifest_pass
    }

    if $phab_mysql_admin_user == undef {
        $mysql_admin_user = $passwords::mysql::phabricator::admin_user
    } else {
        $mysql_admin_user = $phab_mysql_admin_user
    }

    if $phab_mysql_admin_pass == undef {
        $mysql_admin_pass = $passwords::mysql::phabricator::admin_pass
    } else {
        $mysql_admin_pass = $phab_mysql_admin_pass
    }

    $mail_config = [
        {
            'key'      => 'wikimedia-smtp',
            'type'     => 'smtp',
            'options'  => {
                'host' => 'localhost',
                'port' => 25,
            }
        }
    ]

    # Collect an array of all ipaddresses
    # in reality $facts['networking']['ipaddress6'] will be the address traffic is sourced from but it
    # does no harm adding all of them
    # TODO: move this to a general function i.e. network::ipaddresses(ipv4=true, ipv6=true)
    $trusted_proxies = $facts['networking']['interfaces'].reduce([]) |$memo, $value| {
        $bindings = $value[1].has_key('bindings') ? {
            true    => $value[1]['bindings'].map |$binding| { $binding['address'] },
            default => [],
        }
        $bindings6 = $value[1].has_key('bindings6') ? {
            true    => $value[1]['bindings6'].map |$binding| { $binding['address'] },
            default => [],
        }
        $memo + $bindings + $bindings6
    }.sort

    class { 'phabricator':
        deploy_target      => $deploy_target,
        deploy_user        => $deploy_user,
        phabdir            => $phab_root_dir,
        serveraliases      => [ $altdom,
                              'bugzilla.wikimedia.org',
                              'bugs.wikimedia.org' ],
        trusted_proxies    => $trusted_proxies,
        enable_vcs         => $enable_vcs,
        mysql_admin_user   => $mysql_admin_user,
        mysql_admin_pass   => $mysql_admin_pass,
        libraries          => [ "${phab_root_dir}/libext/misc",
                              "${phab_root_dir}/libext/ava/src",
                              "${phab_root_dir}/libext/translations/src" ],
        settings           => {
            'cluster.search'                 => $cluster_search,
            'darkconsole.enabled'            => false,
            'differential.allow-self-accept' => true,
            'phabricator.base-uri'           => "https://${domain}",
            'security.alternate-file-domain' => "https://${altdom}",
            'mysql.host'                     => $mysql_host,
            'mysql.port'                     => $mysql_port,
            'cluster.mailers'                => $mail_config,
            'metamta.default-address'        => "no-reply@${domain}",
            'metamta.reply-handler-domain'   => $domain,
            'repository.default-local-path'  => '/srv/repos',
            'phd.taskmasters'                => $phd_taskmasters,
            'events.listeners'               => [],
            'diffusion.allow-http-auth'      => true,
            'diffusion.ssh-host'             => $phab_diffusion_ssh_host,
            'gitblit.hostname'               => 'git.wikimedia.org',
            'notification.servers'           => $notification_servers,
        },
        config_deploy_vars => {
            'phabricator' => {
                'www'       => {
                    'database_username' => $app_user,
                    'database_password' => $app_pass,
                },
                'mail'      => {
                    'database_username' => $app_user,
                    'database_password' => $app_pass,
                },
                'phd'       => {
                    'database_username' => $daemons_user,
                    'database_password' => $daemons_pass,
                },
                'vcs'       => {
                    'database_username' => $daemons_user,
                    'database_password' => $daemons_pass,
                },
                'redirects' => {
                    'database_username' => $daemons_user,
                    'database_password' => $daemons_pass,
                    'database_host'     => $mysql_host,
                    'field_index'       => '4rRUkCdImLQU',
                },
                'local'     => {
                    'base_uri'                  => "https://${domain}",
                    'alternate_file_domain'     => "https://${altdom}",
                    'mail_default_address'      => "no-reply@${domain}",
                    'mail_reply_handler_domain' => $domain,
                    'phd_taskmasters'           => $phd_taskmasters,
                    'ssh_host'                  => $phab_diffusion_ssh_host,
                    'notification_servers'      => $notification_servers,
                    'cluster_search'            => $cluster_search,
                    'cluster_mailers'           => $mail_config,
                    'database_host'             => $mysql_host,
                    'database_port'             => $mysql_port,
                    'gitlab_api_key'            => $gitlab_api_key,
                },
            },
        },
        opcache_validate   => $opcache_validate,
        timezone           => $timezone,
        phd_service_ensure => $phd_service_ensure,
        phd_service_enable => $phd_service_enable,
        manage_scap_user   => $manage_scap_user,
    }

    $fpm_config = {
        'date'                   => {
            'timezone' => $timezone,
        },
        'opcache'                   => {
            'memory_consumption'      => 128,
            'interned_strings_buffer' => 16,
            'max_accelerated_files'   => 10000,
            'validate_timestamps'     => $opcache_validate,
        },
        'max_execution_time'  => 30,
        'post_max_size'       => '10M',
        'track_errors'        => 'Off',
        'upload_max_filesize' => '10M',
    }

    $core_extensions =  [
        'curl',
        'gd',
        'gmp',
        'intl',
        'mbstring',
        'ldap',
    ]

    $php_version='7.3'

    # Install the runtime
    class { '::php':
        ensure         => present,
        versions       => [$php_version],
        sapis          => ['cli', 'fpm'],
        config_by_sapi => {
            'fpm' => $fpm_config,
        },
    }

    $core_extensions.each |$extension| {
        php::extension { $extension:
            versioned_packages => true,
            sapis              => ['cli', 'fpm'],
        }
    }

    class { '::php::fpm':
        ensure => present,
        config => {
            'emergency_restart_interval' => '60s',
            'process.priority'           => -19,
        },
    }

    # Extensions that require configuration.
    php::extension {
        default:
            sapis        => ['cli', 'fpm'];
        'apcu':
            ;
        'mailparse':
            priority     => 21;
        'mysqlnd':
            install_packages => false,
            priority         => 10;
        'xml':
            versioned_packages => true,
            priority           => 15;
        'mysqli':
            package_overrides => {"${php_version}" =>"php${php_version}-mysql"},;
    }

    $num_workers = max(floor($facts['processors']['count'] * 1.5), 8)
    # These numbers need to be positive integers
    $max_spare = ceiling($num_workers * 0.3)
    $min_spare = ceiling($num_workers * 0.1)
    php::fpm::pool { 'www':
        version => $php_version,
        config  => {
            'pm'                   => 'dynamic',
            'pm.max_spare_servers' => $max_spare,
            'pm.min_spare_servers' => $min_spare,
            'pm.start_servers'     => $min_spare,
            'pm.max_children'      => $num_workers,
        }
    }

    class { '::phabricator::aphlict':
        ensure     => $aphlict_ensure,
        basedir    => $phab_root_dir,
        enable_ssl => $aphlict_ssl,
        sslcert    => $aphlict_cert,
        sslkey     => $aphlict_key,
        sslchain   => $aphlict_chain,
        require    => Class[phabricator],
    }

    if $enable_vcs {
    # This exists to offer git services at git-ssh.wikimedia.org.

        if $use_lvs {
            class { '::lvs::realserver': }
        }

        if $vcs_ip_v4 or $vcs_ip_v6 {
            interface::alias { 'phabricator vcs':
                ipv4 => $vcs_ip_v4,
                ipv6 => $vcs_ip_v6,
            }
        }
    }

    class { '::phabricator::tools':
        directory       => "${phab_root_dir}/tools",
        dbmaster_host   => $mysql_host,
        dbmaster_port   => $mysql_port,
        dbslave_host    => $mysql_slave,
        dbslave_port    => $mysql_slave_port,
        manifest_user   => $manifest_user,
        manifest_pass   => $manifest_pass,
        app_user        => $app_user,
        app_pass        => $app_pass,
        bz_user         => $passwords::mysql::phabricator::bz_user,
        bz_pass         => $passwords::mysql::phabricator::bz_pass,
        rt_user         => $passwords::mysql::phabricator::rt_user,
        rt_pass         => $passwords::mysql::phabricator::rt_pass,
        phabtools_cert  => $passwords::phabricator::phabtools_cert,
        phabtools_user  => $passwords::phabricator::phabtools_user,
        gerritbot_token => $passwords::phabricator::gerritbot_token,
        dump            => $dump_enabled,
        require         => Package[$deploy_target]
    }

    # Allow dumps servers to pull dump files.
    rsync::server::module { 'srv-dumps':
            path           => '/srv/dumps',
            read_only      => 'yes',
            hosts_allow    => $dumps_rsync_clients,
            auto_ferm      => true,
            auto_ferm_ipv6 => true,
    }

    # Allow pthers phab servers to pull tarballs with home dir files
    file { '/srv/homes': ensure => 'directory',}

    rsync::server::module { 'srv-homes':
            path           => '/srv/homes',
            read_only      => 'yes',
            hosts_allow    => $phabricator_servers,
            auto_ferm      => true,
            auto_ferm_ipv6 => true,
    }
    # Backup repositories
    backup::set { 'srv-repos': }

    class { '::exim4':
        variant => 'heavy',
        config  => template('role/exim/exim4.conf.phab.erb'),
        filter  => template('role/exim/system_filter.conf.erb'),
    }

    class { '::phabricator::mailrelay':
        default  => {
            maint    => false,
        },
        phab_bot => {
            root_dir => "${phab_root_dir}/phabricator/",
        },
    }

    # receive mail from mail smarthosts
    ferm::service { 'phabmain-smtp':
        ensure => $ferm_ensure,
        port   => '25',
        proto  => 'tcp',
        srange => inline_template('(<%= @mail_smarthost.map{|x| "@resolve(#{x})" }.join(" ") %>)'),
    }

    ferm::service { 'phabmain-smtp_ipv6':
        ensure => $ferm_ensure,
        port   => '25',
        proto  => 'tcp',
        srange => inline_template('(<%= @mail_smarthost.map{|x| "@resolve(#{x}, AAAA)" }.join(" ") %>)'),
    }

    prometheus::blackbox::check::tcp { 'phabricator-smtp':
        team     => 'serviceops-collab',
        severity => 'task',
        port     => 25,
    }

    # ssh between phabricator servers for clustering support
    $phabricator_servers_ferm = join($phabricator_servers, ' ')
    ferm::service { 'ssh_cluster':
        port   => '22',
        proto  => 'tcp',
        srange => "@resolve((${phabricator_servers_ferm}))",
    }

    if $aphlict_enabled {
        ferm::service { 'notification_server':
            ensure => $ferm_ensure,
            proto  => 'tcp',
            port   => '22280',
        }
    }

    # community metrics mail (T81784, T1003)
    phabricator::logmail {'community_metrics':
        ensure           => $logmail_ensure,
        rcpt_address     => 'wikitech-l@lists.wikimedia.org',
        sndr_address     => 'aklapper@wikimedia.org',
        monthday         => 1,
        require          => Package[$deploy_target],
        mysql_slave      => $mysql_slave,
        mysql_slave_port => $mysql_slave_port,
        mysql_db_name    => 'phabricator_maniphest',
    }

    # project changes mail (T85183)
    phabricator::logmail {'project_changes':
        ensure           => $logmail_ensure,
        rcpt_address     => [ 'phabricator-reports@lists.wikimedia.org' ],
        sndr_address     => 'aklapper@wikimedia.org',
        weekday          => 'Monday',
        require          => Package[$deploy_target],
        mysql_slave      => $mysql_slave,
        mysql_slave_port => $mysql_slave_port,
        mysql_db_name    => 'phabricator_project',
    }

    # multi-factor auth mail (T299403)
    phabricator::logmail {'mfa_check':
        ensure           => $logmail_ensure,
        rcpt_address     => [ 'aklapper@wikimedia.org' ],
        sndr_address     => 'aklapper@wikimedia.org',
        weekday          => 'Wednesday',
        require          => Package[$deploy_target],
        mysql_slave      => $mysql_slave,
        mysql_slave_port => $mysql_slave_port,
        mysql_db_name    => 'phabricator_user',
    }

    # Allow pulling /srv/repos data from the active server.
    rsync::server::module { 'srv-repos':
        ensure         => 'present',
        read_only      => 'yes',
        path           => '/srv/repos',
        hosts_allow    => $phabricator_servers,
        auto_ferm      => true,
        auto_ferm_ipv6 => true,
    }

    # Ship apache error logs to ELK - T141895
    rsyslog::input::file { 'apache2-error':
        path => '/var/log/apache2/*error*.log',
    }

    rsyslog::input::file { 'apache2-access':
        path => '/var/log/apache2/*access*.log',
    }

    file { '/usr/local/bin/chk_phuser':
        source => 'puppet:///modules/phabricator/chk_phuser.sh',
        owner  => 'root',
        group  => 'root',
        mode   => '0550',
    }

    # mysql read access for phab admins, in production (T238425)
    if $::realm == 'production' {
        $::admin::data['groups']['phabricator-admin']['members'].each |String $user| {
            file { "/home/${user}/.my.cnf":
                content => template('phabricator/my.cnf.erb'),
                owner   => $user,
                group   => 'root',
                mode    => '0440',
            }
        }
    }
}
