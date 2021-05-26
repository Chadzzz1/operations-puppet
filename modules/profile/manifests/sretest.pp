class profile::sretest {
    if debian::codename::eq('buster') {
        include profile::docker::firewall
        include profile::base::cuminunpriv
    }

    # Temporary test for Bacula/Bullseye
    if debian::codename::eq('bullseye') {
        include profile::backup::host
        backup::set {'home':}
    }

    profile::logoutd::script {'sretest':
        source => 'puppet:///modules/profile/sretest/sretest-logout.py',
    }
    profile::contact { $title:
        contacts => ['jbond', 'MoritzMuehlenhoff']
    }
}
