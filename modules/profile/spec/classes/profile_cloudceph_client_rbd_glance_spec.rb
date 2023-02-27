require_relative "../../../../rake_modules/spec_helper"

describe "profile::cloudceph::client::rbd_glance" do
  let(:pre_condition) { 'class { "::apt": }' }
  on_supported_os(WMFConfig.test_on).each do |os, os_facts|
    context "on #{os}" do
      let(:params) {{
        "enable_v2_messenger" => true,
        "mon_hosts" => {
          "monhost01.local" => {
            "public" => {
              "addr" => "127.0.10.1",
            },
          },
          "monhost02.local" => {
            "public" => {
              "addr" => "127.0.10.2",
            },
          },
        },
        "cluster_networks" => ["192.168.4.0/22"],
        "public_networks" => ["10.192.20.0/24"],
        "data_dir" => "/data/dir",
        "fsid" => "dummyfsid-17bc-44dc-9aeb-1d044c9bba9e",
      }}
      let(:facts) { os_facts }

      context "when no ceph repo passed uses correct default" do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_apt__repository("repository_ceph").with_components("thirdparty/ceph-octopus") }
      end

      context "when ceph repo passed uses the given one" do
        let(:params) {
          super().merge({
            "ceph_repository_component" => "dummy/component-repo",
          })
        }
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_apt__repository("repository_ceph").with_components("dummy/component-repo") }
      end
    end
  end
end
