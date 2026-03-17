#!/usr/bin/env bash
set -euo pipefail

python3 <<'PY'
#!/usr/bin/env python3
import base64
import hashlib
import os
import pathlib
import secrets

conf = pathlib.Path("/config/qBittorrent/qBittorrent.conf")

username = os.environ["QBITTORRENT_USERNAME"]
password = os.environ["QBITTORRENT_PASSWORD"]

salt = secrets.token_bytes(16)
salt_b64 = base64.b64encode(salt).decode()
digest = hashlib.pbkdf2_hmac("sha512", password.encode(), salt, 100000)
digest_b64 = base64.b64encode(digest).decode()
pbkdf2 = f'@ByteArray({salt_b64}:{digest_b64})'

lines = conf.read_text().splitlines()
lines = [
    rf"WebUI\Username={username}" if line.startswith(r"WebUI\Username=") else
    rf'WebUI\Password_PBKDF2="{pbkdf2}"' if line.startswith(r"WebUI\Password_PBKDF2=") else
    line
    for line in lines
]

conf.write_text("\n".join(lines) + "\n")
PY
