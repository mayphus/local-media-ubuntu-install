#!/usr/bin/env python3
"""Static checks and file-only rejection probes. No credentials, VM or downloads."""
from pathlib import Path
import os
import re
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def require(condition, message):
    if not condition:
        raise SystemExit(message)

def run(arguments, **kwargs):
    return subprocess.run(arguments, check=True, text=True, capture_output=True, **kwargs)

seed = ROOT / 'preseed.cfg'
script = ROOT / 'remaster-ubuntu-legacy.sh'
text = seed.read_text()
records = {}
for line in re.sub(r'\\\n[ \t]*', ' ', text).splitlines():
    if not line or line.startswith('#'):
        continue
    parts = line.split(None, 3)
    require(len(parts) >= 3, 'Malformed preseed record')
    require(parts[1] not in records, 'Duplicate preseed key')
    records[parts[1]] = parts[3] if len(parts) == 4 else ''

run(['debconf-set-selections', '--checkonly', str(seed)])
run(['bash', '-n', str(script)])
for key in ['preseed/early_command', 'preseed/late_command']:
    run(['sh', '-n', '-c', records[key]])
late = shlex.split(records['preseed/late_command'])
require(late[:3] == ['in-target', '/bin/sh', '-c'] and len(late) == 4,
        'Expected one target-shell command')
run(['sh', '-n', '-c', late[3]])
for key, expected in {
    'partman-auto/disk': '/dev/vda',
    'grub-installer/bootdev': '/dev/vda',
    'netcfg/enable': 'true',
    'netcfg/choose_interface': 'auto',
    'passwd/root-login': 'false',
    'passwd/make-user': 'true',
    'passwd/user-fullname': 'REPLACE_WITH_DISPLAY_NAME',
    'passwd/username': 'REPLACE_WITH_USERNAME',
    'passwd/user-password-crypted': 'REPLACE_WITH_SHA512_PASSWORD_HASH',
    'pkgsel/include': 'nginx',
    'debian-installer/exit/poweroff': 'false',
}.items():
    require(records[key] == expected, f'Unexpected template value: {key}')
require('systemctl enable nginx.service' in late[3] and '--now' not in late[3],
        'Expected enable-only service setup')
require('nginx -t' in late[3] and 'listen 80 default_server;' in late[3],
        'Missing nginx validation/listener')
require(not any(value in text for value in ['firstboot.sh', 'reconstruction-proof',
                                         'RECONSTRUCTION_PROOF_BEGIN']),
        'Old boot instrumentation must not enter this template')
blocks = re.findall(r"<<'PY'\n(.*?)\nPY", script.read_text(), re.S)
require(len(blocks) == 3, 'Expected three embedded Python programs')
for block in blocks:
    compile(block, 'remaster-inline', 'exec')
require('assert ' not in script.read_text(), 'Safety checks must not use assert')

# Exercise only early refusals. Blank regular file is deliberately not an ISO.
# No credential generation, signature verification, extraction or remaster occurs.
with tempfile.TemporaryDirectory(prefix='iso-template-check-') as directory:
    tmp = Path(directory)
    original = tmp / 'blank.iso'
    original.write_bytes(b'')
    output = tmp / 'existing.iso'
    output.write_bytes(b'preserve')
    p = subprocess.run(['bash', str(script), str(original), str(seed),
                        str(output), str(tmp / 'new-work')],
                       text=True, capture_output=True)
    require(p.returncode != 0 and 'Refusing to overwrite output' in p.stderr,
            'Overwrite rejection failed')
    require(output.read_bytes() == b'preserve', 'Existing file changed')
    p = subprocess.run(['bash', str(script), str(original), str(seed),
                        str(tmp / 'new.iso'), str(tmp / 'new-work')],
                       text=True, capture_output=True)
    require(p.returncode != 0 and 'Fill every account placeholder' in p.stderr,
            'Unfilled-placeholder rejection failed')
    require(not (tmp / 'new.iso').exists() and not (tmp / 'new-work').exists(),
            'Refusal should precede output creation')

# Inspect tracked payload when Git is available; otherwise inspect source files.
if (ROOT / '.git').exists():
    names = run(['git', '-C', str(ROOT), 'ls-files', '-z']).stdout.split('\0')
    files = [ROOT / name for name in names if name]
else:
    files = [p for p in ROOT.rglob('*') if p.is_file() and '__pycache__' not in p.parts]
for path in files:
    require(not path.is_symlink(), 'Unexpected tracked symlink')
    require(path.stat().st_size < 100_000, 'Unexpected large repository file')
    require(path.suffix not in {'.iso', '.qcow2', '.img', '.log', '.raw'},
            'Private artifact must not be tracked')
    body = path.read_text()
    require(not re.search(r'\$6\$(?:rounds=\d+\$)?[./A-Za-z0-9]{1,16}\$[./A-Za-z0-9]{86}', body),
            'Actual password hash found')
    require(not re.search(r'/(?:home|Users)/[A-Za-z0-9._-]+/', body),
            'Private absolute path found')
    require(not re.search(r'-----BEGIN (?:OPENSSH |RSA |EC )?PRIVATE KEY-----', body),
            'Private key material found')
print(f'PASS: {len(records)} preseed records; shell/Python syntax; template audit; '
      f'2 file-only refusal probes; {len(files)} source files inspected. '
      'No ISO, VM, package installation or service execution.')
