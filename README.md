# dirty_frag

## Description

Detect and mitigate the dirty frag kernel vulnerability (CVE-2026-43284, CVE-2026-43500) across your Linux fleet.

The dirty frag vulnerability allows attackers to exploit IP fragment reassembly in the `esp4`, `esp6`, and `rxrpc` kernel modules to achieve privilege escalation or remote code execution. This module provides three complementary tools to manage the risk:

1. A **structured fact** that reports whether each vulnerable module is loaded, blacklisted, or available on every node
2. A **Puppet class** that blacklists vulnerable modules via `modprobe.d`, preventing them from loading on boot
3. A **Bolt task** that unloads a vulnerable module from a running kernel immediately

Together, these give you fleet-wide visibility, persistent mitigation, and on-demand remediation.

## Setup

### Requirements

- Puppet 7.x or 8.x
- [puppetlabs-stdlib](https://forge.puppet.com/modules/puppetlabs/stdlib) >= 4.0.0 < 10.0.0
- Linux operating system (the fact and class are Linux-only)

### What dirty_frag affects

- Creates and manages `/etc/modprobe.d/dirtyfrag.conf` to blacklist vulnerable kernel modules
- The custom fact reads `/proc/modules` and `/etc/modprobe.d/` files, and runs `modinfo` to determine module availability
- The Bolt task runs `modprobe -r` to unload modules from the running kernel

### Supported operating systems

- RedHat 7, 8, 9
- CentOS 7, 8
- Ubuntu 20.04, 22.04, 24.04
- Debian 11, 12
- SLES 15

## Usage

### Viewing the fact

Once the module is installed, the `dirty_frag` fact is available on every Linux node. It returns a hash with one entry per vulnerable module:

```json
{
  "esp4": {
    "loaded": true,
    "blacklisted": false,
    "available": true
  },
  "esp6": {
    "loaded": false,
    "blacklisted": false,
    "available": true
  },
  "rxrpc": {
    "loaded": false,
    "blacklisted": true,
    "available": true
  }
}
```

Each module reports three fields:

- `loaded` — whether the module is currently loaded in the running kernel (present in `/proc/modules`)
- `blacklisted` — whether an `install <module> /bin/false` directive exists in any file under `/etc/modprobe.d/`
- `available` — whether the module is available on the system (i.e. `modinfo` can find it)

Query the fact on a single node:

```shell
puppet facts show dirty_frag
```

### Applying the class with Hiera

The class exposes three Boolean parameters, all defaulting to `false`:

| Parameter | Type | Default | Description |
|---|---|---|---|
| `mitigate_esp4` | `Boolean` | `false` | Blacklist the `esp4` kernel module |
| `mitigate_esp6` | `Boolean` | `false` | Blacklist the `esp6` kernel module |
| `mitigate_rxrpc` | `Boolean` | `false` | Blacklist the `rxrpc` kernel module |

To blacklist all three modules via Hiera:

```yaml
# data/common.yaml (or your preferred hierarchy level)
dirty_frag::mitigate_esp4: true
dirty_frag::mitigate_esp6: true
dirty_frag::mitigate_rxrpc: true
```

Then include the class in your node classification:

```puppet
include dirty_frag
```

This writes `/etc/modprobe.d/dirtyfrag.conf` with `install <module> /bin/false` directives for each enabled parameter. The `install ... /bin/false` approach is used rather than the `blacklist` directive because `blacklist` only prevents autoloading and does not block explicit `modprobe` calls.

### Applying the class with resource-like declaration

```puppet
class { 'dirty_frag':
  mitigate_esp4  => true,
  mitigate_esp6  => true,
  mitigate_rxrpc => false,
}
```

### Using the Bolt task

The `dirty_frag::unload` task unloads a specified vulnerable module from the running kernel. This is useful for immediate remediation without waiting for a reboot.

```shell
bolt task run dirty_frag::unload module=esp4 --targets servers
```

The `module` parameter accepts one of: `esp4`, `esp6`, or `rxrpc`.

On success, the task returns structured JSON:

```json
{
  "module": "esp4",
  "status": "unloaded",
  "message": "Successfully unloaded module 'esp4'"
}
```

The task will return an error if the module is not currently loaded, is in use by another kernel subsystem, or is not in the allow-list.

### PuppetDB queries for fleet-wide visibility

Find all nodes where `esp4` is currently loaded:

```shell
puppet query 'facts[certname, value] { name = "dirty_frag" and value.esp4.loaded = true }'
```

Find all nodes where any vulnerable module is loaded but not yet blacklisted:

```shell
puppet query 'facts[certname, value] { name = "dirty_frag" and (value.esp4.loaded = true and value.esp4.blacklisted = false) or (value.esp6.loaded = true and value.esp6.blacklisted = false) or (value.rxrpc.loaded = true and value.rxrpc.blacklisted = false) }'
```

## Reference

Full reference documentation for classes, facts, and tasks is available in [REFERENCE.md](REFERENCE.md), generated from inline Puppet Strings comments.

## Limitations

- **Linux only.** The fact is confined to nodes where `kernel == 'Linux'`. The class and task assume Linux kernel module tooling.
- **Blacklisting does not unload live modules.** The Puppet class writes `modprobe.d` configuration that prevents modules from loading on next boot or next `modprobe` call. It does not unload modules that are already running. Use the `dirty_frag::unload` Bolt task for immediate removal from a live kernel.
- **No kernel version detection.** The module does not attempt to determine whether the running kernel version is actually vulnerable. It reports and manages module state regardless of kernel version. If you need kernel-version-aware logic, handle that in your classification or Hiera hierarchy.
- **Module in use.** The Bolt task cannot unload a module that is in use by another kernel subsystem. In that case, a reboot with the blacklist in place is the recommended remediation path.

## Development

This module uses the [Puppet Development Kit (PDK)](https://www.puppet.com/docs/pdk/latest/pdk.html) for development and testing.

Validate the module:

```shell
pdk validate
```

Run unit tests:

```shell
pdk test unit
```

Run a specific test file:

```shell
pdk test unit --tests spec/classes/dirty_frag_spec.rb
```

Generate the REFERENCE.md from Puppet Strings comments:

```shell
pdk bundle exec puppet strings generate --format markdown
```
