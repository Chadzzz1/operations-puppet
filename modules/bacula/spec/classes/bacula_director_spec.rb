require_relative '../../../../rake_modules/spec_helper'

describe 'bacula::director', :type => :class do
    let(:node) { 'testhost.example.com' }
    let(:facts) do
      {
        'lsbdistrelease' => '10.1',
        'lsbdistid' => 'Debian'
      }
    end
    let(:params) { {
        :max_dir_concur_jobs => '10',
        :sqlvariant => 'testsql',
        :dir_port => '9900',
        :bconsolepassword => 'bconsolepass',
        }
    }
    let(:pre_condition) { "class {'base::puppet': ca_source => 'puppet:///files/puppet/ca.production.pem'}" }

    it { should contain_package('bacula-director') }
    it { should contain_package('bacula-director-testsql') }
    it { should contain_service('bacula-director') }
    it do
        should contain_file('/etc/bacula/conf.d').with({
        'ensure'  => 'directory',
        'recurse' => 'true',
        'force'   => 'true',
        'purge'   => 'true',
        'mode'    => '0550',
        'owner'   => 'bacula',
        'group'   => 'bacula',
        })
    end
    it do
        should contain_file('/etc/bacula/jobs.d').with({
        'ensure'  => 'directory',
        'recurse' => 'true',
        'force'   => 'true',
        'purge'   => 'true',
        'mode'    => '0550',
        'owner'   => 'bacula',
        'group'   => 'bacula',
        })
    end
    it do
        should contain_file('/etc/bacula/clients.d').with({
        'ensure'  => 'directory',
        'recurse' => 'true',
        'force'   => 'true',
        'purge'   => 'true',
        'mode'    => '0550',
        'owner'   => 'bacula',
        'group'   => 'bacula',
        })
    end
    it do
        should contain_file('/etc/bacula/storages.d').with({
        'ensure'  => 'directory',
        'recurse' => 'true',
        'force'   => 'true',
        'purge'   => 'true',
        'mode'    => '0550',
        'owner'   => 'bacula',
        'group'   => 'bacula',
        })
    end
    it 'should generate valid content for /etc/bacula/bacula-dir.conf' do
        should contain_file('/etc/bacula/bacula-dir.conf').with({
            'ensure'  => 'present',
            'owner'   => 'bacula',
            'group'   => 'bacula',
            'mode'    => '0400',
        }) \
        .with_content(/Name = "testhost.example.com"/) \
        .with_content(/Password = "bconsolepass"/) \
        .with_content(%r{TLS Certificate = "/etc/bacula/director/ssl/cert.pem"}) \
        .with_content(%r{TLS Key = "/etc/bacula/director/ssl/server.key"}) \
        .with_content(/DIRport = 9900/) \
        .with_content(/Maximum Concurrent Jobs = 10/)
    end
    it 'should generate valid content for /etc/bacula/jobs.d/restore-migrate-jobs.conf' do
        should contain_file('/etc/bacula/jobs.d/restore-migrate-jobs.conf').with({
            'ensure'  => 'file',
            'owner'   => 'bacula',
            'group'   => 'bacula',
            'mode'    => '0400',
        }) \
        .with_content(/Client = testhost.example.com-fd/) \
        .with_content(/Type = Restore/) \
        .with_content(/Type = Migrate/) \
    end
end
