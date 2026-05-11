# Detection only (default) — deploys the config file with no modules blacklisted.
# The dirty_frag fact still reports loaded/blacklisted/available state for each module.
include dirty_frag

# Selectively blacklist a single module (e.g. esp4 only).
class { 'dirty_frag':
  mitigate_esp4 => true,
}

# Blacklist all three vulnerable modules.
class { 'dirty_frag':
  mitigate_esp4  => true,
  mitigate_esp6  => true,
  mitigate_rxrpc => true,
}
