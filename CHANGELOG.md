# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.0] - 2026-05-11

### Added

- Structured custom fact (`dirty_frag`) reporting `loaded`, `blocked`, and `available` state for the esp4, esp6, and rxrpc kernel modules, plus `vulnerable` and `reboot_required` summary keys
- Puppet class (`dirty_frag`) with opt-in Boolean parameters (`mitigate_esp4`, `mitigate_esp6`, `mitigate_rxrpc`) to block vulnerable modules via `install /bin/false` in `/etc/modprobe.d/dirtyfrag.conf`
- Bolt task (`dirty_frag::unload`) to immediately unload a specified vulnerable kernel module via `modprobe -r`
- Comprehensive README with vulnerability context (CVE-2026-43284, CVE-2026-43500), usage examples, PuppetDB queries, and limitations
- REFERENCE.md generated from Puppet Strings
- Example manifests for Forge display
- RSpec unit tests covering all parameters and fact detection patterns
