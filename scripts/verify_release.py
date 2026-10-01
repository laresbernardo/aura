#!/usr/bin/env python3
"""Mount the final DMG and verify its version and both CPU slices."""
import json
import plistlib
import subprocess
from pathlib import Path

mount = Path('/tmp/AuraReleaseVerify')
mount.mkdir(exist_ok=True)
subprocess.run(['hdiutil', 'attach', 'Aura.dmg', '-nobrowse', '-readonly', '-mountpoint', str(mount)], check=True)
try:
    app = mount / 'Aura.app'
    with (app / 'Contents/Info.plist').open('rb') as source:
        info = plistlib.load(source)
    manifest = json.loads(Path('website/public/version.json').read_text())
    assert manifest == json.loads(Path('version.json').read_text())
    assert manifest['version'] == info['CFBundleShortVersionString']
    assert manifest['build'] == int(info['CFBundleVersion'])
    assert manifest['appID'] == info['CFBundleIdentifier']
    assert manifest['minimumMacOS'] == info['LSMinimumSystemVersion']
    archs = subprocess.check_output(['lipo', '-archs', str(app / 'Contents/MacOS/Aura')], text=True).split()
    assert sorted(archs) == sorted(manifest['architectures'])
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
    print('Verified final DMG metadata, universal architectures and ad-hoc signature:', manifest)
finally:
    subprocess.run(['hdiutil', 'detach', str(mount)], check=True)
