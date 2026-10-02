#!/bin/bash
# Real Apple-SDK build + XCTest. Run only on a Mac. No signing or upload to Apple.
set -euo pipefail
cd "$(dirname "$0")/.."
MODE="${1:-all}"
if [[ "$MODE" != all && "$MODE" != unit ]]; then
  echo 'Usage: bash scripts/ci_macos.sh [all|unit]' >&2; exit 2
fi
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'This step requires macOS, full Xcode and an installed iPhone Simulator.' >&2; exit 2
fi
OUT="$PWD/build/ci"
mkdir -p "$OUT"
# A fresh directory preserves the previous run for local developers.
RUN_OUT="$OUT/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$RUN_OUT"
printf '%s\n' "$RUN_OUT" > "$OUT/latest-path.txt"
{
  date -u
  sw_vers
  uname -m
  xcode-select -p
  xcodebuild -version
  xcrun swift --version
  xcrun simctl list runtimes
} | tee "$RUN_OUT/environment.txt"
python3 scripts/validate_project.py | tee "$RUN_OUT/project-checks.txt"
xcodebuild -list -project JFTA.xcodeproj | tee "$RUN_OUT/xcode-project.txt"
python3 scripts/select_simulator.py --json > "$RUN_OUT/simulator.json"
DEVICE="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["udid"])' "$RUN_OUT/simulator.json")"
RESULT="$RUN_OUT/JFTA.xcresult"
cleanup() {
  status=$?
  trap - EXIT
  # Export actual screenshots, never substitute design-reference images.
  if [[ -d "$RESULT" ]]; then
    mkdir -p "$RUN_OUT/screenshots"
    if ! xcrun xcresulttool export attachments --path "$RESULT" --output-path "$RUN_OUT/screenshots" > "$RUN_OUT/attachment-export.log" 2>&1; then
      echo 'Attachment export failed; retain the xcresult to inspect in Xcode.' >> "$RUN_OUT/attachment-export.log"
    fi
  fi
  # Shut down only the chosen CI simulator. Do not stop unrelated local devices.
  if [[ "${GITHUB_ACTIONS:-false}" == true ]]; then
    xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true
  fi
  printf '%s\n' "$status" > "$RUN_OUT/exit-code.txt"
  exit "$status"
}
trap cleanup EXIT
# simctl returns an error for an already-booted device; bootstatus still validates it.
xcrun simctl boot "$DEVICE" 2> "$RUN_OUT/boot.log" || true
xcrun simctl bootstatus "$DEVICE" -b >> "$RUN_OUT/boot.log" 2>&1
ARGS=(test -project JFTA.xcodeproj -scheme JFTA -configuration Debug
  -destination "platform=iOS Simulator,id=$DEVICE" -destination-timeout 90
  -derivedDataPath "$PWD/build/DerivedData" -resultBundlePath "$RESULT"
  -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1
  -test-timeouts-enabled YES -default-test-execution-time-allowance 90
  -maximum-test-execution-time-allowance 150 CODE_SIGNING_ALLOWED=NO)
if [[ "$MODE" == unit ]]; then ARGS+=(-only-testing:JFTAUnitTests); fi
xcodebuild "${ARGS[@]}" 2>&1 | tee "$RUN_OUT/xcodebuild.log"
# A successful build is still not a signed IPA and not a real-device acceptance test.
