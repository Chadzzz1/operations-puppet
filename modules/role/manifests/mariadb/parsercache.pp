# parsercache (pc) specific configuration
# These are mariadb servers acting as on-disk cache for parsed wikitext

class role::mariadb::parsercache {
    system::role { 'mariadb::parsercache':
        description => 'Parser Cache Database',
    }
    include ::standard
    include ::profile::base::firewall
    ::profile::mariadb::ferm { 'parsercache': }

    include profile::mariadb::parsercache
    include ::profile::mariadb::monitor
}
