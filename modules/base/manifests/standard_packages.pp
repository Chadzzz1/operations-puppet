class base::standard_packages {

    ensure_packages ([
        'acct', 'apt-transport-https', 'byobu', 'colordiff', 'curl', 'debian-goodies', 'dnsutils', 'dstat',
        'ethtool', 'gdb', 'gdisk', 'git-fat', 'git', 'htop', 'httpry', 'iotop', 'iperf', 'jq',
        'libtemplate-perl', 'lldpd', 'lshw', 'molly-guard', 'moreutils', 'net-tools', 'numactl', 'ncdu',
        'ngrep', 'pigz', 'psmisc', 'pv', 'python3', 'quickstack', 'screen', 'strace', 'sysstat', 'tcpdump',
        'tmux', 'tree', 'vim', 'vim-addon-manager', 'vim-scripts', 'wipe', 'xfsprogs', 'zsh',
    ])
    package { 'tzdata': ensure => latest }

    # Pulled in via tshark below, defaults to "no"
    debconf::seen { 'wireshark-common/install-setuid': }
    package { 'tshark': ensure => present }

    # ack-grep was renamed to ack
    if debian::codename::ge('stretch') {
        ensure_packages('ack')
    } else {
        ensure_packages('ack-grep')
    }

    # These packages exists only from stretch onwards, once we are free of
    # jessie, remove the if and move them to the array above
    if debian::codename::gt('jessie') {
        ensure_packages('icdiff')
        ensure_packages('linux-perf')
        ensure_packages('s-nail')
    }

    # pxz was removed in buster. In xz >= 5.2 (so stretch and later), xz has
    # builtin threading support using the -T option, so pxz was removed
    if debian::codename::lt('buster') {
        ensure_packages('pxz')
    }

    # uninstall these packages
    package { [
        'apport', 'command-not-found', 'command-not-found-data',
        'ecryptfs-utils', 'mlocate', 'os-prober', 'python3-apport', 'wpasupplicant']:
            ensure => absent,
    }

    # purge these packages
    # atop causes severe performance degradation T192551 debian:896767
    package { [
            'atop', 'apt-listchanges',
        ]:
        ensure => purged,
    }

    # real-hardware specific
    unless $facts['is_virtual'] {
        # As of September 2015, mcelog still does not support newer AMD processors.
        # See <https://www.mcelog.org/faq.html#18>.
        if $::processor0 !~ /AMD/ {
            ensure_packages('intel-microcode')
            if debian::codename::le('stretch') {
                $mcelog_ensure = versioncmp($::kernelversion, '4.12') ? {
                    -1      => 'present',
                    default => 'absent',
                }
                package { 'mcelog':
                    ensure => $mcelog_ensure,
                }
                base::service_auto_restart { 'mcelog':
                    ensure => $mcelog_ensure,
                }
            }
        }
        # rasdaemon replaces mcelog on buster
        if debian::codename::eq('buster') {
            ensure_packages('rasdaemon')
            base::service_auto_restart { 'rasdaemon': }
        }

        # for HP servers only - install the backplane health service and CLI
        # As of February 2018, we are using a version of Facter where manufacturer
        # is a current fact.  In a future upgrade, it will be a legacy fact and
        # should be replaced with a parse of the dmi fact (which will be a map not
        # a string).
        if $facts['manufacturer'] == 'HP' {
            ensure_packages('hp-health')
        }
    }

    case debian::codename() {
        'stretch': {
            # An upgrade from jessie to stretch leaves some old binary packages around, remove those
            $absent_packages = [
                'libapt-inst1.5', 'libapt-pkg4.12', 'libdns-export100', 'libirs-export91',
                'libisc-export95', 'libisccfg-export90', 'liblwres90', 'libgnutls-deb0-28',
                'libhogweed2', 'libjasper1', 'libnettle4', 'libruby2.1', 'ruby2.1', 'libpsl0',
                'libwiretap4', 'libwsutil4', 'libbind9-90', 'libdns100', 'libisc95', 'libisccc90',
                'libisccfg90', 'python-reportbug', 'libpng12-0'
            ]
            $purged_packages = []
        }
        'buster': {
            # An upgrade from stretch to buster leaves some old binary packages around, remove those
            $absent_packages = [
                'libbind9-140', 'libdns162', 'libevent-2.0-5', 'libisc160', 'libisccc140', 'libisccfg140',
                'liblwres141', 'libonig4', 'libdns-export162', 'libhunspell-1.4-0', 'libisc-export160',
                'libgdbm3', 'libyaml-cpp0.5v5', 'libperl5.24', 'ruby2.3', 'libruby2.3', 'libunbound2', 'git-core',
                'libboost-atomic1.62.0', 'libboost-chrono1.62.0', 'libboost-date-time1.62.0',
                'libboost-filesystem1.62.0', 'libboost-iostreams1.62.0', 'libboost-locale1.62.0',
                'libboost-log1.62.0', 'libboost-program-options1.62.0', 'libboost-regex1.62.0',
                'libboost-system1.62.0', 'libboost-thread1.62.0', 'libmpfr4', 'libprocps6', 'libunistring0',
                'libbabeltrace-ctf1', 'libleatherman-data'
            ]
            # mcelog is broken with the Linux kernel used in buster
            $purged_packages = ['mcelog']
        }
        default: {
            $absent_packages = []
            $purged_packages = []
        }
    }
    package {$absent_packages: ensure => 'absent'}
    package {$purged_packages: ensure => 'purged'}

    base::service_auto_restart { 'lldpd': }
    base::service_auto_restart { 'cron': }

    # Safe restarts are supported since systemd 219:
    # * systemd now provides a way to store file descriptors
    # per-service in PID 1. This is useful for daemons to ensure
    # that fds they require are not lost during a daemon
    # restart. The fds are passed to the daemon on the next
    # invocation in the same way socket activation fds are
    # passed. This is now used by journald to ensure that the
    # various sockets connected to all the system's stdout/stderr
    # are not lost when journald is restarted.
    if debian::codename::ge('stretch') {
        base::service_auto_restart { 'systemd-journald': }
    }
}
