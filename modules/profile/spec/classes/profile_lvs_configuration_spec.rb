# SPDX-License-Identifier: Apache-2.0
require_relative '../../../../rake_modules/spec_helper'

describe 'profile::lvs::configuration' do
  on_supported_os(WMFConfig.test_on).each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:node) { 'idontexist1001' }
      let(:params) do
        {
          all_class_hosts: {
            'eqiad' => {
              'high-traffic1' => {
                'primary' => 'lvs1017',
                'secondary' => 'lvs1020',
              },
              'high-traffic2' => {
                'primary' => 'lvs1018',
                'secondary' => 'lvs1020',
              },
              'low-traffic' => {
                'primary' => 'lvs1019',
                'secondary' => 'lvs1020',
              }
            },
            'codfw' => {
              'high-traffic1' => {
                'primary' => 'lvs2017',
                'secondary' => 'lvs2020',
              },
              'high-traffic2' => {
                'primary' => 'lvs2018',
                'secondary' => 'lvs2020',
              },
              'low-traffic' => {
                'primary' => 'lvs2019',
                'secondary' => 'lvs2020',
              }
            }
          }
        }
      end

      describe 'unclassified host' do
        it { is_expected.to compile }
        it { is_expected.to have_motd__message_resource_count(0) }
      end
      describe 'high-traffic1 primary' do
        let(:node) { 'lvs1017' }

        it { is_expected.to compile }
        it { is_expected.to contain_motd__message('LVS Class: high-traffic1') }
      end
      describe 'high-traffic1 secondary' do
        let(:node) { 'lvs1020' }

        it { is_expected.to compile }
        it { is_expected.to contain_motd__message('LVS Class: secondary') }
      end
      describe 'high-traffic2 primary' do
        let(:node) { 'lvs1018' }

        it { is_expected.to compile }
        it { is_expected.to contain_motd__message('LVS Class: high-traffic2') }
      end
      describe 'high-traffic2 secondary' do
        let(:node) { 'lvs1020' }

        it { is_expected.to compile }
        it { is_expected.to contain_motd__message('LVS Class: secondary') }
      end
      describe 'low-traffic primary' do
        let(:node) { 'lvs1019' }

        it { is_expected.to compile }
        it { is_expected.to contain_motd__message('LVS Class: low-traffic') }
      end
      describe 'low-traffic secondary' do
        let(:node) { 'lvs1020' }

        it { is_expected.to compile }
        it { is_expected.to contain_motd__message('LVS Class: secondary') }
      end
    end
  end
end
