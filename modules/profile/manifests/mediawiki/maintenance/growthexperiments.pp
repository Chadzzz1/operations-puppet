class profile::mediawiki::maintenance::growthexperiments {
    # Purge old welcome survey data (personal data used in user options,
    # with a 270-day retention exception) that's within 30 days of expiry,
    # twice a month. See T208369 and T252575. Logs are saved to
    # /var/log/mediawiki/mediawiki_job_growthexperiments-deleteOldSurveys/syslog.log
    profile::mediawiki::periodic_job { 'growthexperiments-deleteOldSurveys':
        command  => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblists/growthexperiments.dblist extensions/GrowthExperiments/maintenance/deleteOldSurveys.php --cutoff 240',
        interval => '*-*-01,15 03:15:00',
    }

    # Ensure that a sufficiently large pool of link recommendations is available.
    profile::mediawiki::periodic_job { 'growthexperiments-refreshLinkRecommendations':
        command  => '/usr/local/bin/foreachwikiindblist /srv/mediawiki/dblists/growthexperiments.dblist extensions/GrowthExperiments/maintenance/refreshLinkRecommendations.php',
        interval => '*-*-* *:27:00',
    }
}
