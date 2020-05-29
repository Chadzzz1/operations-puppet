# frozen_string_literal: true

require_relative '../../../../rake_modules/spec_helper'

describe 'apereo_cas' do
  on_supported_os(WMFConfig.test_on(10)).each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }
      let(:params) do
        {
          keystore_source: 'puppet:///modules/apereo_cas/thekeystore',
          idp_primary: 'idp1001.wikimedia.org',  # theses need to resolve for the checks to pass
          idp_failover: 'idp2001.wikimedia.org',
        }
      end
      let(:pre_condition) do
        "class profile::base ( $notifications_enabled = 1 ){}
        service{'tomcat9':}
        include profile::base"
      end
      describe 'test with default settings' do
        it { is_expected.to compile.with_all_deps }
        ['/etc/cas', '/etc/cas/services', '/etc/cas/config'].each do |dir|
          it do
            is_expected.to contain_file(dir).with_ensure('directory')
          end
        end
        it do
          is_expected.to contain_file('/etc/cas/config/cas.properties').with(
            owner: 'cas',
            group: 'root',
            mode: '0400'
          ).with_content(
            %r{^cas\.server\.name=https://foo.example.com:8443$}
          ).with_content(
            %r{^cas\.server\.prefix=https://foo.example.com:8443/cas$}
          ).with_content(
            %r{^cas\.serviceRegistry\.json\.location=file:/etc/cas/services$}
          ).with_content(
            /^cas\.authn\.ldap\[0\]\.principalAttributeList=cn,memberOf,mail$/
          ).with_content(
            /^cas\.authn\.ldap\[0\]\.type=AUTHENTICATED$/
          ).with_content(
            /^cas\.authn\.ldap\[0\]\.connectionStrategy=ACTIVE_PASSIVE$/
          ).with_content(
            /^cas\.authn\.ldap\[0\]\.ldapurl=$/
          ).with_content(
            /^cas\.authn\.ldap\[0\]\.useStartTLS=true$/
          ).with_content(
            /^cas\.authn\.ldap\[0\]\.basedn=dc=example,dc=org/
          ).with_content(
            /^cas\.authn\.ldap\[0\]\.searchFilter=cn={user}$/
          ).with_content(
            /^cas\.authn\.ldap\[0\]\.binddn=cn=user,dc=example,dc=org$/
          ).with_content(
            /^cas\.authn\.ldap\[0\]\.bindcredential=changeme$/
          ).with_content(
            /^cas\.authn\.accept.users=$/
          ).with_content(
            /^logging\.level\.org\.apereo=WARN$/
          ).without_content(
            /cas\.(tgc|webflow|authn\.mfa\.u2f)\.crypto\.(signing|encryption)\.key/
          ).without_content(
            /cas\.ticket\.registry\.memcached/
          )

          is_expected.to contain_file('/etc/cas/config/log4j2.xml').with(
            owner: 'cas',
            group: 'root',
            mode: '0400'
          )
          is_expected.to contain_file('/etc/cas/thekeystore').with(
            owner: 'cas',
            group: 'root',
            mode: '0400'
          )
        end
      end
      describe 'Change Defaults' do
        context 'tgc_signing_key' do
          let(:params) { super().merge(tgc_signing_key: 'foobar') }

          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/cas/config/cas.properties').with_content(
              /cas.tgc.crypto.signing.key=foobar/
            )
          end
        end
        context 'tgc_encryption_key' do
          let(:params) { super().merge(tgc_encryption_key: 'foobar') }

          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/cas/config/cas.properties').with_content(
              /cas.tgc.crypto.encryption.key=foobar/
            )
          end
        end
        context 'webflow_signing_key' do
          let(:params) { super().merge(webflow_signing_key: 'foobar') }

          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/cas/config/cas.properties').with_content(
              /cas.webflow.crypto.signing.key=foobar/
            )
          end
        end
        context 'webflow_encryption_key' do
          let(:params) { super().merge(webflow_encryption_key: 'foobar') }

          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/cas/config/cas.properties').with_content(
              /cas.webflow.crypto.encryption.key=foobar/
            )
          end
        end
        context 'u2f_signing_key' do
          let(:params) { super().merge(u2f_signing_key: 'foobar') }

          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/cas/config/cas.properties').with_content(
              /cas.authn.mfa.u2f.crypto.signing.key=foobar/
            )
          end
        end
        context 'u2f_encryption_key' do
          let(:params) { super().merge(u2f_encryption_key: 'foobar') }

          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/cas/config/cas.properties').with_content(
              /cas.authn.mfa.u2f.crypto.encryption.key=foobar/
            )
          end
        end
        context 'prometheus_nodes' do
          # If we use a host with ipv6 then CI fails if a user without IPv6 tests localy
          # So we use ns0 and ns1 as they are IPv4 only and somewhat stable
          let(:params) { super().merge(prometheus_nodes: ['ns0.wikimedia.org', 'ns1.wikimedia.org']) }

          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/cas/config/cas.properties').with_content(
              /management.metrics.export.prometheus.enabled=true\n
               cas.monitor.endpoints.endpoint.prometheus.access=IP_ADDRESS\n
              cas.monitor.endpoints.endpoint.prometheus.requiredIpAddresses=::1,127.0.0.1,208.80.153.231,208.80.154.238\n
              /x
            )
          end
        end
        context 'memcached_enable' do
          let(:params) { super().merge(memcached_enable: true) }

          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/cas/config/cas.properties').with_content(
              /cas.ticket.registry.memcached.servers=localhost:11211/
            ).with_content(
              /cas.ticket.registry.memcached.transcoder=KRYO/
            )
          end
        end
        context 'memcached_port' do
          let(:params) { super().merge(memcached_enable: true, memcached_port: 42) }

          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/cas/config/cas.properties').with_content(
              /cas.ticket.registry.memcached.servers=localhost:42/
            )
          end
        end
        context 'memcached_enable' do
          let(:params) { super().merge(memcached_enable: true, memcached_server: 'foobar.org') }

          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/cas/config/cas.properties').with_content(
              /cas.ticket.registry.memcached.servers=foobar.org:11211/
            )
          end
        end
        context 'memcached_enable' do
          let(:params) { super().merge(memcached_enable: true, memcached_transcoder: 'WHALINV1') }

          it { is_expected.to compile }
          it do
            is_expected.to contain_file('/etc/cas/config/cas.properties').with_content(
              /cas.ticket.registry.memcached.transcoder=WHALINV1/
            )
          end
        end
      end
    end
  end
end
