# == Class profile::presto::server
#
# Sets up a presto server in a presto cluster.
# By default this node will be set up as a worker node.  To enable the
# coordinator or discovery, provide appropriate settings in $config_properties.
#
# See also: https://prestodb.io/docs/current/installation/deployment.html
#
# == Parameters
#
# [*cluster_name*]
#   Name of the Presto cluster.  This will be used as the default node.environment.
#
# [*discovery_uri*]
#   URI to the Presto discovery server.
#
# [*node_properties*]
#   Specific node.properties settings. This profile attempts to use sane defaults.
#   Only set this if you need to override them.  Note that node.id will be
#   set automatically by the presto::server module class based on the current node's
#   $::fqdn.
#
# [*config_properties*]
#   Specific config.properties settings. This profile attempts to use sane defaults.
#   Only set this if you need to override them.
#
# [*log_properties*]
#   Specific log.properties settings.
#
# [*heap_max*]
#   -Xmx argument. Default: 2G
#
#  [*presto_clusters_secrets*]
#    Hash of available/configured Presto clusters and their secret properties,
#    like passwords, etc..
#    The following values will be checked in the hash table only if TLS/Kerberos
#    configs are enabled (see in the code for the exact values).
#      - 'ssl_keystore_password'
#      - 'ssl_trustore_password'
#    Default: {}
#
class profile::presto::server(
    String $cluster_name      = hiera('profile::presto::cluster_name'),
    String $discovery_uri     = hiera('profile::presto::discovery_uri'),
    Hash   $node_properties   = hiera('profile::presto::server::node_properties',   {}),
    Hash   $config_properties = hiera('profile::presto::server::config_properties', {}),
    Hash   $catalogs          = hiera('profile::presto::server::catalogs',          {}),
    Hash   $log_properties    = hiera('profile::presto::server::log_properties',    {}),
    String $heap_max          = hiera('profile::presto::server::heap_max',          '2G'),
    String $ferm_srange       = hiera('profile::presto::server::ferm_srange',       '$DOMAIN_NETWORKS'),
    Boolean $use_kerberos     = hiera('profile::presto::use_kerberos', false),
    Optional[Hash[String, Hash[String, String]]] $presto_clusters_secrets = hiera('presto_clusters_secrets', {}),
) {

    $default_node_properties = {
        'node.enviroment'              => $cluster_name,
        'node.data-dir'                => '/srv/presto',
        'node.internal-address-source' => 'FQDN',
    }

    $default_config_properties = {
        'http-server.http.port'              => '8280',
        'jmx.rmiregistry.port'               => '8279',
        'discovery.uri'                      => $discovery_uri,
        # flat will try to schedule splits on the host where the data is located by reserving
        # 50% of the work queue for local splits. It is recommended to use flat for clusters
        # where distributed storage runs on the same nodes as Presto workers.
        # You should change this if your Presto cluster is not colocated with storage.
        'node-scheduler.network-topology'    => 'flat',
    }

    if $use_kerberos {
        $hostname_suffix = $::realm ? {
            'labs'  => '.eqiad.wmflabs',
            default => "${::site}.wmnet",
        }

        $hostname_tls_cn = "${::hostname}.${hostname_suffix}"
        $ssl_keystore_path = '/etc/presto/keystore.jks'
        file { $ssl_keystore_path:
            content => secret("certificates/presto_${cluster_name}/${hostname_tls_cn}/${hostname_tls_cn}.keystore.jks"),
            owner   => 'presto',
            group   => 'presto',
            mode    => '0440',
            require => Package['presto-server'],
        }

        $ssl_truststore_path = '/etc/presto/truststore.jks'
        file { $ssl_truststore_path:
            content => secret("certificates/presto_${cluster_name}/root_ca/truststore.jks"),
            owner   => 'presto',
            group   => 'presto',
            mode    => '0444',
            require => Package['presto-server'],
        }

        $ssl_truststore_password = $presto_clusters_secrets[$cluster_name]['ssl_truststore_password']
        file { '/usr/local/bin/presto':
            owner   => 'root',
            group   => 'root',
            mode    => '0555',
            content => template('profile/presto/presto_client_ssl_kerberos.erb'),
            require => Package['presto-server'],
        }
    }

    if $presto_clusters_secrets[$cluster_name] {
        $ssl_keystore_password = $presto_clusters_secrets[$cluster_name]['ssl_keystore_password']
        $default_ssl_properties = {
            'http-server.https.keystore.path' => $ssl_keystore_path,
            'http-server.https.keystore.key' => $ssl_keystore_password,
            'internal-communication.https.required' => true,
            'internal-communication.https.keystore.path' => $ssl_keystore_path,
            'internal-communication.https.keystore.key' => $ssl_keystore_password,
            'http-server.https.port' => '8281',
            'http-server.http.enabled' => false,
            'http-server.https.enabled' => true,
        }
    } else {
        $default_ssl_properties = {}
    }

    if $use_kerberos {
        $default_kerberos_properties = {
            'internal-communication.kerberos.enabled' => true,
            'http-server.authentication.type' => 'KERBEROS',
            'http.authentication.krb5.config' => '/etc/krb5.conf',
            'http.server.authentication.krb5.keytab' => '/etc/security/keytabs/presto/presto.keytab',
            'http.server.authentication.krb5.service-name' => 'presto',
        }
    } else {
        $default_kerberos_properties = {}
    }

    # Merge in any overrides for properties
    $_node_properties = $default_node_properties + $node_properties
    $_config_properties = $default_config_properties + $config_properties + $default_ssl_properties + $default_kerberos_properties

    class { '::presto::server':
        node_properties   => $_node_properties,
        config_properties => $_config_properties,
        log_properties    => $log_properties,
        catalogs          => $catalogs,
        heap_max          => $heap_max,
    }

    if $presto_clusters_secrets[$cluster_name] {
        ferm::service{ 'presto-https':
            proto  => 'tcp',
            port   => $_config_properties['http-server.https.port'],
            srange => $ferm_srange,
        }
    } else {
        ferm::service{ 'presto-http':
            proto  => 'tcp',
            port   => $_config_properties['http-server.http.port'],
            srange => $ferm_srange,
        }
    }

    ferm::service{ 'presto-jmx-rmiregistry':
        proto  => 'tcp',
        port   => $_config_properties['jmx.rmiregistry.port'],
        srange => $ferm_srange,
    }
}
