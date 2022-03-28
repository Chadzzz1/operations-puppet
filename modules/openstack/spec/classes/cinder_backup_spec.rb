require_relative '../../../../rake_modules/spec_helper'
require 'rspec-puppet/cache'

describe 'openstack::cinder::backup' do
  on_supported_os(WMFConfig.test_on(10)).each do |os, facts|
    context "On #{os}" do
      case os
      when "bullseye"
        # To be added once tests support bullseye
        supported_openstacks = ["victoria", "wallaby"]
      else
        supported_openstacks = ["victoria"]
      end
      supported_openstacks.each do |openstack_version|
        context "On openstack #{openstack_version}" do
          let(:pre_condition) {
            "class {'base::puppet': ca_source => 'puppet:///modules/profile/puppet/ca.production.pem'}"
            "class {'openstack::cinder::config::#{openstack_version}':
                openstack_controllers => ['dummy-controller.local'],
                db_user => 'dummy-db-user',
                db_pass => 'dummy-db-pass',
                db_name => 'dummy-db-name',
                db_host => 'dummy.db.host.local',
                ldap_user_pass => 'dummy-ldap-user-pass',
                keystone_admin_uri => 'http://dummy.keystone.local/admin/uri',
                region => 'dummy-region',
                ceph_pool => 'dummy-ceph-pool',
                ceph_rbd_client_name => 'dummy-rdb-client-name',
                rabbit_user => 'dummy-rabbit-user',
                rabbit_pass => 'dummy-rabbit-pass',
                api_bind_port => 1234,
                libvirt_rbd_cinder_uuid => 'dummycinderuuid',
                backup_path => '/dummy/backup/path',
            }"
          }
          before(:each) do
            Puppet::Parser::Functions.newfunction(:ipresolve, :type => :rvalue) { |_| '127.0.0.10' }
          end
          let(:facts) { facts }
          let(:params) {
            {
              'version' => openstack_version,
              'active'  => true,
            }
          }
          it { should compile }
          it {
            should contain_file('/usr/lib/python3/dist-packages/cinder/backup/chunkeddriver.py.patch')
                   .with_source("puppet:///modules/openstack/#{openstack_version}/cinder/hacks/backup/chunkeddriver.py.patch")
            should contain_exec('apply /usr/lib/python3/dist-packages/cinder/backup/chunkeddriver.py.patch')
          }
        end
      end
    end
  end
end
