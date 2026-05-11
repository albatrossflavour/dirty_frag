# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'dirty_frag class' do
  include PuppetLitmus

  context 'with default parameters (detection only)' do
    let(:manifest) { 'include dirty_frag' }

    it 'applies cleanly' do
      idempotent_apply(manifest)
    end

    it 'creates the modprobe.d config file' do
      result = run_shell('test -f /etc/modprobe.d/dirtyfrag.conf')
      expect(result.exit_code).to eq(0)
    end

    it 'does not contain any install lines when no mitigation is enabled' do
      result = run_shell('cat /etc/modprobe.d/dirtyfrag.conf')
      expect(result.stdout).not_to match(%r{^install\s+})
    end
  end

  context 'with mitigate_esp4 enabled' do
    let(:manifest) do
      <<~PUPPET
        class { 'dirty_frag':
          mitigate_esp4 => true,
        }
      PUPPET
    end

    it 'applies cleanly' do
      idempotent_apply(manifest)
    end

    it 'creates config containing esp4 install block' do
      result = run_shell('cat /etc/modprobe.d/dirtyfrag.conf')
      expect(result.stdout).to match(%r{^install esp4 /bin/false$})
    end

    it 'does not contain esp6 or rxrpc lines' do
      result = run_shell('cat /etc/modprobe.d/dirtyfrag.conf')
      expect(result.stdout).not_to match(%r{^install esp6 })
      expect(result.stdout).not_to match(%r{^install rxrpc })
    end
  end

  context 'with all three parameters enabled' do
    let(:manifest) do
      <<~PUPPET
        class { 'dirty_frag':
          mitigate_esp4  => true,
          mitigate_esp6  => true,
          mitigate_rxrpc => true,
        }
      PUPPET
    end

    it 'applies cleanly' do
      idempotent_apply(manifest)
    end

    it 'contains all three install lines' do
      result = run_shell('cat /etc/modprobe.d/dirtyfrag.conf')
      expect(result.stdout).to match(%r{^install esp4 /bin/false$})
      expect(result.stdout).to match(%r{^install esp6 /bin/false$})
      expect(result.stdout).to match(%r{^install rxrpc /bin/false$})
    end
  end

  context 'file ownership and permissions' do
    let(:manifest) { 'include dirty_frag' }

    before(:all) do
      apply_manifest('include dirty_frag')
    end

    it 'has root:root ownership' do
      result = run_shell('stat -c "%U:%G" /etc/modprobe.d/dirtyfrag.conf')
      expect(result.stdout.strip).to eq('root:root')
    end

    it 'has 0644 permissions' do
      result = run_shell('stat -c "%a" /etc/modprobe.d/dirtyfrag.conf')
      expect(result.stdout.strip).to eq('644')
    end
  end

  context 'dirty_frag fact' do
    it 'is present and returns a hash' do
      result = run_shell('facter -p dirty_frag --json')
      fact_data = JSON.parse(result.stdout)
      expect(fact_data['dirty_frag']).to be_a(Hash)
    end

    it 'contains entries for esp4, esp6, and rxrpc' do
      result = run_shell('facter -p dirty_frag --json')
      fact_data = JSON.parse(result.stdout)
      ['esp4', 'esp6', 'rxrpc'].each do |mod|
        expect(fact_data['dirty_frag']).to have_key(mod)
        expect(fact_data['dirty_frag'][mod]).to have_key('loaded')
        expect(fact_data['dirty_frag'][mod]).to have_key('blocked')
        expect(fact_data['dirty_frag'][mod]).to have_key('available')
      end
    end
  end
end
