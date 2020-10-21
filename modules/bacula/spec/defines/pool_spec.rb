require_relative '../../../../rake_modules/spec_helper'

describe 'bacula::director::pool', :type => :define do
    let(:title) { 'something' }
    let(:params) { {
        :max_vols => '10',
        :storage => 'teststorage',
        :volume_retention => '10 days',
        }
    }
    let(:facts) do
      {
        'lsbdistrelease' => '10.1',
        'lsbdistid' => 'Debian'
      }
    end
    let(:pre_condition) do
      "class {'bacula::director':
        sqlvariant          => 'mysql',
        max_dir_concur_jobs => '10',
      }
      class profile::base ( $notifications_enabled = 1 ){}
      include profile::base
      class {'base::puppet': ca_source => 'puppet:///files/puppet/ca.production.pem'}"
    end

    context 'without label_fmt, max_vol_bytes' do
        it 'should create /etc/bacula/conf.d/pool-something.conf' do
            should contain_file('/etc/bacula/conf.d/pool-something.conf').with({
                'ensure'  => 'present',
                'owner'   => 'root',
                'group'   => 'bacula',
                'mode'    => '0440',
            }) \
            .with_content(/Name = something/) \
            .with_content(/Maximum Volumes = 10/) \
            .with_content(/Storage = teststorage/) \
            .with_content(/Volume Retention = 10 days/) \
            .with_content(/AutoPrune = yes/) \
            .with_content(/Recycle = yes/) \
            .with_content(/Catalog Files = yes/)
        end
    end

    context 'with max_vol_bytes' do
        let(:params) { {
            :max_vols => '10',
            :storage => 'teststorage',
            :volume_retention => '10 days',
            :max_vol_bytes => '2000',
            }
        }
        it 'should create /etc/bacula/conf.d/pool-something.conf' do
            should contain_file('/etc/bacula/conf.d/pool-something.conf') \
            .with_content(/Maximum Volume Bytes = 2000/) \
        end
    end
    context 'with max_vol_bytes' do
        let(:params) { {
            :max_vols => '10',
            :storage => 'teststorage',
            :volume_retention => '10 days',
            :label_fmt => 'TEST',
            }
        }
        it 'should create /etc/bacula/conf.d/pool-something.conf' do
            should contain_file('/etc/bacula/conf.d/pool-something.conf') \
            .with_content(/Label Format = "TEST"/) \
        end
    end
end
