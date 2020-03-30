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
      let(:params) {
        {
          services: [{server_names: ['*'], port: 80, cert_name: 'test'}],
          global_cert_name: 'example',
          tls_port: 4443
        }
      }

      context "global TLS, non-SNI" do
        let(:params) { super().merge(tls_port: 443) }

        if facts[:lsbdistcodename] != 'jessie'
          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_class('envoyproxy')
                             .with_ensure('present')
          }
          it {
            is_expected.to contain_envoyproxy__tls_terminator('443')
                             .with_global_cert_path('/etc/ssl/localcerts/example.crt')
                             .with_retry_policy(nil)
          }
          it {
            is_expected.to contain_sslcert__certificate('example')
                             .with_ensure('present')
          }
        else
          it { is_expected.to compile.and_raise_error(/Envoy can only work with unprivileged ports under jessie./) }
        end
      end

      context 'test upstream_addr' do
        context "default" do
          it { is_expected.to compile.with_all_deps }
          it do
            is_expected.to contain_envoyproxy__tls_terminator('4443').with_upstreams([
              'server_names'  => ['*'],
              'cert_path'     => :undef,
              'key_path'      => :undef,
              'upstream_port' => 80,
              'upstream_addr' => facts[:fqdn]
            ])
          end
        end
        [
          'localhost', '127.0.0.1', '::1',
          facts[:networking]['ip'], facts[:networking]['ip6']
        ].reject{|e| e.to_s.empty? }.each do |valid|
          # jessie doesn't have ipv6 facts.
          if facts[:lsbdistcodename] == 'jessie' && valid == '::1'
            next
          end
          context "valid: #{valid}" do
            let(:params) { super().merge(upstream_addr: valid) }

            it { is_expected.to compile.with_all_deps }
            it do
              is_expected.to contain_envoyproxy__tls_terminator('4443').with_upstreams([
                'server_names'  => ['*'],
                'cert_path'     => :undef,
                'key_path'      => :undef,
                'upstream_port' => 80,
                'upstream_addr' => valid
              ])
            end
          end
        end
        ['foobar', '192.0.2.1', '2001:db8::1'].each do |invalid|
          context "invalid #{invalid}" do
            let(:params) { super().merge(upstream_addr: 'foobar') }

            it do
              is_expected.to raise_error(
                Puppet::PreformattedError, /upstream_addr must be one of:/
              )
            end
          end
        end
      end
      context "SNI-only" do
        let(:params) do
          super().merge(
            sni_support: 'strict',
            services: [
              {server_names: ['citoid.discovery.wmnet', 'citoid'], port: 8080, cert_name: 'citoid'},
              {server_names: ['blubberoid.discovery.wmnet', 'blubberoid'], port: 8081, cert_name: 'blubberoid'}
            ]
          )
        end

        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_sslcert__certificate('blubberoid')
                           .with_ensure('present')
        }
        it {
          is_expected.to contain_envoyproxy__tls_terminator('4443')
                          .with_retry_policy(nil)
                          .with_route_timeout(65.0)
        }
        context "No retries" do
          let(:params) { super().merge(retries: false) }

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_envoyproxy__tls_terminator('4443')
                              .with_retry_policy({"num_retries" => 0})
          }
        end
        context "Larger timeout" do
          let(:params) { super().merge(request_timeout: 201.0) }

          it { is_expected.to compile.with_all_deps }
          it {
            is_expected.to contain_envoyproxy__tls_terminator('4443')
                              .with_route_timeout(201.0)
          }
        end
      end
    end
  end
end
