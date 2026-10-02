#!/usr/bin/env python3
"""Select an installed iPhone runtime without downloading or creating any device."""
import json
import re
import subprocess
import sys

def choose(payload: dict) -> dict:
    candidates = []
    for runtime, devices in payload.get('devices', {}).items():
        match = re.search(r'iOS-(\d+)-(\d+)(?:-(\d+))?$', runtime)
        if not match:
            continue
        version = tuple(int(part or 0) for part in match.groups())
        if version < (17, 0, 0):
            continue
        for device in devices:
            name = device.get('name', '')
            if device.get('isAvailable') is not True or not name.startswith('iPhone'):
                continue
            if not re.fullmatch(r'[0-9A-Fa-f-]{36}', device.get('udid', '')):
                continue
            # Prefer a standard, non-Max device; no assumed model or fixed UDID.
            score = (version, 'Max' not in name and 'Plus' not in name, name)
            candidates.append((score, dict(device, runtime=runtime)))
    if not candidates:
        raise ValueError('No available iPhone simulator with iOS >=17. Install a runtime on your Mac first. CI will not download one.')
    return max(candidates, key=lambda entry: entry[0])[1]

def main() -> None:
    raw = subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json'], text=True)
    selected = choose(json.loads(raw))
    print(json.dumps(selected) if '--json' in sys.argv else selected['udid'])

if __name__ == '__main__':
    main()
