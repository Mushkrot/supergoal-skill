#!/usr/bin/env bash
# Regression contract for publishing progress outside collapsed tool output.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/scripts/progress.sh"
FIXTURE="$ROOT/tests/fixtures/progress-basic.tsv"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/supergoal-progress-transcript.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

passes=0
failures=0

pass() { passes=$((passes + 1)); }
fail_test() { printf 'FAIL: %s\n' "$1" >&2; failures=$((failures + 1)); }

assert_equals() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then pass; else fail_test "$label (expected $expected, got $actual)"; fi
}

assert_contains() {
  local value="$1" expected="$2" label="$3"
  if [[ "$value" == *"$expected"* ]]; then pass; else fail_test "$label (missing: $expected)"; fi
}

assert_file_contains() {
  local file="$1" expected="$2" label="$3"
  if grep -Fq "$expected" "$file"; then pass; else fail_test "$label (missing in $file: $expected)"; fi
}

progress_at() {
  local now="$1"; shift
  SUPERGOAL_PROGRESS_NOW="$now" bash "$SCRIPT" "$@"
}

run="$TMP/run"
mkdir -p "$run"
cp "$FIXTURE" "$run/progress.tsv"
progress_at 1000 init "$run" >/dev/null

first=$(progress_at 1000 snapshot "$run" --force --event goal-dispatched)
latest_before=$(<"$run/progress-latest.md")
assert_equals "$first" "$latest_before" 'snapshot stdout and durable latest report match'
assert_equals "$(printf '%s\n' "$latest_before" | wc -l | tr -d ' ')" '3' 'durable report has three lines'

suppressed=$(progress_at 1001 snapshot "$run")
assert_equals "$suppressed" '' 'ordinary duplicate remains cadence-suppressed'
assert_equals "$(<"$run/progress-latest.md")" "$latest_before" 'suppression does not erase the latest report'

reemit=$(progress_at 1001 report "$run")
assert_equals "$reemit" "$latest_before" 'report bypasses suppression and re-emits exact block'

# Simulate compaction: collapsed tool output is discarded, then the protocol
# publishes a fresh assistant message from the durable report command.
transcript="$TMP/transcript.txt"
printf 'collapsed-tool-output\n' > "$transcript"
printf 'assistant-message\n%s\n' "$reemit" > "$transcript"
transcript_content=$(<"$transcript")
assert_contains "$transcript_content" 'assistant-message' 'transcript has an explicit assistant publication boundary'
assert_contains "$transcript_content" "$reemit" 'post-compaction publication preserves the exact block'
assert_file_contains "$ROOT/templates/PROTOCOL.md" 'stdout as tool evidence' 'protocol rejects collapsed stdout as publication'
assert_file_contains "$ROOT/templates/PROTOCOL.md" 'progress.sh report <run-root>' 'protocol defines compaction re-emission'
assert_file_contains "$ROOT/references/progress-reporting.md" 'progress-latest.md' 'reference defines the durable handoff'

if [[ "$failures" -eq 0 ]]; then
  printf 'PASS: %s transcript-publication assertions\n' "$passes"
else
  printf 'FAIL: %s passed, %s failed\n' "$passes" "$failures" >&2
  exit 1
fi
