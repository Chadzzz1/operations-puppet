require 'spec_helper'

describe 'wdqs::deploy::manual', :type => :class do
   before(:each) do
        Puppet::Parser::Functions.newfunction(:secret, :type => :rvalue) { |_|
            'fake_secret'
        }
   end

   let(:params) { {
        :deploy_user => 'deploy-service',
        :package_dir => '/srv/deployment/wdqs/wdqs',
        }
   }

   context 'with systemd' do
    let(:facts) { {
        :initsystem => 'systemd',
        :lsbdistrelease => '8.7',
        :lsbdistid => 'Debian',
    } }

    it { is_expected.to contain_sudo__user('deploy-service_wdqs-updater').with('user' => 'deploy-service') }
    it { is_expected.to contain_sudo__user('deploy-service_wdqs-blazegraph').with('user' => 'deploy-service') }
  end
end
