# Local-media Ubuntu installation

Companion resources for [Reconstructing an unattended Ubuntu install from local media](https://mayphus.org/local-media-ubuntu-install/).

This is a **new xorriso reconstruction**, not a recovered historical recipe. The historical image-customization tool is recalled as **Cubic**; its version and original configuration have not been recovered. Physical CR160 compatibility has not been established.

The template targets **Ubuntu 20.04.1 legacy-server AMD64 / debian-installer / preseed / BIOS**. It is not a modern live-server Subiquity autoinstall file. Ubuntu 20.04 standard maintenance ended in May 2025; a reachable archive does not establish current security coverage. See [Canonical's lifecycle](https://ubuntu.com/about/release-cycle).

## What is included

- [`preseed.cfg`](preseed.cfg): normal-user placeholders, wired DHCP, standard utilities and an nginx static demo enabled on boot. No SSH server is requested.
- [`remaster-ubuntu-legacy.sh`](remaster-ubuntu-legacy.sh): authenticates the pinned original image, extracts it, inserts the template, edits BIOS startup, rebuilds file checksums and replays the original hybrid boot metadata.
- [`docs/recipe.txt`](docs/recipe.txt): full configuration, unpack/repack and post-install verification instructions.
- [`docs/evidence.md`](docs/evidence.md): measured results, failed attempts and limitations.
- [`docs/toolchain.md`](docs/toolchain.md): exact image and observed tool versions.
- [`scripts/check.py`](scripts/check.py): local static checks, with no VM, service, disk formatting or download.

No ISO, disk image, credentials, keys or raw private logs are included. There is no automatic CI or release workflow.

## Disk and credential boundary

**The installer erases all data on guest `/dev/vda` without confirmation.** Use only one disposable VM with one blank virtio disk, at least 12 GiB. Do not boot this media on a physical machine or attach valuable disks. A changed disk name does not make the automatic partitioning safe.

The checked-in template is intentionally nonfunctional until all three `REPLACE_` account values are filled. Copy it to ignored `preseed.local.cfg` and edit that local file. Supply a fresh password hash through a trusted local workflow described in the recipe. Do not commit the personalized file, hash, ISO or extracted tree. There is no supplied default password. The preparation of this repository generated no credentials.

The template's early error check is not a disk-protection mechanism. Review the completed answer file and VM attachments before any test. Remove the ISO after installation: leaving auto-install media first in the boot order risks reinstalling the disk.

## Build an ISO

Use existing Bash, xorriso, Python 3, gpgv and GNU Unix utilities. The helper installs nothing and downloads nothing. Start with a trusted Ubuntu CD-image signing keyring and these three files from the [official release directory](https://cdimage.ubuntu.com/ubuntu-legacy-server/releases/20.04/release/):

- `ubuntu-20.04.1-legacy-server-amd64.iso`
- `SHA256SUMS`
- `SHA256SUMS.gpg`

Keep the verification files alongside the original ISO. The helper uses `/usr/share/keyrings/ubuntu-archive-keyring.gpg` by default, or the trusted keyring supplied through `UBUNTU_KEYRING`. It checks the detached signature and pinned SHA-256 before extracting anything. Do not bypass verification or establish trust solely from a key downloaded beside the image.

```sh
cp preseed.cfg preseed.local.cfg
# Edit all three account placeholders in preseed.local.cfg before proceeding.
bash remaster-ubuntu-legacy.sh \
  ./ubuntu-20.04.1-legacy-server-amd64.iso \
  ./preseed.local.cfg \
  ./ubuntu-nginx-demo.iso \
  ./remaster-work
```

Output ISO, checksum sidecar and work directory must not already exist. Run as a normal user. The script never writes a block device or starts a VM. It retains extraction/repack logs and a boot-layout report in the private work directory. Its SHA-256 sidecar identifies your new ISO; Canonical's signature authenticates only the original.

Full-tree extraction is for inspection. Repacking imports the authenticated original and overlays **only** `/preseed.cfg`, `/isolinux/isolinux.cfg` and `/md5sum.txt`. Arbitrary edits elsewhere in the extracted tree are not included. The exact commands and checksum exclusions are explained in the recipe; no generic `mkisofs` replacement is used.

## Validation status and a future test

| Scope | Status |
| --- | --- |
| Earlier offline image: unattended install, then disk-only instrumented boot | Completed; 638.102-second install, about 21-second boot |
| Earlier hybrid image via emulated USB storage | Installer kernel reached; no full USB-path installation |
| This DHCP/nginx template | Static checks only; not installed or runtime-tested |
| This packaged remaster helper | Static checks only; not run to produce a new ISO |
| UEFI unattended boot | Not configured or tested; original structures retained |
| Physical mini-PC, firmware, SD reader or USB NIC | Not tested |

Run local checks with:

```sh
python3 scripts/check.py
```

If separately choosing to test the networked template, use one disposable VM with at most 2 vCPUs/3 GiB RAM and a fresh 12 GiB virtio disk. DHCP, DNS and outbound package access are required. Use a controlled user-mode/NAT network; no bridge, host port forwards, physical disks or USB passthrough are needed. This repository does not start that VM or change host networking.

After installation, boot the disk without the ISO and use the recipe's guest-console commands to verify DHCP, nginx configuration, enabled/active service and the local HTTP page. Repeat after a reboot. The nginx template includes **none** of the prior experiment's serial-proof service or recurring automatic poweroff behavior.
