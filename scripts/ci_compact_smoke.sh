#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ "$(uname -s)" == Darwin ]] || { echo "Full Xcode on macOS required"; exit 2; }
OUT="$PWD/build/ci/compact-smoke"
mkdir -p "$OUT"
git rev-parse HEAD > "$OUT/source-commit.txt" 2>/dev/null || printf 'Source export without Git history\n' > "$OUT/source-commit.txt"
git status --porcelain > "$OUT/working-tree-status.txt" 2>/dev/null || true
xcodebuild -version > "$OUT/environment.txt"
python3 scripts/create_compact_simulator.py > "$OUT/simulator.json"
DEVICE="$(python3 -c 'import json,sys;print(json.load(open(sys.argv[1]))["udid"])' "$OUT/simulator.json")"
RESULT="$OUT/Compact.xcresult"
finish() {
  status=$?; trap - EXIT
  if [[ -d "$RESULT" ]]; then
    xcrun xcresulttool get test-results summary --path "$RESULT" > "$OUT/test-summary.json" || true
    mkdir -p "$OUT/screenshots"
    xcrun xcresulttool export attachments --path "$RESULT" --output-path "$OUT/screenshots" > "$OUT/attachment-export.log" 2>&1 || true
  fi
  if [[ "${GITHUB_ACTIONS:-false}" == true ]]; then xcrun simctl shutdown "$DEVICE" >/dev/null 2>&1 || true; xcrun simctl delete "$DEVICE" >/dev/null 2>&1 || true; fi
  printf '%s\n' "$status" > "$OUT/exit-code.txt"
  exit "$status"
}
trap finish EXIT
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
# Actual compact iPhone instance. Each test starts with isolated sample data.
xcodebuild test -project JFTA.xcodeproj -scheme JFTA -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE" -destination-timeout 90 \
  -derivedDataPath "$PWD/build/CompactDerivedData" -resultBundlePath "$RESULT" \
  -parallel-testing-enabled NO -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 300 -maximum-test-execution-time-allowance 360 \
  -only-testing:JFTAUITests/JFTAUITests/testHomeWorkspaceCardsOpenRealDestinations -only-testing:JFTAUITests/JFTAUITests/testLargeTextServicesAndPassRemainReachable -only-testing:JFTAUITests/JFTAUITests/testDraftAttachmentsToggleAndDeleteWithoutOpeningPreview \
  CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES ONLY_ACTIVE_ARCH=YES 2>&1 | tee "$OUT/xcodebuild.log"
