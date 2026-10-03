# JFTA iOS 0.2.3 (6)

Open `JFTA.xcodeproj`, choose the shared `JFTA` scheme and an iPhone Simulator. This is a native SwiftUI local beta with real forms, navigation, document actions and persistence, not a screenshot viewer.

## Verified acceptance

Xcode 26.6 run **37106664707** passed **64 Core tests and 28 UI scenarios**, with no failures, skips or reruns. The 92 distinct cases were executed on iPhone Air / iOS 26.5. An unsigned Release archive for generic iOS succeeded. Separate Release run **37106813385** passed onboarding and persistence without the DEBUG-only automatic test profile. This additional execution is not a new distinct test.

The full matrix's compact preference fell back to Air. The separate explicit compact-device run **37107664200** passed 3/3 scenarios on iPhone SE (3rd generation), iOS 26.5. See `docs/QA_STATUS.md` for the limited scope of that extra check.

## Improvements

Home draft and saved-offer counters now navigate to their lists. Profile and post editors protect unsaved changes. Discussions can be edited, exported and deleted while retaining replies during editing. Draft details support explicit deletion and a fuller text export. Document preview, attachment selection and actions menus have independent tap targets. A safe sample document is available in both Debug and Release. Service and member-pass layouts adapt to accessibility text sizes.

## Honest local-beta scope

Profile, request drafts, sample-document import/preview/sharing/deletion, saved catalogs, resources, local posts/replies and preferences work locally. Online accounts, server synchronization, membership verification, payments, appointments, submitted requests, providers and a shared community are not connected. The QR and catalogs are demonstrations, not valid benefits. Use sample data only and retain original files elsewhere.

No signed IPA, physical-iPhone installation, Apple upload, TestFlight processing or Apple approval was performed by this workflow. Real-device file-provider import, sharing, VoiceOver, lock/unlock and supported-OS compatibility remain acceptance checks. Minimum iOS 17 does not mean iOS 17 was tested.

## Reproduce on a Mac

Run `bash scripts/ci_macos.sh unit` or `bash scripts/ci_macos.sh all`. Actual logs, XCTest results and screenshots are written to `build/ci`. The latter command also creates an unsigned archive, not an installable IPA. A separate Release check is `bash scripts/ci_release_smoke.sh` in a clean build directory. The compact simulator creator is restricted to GitHub CI and deletes only the device it created.

Select the agreed Apple Developer Team and registered Bundle ID, install on a real iPhone, then create and validate a signed Archive for App Store Connect. Read `docs/TESTFLIGHT_HANDOFF.md`. Never commit signing credentials.
