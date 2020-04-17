class profile::kubernetes::deployment_server::helmfile(
    Hash[String, Any] $services=hiera('profile::kubernetes::deployment_server::services', {}),
    Hash[String, Any] $services_secrets=hiera('profile::kubernetes::deployment_server_secrets::services', {}),
    Hash[String, Any] $admin_services_secrets=hiera('profile::kubernetes::deployment_server_secrets::admin_services', {}),
    Array[Stdlib::Fqdn] $prometheus_nodes = lookup('prometheus_all_nodes'),
){

    require_package('helmfile')
    require_package('helm-diff')

    # logging script needed for sal on helmfile
    file { '/usr/local/bin/helmfile_log_sal':
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0555',
        source => 'puppet:///modules/profile/kubernetes/helmfile_log_sal.sh',
    }

    git::clone { 'operations/deployment-charts':
        ensure    => 'present',
        directory => '/srv/deployment-charts',
    }

    systemd::timer::job { 'git_pull_charts':
        ensure                    => present,
        description               => 'Pull changes on deployment-charts repo',
        command                   => '/bin/bash -c "cd /srv/deployment-charts && /usr/bin/git pull >/dev/null 2>&1"',
        interval                  => {
            'start'    => 'OnCalendar',
            'interval' => '*-*-* *:*:00', # every minute
        },
        logging_enabled           => false,
        monitoring_enabled        => true,
        monitoring_contact_groups => 'admins',
        user                      => 'root',
    }

    $merged_services = deep_merge($services, $services_secrets)
    $clusters = ['staging', 'eqiad', 'codfw']
    $clusters.each |String $environment| {
        # populate .hfenv is a temporary workaround for hemlfile checkout T212130 for context
        $merged_services.map |String $svcname, Hash $data| {
          if $svcname == 'admin' {
              $hfenv="/srv/deployment-charts/helmfile.d/admin/${environment}/.hfenv"
              $hfdir="/srv/deployment-charts/helmfile.d/admin/${environment}"
          }elsif $svcname != 'admin' and size($svcname) > 1 {
              $hfenv="/srv/deployment-charts/helmfile.d/services/${environment}/${svcname}/.hfenv"
              $hfdir="/srv/deployment-charts/helmfile.d/services/${environment}/${svcname}"
          }else {
              fail("unexpected servicename ${svcname}")
          }
          file { $hfdir:
            ensure => directory,
            owner  => $data['owner'],
            group  => $data['group'],
          }
          file { $hfenv:
            ensure  => present,
            owner   => $data['owner'],
            group   => $data['group'],
            mode    => $data['mode'],
            content => template('profile/kubernetes/.hfenv.erb'),
            require => File[$hfdir]
          }
        }
        $merged_services.map |String $svcname, Hash $data| {
            unless $svcname == 'admin' {
                $secrets_dir="/srv/deployment-charts/helmfile.d/services/${environment}/${svcname}/private"
                file { $secrets_dir:
                    ensure  => directory,
                    owner   => $data['owner'],
                    group   => $data['group'],
                    require => Git::Clone['operations/deployment-charts'],
                }
                if $environment == 'staging' {
                    $dc = 'eqiad'
                }
                else {
                    $dc = $environment
                }

                $puppet_ca_data = file($facts['puppet_config']['localcacert'])

                $filtered_prometheus_nodes = $prometheus_nodes.filter |$node| { "${dc}.wmnet" in $node }.map |$node| { ipresolve($node) }

                unless empty($filtered_prometheus_nodes) {
                  $deployment_config_opts = {
                    'tls' => {
                      'telemetry' => {
                        'prometheus_nodes' => $filtered_prometheus_nodes
                      }
                    },
                    'puppet_ca_crt' => $puppet_ca_data,
                  }
                } else {
                  $deployment_config_opts = {
                    'puppet_ca_crt' => $puppet_ca_data
                  }
                }

                # Add here values provided by puppet, like the IPs of the prometheus nodes.
                file { "${secrets_dir}/general.yaml":
                    ensure  => present,
                    owner   => $data['owner'],
                    group   => $data['group'],
                    mode    => $data['mode'],
                    content => to_yaml($deployment_config_opts)
                }
                # write private section only if there is any secret defined.
                $raw_data = $data[$environment]
                if $raw_data {
                    # Substitute the value of any key in the form <somekey>: secret__<somevalue>
                    # with <somekey>: secret(<somevalue>)
                    # This allows to avoid having to copy/paste certs inside of yaml files directly,
                    # for example.
                    $secret_data = wmflib::inject_secret($raw_data)

                    file { "${secrets_dir}/secrets.yaml":
                        owner   => $data['owner'],
                        group   => $data['group'],
                        mode    => $data['mode'],
                        content => ordered_yaml($secret_data),
                        require => [ Git::Clone['operations/deployment-charts'], File[$secrets_dir], ]
                    }
                }
            }
        }
        $admin_services_secrets.map |String $svcname, Hash $data| {
          if $data[$environment] {
            $secrets_dir="/srv/deployment-charts/helmfile.d/admin/${environment}/${svcname}"
            file { $secrets_dir:
                ensure  => directory,
                owner   => $data['owner'],
                group   => $data['group'],
                require => Git::Clone['operations/deployment-charts'],
            }
            file { "${secrets_dir}/private":
                ensure  => directory,
                owner   => $data['owner'],
                group   => $data['group'],
                require => Git::Clone['operations/deployment-charts'],
            }
            file { "${secrets_dir}/private/secrets.yaml":
                owner   => $data['owner'],
                group   => $data['group'],
                mode    => $data['mode'],
                content => ordered_yaml($data[$environment]),
                require => [ Git::Clone['operations/deployment-charts'], File[$secrets_dir], File["${secrets_dir}/private"] ]
            }
          }
        }
    } # end clusters

}
