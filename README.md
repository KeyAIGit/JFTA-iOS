> CI now runs only while this repository is PUBLIC, on the standard macos-26 runner. Returning to private disables Mac job allocation. No Apple credentials are used. Publication does not grant an open-source license.

# JFTA iOS

Native SwiftUI local beta **0.2.0 (3)** for the JFTA trucking/member app. This is not a screenshot wrapper. The source, Xcode project, shared scheme, assets and automated test code are stored in this private repository.

## Current status (2026-10-02)

The repository and GitHub CLI access have been configured. The native source was imported from `JFTA-iOS-Native-0.2.0.zip`, SHA256 `c80ab597053c7f9ce05517435cac19f39ac702d6fc5082a2aefc64e4b1cb7567`. The original archive is retained in the owner's ChatGPT Library. Runtime/test/project hashes are recorded in `docs/native-source-baseline.json`.

**No Apple-SDK build or simulator UI run is confirmed yet.** The initial hosted run is held until the remaining included Actions quota and a genuine account-level paid-usage stop are verified. The existing CLI authorization permits repository/workflow operations but the billing API additionally requested the `user` OAuth scope. A missing permission is not proof that the account has no paid usage or no quota.

The earlier Linux verification passed 37 Swift/Foundation XCTest cases. During repository setup, 42 structural checks and 7 Python simulator-selector tests also passed on the owner's Windows/WSL setup. These are not simulator tests. The project contains 10 XCUITest scenarios that have not run on iOS yet.

## Native local functionality

Four tabs provide native navigation, editable local onboarding/profile/settings, local request drafts with search/edit/delete/export, document import/preview/share/delete and draft attachment references, sample benefit and marketplace catalogs with bookmarks, readable resources, local discussion posts/replies and local activity notices. A demo member pass contains a random demo QR identifier, not a membership credential.

There is **no backend, real authentication, active membership, payment, verified provider, submitted request, live community or push service**. Local-only and sample states are labelled in the UI. Use non-sensitive sample documents only. Deleting the app can delete local data.

## Open on a Mac

Open `JFTA.xcodeproj` and select the shared `JFTA` scheme. Install/select the full Xcode and an iPhone Simulator runtime. The deployment target is iOS 17.0; the CI uses the pinned Xcode 26.6 installation on a standard `macos-26` runner.

Run `bash scripts/ci_macos.sh unit` for the initial compiler/unit check, or `bash scripts/ci_macos.sh all` for unit and UI tests. The script refuses to run on a non-Mac; it never fabricates simulator output. It uses an already installed iPhone runtime and does not sign or upload anything to Apple.

## GitHub Actions

Open **Actions > iOS native build and tests > Run workflow** only after the billing checks below. No push, pull-request or scheduled trigger is configured.

The workflow runs one standard Mac job, with a 20-minute timeout, no parallel simulator testing and three-day evidence retention. Checkout and artifact actions are pinned to exact commits. Repository credentials are not persisted by checkout. Logs, the `.xcresult` and actual UI-test screenshot attachments are uploaded as a private run artifact.

The input `no_charge_guard_confirmed` is an acknowledgement, **not a spending cap**. Check both the available included quota and the account's actual Actions paid-usage stop before setting it to true. A time limit or budget notification alone does not guarantee zero charges. Do not enable larger runners, increase a budget or add a paid service for this project without owner approval.

## Acceptance before calling the UI complete

A successful simulator compile is necessary but insufficient. Run all XCTest cases and inspect actual screenshots. Check keyboard overlap, small/large iPhone layouts, Dynamic Type, VoiceOver, validation errors and persistence after a real restart. Test Apple Files/iCloud import, cancellation, Quick Look and sharing manually; the automated import scenario uses a local fixture and does not validate external file providers.

A real iPhone must also be checked for cold starts, app updates, lock/unlock, backgrounding, file protection, storage errors and data retention. Do not replace unverified test evidence with the old design images.

## TestFlight handoff

Signing, Apple Developer membership, App Store Connect access and app ownership are separate from this CI. The friend should use their own authorized Apple account to sign an agreed release; do not share Apple passwords, two-factor codes, private keys or certificates through chat or Git. The current Bundle ID is a placeholder. Decide the intended publisher and a unique Bundle ID before uploading. A simulator success is not an IPA, a device test, an Apple review or a TestFlight release.

## Local non-Apple checks

`swift test` runs the Foundation package tests where Swift is installed. `python3 scripts/validate_project.py` verifies source references, resources and CI guard structure. `python3 scripts/test_ci_scripts.py` tests simulator selection on fixture data. `bash -n scripts/ci_macos.sh` checks shell syntax.

`scripts/generate_project.py` deterministically regenerates the checked-in project and shared scheme on macOS/Linux. `scripts/import_existing_assets.py` was a one-time, hash-verified import from the owner's existing audited local source; it is not needed to build or test the repository and is not invoked by CI.
