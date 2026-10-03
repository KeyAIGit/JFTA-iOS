import json, os, re, subprocess, sys
if sys.platform != 'darwin' or os.environ.get('GITHUB_ACTIONS') != 'true':
    raise SystemExit('This isolated simulator creator is restricted to GitHub macOS CI.')
def call(*args): return subprocess.check_output(['xcrun', 'simctl', *args], text=True)
types=json.loads(call('list','devicetypes','--json'))['devicetypes']
preferences=['iPhone SE (3rd generation)', 'iPhone 13 mini']
kind=next((t for name in preferences for t in types if t['name']==name),None)
if not kind: raise SystemExit('No supported compact device type available. No compact pass claimed.')
standard=json.loads(subprocess.check_output(['python3','scripts/select_simulator.py','--json'],text=True))
runtime=standard['runtime']
udid=call('create','JFTA Compact CI',kind['identifier'],runtime).strip()
if not re.fullmatch(r'[A-Fa-f0-9-]{36}',udid): raise SystemExit('Invalid new simulator identifier')
all_devices=json.loads(call('list','devices','--json'))['devices']
new=next(d for devices in all_devices.values() for d in devices if d['udid']==udid)
new.update(runtime=runtime,requested_kind='explicit compact creation',created_for_this_job=True)
print(json.dumps(new))
