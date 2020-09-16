# == Class profile::hue
#
# Installs Hue server.
#
class profile::hue (
    $hive_server_host           = hiera('profile::hue::hive_server_host'),
    $database_host              = hiera('profile::hue::database_host'),
    $ldap_config                = lookup('ldap', Hash, hash, {}),
    $ldap_base_dn               = hiera('profile::hue::ldap_base_dn', 'dc=wikimedia,dc=org'),
    $database_engine            = hiera('profile::hue::database_engine', 'mysql'),
    $database_user              = hiera('profile::hue::database_user', 'hue'),
    $database_password          = hiera('profile::hue::database_password', 'hue'),
    $session_secret_key         = hiera('profile::hue::session_secret_key', undef),
    $database_port              = hiera('profile::hue::database_port', 3306),
    $database_name              = hiera('profile::hue::database_name', 'hue'),
    $ldap_create_users_on_login = hiera('profile::hue::ldap_create_users_on_login', false),
    $monitoring_enabled         = hiera('profile::hue::monitoring_enabled', false),
    $kerberos_keytab            = hiera('profile::hue::kerberos_keytab', undef),
    $kerberos_principal         = hiera('profile::hue::kerberos_principal', undef),
    $kerberos_kinit_path        = hiera('profile::hue::kerberos_kinit_path', undef),
    $use_yarn_ssl_config        = hiera('profile::hue::use_yarn_ssl_config', false),
    $use_hdfs_ssl_config        = hiera('profile::hue::use_hdfs_ssl_config', false),
    $use_mapred_ssl_config      = hiera('profile::hue::use_mapred_ssl_config', false),
    $oozie_security_enabled     = hiera('profile::hue::oozie_security_enabled', false),
    $server_name                = lookup('profile::hue::servername'),
    Boolean $enable_cas         = lookup('profile::hue::enable_cas'),
    Boolean $use_hue4_settings  = lookup('profile::hue::use_hue4_settings', { 'default_value' => false }),
){

    # Require that all Hue applications
    # have their corresponding clients
    # and configs installed.
    # Include Hadoop ecosystem client classes.
    require ::profile::hadoop::common
    require ::profile::hadoop::httpd
    require ::profile::hive::client
    require ::profile::oozie::client

    require ::profile::analytics::httpd::utils

    # These don't require any extra configuration,
    # so no role class is needed.
    class { '::cdh::sqoop': }
    class { '::cdh::mahout': }

    class { '::passwords::ldap::production': }

    # For snappy support with Hue.
    require_package('python-snappy')

    class { '::cdh::hue':
        # We always host hive-server on the same node as hive-metastore.
        hive_server_host           => $hive_server_host,
        smtp_host                  => 'localhost',
        database_host              => $database_host,
        database_user              => $database_user,
        database_password          => $database_password,
        database_engine            => $database_engine,
        database_name              => $database_name,
        database_port              => $database_port,
        secret_key                 => $session_secret_key,
        smtp_from_email            => "hue@${::fqdn}",
        ldap_url                   => "ldaps://${ldap_config[ro-server]}",
        ldap_bind_dn               => "cn=proxyagent,ou=profile,${ldap_base_dn}",
        ldap_bind_password         => $passwords::ldap::production::proxypass,
        ldap_base_dn               => $ldap_base_dn,
        ldap_username_pattern      => 'uid=<username>,ou=people,dc=wikimedia,dc=org',
        ldap_user_filter           => 'objectclass=person',
        ldap_user_name_attr        => 'uid',
        ldap_group_filter          => 'objectclass=posixgroup',
        ldap_group_member_attr     => 'member',
        ldap_create_users_on_login => $ldap_create_users_on_login,
        # Disable hue's SSL.  SSL terminiation is handled by an upstream proxy.
        ssl_private_key            => false,
        ssl_certificate            => false,
        secure_proxy_ssl_header    => true,
        oozie_security_enabled     => $oozie_security_enabled,
        kerberos_keytab            => $kerberos_keytab,
        kerberos_principal         => $kerberos_principal,
        kerberos_kinit_path        => $kerberos_kinit_path,
        use_yarn_ssl_config        => $use_yarn_ssl_config,
        use_hdfs_ssl_config        => $use_hdfs_ssl_config,
        use_mapred_ssl_config      => $use_mapred_ssl_config,
        use_hue4_settings          => $use_hue4_settings,
    }

    # Include icinga alerts if production realm.
    if $monitoring_enabled {
        nrpe::monitor_service { 'hue-cherrypy':
            description   => 'Hue CherryPy python server',
            nrpe_command  => '/usr/lib/nagios/plugins/check_procs -c 1:1 -C python2.7 -a "/usr/lib/hue/build/env/bin/hue runcherrypyserver"',
            contact_group => 'analytics',
            require       => Class['cdh::hue'],
            notes_url     => 'https://wikitech.wikimedia.org/wiki/Analytics/Cluster/Hue/Administration',
        }
        if $kerberos_kinit_path {
            nrpe::monitor_service { 'hue-kt-renewer':
                description   => 'Hue Kerberos keytab renewer',
                nrpe_command  => '/usr/lib/nagios/plugins/check_procs -c 1:1 -C python2.7 -a "/usr/lib/hue/build/env/bin/hue kt_renewer"',
                contact_group => 'analytics',
                require       => Class['cdh::hue'],
                notes_url     => 'https://wikitech.wikimedia.org/wiki/Analytics/Cluster/Hue/Administration',
            }
        }
    }

    # Vhost proxy to Hue app server.
    # This is not for LDAP auth, LDAP is done by Hue itself.

    $hue_port = $::cdh::hue::http_port

    if $enable_cas {
        profile::idp::client::httpd::site {$server_name:
            vhost_content    => 'profile/idp/client/httpd-hue.erb',
            document_root    => '/var/www',
            proxied_as_https => true,
            vhost_settings   => { 'hue_port' => $hue_port },
            required_groups  => [
                'cn=ops,ou=groups,dc=wikimedia,dc=org',
                'cn=wmf,ou=groups,dc=wikimedia,dc=org',
                'cn=nda,ou=groups,dc=wikimedia,dc=org',
            ]
        }
    } else {
        httpd::site { $server_name:
            content => template('profile/hue/hue.vhost.erb'),
            require => File['/var/www/health_check'],
        }
    }
}
