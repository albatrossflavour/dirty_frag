# frozen_string_literal: true

Facter.add('dirty_frag') do
  confine kernel: 'Linux'

  setcode do
    modules = ['esp4', 'esp6', 'rxrpc']

    begin
      proc_modules_content = File.read('/proc/modules')
      loaded_modules = proc_modules_content.each_line.map { |line| line.split.first }.compact
    rescue StandardError => e
      next { 'error' => "Failed to read /proc/modules: #{e.message}" }
    end

    result = {}
    any_loaded = false
    any_reboot_required = false

    modules.each do |mod|
      loaded = loaded_modules.include?(mod)
      any_loaded = true if loaded

      blocked = false
      modprobe_dir = '/etc/modprobe.d'
      if File.directory?(modprobe_dir)
        begin
          Dir.glob(File.join(modprobe_dir, '*')).each do |conf_file|
            next unless File.file?(conf_file)

            File.readlines(conf_file).each do |line|
              if line.match?(%r{^\s*install\s+#{Regexp.escape(mod)}\s+/bin/(true|false)})
                blocked = true
                break
              end
            end
            break if blocked
          end
        rescue StandardError
          # If we cannot read modprobe.d files, treat as not blocked
        end
      end

      any_reboot_required = true if blocked && loaded

      modinfo_result = Facter::Core::Execution.execute("modinfo #{mod}", on_fail: :failed)
      available = modinfo_result != :failed

      result[mod] = {
        'loaded'   => loaded,
        'blocked'  => blocked,
        'available' => available,
      }
    end

    result['vulnerable'] = any_loaded
    result['reboot_required'] = any_reboot_required

    result
  end
end
