# JFTA iOS 0.2.2 (5)

Native SwiftUI **local beta** for the JFTA trucking/member app. This is an actual Xcode project, not a set of screen images. Online services are not connected.

## Verified Xcode and Simulator checks

Tested source commit: `9ec09bdfcc9278b572b82b7cd06a7d56eba98f7c`. GitHub Actions run: **37099600328**.

**55 Core tests + 18 UI tests passed in the accepted shard evidence, with no skipped tests.** The first attempt of this same commit had one failed UI navigation check; that group was retried once without source changes. The retry history is retained, and this is not a claim of a flawless first run or completely stable UI automation. The independent evidence reconciliation checked every declared test against its real XCTest pass log, exactly once across all four shards. Both the Simulator build and the unsigned Release archive for a generic iOS target succeeded.

This does not prove a signed installation, a real-device pass, TestFlight processing, Apple approval, accessibility on every screen or compatibility with every supported iOS version. See `docs/QA_STATUS.md` and `docs/TESTFLIGHT_HANDOFF.md`.

## Open on a Mac

Open **JFTA.xcodeproj** and choose scheme **JFTA**, then an installed iPhone Simulator. The verified environment used **Xcode 26.6**. The minimum deployment target is iOS 17; this is not a claim that iOS 17 was tested. No third-party Swift dependency or backend credential is needed.

From the project folder:

```sh
bash scripts/ci_macos.sh unit
bash scripts/ci_macos.sh all
```

The second command runs Core/UI tests and an unsigned Release archive. Genuine logs, xcresult and screenshot attachments are stored in `build/ci`. The unsigned archive is not an installable IPA. The authorized Apple account owner must select their Team and a registered Bundle ID, test on an iPhone, then create a signed archive for App Store Connect. Never put signing credentials in Git.

## Local functions

Editable profile/onboarding; four native tabs; validated request drafts with search, edit, delete, export and unsaved-change confirmation; local document import, preview, sharing and removal; sample benefits and marketplace catalogs with saved items; readable resources; local discussion drafts/replies and activity notices. The pass QR contains a demo identifier only.

There is **no online login, server synchronization, verified membership, provider request submission, appointment booking, live community, payment or push service**. The app labels local/sample states. Use non-sensitive sample files and keep originals elsewhere. Deleting the app can remove local data.

## Changes in this revision

Request forms now warn before discarding unsaved changes. Discarding an edit preserves the previous saved draft. Successful profile/request saves dismiss the keyboard. Document previews use the native Quick Look renderer inside a SwiftUI sheet with an explicit close action and local sharing. The UI test driver waits until the entire injected text is visible before saving. Additional file-store regression checks reject unsafe symbolic-link paths, invalid import limits, oversized state files and deletion of directories or aliases in the local vault.

## GitHub Actions

The workflow is manual-only and uses standard `macos-26` runners, four test shards, a 40-minute per-job hang safeguard and one-day evidence retention. Core tests and the unsigned archive run on shard 0. A public-repository gate prevents this workflow from allocating a private-repository runner. There are no automatic push, schedule or TestFlight publication triggers, and no Apple secrets.

GitHub's standard public-repository runner compute is free under its applicable terms, but concurrency, job duration and storage are not unlimited. Larger runners must not be enabled without owner authorization. Closing a public repository cannot recall copies already downloaded or public forks. This README does not grant an open-source license.

## Source provenance

`SOURCE_PROVENANCE.json` records the tested archive hash and file hashes. The source, tests, resources, Xcode project and workflow in this delivery are byte-identical to the tested commit. The README and QA/handoff documents were updated after testing; the original baseline manifest and older validation logs remain historical evidence, not proof of this revision.

Official references checked October 2, 2026:
- https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- https://docs.github.com/en/actions/reference/limits
- https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/
