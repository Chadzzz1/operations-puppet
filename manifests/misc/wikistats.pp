# misc/wikistats.pp
# mediawiki statistics site

class misc::wikistats {
	system_role { "misc::wikistats": description => "wikistats host" }
	systemuser { wikistats: name => "wikistats", home => "/var/lib/wikistats", groups => [ "wikistats" ] }

	# the web UI part (output)
	class web {

		class {'generic::webserver::php5': ssl => 'true'; }

			$wikistats_host = "$instancename.${domain}"
			$wikistats_ssl_cert = "/etc/ssl/certs/star.wmflabs.pem"
			$wikistats_ssl_key = "/etc/ssl/private/star.wmflabs.key"

		file {
			"/etc/apache2/sites-available/wikistats.wmflabs.org":
			mode => 444,
			owner => root,
			group => root,
			content => template('apache/sites/wikistats.wmflabs.org.erb'),
			ensure => present;
			"/etc/apache2/ports.conf":
			mode => 644,
			owner => root,
			group => root,
			source => 'puppet:///files/apache/ports.conf',
			ensure => present;
			"/var/www/wikistats":
			mode => 755,
			owner => wikistats,
			group => www-data,
			ensure => directory;
		}

		apache_module { rewrite: name => "rewrite" }

		apache_confd { namevirtualhost: install => "true", name => "namevirtualhost" }
		apache_site { no_default: name => "000-default", ensure => absent }
		apache_site { wikistats: name => "wikistats.wmflabs.org" }

	}

	# the update scripts fetching data (input)
	class updates {

		include generic::mysql::client
		package { "php5-cli": ensure => 'latest'; }
	}

}

