#!/usr/bin/env python3
"""Generate the checked-in Xcode project without XcodeGen or external dependencies."""
from pathlib import Path
import hashlib, json, plistlib, xml.etree.ElementTree as ET
ROOT = Path(__file__).resolve().parents[1]
objects = {}
def uid(key): return hashlib.sha256(key.encode()).hexdigest()[:24].upper()
def obj(key, isa, **kwargs):
    i=uid(key); objects[i]={'isa':isa,**kwargs}; return i
def file(path, typ): return obj('file:'+path,'PBXFileReference',lastKnownFileType=typ,path=path,sourceTree='SOURCE_ROOT')
def build_file(path, typ):
    r=file(path,typ); return r,obj('build:'+path,'PBXBuildFile',fileRef=r)
def configs(key, settings):
    arr=[]
    for mode in ['Debug','Release']:
        conf=dict(settings)
        if key=='project': conf.update(SWIFT_OPTIMIZATION_LEVEL='-Onone' if mode=='Debug' else '-O', DEBUG_INFORMATION_FORMAT='dwarf' if mode=='Debug' else 'dwarf-with-dsym')
        if mode=='Debug': conf.update(SWIFT_ACTIVE_COMPILATION_CONDITIONS='DEBUG $(inherited)',ENABLE_TESTABILITY='YES')
        arr.append(obj(key+mode,'XCBuildConfiguration',buildSettings=conf,name=mode))
    return obj(key+'configs','XCConfigurationList',buildConfigurations=arr,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
app_sources=sorted(str(p.relative_to(ROOT)) for folder in ['JFTA','Core'] for p in (ROOT/folder).glob('*.swift'))
unit_sources=['Tests/JFTACoreTests/CoreTests.swift']; ui_sources=['JFTAUITests/JFTAUITests.swift']
app_refs=[];app_build=[]
for p in app_sources:
    r,b=build_file(p,'sourcecode.swift');app_refs.append(r);app_build.append(b)
assetref,assetbuild=build_file('JFTA/Assets.xcassets','folder.assetcatalog')
privacyref,privacybuild=build_file('JFTA/PrivacyInfo.xcprivacy','text.xml')
app_refs.extend([assetref,privacyref,file('JFTA/Info.plist','text.plist.xml')])
unit_refs=[];unit_build=[];ui_refs=[];ui_build=[]
for paths,refs,builds in [(unit_sources,unit_refs,unit_build),(ui_sources,ui_refs,ui_build)]:
    for p in paths:
        r,b=build_file(p,'sourcecode.swift');refs.append(r);builds.append(b)
project_id=uid('project');app_id=uid('target:JFTA')
products=[];targets=[]
common={'SWIFT_VERSION':'5.0','IPHONEOS_DEPLOYMENT_TARGET':'17.0','TARGETED_DEVICE_FAMILY':'1','CODE_SIGN_STYLE':'Automatic','DEVELOPMENT_TEAM':'','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','PRODUCT_NAME':'$(TARGET_NAME)','SWIFT_EMIT_LOC_STRINGS':'YES'}
for name, sources, producttype, ext in [('JFTA',app_build,'application','app'),('JFTAUnitTests',unit_build,'bundle.unit-test','xctest'),('JFTAUITests',ui_build,'bundle.ui-testing','xctest')]:
    product=obj('product:'+name,'PBXFileReference',explicitFileType='wrapper.application' if ext=='app' else 'wrapper.cfbundle',includeInIndex=0,path=name+'.'+ext,sourceTree='BUILT_PRODUCTS_DIR');products.append(product)
    settings=dict(common);deps=[]
    if name=='JFTA': settings.update(PRODUCT_BUNDLE_IDENTIFIER='org.jftateam.memberapp',GENERATE_INFOPLIST_FILE='NO',INFOPLIST_FILE='JFTA/Info.plist',ASSETCATALOG_COMPILER_APPICON_NAME='AppIcon',CURRENT_PROJECT_VERSION='3',MARKETING_VERSION='0.2.0')
    else:
        settings.update(PRODUCT_BUNDLE_IDENTIFIER='org.jftateam.memberapp.'+name,GENERATE_INFOPLIST_FILE='YES')
        if name=='JFTAUnitTests': settings.update(TEST_HOST='$(BUILT_PRODUCTS_DIR)/JFTA.app/JFTA',BUNDLE_LOADER='$(TEST_HOST)')
        else: settings['TEST_TARGET_NAME']='JFTA'
        proxy=obj('proxy:'+name,'PBXContainerItemProxy',containerPortal=project_id,proxyType=1,remoteGlobalIDString=app_id,remoteInfo='JFTA')
        deps=[obj('dependency:'+name,'PBXTargetDependency',target=app_id,targetProxy=proxy)]
    phases=[obj(name+'sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=sources,runOnlyForDeploymentPostprocessing=0),obj(name+'frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0),obj(name+'resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=[assetbuild,privacybuild] if name=='JFTA' else [],runOnlyForDeploymentPostprocessing=0)]
    targets.append(obj('target:'+name,'PBXNativeTarget',buildConfigurationList=configs(name,settings),buildPhases=phases,buildRules=[],dependencies=deps,name=name,productName=name,productReference=product,productType='com.apple.product-type.'+producttype))
appgroup=obj('appgroup','PBXGroup',children=app_refs,name='Application and Core',sourceTree='<group>')
testgroup=obj('testgroup','PBXGroup',children=unit_refs+ui_refs,name='Tests',sourceTree='<group>')
productgroup=obj('productgroup','PBXGroup',children=products,name='Products',sourceTree='<group>')
rootgroup=obj('rootgroup','PBXGroup',children=[appgroup,testgroup,productgroup],sourceTree='<group>')
project_settings={'ALWAYS_SEARCH_USER_PATHS':'NO','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0'}
obj('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'2660','TargetAttributes':{uid('target:JFTA'):{'CreatedOnToolsVersion':'26.6'},uid('target:JFTAUnitTests'):{'CreatedOnToolsVersion':'26.6','TestTargetID':app_id},uid('target:JFTAUITests'):{'CreatedOnToolsVersion':'26.6','TestTargetID':app_id}}},buildConfigurationList=configs('project',project_settings),compatibilityVersion='Xcode 15.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=rootgroup,productRefGroup=productgroup,projectDirPath='',projectRoot='',targets=targets)
def dump(x,level=0):
    pad='\t'*level
    if isinstance(x,dict): return '{\n'+''.join('\t'*(level+1)+json.dumps(str(k))+ ' = '+dump(v,level+1)+';\n' for k,v in x.items())+pad+'}'
    if isinstance(x,list): return '(\n'+''.join('\t'*(level+1)+dump(v,level+1)+',\n' for v in x)+pad+')'
    if isinstance(x,int):return str(x)
    return json.dumps(str(x),ensure_ascii=False)
p=ROOT/'JFTA.xcodeproj';p.mkdir(exist_ok=True)
project={'archiveVersion':1,'classes':{},'objectVersion':60,'objects':objects,'rootObject':project_id}
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n'+dump(project)+'\n')
shared=p/'xcshareddata/xcschemes';shared.mkdir(parents=True,exist_ok=True)
scheme=ET.Element('Scheme',LastUpgradeVersion='2660',version='1.7')
def ref(parent,name):ET.SubElement(parent,'BuildableReference',BuildableIdentifier='primary',BlueprintIdentifier=uid('target:'+name),BuildableName=name+('.app' if name=='JFTA' else '.xctest'),BlueprintName=name,ReferencedContainer='container:JFTA.xcodeproj')
ba=ET.SubElement(scheme,'BuildAction',parallelizeBuildables='YES',buildImplicitDependencies='YES');entries=ET.SubElement(ba,'BuildActionEntries')
entry=ET.SubElement(entries,'BuildActionEntry',buildForTesting='YES',buildForRunning='YES',buildForProfiling='YES',buildForArchiving='YES',buildForAnalyzing='YES');ref(entry,'JFTA')
test=ET.SubElement(scheme,'TestAction',buildConfiguration='Debug',selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB',shouldUseLaunchSchemeArgsEnv='YES');testables=ET.SubElement(test,'Testables')
for name in ['JFTAUnitTests','JFTAUITests']:ref(ET.SubElement(testables,'TestableReference',skipped='NO',parallelizable='NO'),name)
launch=ET.SubElement(scheme,'LaunchAction',buildConfiguration='Debug',selectedDebuggerIdentifier='Xcode.DebuggerFoundation.Debugger.LLDB',selectedLauncherIdentifier='Xcode.IDEFoundation.Launcher.LLDB',launchStyle='0',useCustomWorkingDirectory='NO',ignoresPersistentStateOnLaunch='NO',debugDocumentVersioning='YES',debugServiceExtension='internal',allowLocationSimulation='YES');ref(ET.SubElement(launch,'BuildableProductRunnable',runnableDebuggingMode='0'),'JFTA')
profile=ET.SubElement(scheme,'ProfileAction',buildConfiguration='Release',shouldUseLaunchSchemeArgsEnv='YES',savedToolIdentifier='',useCustomWorkingDirectory='NO',debugDocumentVersioning='YES');ref(ET.SubElement(profile,'BuildableProductRunnable',runnableDebuggingMode='0'),'JFTA')
ET.SubElement(scheme,'AnalyzeAction',buildConfiguration='Debug');ET.SubElement(scheme,'ArchiveAction',buildConfiguration='Release',revealArchiveInOrganizer='YES')
ET.indent(scheme);ET.ElementTree(scheme).write(shared/'JFTA.xcscheme',encoding='UTF-8',xml_declaration=True)
manifest={'app_sources':app_sources,'unit_sources':unit_sources,'ui_sources':ui_sources,'target_ids':{name:uid('target:'+name) for name in ['JFTA','JFTAUnitTests','JFTAUITests']}}
(ROOT/'docs/project-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Generated Xcode project:',len(app_sources),'app/core sources, 3 targets, shared JFTA scheme')
