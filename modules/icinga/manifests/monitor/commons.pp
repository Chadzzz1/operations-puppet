# monitoring of content on commons (T124812)
class icinga::monitor::commons {

    @monitoring::host { 'commons.wikimedia.org':
        host_fqdn => 'commons.wikimedia.org',
    }

    monitoring::service {
        default:
            host          => 'commons.wikimedia.org',
            contact_group => 'admins',
            critical      => true,
            notes_url     => 'https://phabricator.wikimedia.org/project/view/1118/';
        'commons_content':
            description   => 'wiki content on commons',
            check_command => 'check_https_url_for_string!commons.wikimedia.org!/wiki/Main_Page!Picture of the day';
        'commons_content_expiry':
            description   => 'wiki content on commons expiry',
            check_command => 'check_https_expiry!commons.wikimedia.org!443';
    }

}
