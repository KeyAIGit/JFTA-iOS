#!/usr/bin/env python3
"""Dependency-free structural checks; this is NOT an Apple SDK build."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]

def validate() -> list[str]:
    results = []
    def check(ok: bool, message: str) -> None:
        if not ok:
            raise AssertionError(message)
        results.append(message)
    manifest = json.loads((ROOT / 'docs/project-manifest.json').read_text())
    project = (ROOT / 'JFTA.xcodeproj/project.pbxproj').read_text()
    sources = manifest['app_sources'] + manifest['unit_sources'] + manifest['ui_sources']
    check(len(sources) == len(set(sources)), 'Source paths are unique')
    for name in sources:
        check((ROOT / name).is_file() and name in project, 'Project reference exists: ' + name)
    check(project.count('"isa" = "PBXNativeTarget"') == 3, 'App, unit test and UI test targets exist')
    check('"DEVELOPMENT_TEAM" = ""' in project, 'No Apple signing team is embedded')
    check('"IPHONEOS_DEPLOYMENT_TARGET" = "17.0"' in project, 'Minimum iOS is 17.0')
    scheme = ET.parse(ROOT / 'JFTA.xcodeproj/xcshareddata/xcschemes/JFTA.xcscheme').getroot()
    names = {x.attrib['BlueprintName'] for x in scheme.findall('./TestAction/Testables/TestableReference/BuildableReference')}
    check(names == {'JFTAUnitTests', 'JFTAUITests'}, 'Shared scheme includes both test bundles')
    for name in ['Info.plist', 'PrivacyInfo.xcprivacy']:
        with (ROOT / 'JFTA' / name).open('rb') as f:
            data = plistlib.load(f)
        check(isinstance(data, dict), 'Valid plist: ' + name)
    for catalog in sorted((ROOT / 'JFTA/Assets.xcassets').rglob('Contents.json')):
        data = json.loads(catalog.read_text())
        for image in data.get('images', []):
            if image.get('filename'):
                check((catalog.parent / image['filename']).is_file(), 'Asset exists: ' + image['filename'])
    runtime = '\n'.join((ROOT / p).read_text() for p in manifest['app_sources'])
    check('Resources/Screens' not in runtime and 'TapGesture' not in runtime, 'No full-screen reference-image hit areas in runtime')
    check(all(x in runtime for x in ['TextField(', 'TextEditor(', 'NavigationStack', 'fileImporter']), 'Native forms, navigation and file import exist')
    check(not re.search(r'URLSession|URLRequest|WKWebView', runtime), 'No networking or web-wrapper implementation in this local beta')
    check(not re.search(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}', runtime), 'No known private-key or token patterns in runtime source')
    workflow = (ROOT / '.github/workflows/ios.yml').read_text()
    check('workflow_dispatch:' in workflow and not re.search(r'^  (push|pull_request|schedule):', workflow, re.M), 'CI runs manually only')
    check('runs-on: macos-26\n' in workflow and '-xlarge' not in workflow and '-large' not in workflow, 'Only standard macos-26 runner selected')
    check('timeout-minutes: 20' in workflow and 'retention-days: 3' in workflow, 'Job time and evidence retention bounded')
    check('github.event.repository.private == false' in workflow, 'Public-only gate blocks private-repository allocation')
    check('persist-credentials: false' in workflow, 'Checkout does not persist repository credentials')
    actions = re.findall(r'uses: ([^\n]+)', workflow)
    check(all(re.search(r'@[0-9a-f]{40}(?: |$)', action) for action in actions), 'All third-party workflow actions pinned to exact commits')
    return results

if __name__ == '__main__':
    try:
        checks = validate()
        for message in checks:
            print('PASS:', message)
        print(f'\n{len(checks)} structural checks passed. No claim of iOS compilation or runtime verification.')
    except Exception as exc:
        print('FAIL:', exc, file=sys.stderr)
        raise SystemExit(1)
