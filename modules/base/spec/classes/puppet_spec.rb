require_relative '../../../../rake_modules/spec_helper'
test_on = {
  supported_os: [
    {
      'operatingsystem'        => 'Debian',
      'operatingsystemrelease' => ['8', '9'],
    }
  ]
}

describe 'base::puppet' do
  let(:pre_condition) {
    [
      'class passwords::puppet::database {}',
      'include apt'
    ]
  }
  on_supported_os(test_on).each do |os, facts|
    context "On #{os}" do
      let(:facts) { facts}
      let(:params) { { 'ca_source' => 'puppet:///modules/foo/ca.pem' } }
      it { should compile }
    end
  end
end
