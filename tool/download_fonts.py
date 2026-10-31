#!/usr/bin/env python3
"""Fetch pinned OFL fonts for reproducible, fully-offline Flutter app builds.

The font binaries are downloaded during project setup, not at app runtime.
Do not commit the downloaded font binaries or link to them directly.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import sys
import urllib.request
from urllib.parse import quote

ROOT = Path(__file__).resolve().parent.parent
FONT_DIR = ROOT / 'assets' / 'fonts'
# Fixed upstream revision: avoids mutable main/HEAD font assets.
REVISION = '7ff85c87f93ea6cca5f41c69f2e4edcb90240f26'
BASE = f'https://raw.githubusercontent.com/google/fonts/{REVISION}/'

FILES = (
    ('DM Sans', 'ofl/dmsans/DMSans[opsz,wght].ttf', 'DMSans.ttf',
     '8cd08d97e89c24d0aa92edd2f0f4c8ee6195eee9b7c9f154865a58b02f0c1c0d'),
    ('Cormorant Garamond', 'ofl/cormorantgaramond/CormorantGaramond[wght].ttf', 'CormorantGaramond.ttf', None),
    ('DM Sans OFL', 'ofl/dmsans/OFL.txt', 'LICENSE-DMSans.txt', None),
    ('Cormorant Garamond OFL', 'ofl/cormorantgaramond/OFL.txt', 'LICENSE-CormorantGaramond.txt', None),
)


def verified(data: bytes, target: str, expected_sha256: str | None) -> bool:
    if target.endswith('.ttf'):
        if len(data) < 10000 or data[:4] not in (b'\x00\x01\x00\x00', b'OTTO', b'true'):
            return False
    elif b'SIL OPEN FONT LICENSE' not in data.upper() or len(data) < 500:
        return False
    return expected_sha256 is None or hashlib.sha256(data).hexdigest() == expected_sha256


def main() -> int:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    for name, source, filename, expected_hash in FILES:
        dest = FONT_DIR / filename
        if dest.exists() and verified(dest.read_bytes(), filename, expected_hash):
            print(f'{name}: already installed')
            continue
        url = BASE + quote(source, safe='/')
        request = urllib.request.Request(url, headers={'User-Agent': 'Savour-Flutter-font-setup/1.0'})
        try:
            with urllib.request.urlopen(request, timeout=40) as response:
                data = response.read()
            if not verified(data, filename, expected_hash):
                raise ValueError(f'Invalid or unexpected font/license content: {filename}')
            # Only install verified downloads. A failure leaves the previous copy untouched.
            pending = dest.with_name(dest.name + '.pending')
            pending.write_bytes(data)
            pending.replace(dest)
            print(f'{name}: downloaded for offline app bundling')
        except Exception as error:
            print(f'Unable to download {name}: {error}', file=sys.stderr)
            return 1
    print('Both typefaces and their SIL Open Font Licenses are ready.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
