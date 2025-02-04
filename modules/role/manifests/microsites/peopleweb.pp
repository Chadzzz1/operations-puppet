# let users publish their own HTML in their home dirs
class role::microsites::peopleweb {

    system::role { $name: }

    include ::profile::base::production
    include ::profile::base::firewall
    include ::profile::backup::host
    include ::profile::microsites::peopleweb
    include ::profile::tlsproxy::envoy # TLS termination

}
