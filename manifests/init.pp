# @summary Detect and mitigate the dirty frag kernel vulnerability
#
# @param mitigate_esp4
#   Blacklist the esp4 kernel module via modprobe.d
# @param mitigate_esp6
#   Blacklist the esp6 kernel module via modprobe.d
# @param mitigate_rxrpc
#   Blacklist the rxrpc kernel module via modprobe.d
class dirty_frag (
  Boolean $mitigate_esp4  = false,
  Boolean $mitigate_esp6  = false,
  Boolean $mitigate_rxrpc = false,
) {
  file { '/etc/modprobe.d/dirtyfrag.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => epp('dirty_frag/dirtyfrag.conf.epp', {
        'mitigate_esp4'  => $mitigate_esp4,
        'mitigate_esp6'  => $mitigate_esp6,
        'mitigate_rxrpc' => $mitigate_rxrpc,
    }),
  }
}
