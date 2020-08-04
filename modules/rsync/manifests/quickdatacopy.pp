# == Class rsync::quickdatacopy
#
# This class sets up a very quick and dirty rsync server. It's designed to be
# used for copying data between two (or more) machines, mostly for migrations.
#
# Since it's meant to be used for data migrations, it assumes the source and
# destination locations are the same
#
# === Parameters
#
# [*source_host*] What machine are we copying data from
#
# [*dest_host*] What machine are we copying data to
#
# [*module_path*] What path are we giving to rsync as the docroot for syncing from
#
# [*file_path*] What file within that document root do we need? (currently not used)
#
# [*auto_sync*] Whether to also have a cronjob that automatically syncs data or not (default: true)
#
# [*ensure*] The usual meaning, set to absent to clean up when done
#
# [*bwlimit*] Optionally limit the maxmium bandwith used
#
# [*delete*] Optionally let rsync delete files on the _destination_ side if they
#            do not exist on the source.
#            To create exact mirrors instead of having old files that are deleted
#            on the source pile up on the destination(s).
#
# [*server_uses_stunnel*]
# For TLS-wrapping rsync.  Must be set here, and must be set true on rsync::server::wrap_with_stunnel
# in the server's hiera.
define rsync::quickdatacopy(
  Stdlib::Fqdn $source_host,
  Stdlib::Fqdn $dest_host,
  Stdlib::Unixpath $module_path,
  Optional[Stdlib::Unixpath] $file_path = undef,
  Boolean $auto_sync = true,
  Wmflib::Ensure $ensure = present,
  Optional[Integer] $bwlimit = undef,
  Optional[Boolean] $delete = false,
  Boolean $server_uses_stunnel = false,  # Must match rsync::server::wrap_with_stunnel as looked up via hiera by the *server*!
  ) {
      if ($title =~ /\s/) {
          fail('the title of rsync::quickdatacopy must not include whitespace')
      }

      if $source_host == $::fqdn {

          include rsync::server

          rsync::server::module { $title:
              ensure         => $ensure,
              read_only      => 'yes',
              path           => $module_path,
              hosts_allow    => [$dest_host],
              auto_ferm      => true,
              auto_ferm_ipv6 => true,
          }
      }
      $_bwlimit = $bwlimit ? {
          undef   => '',
          default => "--bwlimit=${bwlimit}",
      }

      $ssl_wrapper_path = "/usr/local/sbin/sync-${title}-ssl-wrapper"
      $_rsh = $server_uses_stunnel ? {
          false   => '',
          default => "--rsh ${ssl_wrapper_path}"
      }
      $_delete = $delete ? {
          true    => ' --delete ',
          default => ' '
      }

      if $dest_host == $::fqdn {

          if $server_uses_stunnel {
              require_package('stunnel4')

              file { $ssl_wrapper_path:
                  ensure  => $ensure,
                  owner   => 'root',
                  group   => 'root',
                  mode    => '0755',
                  content => template('rsync/quickdatacopy-ssl-wrapper.erb'),
              }
          }
          $quickdatacopy = @("SCRIPT")
          #!/bin/sh
          /usr/bin/rsync ${_rsh}${_delete}-a ${_bwlimit} rsync://${source_host}/${title} ${module_path}/
          | SCRIPT

          file { "/usr/local/sbin/sync-${title}":
              ensure  => $ensure,
              owner   => 'root',
              group   => 'root',
              mode    => '0755',
              content => $quickdatacopy,
          }

          if $auto_sync {
              $cron_ensure = $ensure
          } else {
              $cron_ensure = 'absent'
          }
          cron { "rsync-${title}":
              ensure  => $cron_ensure,
              minute  => '*/10',
              command => "/usr/local/sbin/sync-${title} >/dev/null 2>&1",
          }
      }
}
