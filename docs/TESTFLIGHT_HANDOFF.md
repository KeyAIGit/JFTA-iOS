# JFTA 0.2.2 (5): handoff to the authorized Apple account owner

The source is a native, local-functionality beta. Consult `QA_STATUS.md` for the exact tested revision and limitations. No Apple account, signing key, certificate, provisioning profile, IPA or App Store Connect record was created or used by GitHub CI.

## Before choosing the app record

Agree who will own the app. The current Bundle ID `org.jftateam.memberapp` is a placeholder, not a confirmed registered identifier. A friend's authorized Developer Team can sign the experimental build, but Apple's standard transfer criteria require a version already released on the App Store. Do not assume that a TestFlight-only record can be transferred unchanged later. Do not publish an unfinished app just to qualify for transfer. [1]

## Build and install

1. Open `JFTA.xcodeproj` in a current full Xcode. The CI uses Xcode 26.6; the project's minimum device OS is iOS 17, a different setting from the build SDK.
2. Select scheme JFTA and an iPhone Simulator, then run the app and tests. The command-line suite is `bash scripts/ci_macos.sh all`. Inspect its genuine screenshots and result bundle; old design images are not evidence.
3. In the app target's Signing & Capabilities, select the agreed Team and a unique Bundle ID belonging to that team. Use automatic signing or the account owner's established signing process. The account owner should handle their own authentication.
4. Run on a connected physical iPhone. Verify the checks below before distributing.
5. Select a physical/generic iOS destination, then Product > Archive. In Organizer validate the signed archive and choose Distribute App > App Store Connect as appropriate. The CI's unsigned archive cannot be uploaded as-is. [2,3]
6. Create/select the matching App Store Connect app record, provide accurate beta/privacy/export metadata and upload. A processed build can then be assigned to the intended TestFlight group. External testing may require Beta App Review. Upload, processing and acceptance remain separate results. [2,4]

Never send Apple passwords, two-factor codes, private keys or certificates through chat or the repository. No fee, account upgrade or publishing action has been authorized by this handoff.

## What to test on the real device

Create a sample profile, edit it and relaunch. Create/edit a request, attach a non-sensitive test file and relaunch. Import from Apple Files, cancel an import, preview with Quick Look, use the share sheet, then delete only the local copy and verify the original file remains. Try an invalid/oversized file and low-storage failures. Exercise unsaved-change confirmation, keyboard dismissal, document-preview closure and sharing, large text, VoiceOver, backgrounding, lock/unlock and updating the app without uninstalling it. Do not keep the only copy of important information in this beta.

## Accurate beta description

JFTA is a local native beta for organizing sample request drafts, documents, saved resources and local discussions. It does not authenticate an online account, verify membership, submit requests, book professionals, process payments, synchronize community posts or provide emergency services. Its QR is explicitly a demo identifier. No reviewer should be told these services work. Automated sample import does not validate an external iCloud/File Provider.

Official sources checked 2026-10-02:
[1] https://developer.apple.com/help/app-store-connect/transfer-an-app/app-transfer-criteria/
[2] https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
[3] https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases
[4] https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
