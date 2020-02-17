require 'spec_helper'

test_on = {
  supported_os: [
    {
      'operatingsystem'        => 'Debian',
      'operatingsystemrelease' => ['9', '10'],
    }
  ]
}

describe 'profile::services_proxy::envoy' do
  on_supported_os(test_on).each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts.merge({ initsystem: 'systemd' }) }
      let(:node_params) {
        {test_name: 'proxy_envoy', site: 'unicornia'}
      }
      context 'with ensure present' do
        let(:params) {
          {
            ensure: 'present',
            listeners: [
              {
                name: 'commons',
                port: 8765,
                timeout: '2s',
                http_host: 'commons.wikimedia.org',
                cluster: 'appservers-rw'
              },
              {
                name: 'meta',
                port: 9876,
                timeout: '2s',
                http_host: 'meta.wikimedia.org',
                cluster: 'text-https_eqiad'
              },
            ],
            local_clusters: ['text-https']
          }
        }
        it { is_expected.to compile.with_all_deps }
        it {
          is_expected.to contain_envoyproxy__cluster('text-https_esams_cluster')
                           .with_content(/address: text-lb.esams.wikimedia.org/)
        }
        it {
          is_expected.to contain_envoyproxy__listener('commons')
                           .with_content(/host_rewrite: commons.wikimedia.org/)
                           .with_content(/cluster: appservers-rw/)
        }
        it {
          is_expected.to contain_envoyproxy__listener('meta')
                           .with_content(/timeout: 2s/)
                           .with_content(/cluster: text-https_eqiad/)
                           .with_content(/port_value: 9876/)
        }
      end
    end
  end
end
