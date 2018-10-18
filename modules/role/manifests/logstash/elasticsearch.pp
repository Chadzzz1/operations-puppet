# vim:sw=4 ts=4 sts=4 et:
# == Class: role::logstash::elasticsearch
#
# Provisions Elasticsearch backend node for a Logstash cluster.
#
class role::logstash::elasticsearch {
    include ::standard
    include ::profile::base::firewall
    include ::profile::elasticsearch::logstash

    # Co-locate kafka with elasticsearch until dedicated hardware is online
    # See also T206454
    include ::role::kafka::logging
}
