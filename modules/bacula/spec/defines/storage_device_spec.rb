require_relative '../../../../rake_modules/spec_helper'

describe 'bacula::storage::device', :type => :define do
    let(:title) { 'something' }
    let(:params) { {
        :device_type => 'File',
        :media_type  => 'File',
        :archive_device => '/dev/nst0',
        :max_concur_jobs => '10',
        }
    }
    let(:facts) do
      {
        'lsbdistrelease' => '10.1',
        'lsbdistid' => 'Debian'
      }
    end
    let(:pre_condition) do
      "class {'bacula::storage':
        director            => 'dir.example.com',
        sd_max_concur_jobs  => 5,
        sqlvariant          => 'mysql',
      }
      class profile::base ( $notifications_enabled = 1 ){}
      include profile::base
      class {'base::puppet': ca_source => 'puppet:///files/puppet/ca.production.pem'}"
    end

    context 'without spool_dir, max_spool_size' do
        it 'should create /etc/bacula/sd-devices.d/something.conf' do
            should contain_file('/etc/bacula/sd-devices.d/something.conf').with({
                'ensure'  => 'present',
                'owner'   => 'bacula',
                'group'   => 'tape',
                'mode'    => '0440',
            }) \
            .with_content(/Name = something/) \
            .with_content(/Device Type = File/) \
            .with_content(/Media Type = File/) \
            .with_content(%r{Archive Device = /dev/nst0}) \
            .with_content(/Maximum Concurrent Jobs = 10/)
        end
    end

    context 'with spool_dir, max_spool_size' do
        let(:params) { {
            :device_type => 'File',
            :media_type  => 'File',
            :archive_device => '/dev/nst0',
            :max_concur_jobs => '10',
            :spool_dir => '/tmp',
            :max_spool_size => '100',
            }
        }

        it 'should create /etc/bacula/sd-devices.d/something.conf' do
            should contain_file('/etc/bacula/sd-devices.d/something.conf') \
            .with_content(/Maximum Spool Size = 100/) \
            .with_content(%r{Spool Directory = /tmp})
        end
    end
end
