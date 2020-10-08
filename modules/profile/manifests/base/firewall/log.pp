# Firewall logging class
class profile::base::firewall::log (
  Integer                                  $log_burst = lookup('profile::base::firewall::log::log_burst'),
  Pattern[/\d+\/(second|minute|hour|day)/] $log_rate  = lookup('profile::base::firewall::log::log_rate'),
) {
  # we only call this class from profile::base::firewall
  assert_private()
  include profile::base::firewall
  $policy = $profile::base::firewall::default_reject.bool2str('reject', 'drop')
  class { '::ulogd': }

  # Explicitly drop pxe/dhcp packets packets so they dont hit the log
  ferm::filter_log { 'filter-bootp':
      proto => 'udp',
      daddr => '255.255.255.255',
      sport => 67,
      dport => 68,
  }

  ferm::rule { 'log-everything':
      rule => "NFLOG mod limit limit ${log_rate} limit-burst ${log_burst} nflog-prefix \"[fw-in-${policy}]\";",
      prio => '98',
  }

}
