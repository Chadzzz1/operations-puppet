# SPDX-License-Identifier: Apache-2.0
# Allow inbound ssh connection from Jenkins controller
class profile::ci::firewall::jenkinsagent (
    Array[Stdlib::Fqdn] $jenkins_controller_hosts = lookup('jenkins_controller_hosts'),
) {
    $jenkins_controller_hosts_ferm = join($jenkins_controller_hosts, ' ')
    ferm::service { 'jenkins_controller_ssh':
        proto  => 'tcp',
        port   => '22',
        srange => "@resolve((${jenkins_controller_hosts_ferm}))",
    }
}
