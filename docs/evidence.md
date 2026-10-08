# Evidence and limitations

## Provenance

This record was checked against retained private installer/boot serial logs, command records, result JSON, checksum/signature records and the published companion article. Raw logs, generated account values, filesystem UUIDs, host identifiers and private local paths are deliberately not copied here. This is a sanitized evidence summary, not a publicly independently replayed test transcript.

The original approach used local installation media and unattended Ubuntu installation. The user now strongly recalls choosing Ubuntu 20.04-era Server specifically for YAML autoinstall support and simpler configuration, rather than legacy preseed. Cubic remains the recalled historical customization tool. The exact original point release, image/file, Cubic version, commands and answer file have not been recovered or independently verified. Hardware configuration and deployment performance remain unknown.

Embedded firmware PXE reportedly did not support the USB Ethernet adapter; iPXE was considered, not established as attempted and failed. Our xorriso/legacy-preseed work is an alternative-method reconstruction and demonstration. Its measured results do not verify the recalled original autoinstall implementation. No Subiquity autoinstall installation has been tested in this repository yet.

## Completed alternative-method offline preseed experiment

- Official Ubuntu 20.04.1 legacy-server AMD64 ISO: checksum matched and signed checksum verified with the preinstalled Ubuntu CD Image signing key.
- QEMU TCG/SeaBIOS, 2 vCPUs, 3072 MiB RAM, a fresh 12 GiB sparse virtio disk, read-only ISO and no NIC. No physical devices or shared host directories.
- The final corrected installation received no input. Serial progress covered account setup, partitioning, system/package configuration, GRUB and shutdown. Wall time: **638.102 seconds**.
- Separate boot with only the installed disk attached: Ubuntu 20.04.1, kernel 5.4.0-42-generic, ext4 root mounted read-write, only the loopback interface. About **21 seconds**, followed by poweroff. Disk integrity check passed.
- Sequential diskless USB-storage probe: same hybrid image on emulated xHCI mass storage, 2 vCPUs/512 MiB, no NIC. Installer kernel reached its initial userspace handoff in about **3 seconds**, then the probe stopped. This was not a complete USB-path installation.

Those durations describe single emulated runs, not mini-PC benchmarks or historical deployment throughput.

## The successful boot was instrumented

The installer's late command copied a verification script and systemd unit into the target, enabled it under `multi-user.target.wants`, wrote a marker, copied the installer syslog and set GRUB's serial console. It ran `update-grub` inside the target. No offline editing of the disk occurred between installation and the verification boot.

The unit used `Type=oneshot`, followed `local-fs.target`, printed OS/kernel/root/block-device/network evidence to the serial console, then requested poweroff. It **did not disable itself** and would run again while enabled. This was neither a stock unmodified boot nor a production-ready machine image. Shutdown-time udev worker messages were present; their cause was not independently isolated. Sustained service health was not tested.

The nginx template in this repository removes that instrumentation and poweroff behavior. Its late command instead writes the static page/site, checks `nginx -t` and enables nginx for normal boot. That new behavior has not been executed in an installation test.

## Failed attempts and runner deviation

Disabling root login and normal-user creation together still prompted for a user. The authenticated image's `user-setup` version `1.63ubuntu6` forces normal-user creation when root login is disabled. Enabling root with a locked password value also prompted because this version did not treat that value as an actual password hash. The completed run supplied a generated normal account with root disabled. These values are omitted; the repository has nonfunctional placeholders only. Failed prompts were not manually answered and then counted as unattended success.

Interrupting an early wrapper initially left its QEMU child running, and a retry briefly overlapped it. This violated the planned one-VM bound. Both task-owned processes were stopped and their disks checked; the runner was repaired to terminate its child explicitly through a stop request or timeout. Subsequent final installation and probes ran sequentially. Neither overlapping VM had networking or physical-device access.

## Static validation of the packaged resources

Local checks cover debconf check-only parsing, continuation joining, both hook shell syntaxes, Bash syntax, compilation of the remaster helper's embedded Python, required placeholders, selected guest disk, DHCP, nginx selection/configuration/enable command and absence of previous boot instrumentation. Repository payload checks reject actual password hashes, private paths, image/log artifacts and unexpected symlinks. Two tiny file-only probes also confirmed rejection of an existing output and an unfilled template before creating work/output files. Neither probe remastered an ISO or generated credentials.

Packaging also changes the helper's Python preflight checks from `assert` to explicit failures, isolates embedded Python from environment options, restricts the work directory's creation permissions and bounds usernames to 32 characters. These are static-reviewed hardening edits; they do not convert the helper into an executed remaster test.

## What remains unverified

DHCP negotiation, online package installation, the nginx runtime/configuration test and startup persistence have not been tested for this template. Archive metadata was reachable when checked on 2026-10-07; that does not establish all package downloads will succeed. UEFI unattended startup is not configured. No physical CR160, SD slot/reader, USB Ethernet adapter or historical recipe was reproduced. No application load test or blockchain software was deployed.
