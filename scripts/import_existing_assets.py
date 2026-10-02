#!/usr/bin/env python3
"""One-time source import from the owner's existing audited JFTA folder. No network."""
from pathlib import Path
import hashlib, json, plistlib, shutil, sys
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(sys.argv[1]).resolve()
ASSETS = ROOT / 'JFTA/Assets.xcassets'
INFO = {'author': 'xcode', 'version': 1}
def put(path, data):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists() and target.read_bytes() != data:
        raise RuntimeError('Refusing to overwrite different file: ' + path)
    target.write_bytes(data)
def text(path, value): put(path, value.encode('utf-8'))
def obj(path, value): text(path, json.dumps(value, indent=2) + '\n')
expected = {
    'icon-1024.png':'616118f36bcf1f30f045296d8303d36143dc8dacea6c46aae6009db2b390a53c',
    'icon-120.png':'56cf12b4c8d846b8fab756283623458f26891ef4e6af274bd4611b9d4db57f35',
    'icon-180.png':'7c55c5a097bd4b397505c8dfb51adfb3213316a1f060026904c5c00e82c76c5c',
    'icon-40.png':'6eee01b818f3040a54f8e983e23bdda8f0d2c129da9d6c51f7abbfa024b55ccb',
    'icon-58.png':'60cc07e2b90e4fecbf185d7e5d0a14f4ff8ce54d4868d87aab744f2869aa105e',
    'icon-60.png':'c4870b1b5e40478f27c43610dcddebfb1880e7bb149b9bea7202136e09ad0ea3',
    'icon-80.png':'4983e1562a489dfefa2fce533053045c0f4a1e6564b8fc0b0c6c58f9a8d70df3',
    'icon-87.png':'84dca892417d07eb1085e30994ff0a3ccd776d961f4bb4600150c7d8872d8d3b'}
for name, digest in expected.items():
    data = (SOURCE/'Assets.xcassets/AppIcon.appiconset'/name).read_bytes()
    assert hashlib.sha256(data).hexdigest() == digest, name
    put('JFTA/Assets.xcassets/AppIcon.appiconset/'+name, data)
brand = (SOURCE/'Resources/JFTA_New_Logo.png').read_bytes()
assert hashlib.sha256(brand).hexdigest() == '45fa4e7707921a770a11243c954f0bc7ac67966dd1bf38c39dfa5b051f674826'
put('JFTA/Assets.xcassets/Brand.imageset/image.png', brand)
import io
buffer = io.BytesIO()
Image.open(SOURCE/'Resources/Screens/03_Home_Need_Help_Now.png').crop((25,130,827,466)).convert('RGB').save(buffer, format='JPEG', quality=91)
hero = buffer.getvalue()
assert hashlib.sha256(hero).hexdigest() == 'a90c40c1c303fb913153511ee615e6f069cc2a616d78dd1845e720ef7489fd69', 'Hero image bytes differ'
put('JFTA/Assets.xcassets/RoadHero.imageset/image.jpg', hero)
obj('JFTA/Assets.xcassets/Contents.json', {'info':INFO})
obj('JFTA/Assets.xcassets/AccentColor.colorset/Contents.json', {'colors':[{'idiom':'universal'}], 'info':INFO})
for name,filename in [('Brand','image.png'),('RoadHero','image.jpg')]:
    text(f'JFTA/Assets.xcassets/{name}.imageset/Contents.json', json.dumps({'images':[{'filename':filename,'idiom':'universal'}],'info':INFO}))
icons = [('20x20','2x',40),('20x20','3x',60),('29x29','2x',58),('29x29','3x',87),('40x40','2x',80),('40x40','3x',120),('60x60','2x',120),('60x60','3x',180)]
images = [{'idiom':'iphone','size':size,'scale':scale,'filename':f'icon-{pixels}.png'} for size,scale,pixels in icons]
images.append({'idiom':'ios-marketing','size':'1024x1024','scale':'1x','filename':'icon-1024.png'})
obj('JFTA/Assets.xcassets/AppIcon.appiconset/Contents.json', {'images':images,'info':INFO})
info = {'CFBundleDevelopmentRegion':'en','CFBundleDisplayName':'JFTA Beta','CFBundleExecutable':'$(EXECUTABLE_NAME)','CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)','CFBundleInfoDictionaryVersion':'6.0','CFBundleName':'$(PRODUCT_NAME)','CFBundlePackageType':'APPL','CFBundleShortVersionString':'$(MARKETING_VERSION)','CFBundleVersion':'$(CURRENT_PROJECT_VERSION)','LSRequiresIPhoneOS':True,'LSSupportsOpeningDocumentsInPlace':True,'UIApplicationSceneManifest':{'UIApplicationSupportsMultipleScenes':False},'UIFileSharingEnabled':False,'UILaunchScreen':{},'UIRequiresFullScreen':True,'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait']}
put('JFTA/Info.plist', plistlib.dumps(info))
put('JFTA/PrivacyInfo.xcprivacy', plistlib.dumps({'NSPrivacyAccessedAPITypes':[],'NSPrivacyCollectedDataTypes':[],'NSPrivacyTracking':False}))
text('.gitignore', '.DS_Store\n.build/\nbuild/\nDerivedData/\n*.xcuserstate\nxcuserdata/\n.env\n.env.*\n!.env.example\n*.p12\n*.p8\n*.mobileprovision\n*.cer\n*.ipa\n*.xcarchive/\n__pycache__/\n*.pyc\n')
text('.gitattributes', '* text=auto\n*.swift text eol=lf\n*.sh text eol=lf\n*.py text eol=lf\n*.yml text eol=lf\n*.md text eol=lf\n*.ps1 text eol=crlf\n*.png binary\n*.jpg binary\n')
text('Package.swift', '// swift-tools-version: 5.9\nimport PackageDescription\nlet package = Package(\n    name: "JFTACore", platforms: [.iOS(.v17), .macOS(.v13)],\n    products: [.library(name: "JFTACore", targets: ["JFTACore"])],\n    targets: [.target(name: "JFTACore", path: "Core"),\n              .testTarget(name: "JFTACoreTests", dependencies: ["JFTACore"], path: "Tests/JFTACoreTests")]\n)\n')
(ROOT/'docs').mkdir(exist_ok=True)
print('Imported 10 graphics with exact SHA256 verification; created metadata. No iOS build performed.')
