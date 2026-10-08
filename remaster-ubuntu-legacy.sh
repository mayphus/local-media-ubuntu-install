#!/usr/bin/env bash
# File-only remaster. Never writes a raw device, starts a VM or installs software.
# Usage: bash remaster-ubuntu-legacy.sh ORIGINAL.iso FILLED-preseed.cfg OUTPUT.iso NEW-WORK-DIR
set -euo pipefail
if [[ $# -ne 4 ]]; then
    echo 'Usage: bash remaster-ubuntu-legacy.sh ORIGINAL.iso FILLED-preseed.cfg OUTPUT.iso NEW-WORK-DIR' >&2
    exit 2
fi
for command in xorriso python3 gpgv realpath; do
    command -v "$command" >/dev/null || { echo "Missing tool: $command" >&2; exit 1; }
done
original=$(realpath -e -- "$1")
seed=$(realpath -e -- "$2")
output=$(realpath -m -- "$3")
work=$(realpath -m -- "$4")
[[ -f "$original" && -f "$seed" ]] || { echo 'Inputs must be regular files.' >&2; exit 1; }
[[ ! -e "$output" && ! -L "$output" ]] || { echo 'Refusing to overwrite output.' >&2; exit 1; }
[[ ! -e "$output.sha256" && ! -L "$output.sha256" ]] || { echo 'Refusing to overwrite checksum sidecar.' >&2; exit 1; }
[[ ! -e "$work" && ! -L "$work" ]] || { echo 'Work directory must not exist.' >&2; exit 1; }
[[ -d "$(dirname -- "$output")" ]] || { echo 'Create output parent directory first.' >&2; exit 1; }
case "$output" in /dev/*|/proc/*|/sys/*) echo 'Output must be a regular workspace file.' >&2; exit 1;; esac
case "$work" in /dev/*|/proc/*|/sys/*) echo 'Work must be a workspace directory.' >&2; exit 1;; esac
if grep -q '^d-i passwd/.*REPLACE_' "$seed"; then
    echo 'Fill every account placeholder before remastering.' >&2
    exit 1
fi
sums="$(dirname -- "$original")/SHA256SUMS"
keyring=${UBUNTU_KEYRING:-/usr/share/keyrings/ubuntu-archive-keyring.gpg}
[[ -f "$keyring" && -f "$sums" && -f "$sums.gpg" ]] || {
    echo 'Need trusted Ubuntu keyring plus official SHA256SUMS and SHA256SUMS.gpg beside ISO.' >&2
    exit 1
}
# Verify the manifest, then require the exact ISO used by this legacy recipe.
gpgv --keyring "$keyring" "$sums.gpg" "$sums"
python3 -I - "$original" "$sums" "$seed" <<'PY'
from pathlib import Path
import hashlib, re, sys
iso, sums, seed = map(Path, sys.argv[1:])
expected = 'f11bda2f2caed8f420802b59f382c25160b114ccc665dbac9c5046e7fceaced2'
name = 'ubuntu-20.04.1-legacy-server-amd64.iso'
if not any(row.split()[0] == expected and row.split()[-1].lstrip('*') == name
           for row in sums.read_text().splitlines() if row.strip()):
    raise SystemExit('Expected checksum absent')
h = hashlib.sha256()
with iso.open('rb') as stream:
    for block in iter(lambda: stream.read(1048576), b''):
        h.update(block)
if h.hexdigest() != expected:
    raise SystemExit('Original ISO checksum mismatch')
text = seed.read_text()
if not re.search(r'^d-i passwd/username string [a-z][a-z0-9_-]{0,31}$', text, re.M):
    raise SystemExit('Invalid username')
if not re.search(r'^d-i passwd/user-password-crypted password \$6\$(?:rounds=\d+\$)?[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{86}$', text, re.M):
    raise SystemExit('Need complete SHA-512 crypt password hash')
print('Authenticated original ISO and required account fields verified.')
PY
umask 077
mkdir -- "$work"
# 1. Unpack for inspection and editing. No loop mount or root permission required.
xorriso -osirrox on -indev "$original" -extract / "$work/tree" > "$work/extract.log" 2>&1
find "$work/tree" -type d -exec chmod u+w {} +
chmod u+w "$work/tree/isolinux/isolinux.cfg" "$work/tree/md5sum.txt"
# 2. Insert the filled seed at the path named by the kernel argument.
cp -- "$seed" "$work/tree/preseed.cfg"
# 3. Replace only the BIOS boot menu. UEFI is preserved, not automated.
cat > "$work/tree/isolinux/isolinux.cfg" <<'CFG'
DEFAULT install
PROMPT 0
TIMEOUT 10
LABEL install
 KERNEL /install/vmlinuz
 APPEND initrd=/install/initrd.gz auto=true priority=critical preseed/file=/cdrom/preseed.cfg ---
CFG
# 4. Refresh content checksums. Exclude the manifest itself and two boot files
# that xorriso generates/patches. The original ISO also excludes these boot files.
python3 -I - "$work/tree" <<'PY'
from pathlib import Path
import hashlib, os, sys
root = Path(sys.argv[1])
excluded = {'md5sum.txt', 'isolinux/isolinux.bin', 'isolinux/boot.cat'}
rows = []
for directory, subdirs, files in os.walk(root, followlinks=False):
    subdirs.sort()
    for name in sorted(files):
        path = Path(directory) / name
        rel = path.relative_to(root).as_posix()
        if rel in excluded or path.is_symlink() or not path.is_file():
            continue
        digest = hashlib.md5()
        with path.open('rb') as stream:
            for block in iter(lambda: stream.read(1048576), b''):
                digest.update(block)
        rows.append(f'{digest.hexdigest()}  ./{rel}\n')
(root / 'md5sum.txt').write_text(''.join(sorted(rows)))
PY
# 5. Repack by importing the authenticated original and replaying its boot setup.
# Overlay precisely our three changes; all other original content stays intact.
# This is intentionally not a generic pack of arbitrary extra edits in tree/.
xorriso -indev "$original" -outdev "$output" \
    -boot_image any replay \
    -map "$work/tree/preseed.cfg" /preseed.cfg \
    -map "$work/tree/isolinux/isolinux.cfg" /isolinux/isolinux.cfg \
    -map "$work/tree/md5sum.txt" /md5sum.txt > "$work/repack.log" 2>&1
xorriso -indev "$output" -report_el_torito plain > "$work/boot-layout.txt" 2>&1
python3 -I - "$output" <<'PY'
from pathlib import Path
import hashlib, sys
path = Path(sys.argv[1])
h = hashlib.sha256()
with path.open('rb') as stream:
    for block in iter(lambda: stream.read(1048576), b''):
        h.update(block)
line = f'{h.hexdigest()}  {path.name}\n'
with Path(str(path) + '.sha256').open('x') as stream:
    stream.write(line)
print(line, end='')
PY
printf 'Created ISO: %s\nUnpacked files and logs: %s\n' "$output" "$work"
printf 'No VM was started. Test only with a disposable disk; remove ISO after installation.\n'
