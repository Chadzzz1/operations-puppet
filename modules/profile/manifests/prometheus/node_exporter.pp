# == Class: profile::prometheus::node_exporter
#
# Profile to provision prometheus machine metrics exporter. See also
# https://github.com/prometheus/node_exporter and the module's documentation.
#

class profile::prometheus::node_exporter {
    # We will fix the style break in a later PS
    include prometheus::node_exporter  # lint:ignore:wmf_styleguide
}
