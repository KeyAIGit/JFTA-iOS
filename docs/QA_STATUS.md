# JFTA 0.2.3 (6): verified native acceptance

Date: 2026-10-03. This report describes local functionality, not an active membership service.

## Confirmed full run

Run 37106664707 at source `8e024ae553826c3cd329b5b2ac40e66c9001031a` passed 64 Core XCTest cases and 28 UI scenarios: 92 distinct tests, zero failures, zero skipped tests, no reruns. All four full-suite shards used iPhone Air / iOS 26.5 with Xcode 26.6. An unsigned generic-iOS Release archive succeeded.

Each declared test was reconciled with actual passing log records and the XCTest summary. The four test selections cover all cases once, working trees were clean, and the four CI source ZIP hashes agree. Original source ZIP SHA256: `ad7a9e5ceb6f60cf52da0630e9b346febb06e2f78d274339eda2ff4fd9efb969`.

Release run 37106813385 at `7ca6d0be440d4255b29bf64f43ec96062f83c334` passed the real onboarding/persistence scenario in Release configuration. The DEBUG-only test-profile shortcut was disabled. This repeats one existing test; it is not added to the 92 unique cases.

Compact run 37107664200 at `ccf779bce13ec8655c726d88f2344746c14c9c8a` passed 3/3 existing scenarios on an explicitly created iPhone SE (3rd generation), iOS 26.5: home routes, draft attachment actions and large-text navigation. No failure, skip or retry occurred. Only this subset, not the entire suite, was repeated on SE. The original matrix compact preference fell back to Air and is not evidence of a smaller display. Do not confuse a preference flag with an actual tested model.

## Source and configuration

Between the full, Release and compact commits, only workflow and helper scripts changed. App code, resources, Xcode project and tests stayed identical. Later documentation changes are not represented as another application test. SOURCE_PROVENANCE.json identifies the tested runtime.

## Important boundaries

No signing, physical-device installation, signed IPA, Apple upload, TestFlight processing or Apple approval has been performed. Real Files/iCloud content transfer, a completed share to another app, VoiceOver, lock/unlock and all supported iOS versions still require acceptance. Minimum iOS 17 is a deployment setting, not proof of an iOS 17 test.

The import automation uses non-sensitive fixtures. The system Files test checks open/cancel behavior, not iCloud import. The app contains local profiles, drafts, document actions, saved catalogs, posts/replies and preferences. Online authentication, real membership, payments, providers, booking, submission and community synchronization remain unconnected and labeled accordingly.

The evidence package contains lightweight logs, test-selection files, XCTest summaries and actual screenshots. Its HTML gallery is not an interactive application. Open JFTA.xcodeproj to run the app. Historical baseline files and old validation logs must not be added to the current test totals.
