class profile::mediawiki::maintenance::wikidata() {
    require profile::mediawiki::common
    require profile::lvs::configuration
    # Resubmit changes in wb_changes that are older than 6 hours
    profile::mediawiki::periodic_job { 'wikidata_resubmit_changes_for_dispatch':
        command  => '/usr/local/bin/mwscript extensions/Wikibase/repo/maintenance/ResubmitChanges.php --wiki wikidatawiki --minimum-age 21600',
        interval => '*-*-* *:39:00',
    }

    if $::realm != 'labs' {
        # Update the cached query service maxlag value every minute
        # We don't need to ensure present/absent as the wrapper will ensure nothing
        # is run unless we're in the master dc
        # Logs are saved to /var/log/mediawiki/mediawiki_job_wikidata-updateQueryServiceLag/syslog.log and properly rotated.
        # When calculating maxlag, we want to only query WDQS servers that are currently pooled. See T238751
        $service_name = 'wdqs'
        $svc = wmflib::service::fetch(true)[$service_name]
        $svc_lbl = "${service_name}_${svc['port']}"
        # Needed to find the LVS servers we need to check.
        $my_lvs_class = $svc['lvs']['class']
        # Select only the hosts in our class
        $lb = $profile::lvs::configuration::lvs_classes.filter |$h, $val| { $my_lvs_class == $val}.map |$host, $_| { "--lb ${host}:9090"}.join(' ')

        $additional_args = "--lb-pool ${svc_lbl} ${lb}"
        profile::mediawiki::periodic_job { 'wikidata-updateQueryServiceLag':
            command  => "/usr/local/bin/mwscript extensions/Wikidata.org/maintenance/updateQueryServiceLag.php --wiki wikidatawiki --cluster wdqs --prometheus prometheus.svc.eqiad.wmnet ${additional_args}",
            interval => '*-*-* *:*:00'
        }
    }
}
