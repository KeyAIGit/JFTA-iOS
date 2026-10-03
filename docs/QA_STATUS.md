# JFTA 0.2.2 (5): verified native acceptance

Local date: October 2, 2026 (America/Los_Angeles). CI timestamps are October 3 UTC.
Tested commit: `9ec09bdfcc9278b572b82b7cd06a7d56eba98f7c`.
Run: https://github.com/KeyAIGit/JFTA-iOS/actions/runs/37099600328

## Results actually verified

- 55 Core XCTest cases passed on iOS Simulator.
- 18 XCUITest UI scenarios passed on iOS Simulator.
- Accepted evidence has zero failed or skipped tests; each declared test appears exactly once across the four selected shard results.
- The first attempt of this commit had one failed navigation check in the document-preview scenario. That four-test group was retried once without changing the source. Initial failure evidence is retained separately; UI automation still showed intermittent timing sensitivity.
- The app and both test bundles compiled with Xcode 26.6.
- An unsigned Release archive for generic iOS completed successfully.
- The same 55 Core tests also passed separately on Linux Swift 6.2.1; that is supplementary evidence, not an iOS substitute.

The evidence reconciliation requires the exact source commit, clean working trees, agreeing source archives, zero exit codes, test-summary totals matching pass records in xcodebuild logs, complete test selection, and ARCHIVE SUCCEEDED in the Release log. No mockup image is used as runtime evidence.

## Scope and remaining checks

This is a working local beta, not a connected membership service. No Apple signing, installed physical iPhone test, signed IPA, App Store Connect upload, TestFlight processing or Apple review was performed. The document-import automation uses a fixture and does not validate external iCloud/File Providers. Real-device Files import/cancellation, sharing, low-storage behavior, large text, VoiceOver, smaller displays and supported-OS compatibility still require acceptance.

Public repository CI is guarded against automatic allocation after a switch back to private. There is no automatic Apple distribution step. The app has no active backend, online account, membership, payments, submitted requests, appointments, live providers or synchronized community.

Current evidence is contained in the separately retained acceptance package; older files under `validation/` and the 0.2.0 baseline hash document are historical records. Do not add historical counts to the current 73 distinct tests.
