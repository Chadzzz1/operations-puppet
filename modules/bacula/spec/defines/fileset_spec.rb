require_relative '../../../../rake_modules/spec_helper'

describe 'bacula::director::fileset', :type => :define do
    let(:title) { 'something' }
    let(:params) { { :includes => ["/", "/var",], } }
    let(:pre_condition) do
      "class {'bacula::director':
        sqlvariant          => 'mysql',
        max_dir_concur_jobs => '10',
      }
      class {'base::puppet': ca_source => 'puppet:///files/puppet/ca.production.pem'}"
    end
    let(:facts) do
      {
        'lsbdistrelease' => '10.1',
        'lsbdistid' => 'Debian'
      }
    end

    it 'should create /etc/bacula/conf.d/fileset-something.conf' do
        should contain_file('/etc/bacula/conf.d/fileset-something.conf').with({
            'ensure'  => 'present',
            'owner'   => 'root',
            'group'   => 'bacula',
            'mode'    => '0440',
        })
    end

    context 'without excludes' do
        it 'should create valid content for /etc/bacula/conf.d/fileset-something.conf' do
            should contain_file('/etc/bacula/conf.d/fileset-something.conf') \
            .with_content(%r{File = /}) \
            .with_content(%r{File = /var})
        end
    end

    context 'with excludes' do
        let(:params) { {
            :includes    => ["/", "/var",],
            :excludes    => ["/tmp",],
            }
        }
        it 'should create valid content for /etc/bacula/conf.d/fileset-something.conf' do
            should contain_file('/etc/bacula/conf.d/fileset-something.conf') \
            .with_content(%r{File = /}) \
            .with_content(%r{File = /var}) \
            .with_content(%r{File = /tmp})
        end
    end
end
