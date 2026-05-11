# frozen_string_literal: true

require 'spec_helper'

describe 'dirty_frag' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').with(
            'ensure' => 'file',
            'owner'  => 'root',
            'group'  => 'root',
            'mode'   => '0644',
          )
        }

        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').with_content(%r{# Managed by Puppet}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').without_content(%r{install esp4 /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').without_content(%r{install esp6 /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').without_content(%r{install rxrpc /bin/false}) }
      end

      context 'with mitigate_esp4 only' do
        let(:params) { { 'mitigate_esp4' => true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').with_content(%r{install esp4 /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').without_content(%r{install esp6 /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').without_content(%r{install rxrpc /bin/false}) }
      end

      context 'with mitigate_esp6 only' do
        let(:params) { { 'mitigate_esp6' => true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').with_content(%r{install esp6 /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').without_content(%r{install esp4 /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').without_content(%r{install rxrpc /bin/false}) }
      end

      context 'with mitigate_rxrpc only' do
        let(:params) { { 'mitigate_rxrpc' => true } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').with_content(%r{install rxrpc /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').without_content(%r{install esp4 /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').without_content(%r{install esp6 /bin/false}) }
      end

      context 'with all three mitigations enabled' do
        let(:params) do
          {
            'mitigate_esp4'  => true,
            'mitigate_esp6'  => true,
            'mitigate_rxrpc' => true,
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').with_content(%r{install esp4 /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').with_content(%r{install esp6 /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').with_content(%r{install rxrpc /bin/false}) }
      end

      context 'with mitigate_esp4 and mitigate_rxrpc enabled' do
        let(:params) do
          {
            'mitigate_esp4'  => true,
            'mitigate_rxrpc' => true,
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').with_content(%r{install esp4 /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').with_content(%r{install rxrpc /bin/false}) }
        it { is_expected.to contain_file('/etc/modprobe.d/dirtyfrag.conf').without_content(%r{install esp6 /bin/false}) }
      end
    end
  end
end
