# The dirty_frag fact is available on every Linux node with no class inclusion
# required. It reports per-module state plus two summary keys:
#
#   $facts['dirty_frag']['vulnerable']      — true if any module is loaded
#   $facts['dirty_frag']['reboot_required'] — true if a module is blocked but still loaded
#
# Use the fact directly in profiles, roles, or PuppetDB queries without
# including the class.

# Only include the class when you need Puppet to *persistently block*
# modules via /etc/modprobe.d/dirtyfrag.conf.

# Block a single module.
class { 'dirty_frag':
  mitigate_esp4 => true,
}

# Block all three vulnerable modules.
class { 'dirty_frag':
  mitigate_esp4  => true,
  mitigate_esp6  => true,
  mitigate_rxrpc => true,
}
