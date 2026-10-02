# JFTA native QA checkpoint

Date: 2026-10-02. This file distinguishes actual Apple testing from source inspection.

## Completed reference run

GitHub Actions run 37073152609 tested commit `70a290dc507afcfa6cc4d3d9820296e6feae819` on the standard macos-26 runner, Xcode 26.6, iPhone Air Simulator / iOS 26.5 (23F77), arm64.

The app and both test bundles compiled. **47 Core tests passed. Nine of 16 UI tests passed; seven failed.** The structured xcresult reports 63 tests, 56 passed, seven failed, zero skipped and zero expected failures. This was not a successful acceptance run. Release archiving did not run after the test failure.

The failing UI scenarios exposed an absent keyboard toolbar on pushed destinations and a Welcome field covered by the keyboard. Four service tests queried lazy cards before scrolling created them. The Quick Look test looked for an old Done label, but the actual iOS viewer had the close-button identifier `QLOverlayDoneButtonAccessibilityIdentifier` and displayed the sample successfully.

## Corrections awaiting the next Apple run

The keyboard toolbar is applied to both root and destination screens; Welcome now has explicit focus/Next/Done navigation and scrolls the selected input into view. Service shortcuts are higher on Home. UI tests scroll before rejecting absent lazy cells and use the actual Quick Look close identifier plus stable document-delete identifiers. No test is removed or marked as an expected failure.

Full acceptance now partitions all 16 UI cases exactly once across four standard public-only Mac jobs. Core tests and unsigned Release archiving run on shard 0. The seven partition helper tests and 42 project checks are source/tool checks, not replacement iOS results. A full success requires every shard to pass and complete union coverage of all UI methods.

No Apple signing, physical iPhone test, IPA, TestFlight upload or Apple review is claimed. Online services remain disconnected. The original 0.2.0 archive and older logs are retained as historical material, not current acceptance evidence.
