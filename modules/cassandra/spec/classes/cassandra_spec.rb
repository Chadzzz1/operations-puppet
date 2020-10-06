require_relative '../../../../rake_modules/spec_helper'

describe 'cassandra', :type => :class do
    let(:pre_condition) { 'class { "::apt": }' }
    on_supported_os(WMFConfig.test_on).each do |os, facts|
        context "on #{os}" do
          let(:params) {  {target_version: '2.2'} }
          let(:facts) { facts }

          # check that there are no dependency cycles
          it { is_expected.to compile }

          it { is_expected.to contain_apt__repository('wikimedia-cassandra22').that_comes_before('Package[cassandra]') }
          it { is_expected.to contain_exec('apt-get update').that_comes_before('Package[cassandra]') }
        end
    end
end
