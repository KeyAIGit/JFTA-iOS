#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo "Full Xcode on macOS required"; exit 2; }
OUT="$PWD/build/ci/release-smoke"
mkdir -p "$OUT"
git rev-parse HEAD > "$OUT/source-commit.txt" 2>/dev/null || printf 'Source export without Git history\n' > "$OUT/source-commit.txt"
git status --porcelain > "$OUT/working-tree-status.txt" 2>/dev/null || true
xcodebuild -version > "$OUT/environment.txt"
python3 scripts/select_simulator.py --json > "$OUT/simulator.json"
DEVICE="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["udid"])' "$OUT/simulator.json")"
RESULT="$OUT/Release.xcresult"
finish() {
  status=$?; trap - EXIT
  if [[ -d "$RESULT" ]]; then
    xcrun xcresulttool get test-results summary --path "$RESULT" > "$OUT/test-summary.json" || true
    mkdir -p "$OUT/screenshots"
    xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/screenshots" > "$OUT/attachment-export.log" 2>&1 || true
  fi
  if [[ "${GITHUB_ACTIONS:-false}" == true ]]; then xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true; fi
  printf '%s\n' "$status" > "$OUT/exit-code.txt"
  exit "$status"
}
trap finish EXIT
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
# Release disables DEBUG-only reset/profile fixtures. A fresh local store is tested by the actual onboarding UI.
xcodebuild test -project JFTA.xcodeproj -scheme JFTA -configuration Release \
  -destination "platform=iOS Simulator,id=$DEVICE" -destination-timeout 90 \
  -derivedDataPath "$PWD/build/ReleaseDerivedData" -resultBundlePath "$RESULT" \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 300 -maximum-test-execution-time-allowance 360 \
  -only-testing:JFTAUITests/JFTAUITests/testWelcomeHasRealFieldsAndValidation \
  CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES ONLY_ACTIVE_ARCH=YES 2>&1 | tee "$OUT/xcodebuild.log"
