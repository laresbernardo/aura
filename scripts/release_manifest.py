#!/usr/bin/env python3
"""Describe the packaged app, not mutable pre-build metadata."""
import json
import plistlib
import sys
from pathlib import Path

with open(sys.argv[1], 'rb') as source:
    info = plistlib.load(source)
manifest = {
    'appID': info['CFBundleIdentifier'],
    'version': info['CFBundleShortVersionString'],
    'build': int(info['CFBundleVersion']),
    'minimumMacOS': info['LSMinimumSystemVersion'],
    'architectures': ['arm64', 'x86_64'],
    'downloadURL': 'https://aura.bervos.org/assets/Aura.dmg',
}
Path(sys.argv[2]).write_text(json.dumps(manifest, indent=2) + '\n')
