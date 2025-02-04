#
# Definition: postgresql::user::hba
#
# This definition provides a way to manage host based authentication for postgresql.
#
# Parameters:
#
# Actions:
#   Create/drop HBA rule
#
# Sample Usage:
# postgresql::user::hba { "Access configuration for ${user} on} ${database}":
#     ensure    => present,
#     user      => 'myuser',
#     database  => 'mydb',
#     type      => 'host',
#     method    => 'md5',
#     cidr      => '10.0.0.1',
#     hba_label => 'myuser@hostname',
#     pgversion => '11',
# }
define postgresql::user::hba(
    String                 $user,
    Wmflib::Ensure         $ensure = 'present',
    String                 $database   = 'template1',
    String                 $type       = 'host',
    String                 $method     = 'md5',
    Stdlib::IP::Address    $cidr       = '127.0.0.1/32',
    Numeric                $pgversion  = undef,
) {

    $pg_hba_file = "/etc/postgresql/${pgversion}/main/pg_hba.conf"

    # xpath expression to identify the user entry in pg_hba.conf
    if $type == 'local' {
        $xpath = "/files${pg_hba_file}/*[type='${type}'][database='${database}'][user='${user}'][method='${method}']"
    }
    else {
        $xpath = "/files${pg_hba_file}/*[type='${type}'][database='${database}'][user='${user}'][address='${cidr}'][method='${method}']"
    }

    if $ensure == 'present' {
        if $type == 'local' {
            $changes = [
                "set 01/type \'${type}\'",
                "set 01/database \'${database}\'",
                "set 01/user \'${user}\'",
                "set 01/method \'${method}\'",
            ]
        } else {
            $changes = [
                "set 01/type \'${type}\'",
                "set 01/database \'${database}\'",
                "set 01/user \'${user}\'",
                "set 01/address \'${cidr}\'",
                "set 01/method \'${method}\'",
            ]
        }

        augeas { "hba_create-${title}":
            context => "/files${pg_hba_file}/",
            changes => $changes,
            onlyif  => "match ${xpath} size == 0",
            notify  => Exec['pgreload'],
        }
    } elsif $ensure == 'absent' {

        augeas { "hba_drop-${title}":
            context => "/files${pg_hba_file}/",
            changes => "rm ${xpath}",
            # only if the user exists
            onlyif  => "match ${xpath} size > 0",
            notify  => Exec['pgreload'],
        }
    }
}
