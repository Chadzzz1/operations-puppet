# Class: role::wmcs::toolforge::grid::web::lighttpd
#
# This configures the web node as a lighttpd node
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
class role::wmcs::toolforge::grid::web::lighttpd {
    system::role { 'wmcs::toolforge::grid::web::lighttpd': description => 'lighttpd web exec node' }

    include profile::toolforge::grid::base
    include profile::toolforge::grid::node::all
    include profile::toolforge::grid::node::web::lighttpd
}
