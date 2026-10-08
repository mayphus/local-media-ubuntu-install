# Input and toolchain

## Pinned alternative-method test image

This is the original input to our alternative-method legacy-preseed experiment, not the historical installer. Privately reviewed notes document Cubic and YAML autoinstall; the user strongly recalls choosing Ubuntu 20.04-era Server for that support. The exact historical release/ISO remains unverified. The documented workflow includes network resources and manual post-install initialization, unlike our measured offline baseline. No Subiquity autoinstall installation has been validated here. See [evidence and provenance](evidence.md).

- File: `ubuntu-20.04.1-legacy-server-amd64.iso`
- Size: **855638016 bytes** (816 MiB).
- SHA-256: `f11bda2f2caed8f420802b59f382c25160b114ccc665dbac9c5046e7fceaced2`.
- [Canonical directory and signed checksums](https://cdimage.ubuntu.com/ubuntu-legacy-server/releases/20.04/release/).
- Verified signing-key fingerprint: `843938DF228D22F7B3742BC0D94AA3F0EFE21092` (Ubuntu CD Image Automatic Signing Key, 2012).

The signature was checked using an already trusted installed Ubuntu archive keyring. No private or public key file is shipped here. Run `gpgv --keyring TRUSTED_KEYRING SHA256SUMS.gpg SHA256SUMS`; then compare the actual ISO hash with the corresponding signed entry. The helper performs both checks and pins the expected original image. A modified image is not signed by Canonical.

## Observed versions, not claimed minimum requirements

The offline experiment recorded QEMU **10.2.1**, xorriso **1.5.6**, SeaBIOS **1.17.0** and guest Linux **5.4.0-42-generic**. QEMU used TCG because KVM was unavailable in the execution environment. The installer account package was `user-setup-udeb_1.63ubuntu6_all.udeb`.

During repository preparation, the available commands reported:

| Command/component | Observed version |
| --- | --- |
| Python interpreter | 3.14.4 |
| Bash | 5.3.9(1)-release |
| gpgv | 2.4.8 |
| OpenSSL | 3.5.5 |
| GNU coreutils package | 9.5-1ubuntu2+0.0.0~ubuntu25 |
| debconf package | 1.5.92 |
| qemu-system-x86 / qemu-utils package | 1:10.2.1+ds-1ubuntu3.2 |
| xorriso package | 1:1.5.6-1.1ubuntu4 |
| SeaBIOS package | 1.17.0-1ubuntu1 |

These observations do not prove these exact binaries are necessary. Python uses the standard library; no pip/npm dependencies are required. The remaster helper requires existing Bash, xorriso, Python 3, gpgv, realpath, grep, find, chmod, cp and other ordinary GNU utilities. Local static validation also needs `debconf-set-selections`. OpenSSL is mentioned only for a user's separate local password-hash preparation; packaging generated no credentials.

OVMF was installed but was not used for an unattended EFI test. iPXE was not exercised by this reconstruction. Neither is a dependency of the provided remaster script. No host software installation or GitHub Actions workflow is provided.
