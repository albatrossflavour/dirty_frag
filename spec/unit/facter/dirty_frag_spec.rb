# frozen_string_literal: true

require 'facter'

describe 'dirty_frag' do
  before(:each) do
    Facter.clear
    allow(Facter.fact(:kernel)).to receive(:value).and_return('Linux')
    allow(File).to receive(:directory?).and_call_original
    allow(File).to receive(:directory?).with('/etc/modprobe.d').and_return(true)
    allow(Dir).to receive(:glob).and_call_original
    allow(Dir).to receive(:glob).with('/etc/modprobe.d/*').and_return([])
    allow(File).to receive(:file?).and_call_original
  end

  let(:proc_modules_all_loaded) do
    <<~PROC
      esp4 12345 0 - Live 0xffffffff00000000
      esp6 12345 0 - Live 0xffffffff00000001
      rxrpc 12345 0 - Live 0xffffffff00000002
      ip_tables 12345 0 - Live 0xffffffff00000003
    PROC
  end

  let(:proc_modules_none_loaded) do
    <<~PROC
      ip_tables 12345 0 - Live 0xffffffff00000000
      nf_conntrack 12345 0 - Live 0xffffffff00000001
    PROC
  end

  let(:proc_modules_mixed) do
    <<~PROC
      esp4 12345 0 - Live 0xffffffff00000000
      ip_tables 12345 0 - Live 0xffffffff00000001
    PROC
  end

  let(:proc_modules_substring) do
    <<~PROC
      esp4_offload 12345 0 - Live 0xffffffff00000000
      esp6_offload 12345 0 - Live 0xffffffff00000001
    PROC
  end

  context 'when all modules are loaded' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_all_loaded)
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'reports all modules as loaded' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['loaded']).to be true
      expect(result['esp6']['loaded']).to be true
      expect(result['rxrpc']['loaded']).to be true
    end

    it 'reports vulnerable as true' do
      result = Facter.value('dirty_frag')
      expect(result['vulnerable']).to be true
    end
  end

  context 'when no modules are loaded' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_none_loaded)
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'reports all modules as not loaded' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['loaded']).to be false
      expect(result['esp6']['loaded']).to be false
      expect(result['rxrpc']['loaded']).to be false
    end

    it 'reports vulnerable as false' do
      result = Facter.value('dirty_frag')
      expect(result['vulnerable']).to be false
    end

    it 'reports reboot_required as false' do
      result = Facter.value('dirty_frag')
      expect(result['reboot_required']).to be false
    end
  end

  context 'when only esp4 is loaded (mixed state)' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_mixed)
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'reports esp4 as loaded and others as not loaded' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['loaded']).to be true
      expect(result['esp6']['loaded']).to be false
      expect(result['rxrpc']['loaded']).to be false
    end

    it 'reports vulnerable as true when any module is loaded' do
      result = Facter.value('dirty_frag')
      expect(result['vulnerable']).to be true
    end
  end

  context 'when a module is blacklisted and still loaded (reboot required)' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_all_loaded)
      allow(Dir).to receive(:glob).with('/etc/modprobe.d/*').and_return(['/etc/modprobe.d/blacklist.conf'])
      allow(File).to receive(:file?).with('/etc/modprobe.d/blacklist.conf').and_return(true)
      allow(File).to receive(:readlines).with('/etc/modprobe.d/blacklist.conf')
                                        .and_return(["install esp4 /bin/false\n"])
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'reports reboot_required as true' do
      result = Facter.value('dirty_frag')
      expect(result['reboot_required']).to be true
    end

    it 'reports vulnerable as true' do
      result = Facter.value('dirty_frag')
      expect(result['vulnerable']).to be true
    end

    it 'reports the module as both blacklisted and loaded' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['blacklisted']).to be true
      expect(result['esp4']['loaded']).to be true
    end
  end

  context 'when a module is blacklisted with /bin/false' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_none_loaded)
      allow(Dir).to receive(:glob).with('/etc/modprobe.d/*').and_return(['/etc/modprobe.d/blacklist.conf'])
      allow(File).to receive(:file?).with('/etc/modprobe.d/blacklist.conf').and_return(true)
      allow(File).to receive(:readlines).with('/etc/modprobe.d/blacklist.conf')
                                        .and_return(["install esp4 /bin/false\n"])
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'reports the module as blacklisted' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['blacklisted']).to be true
    end

    it 'reports reboot_required as false when blacklisted but not loaded' do
      result = Facter.value('dirty_frag')
      expect(result['reboot_required']).to be false
    end
  end

  context 'when a module is blacklisted with /bin/true' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_none_loaded)
      allow(Dir).to receive(:glob).with('/etc/modprobe.d/*').and_return(['/etc/modprobe.d/nomod.conf'])
      allow(File).to receive(:file?).with('/etc/modprobe.d/nomod.conf').and_return(true)
      allow(File).to receive(:readlines).with('/etc/modprobe.d/nomod.conf')
                                        .and_return(["install esp6 /bin/true\n"])
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'reports the module as blacklisted' do
      result = Facter.value('dirty_frag')
      expect(result['esp6']['blacklisted']).to be true
    end
  end

  context 'when no blacklist directives are present' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_none_loaded)
      allow(Dir).to receive(:glob).with('/etc/modprobe.d/*').and_return(['/etc/modprobe.d/other.conf'])
      allow(File).to receive(:file?).with('/etc/modprobe.d/other.conf').and_return(true)
      allow(File).to receive(:readlines).with('/etc/modprobe.d/other.conf')
                                        .and_return(["# just a comment\n", "options snd_hda_intel power_save=1\n"])
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'reports all modules as not blacklisted' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['blacklisted']).to be false
      expect(result['esp6']['blacklisted']).to be false
      expect(result['rxrpc']['blacklisted']).to be false
    end
  end

  context 'when a module is available via modinfo' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_none_loaded)
      allow(Facter::Core::Execution).to receive(:execute)
        .with('modinfo esp4', on_fail: :failed)
        .and_return('filename: /lib/modules/esp4.ko')
      allow(Facter::Core::Execution).to receive(:execute)
        .with('modinfo esp6', on_fail: :failed)
        .and_return('filename: /lib/modules/esp6.ko')
      allow(Facter::Core::Execution).to receive(:execute)
        .with('modinfo rxrpc', on_fail: :failed)
        .and_return(:failed)
    end

    it 'reports available modules correctly' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['available']).to be true
      expect(result['esp6']['available']).to be true
      expect(result['rxrpc']['available']).to be false
    end
  end

  context 'when modinfo fails for all modules' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_none_loaded)
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return(:failed)
    end

    it 'reports all modules as not available without crashing' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['available']).to be false
      expect(result['esp6']['available']).to be false
      expect(result['rxrpc']['available']).to be false
    end
  end

  context 'when /proc/modules is unreadable' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_raise(Errno::EACCES, '/proc/modules')
    end

    it 'returns a hash with an error key' do
      result = Facter.value('dirty_frag')
      expect(result).to be_a(Hash)
      expect(result).to have_key('error')
      expect(result['error']).to match(%r{Permission denied})
    end
  end

  context 'when kernel is not Linux (non-Linux confine)' do
    before(:each) do
      Facter.clear
      allow(Facter.fact(:kernel)).to receive(:value).and_return('Darwin')
    end

    it 'does not resolve the fact' do
      result = Facter.value('dirty_frag')
      expect(result).to be_nil
    end
  end

  context 'when /proc/modules contains substring matches' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_substring)
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'does not match esp4_offload as esp4' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['loaded']).to be false
      expect(result['esp6']['loaded']).to be false
    end
  end

  context 'when blacklist directive is in a custom conf file' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_none_loaded)
      allow(Dir).to receive(:glob).with('/etc/modprobe.d/*')
                                  .and_return(['/etc/modprobe.d/custom.conf', '/etc/modprobe.d/another.conf'])
      allow(File).to receive(:file?).with('/etc/modprobe.d/custom.conf').and_return(true)
      allow(File).to receive(:file?).with('/etc/modprobe.d/another.conf').and_return(true)
      allow(File).to receive(:readlines).with('/etc/modprobe.d/custom.conf')
                                        .and_return(["# custom blacklist\n", "install rxrpc /bin/false\n"])
      allow(File).to receive(:readlines).with('/etc/modprobe.d/another.conf')
                                        .and_return(["# nothing relevant\n"])
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'detects blacklist in non-standard config files' do
      result = Facter.value('dirty_frag')
      expect(result['rxrpc']['blacklisted']).to be true
      expect(result['esp4']['blacklisted']).to be false
    end
  end

  context 'when /etc/modprobe.d does not exist' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_none_loaded)
      allow(File).to receive(:directory?).with('/etc/modprobe.d').and_return(false)
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'reports all modules as not blacklisted' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['blacklisted']).to be false
      expect(result['esp6']['blacklisted']).to be false
      expect(result['rxrpc']['blacklisted']).to be false
    end
  end

  context 'when /proc/modules is empty' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return('')
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'reports all modules as not loaded' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['loaded']).to be false
      expect(result['esp6']['loaded']).to be false
      expect(result['rxrpc']['loaded']).to be false
    end
  end

  context 'when blacklist directive has leading whitespace' do
    before(:each) do
      allow(File).to receive(:read).with('/proc/modules').and_return(proc_modules_none_loaded)
      allow(Dir).to receive(:glob).with('/etc/modprobe.d/*').and_return(['/etc/modprobe.d/ws.conf'])
      allow(File).to receive(:file?).with('/etc/modprobe.d/ws.conf').and_return(true)
      allow(File).to receive(:readlines).with('/etc/modprobe.d/ws.conf')
                                        .and_return(["  \tinstall esp4 /bin/false\n"])
      allow(Facter::Core::Execution).to receive(:execute)
        .with(anything, on_fail: :failed)
        .and_return('filename: /lib/modules/test')
    end

    it 'detects blacklist with leading whitespace' do
      result = Facter.value('dirty_frag')
      expect(result['esp4']['blacklisted']).to be true
    end
  end
end
