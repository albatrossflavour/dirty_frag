# dirty_frag

Detect and mitigate the [dirty frag](https://nvd.nist.gov/vuln/detail/CVE-2026-43284) kernel vulnerability across your Linux fleet.

## What is dirty frag?

Dirty frag ([CVE-2026-43284](https://nvd.nist.gov/vuln/detail/CVE-2026-43284), [CVE-2026-43500](https://nvd.nist.gov/vuln/detail/CVE-2026-43500)) is a Linux kernel vulnerability in IP fragment reassembly. Attackers can exploit the `esp4`, `esp6`, and `rxrpc` kernel modules to achieve privilege escalation or remote code execution. If any of these modules is loaded, the system is vulnerable.

The primary mitigation is to prevent these modules from loading. The `install <module> /bin/false` directive in `modprobe.d` achieves this persistently, but a reboot is required to unload modules that are already running.

## What this module provides

This module ships three complementary tools:

1. **A structured fact** (`dirty_frag`) that reports vulnerability status, per-module state, and whether a reboot is needed. No code changes required, just deploy the module.
2. **A Puppet class** (`dirty_frag`) that persistently blacklists modules via `/etc/modprobe.d/dirtyfrag.conf`. Only needed when you want Puppet to enforce the blacklist.
3. **A Bolt task** (`dirty_frag::unload`) that immediately unloads a module from a running kernel.

The fact is the primary tool. Deploy the module and you get fleet-wide visibility without touching a manifest.

## Setup

### Requirements

- Puppet 7.x or 8.x
- [puppetlabs-stdlib](https://forge.puppet.com/modules/puppetlabs/stdlib) >= 4.0.0 < 10.0.0
- Linux operating system

### Supported operating systems

- RedHat 7, 8, 9
- CentOS 7, 8
- Ubuntu 20.04, 22.04, 24.04
- Debian 11, 12
- SLES 15

## The dirty_frag fact

Once the module is deployed, the `dirty_frag` fact is available on every Linux node automatically. No class inclusion is needed.

### Fact structure

The fact returns a hash with per-module detail and two summary keys:

```json
{
  "esp4": {
    "loaded": true,
    "blacklisted": true,
    "available": true
  },
  "esp6": {
    "loaded": false,
    "blacklisted": false,
    "available": true
  },
  "rxrpc": {
    "loaded": false,
    "blacklisted": false,
    "available": true
  },
  "vulnerable": true,
  "reboot_required": true
}
```

#### Per-module keys

Each of `esp4`, `esp6`, and `rxrpc` reports:

| Key | Type | Meaning |
|---|---|---|
| `loaded` | Boolean | Module is currently in the running kernel (present in `/proc/modules`) |
| `blacklisted` | Boolean | An `install <module> /bin/false` directive exists in `/etc/modprobe.d/` |
| `available` | Boolean | Module binary exists on the system (`modinfo` can find it) |

#### Summary keys

| Key | Type | Meaning |
|---|---|---|
| `vulnerable` | Boolean | `true` if **any** of the three modules is currently loaded |
| `reboot_required` | Boolean | `true` if any module is both blacklisted **and** still loaded (the blacklist will not take effect until reboot) |

### Querying the fact

On a single node:

```shell
puppet facts show dirty_frag
```

### Accessing the fact in Puppet code

The fact is available as `$facts['dirty_frag']` in any manifest or profile:

```puppet
if $facts['dirty_frag']['vulnerable'] {
  notify { 'dirty_frag_vulnerable':
    message  => 'This node has vulnerable kernel modules loaded',
    loglevel => warning,
  }
}

if $facts['dirty_frag']['reboot_required'] {
  notify { 'dirty_frag_reboot':
    message  => 'Reboot required to complete dirty frag mitigation',
    loglevel => warning,
  }
}
```

### PuppetDB queries

Find all vulnerable nodes:

```shell
puppet query 'facts[certname, value] { name = "dirty_frag" and value.vulnerable = true }'
```

Find nodes that need a reboot to complete mitigation:

```shell
puppet query 'facts[certname, value] { name = "dirty_frag" and value.reboot_required = true }'
```

Find nodes where `esp4` is loaded but not yet blacklisted:

```shell
puppet query 'facts[certname, value] { name = "dirty_frag" and value.esp4.loaded = true and value.esp4.blacklisted = false }'
```

## The dirty_frag class (optional)

The class writes `/etc/modprobe.d/dirtyfrag.conf` with `install <module> /bin/false` directives for each enabled parameter. This persistently prevents modules from loading on boot or via explicit `modprobe` calls.

Only include this class when you need Puppet to enforce the blacklist. The fact works independently.

### Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `mitigate_esp4` | `Boolean` | `false` | Blacklist the `esp4` kernel module |
| `mitigate_esp6` | `Boolean` | `false` | Blacklist the `esp6` kernel module |
| `mitigate_rxrpc` | `Boolean` | `false` | Blacklist the `rxrpc` kernel module |

### Usage with Hiera

```yaml
dirty_frag::mitigate_esp4: true
dirty_frag::mitigate_esp6: true
dirty_frag::mitigate_rxrpc: true
```

Then classify the node:

```puppet
include dirty_frag
```

### Usage with resource-like declaration

```puppet
class { 'dirty_frag':
  mitigate_esp4  => true,
  mitigate_esp6  => true,
  mitigate_rxrpc => false,
}
```

### Why install /bin/false instead of blacklist?

The `blacklist` directive only prevents autoloading. It does not block explicit `modprobe` calls. The `install ... /bin/false` approach ensures the module cannot be loaded by any mechanism.

## The unload Bolt task

The `dirty_frag::unload` task unloads a vulnerable module from the running kernel immediately, without waiting for a reboot.

```shell
bolt task run dirty_frag::unload module=esp4 --targets servers
```

The `module` parameter accepts one of: `esp4`, `esp6`, or `rxrpc`.

On success:

```json
{
  "module": "esp4",
  "status": "unloaded",
  "message": "Successfully unloaded module 'esp4'"
}
```

The task returns an error if the module is not currently loaded, is in use by another kernel subsystem, or is not in the allow-list. If a module is in use and cannot be unloaded, apply the blacklist and reboot.

## What this module affects

- The custom fact reads `/proc/modules`, scans `/etc/modprobe.d/` files, and runs `modinfo`
- The class creates and manages `/etc/modprobe.d/dirtyfrag.conf`
- The Bolt task runs `modprobe -r` to unload modules from the running kernel

## Limitations

- **Linux only.** The fact is confined to nodes where `kernel == 'Linux'`. The class and task assume Linux kernel module tooling.
- **Blacklisting does not unload live modules.** The class writes `modprobe.d` configuration that takes effect on next boot or next `modprobe` call. Use the Bolt task or a reboot to remove already-loaded modules.
- **No kernel version detection.** The module reports and manages module state regardless of kernel version. If you need kernel-version-aware logic, handle that in your classification or Hiera hierarchy.
- **Module in use.** The Bolt task cannot unload a module that is in use by another kernel subsystem. Apply the blacklist and reboot in that case.

## Reference

Full reference documentation for classes and tasks is available in [REFERENCE.md](REFERENCE.md), generated from inline Puppet Strings comments.

## Development

This module uses the [Puppet Development Kit (PDK)](https://www.puppet.com/docs/pdk/latest/pdk.html).

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
pdk test unit --tests spec/unit/facter/dirty_frag_spec.rb
```

Generate REFERENCE.md:

```shell
pdk bundle exec puppet strings generate --format markdown
```
