require_relative '../../../../rake_modules/spec_helper'

describe 'bacula::storage', :type => :class do
    let(:node) { 'testhost.example.com' }
    let(:facts) do
      {
        'lsbdistrelease' => '10.1',
        'lsbdistid' => 'Debian'
      }
    end
    let(:params) { {
        :director => 'testdirector',
        :sd_max_concur_jobs => '10',
        :sqlvariant => 'testsql',
        :sd_port => '9000',
        :directorpassword => 'testdirectorpass',
        }
    }
    let(:pre_condition) { "class {'base::puppet': ca_source => 'puppet:///files/puppet/ca.production.pem'}" }

    it { should contain_package('bacula-sd') }
    it { should contain_service('bacula-sd') }
    it do
        should contain_file('/etc/bacula/sd-devices.d').with({
        'ensure'  => 'directory',
        'recurse' => 'true',
        'force'   => 'true',
        'purge'   => 'true',
        'mode'    => '0550',
        'owner'   => 'bacula',
        'group'   => 'tape',
        })
    end
    it 'should generate valid content for /etc/bacula/bacula-sd.conf' do
        should contain_file('/etc/bacula/bacula-sd.conf').with({
            'ensure'  => 'present',
            'owner'   => 'bacula',
            'group'   => 'tape',
            'mode'    => '0400',
        }) \
        .with_content(/Name = "testdirector"/) \
        .with_content(/Password = "testdirectorpass"/) \
        .with_content(%r{TLS Certificate = "/etc/bacula/sd/ssl/cert.pem"}) \
        .with_content(%r{TLS Key = "/etc/bacula/sd/ssl/server.key"}) \
        .with_content(/Name = "testhost.example.com-fd"/) \
        .with_content(/SDport = 9000/) \
        .with_content(/Maximum Concurrent Jobs = 10/)
    end
end
