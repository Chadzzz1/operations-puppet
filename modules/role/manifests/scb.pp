# "Compendium" class for nodes supporting various *oid services
# This class is an intermediate step to better design
class role::scb {

    $services = [
        'changeprop', 'cpjobqueue',
        'graphoid', 'mobileapps',
    ]
    $msg_services = join($services, "\n\t")

    system::role { 'scb':
        description => "Service cluster B; includes:\n\t${msg_services}"
    }

    include ::profile::standard
    include ::profile::base::firewall
    include profile::lvs::realserver

    include ::profile::rsyslog::udp_localhost_compat

    include ::profile::nutcracker

    include ::profile::cpjobqueue
    include ::profile::recommendation_api
    include ::profile::mobileapps
    include ::profile::graphoid
    include ::profile::changeprop
    include ::profile::apertium
}
