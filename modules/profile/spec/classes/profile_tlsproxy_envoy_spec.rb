require 'spec_helper'
test_on = {
  supported_os: [
    {
      'operatingsystem'        => 'Debian',
      'operatingsystemrelease' => ['8', '9', '10'],
    }
  ]
}

describe 'profile::tlsproxy::envoy' do
  on_supported_os(test_on).each do |os, facts|
    context "on #{os}" do
      # Patch the secret function, we don't care about it
      before(:each) do
        Puppet::Parser::Functions.newfunction(:secret) { |_|
          'expected value'
        }
      end
      let(:node_params) { {site: 'eqiad', test_name: 'tlsproxy_envoy'}}
      let(:facts) { facts.merge({ initsystem: 'systemd' }) }

      let(:pre_condition) {
        [
          'exec { "apt-get update": command => "/bin/true"}',
          'class profile::base { $notifications_enabled = false }',
          'require ::profile::base'
        ]
      }

      context "global TLS, non-SNI" do
        let(:params) {
          {
            services: [{server_names: ['*'], port: 80, cert_name: 'test'}],
            global_cert_name: 'example',
          }
        }
        if facts[:lsbdistcodename] != 'jessie'
          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_class('envoyproxy')
                             .with_ensure('present')
          }
          it {
            is_expected.to contain_envoyproxy__tls_terminator('443')
                             .with_global_cert_path('/etc/ssl/localcerts/example.crt')
          }
          it {
            is_expected.to contain_sslcert__certificate('example')
                             .with_ensure('present')
          }
        else
          it { is_expected.to compile.and_raise_error(/Envoy can only work with unprivileged ports under jessie./) }
        end
      end
      context "SNI-only" do
        let(:params) {
          {
            tls_port: 4443,
            sni_support: 'strict',
            services: [
              {server_names: ['citoid.discovery.wmnet', 'citoid'], port: 8080, cert_name: 'citoid'},
              {server_names: ['blubberoid.discovery.wmnet', 'blubberoid'], port: 8081, cert_name: 'blubberoid'}
            ],
          }
        }
        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_sslcert__certificate('blubberoid')
                           .with_ensure('present')
        }
      end
    end
  end
end
