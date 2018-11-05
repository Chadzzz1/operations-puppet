# Class: role::wmcs::toolforge::compute::general
#
# This configures the compute node as a general node
#
# Parameters:
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
# filtertags: toolforge
class role::wmcs::toolforge::grid::compute::general {
    system::role { 'wmcs::toolforge::grid::compute::general': description => 'General computation node' }

    include profile::toolforge::base
    include profile::toolforge::apt_pinning
    include profile::toolforge::grid::base
    include profile::toolforge::grid::node::all
    include profile::toolforge::grid::node::compute::general
}
