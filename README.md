# JFTA iOS

Native SwiftUI local beta **0.2.1 (4)** for the JFTA trucking/member app. The screens use native controls and local data, not full-screen images with invisible hotspots.

## What works locally

Four tabs, editable onboarding and profile, request drafts with validation/search/edit/delete/export, document import/Quick Look/share/delete and draft attachment references, sample benefit and marketplace catalogs with saved items, readable resources, local posts/replies and activity notices. The demo member pass contains a random identifier, not a valid credential.

There is **no backend, online login, active membership, payment, verified provider, submitted request, synchronized community or push service**. The interface identifies local and sample states. Use non-sensitive sample files. Removing the app can remove its local data.

## Verification

Read `docs/QA_STATUS.md` for the exact tested commit and actual run results. There are 47 Foundation tests and 16 UI scenarios. A test being present does not mean it passed. Historical logs and `docs/native-source-baseline.json` refer to the original 0.2.0 source, not proof of this version.

The original baseline was genuinely compiled with Xcode 26.6 and ran 37 passing Core tests on iOS Simulator. Its complete UI run did not pass: the UI harness hit a timeout and was cancelled. Version 0.2.1 fixes missing-record updates, adds keyboard dismissal, expands regression coverage and uses one simulator architecture with realistic test allowances.

## Open and test on a Mac

Open `JFTA.xcodeproj`, choose scheme **JFTA** and an installed iPhone Simulator. Minimum deployment target: iOS 17. CI pins Xcode 26.6 on the standard `macos-26` runner. No third-party Swift package or backend credential is required.

From the project directory, run `bash scripts/ci_macos.sh unit` for the compiler/Core check or `bash scripts/ci_macos.sh all` for Core/UI tests and an unsigned Release archive. Use an installed full Xcode and iPhone runtime. Logs, the result bundle and real screenshot attachments are written under `build/ci`. An unsigned archive is not an installable IPA and cannot substitute for Apple signing.

## GitHub Actions and privacy

The manual-only workflow allocates a standard Mac **only while this repository is public**. Returning it to private blocks allocation; no paid private run is automatically enabled. There are no push, pull-request or scheduled triggers. A public copy may remain with someone who downloaded or forked it even after visibility changes. No open-source license is granted by this README.

Full acceptance is partitioned across four standard Macs, with a 40-minute per-job limit and one-day evidence retention. Every UI case is assigned once; Core tests and the unsigned Release archive run on shard 0. Unit-only mode allocates one Mac. Actions are pinned to exact commits, checkout does not persist credentials and no Apple secrets are used. Standard public-repository runner compute is free under GitHub's applicable terms, not technically unlimited. Do not enable larger runners or a paid service without owner authorization.

## Device acceptance and TestFlight

A passing simulator suite does not prove real-iPhone or distribution readiness. Check external Files/iCloud import and cancellation, Quick Look, sharing, keyboard overlap, Dynamic Type, VoiceOver, small-screen layouts, background/lock/unlock and update persistence on a physical device. The automated document import uses a test fixture, not an external file provider.

See `docs/TESTFLIGHT_HANDOFF.md`. The authorized account owner must choose the intended publisher, Developer Team and permanent Bundle ID before building a signed archive. Do not send Apple passwords, two-factor codes or signing keys in chat or Git. The current `org.jftateam.memberapp` is a placeholder. App review and TestFlight acceptance are separate checks, not guaranteed by CI.

## Local checks and source

`swift test` executes the Foundation package. `python3 scripts/validate_project.py` checks project/resource/CI structure; `python3 scripts/test_ci_scripts.py` tests simulator selection on fixtures. `bash -n scripts/ci_macos.sh` checks shell syntax. These checks do not replace Xcode.

`scripts/generate_project.py` regenerates the project and shared scheme. `scripts/import_existing_assets.py` was a one-time, hash-verified import from the owner's old source and is not needed to build. The original 0.2.0 ZIP is retained separately with SHA256 `c80ab597053c7f9ce05517435cac19f39ac702d6fc5082a2aefc64e4b1cb7567`.

Official references checked 2026-10-02:
- https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- https://docs.github.com/en/actions/reference/limits
- https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility
- https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
