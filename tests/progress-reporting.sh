#!/usr/bin/env bash
# Portable contract and behavior tests for scripts/progress.sh.

set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
SCRIPT="$ROOT/scripts/progress.sh"
FIXTURES="$ROOT/tests/fixtures"
TMP=$(mktemp -d "${TMPDIR:-/tmp}/supergoal-progress-test.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

passes=0
failures=0

pass() {
  passes=$((passes + 1))
}

fail_test() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

assert_contains() {
  local value="$1" expected="$2" label="$3"
  if [[ "$value" == *"$expected"* ]]; then pass; else fail_test "$label (missing: $expected)"; fi
}

assert_empty() {
  local value="$1" label="$2"
  if [[ -z "$value" ]]; then pass; else fail_test "$label (got: $value)"; fi
}

assert_equals() {
  local actual="$1" expected="$2" label="$3"
  if [[ "$actual" == "$expected" ]]; then pass; else fail_test "$label (expected $expected, got $actual)"; fi
}

assert_file_contains() {
  local file="$1" expected="$2" label="$3"
  if grep -Fq "$expected" "$file"; then pass; else fail_test "$label (missing in $file: $expected)"; fi
}

new_run() {
  local name="$1" fixture="$2"
  mkdir -p "$TMP/$name"
  cp "$FIXTURES/$fixture" "$TMP/$name/progress.tsv"
  printf '%s' "$TMP/$name"
}

progress_at() {
  local now="$1"; shift
  SUPERGOAL_PROGRESS_NOW="$now" bash "$SCRIPT" "$@"
}

# Baseline initialization and deterministic initial rendering.
run=$(new_run basic progress-basic.tsv)
output=$(progress_at 1000 init "$run")
assert_contains "$output" 'schema 1, 3 Worksteps' 'init validates the basic schema'
output=$(progress_at 1000 snapshot "$run" --force --event baseline)
assert_contains "$output" '0%' 'initial percentage is zero'
assert_contains "$output" '0/3 Worksteps' 'initial Workstep count is visible'
assert_contains "$output" 'ETA **40m–1h 30m** *(low)*' 'initial ETA uses the planned range'
assert_equals "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" '3' 'normal snapshot has three lines'
assert_file_contains "$run/progress-latest.md" 'SUPERGOAL PROGRESS' 'emitted snapshot is durably available for visible-message publication'
assert_equals "$(wc -l < "$run/progress-latest.md" | tr -d ' ')" '3' 'latest report remains exactly three lines'
output=$(progress_at 1001 snapshot "$run")
assert_empty "$output" 'unchanged snapshot is suppressed before cadence'
output=$(progress_at 1001 report "$run")
assert_contains "$output" 'SUPERGOAL PROGRESS' 'report re-emits the latest state after compaction'
assert_equals "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" '3' 'report re-emission remains exactly three lines'

# Evidence points change the signature before a Workstep is complete.
progress_at 1000 workstep-start "$run" 1
progress_at 1100 milestone-done "$run" M1.1 'AC-1.1 passed'
output=$(progress_at 1100 snapshot "$run")
assert_contains "$output" '10%' 'partial evidence contributes weighted progress'
assert_contains "$output" '0/3 Worksteps' 'partial evidence does not complete a Workstep'
if progress_at 1100 workstep-done "$run" 1 >/dev/null 2>&1; then fail_test 'Workstep completion rejects pending milestones'; else pass; fi

progress_at 1200 milestone-done "$run" M1.2 'AC-1.2 passed'
progress_at 1600 workstep-done "$run" 1
output=$(progress_at 1600 snapshot "$run" --force --event workstep-done)
assert_contains "$output" '20%' 'weighted percentage uses effort rather than naive count'
assert_contains "$output" '1/3 Worksteps' 'completed count advances separately'
assert_contains "$output" 'ETA **25m–58m**' 'a fast completed Workstep recalibrates the ETA range'
if [[ "$output" != *'33%'* ]]; then pass; else fail_test 'weighted percentage must differ from naive 1/3'; fi

# Waiting time is excluded from active pace, while ETA is unavailable during waiting.
progress_at 1600 workstep-start "$run" 2
progress_at 1700 mode "$run" waiting
progress_at 1750 mode "$run" waiting
output=$(progress_at 1800 snapshot "$run" --force --event waiting)
assert_contains "$output" 'ETA **unavailable** *(unavailable)*' 'waiting makes ETA unavailable'
progress_at 2300 mode "$run" active
paused=$(awk -F '\t' '$1=="meta" && $2=="paused_seconds" {print $3}' "$run/progress.tsv")
assert_equals "$paused" '600' 'repeated waiting mode does not lose paused time'
progress_at 2400 milestone-done "$run" M2.1 'integration half verified'
progress_at 2500 milestone-done "$run" M2.2 'integration complete'
progress_at 2900 workstep-done "$run" 2
output=$(progress_at 2900 snapshot "$run" --force --event workstep-done)
assert_contains "$output" '70%' 'different Workstep weights accumulate correctly'
assert_contains "$output" '2/3 Worksteps' 'second Workstep completes'
assert_contains "$output" '(medium)' 'two stable observed completions raise confidence to medium'
assert_contains "$output" 'ETA **5m–16m**' 'waiting-excluded observed pace calibrates remaining ETA'

# Recovery resets calibration stability, then a later completion rebuilds it.
progress_at 3000 mode "$run" recovering
stable=$(awk -F '\t' '$1=="meta" && $2=="stable_completions" {print $3}' "$run/progress.tsv")
assert_equals "$stable" '0' 'recovery resets stable completions'
progress_at 3100 mode "$run" active

# Recovery remains active work and therefore expands observed ETA when it is slow.
recovery_run=$(new_run recovery-pace progress-basic.tsv)
progress_at 1000 init "$recovery_run" >/dev/null
progress_at 1000 workstep-start "$recovery_run" 1
progress_at 1100 mode "$recovery_run" recovering
progress_at 2800 mode "$recovery_run" active
progress_at 2900 milestone-done "$recovery_run" M1.1 'recovery proof one'
progress_at 2950 milestone-done "$recovery_run" M1.2 'recovery proof two'
progress_at 3000 workstep-done "$recovery_run" 1
output=$(progress_at 3000 snapshot "$recovery_run" --force --event recovery-complete)
assert_contains "$output" 'ETA **48m–1h 53m**' 'recovery overhead is included in active pace calibration'

# Adaptive heartbeat uses 15, 30, and 60 minute intervals.
cadence_short=$(new_run cadence-short progress-basic.tsv)
progress_at 1000 init "$cadence_short" >/dev/null
progress_at 1000 snapshot "$cadence_short" --force --event baseline >/dev/null
assert_empty "$(progress_at 1899 snapshot "$cadence_short")" 'short ETA suppresses before 15 minutes'
assert_contains "$(progress_at 1900 snapshot "$cadence_short")" 'SUPERGOAL PROGRESS' 'short ETA emits at 15 minutes'

cadence_medium=$(new_run cadence-medium progress-basic.tsv)
tmp_state="$cadence_medium/progress.next.tsv"
awk -F '\t' -v OFS='\t' '$1=="workstep" {$5=$5*4; $6=$6*4} {print}' "$cadence_medium/progress.tsv" > "$tmp_state"
mv "$tmp_state" "$cadence_medium/progress.tsv"
progress_at 1000 init "$cadence_medium" >/dev/null
progress_at 1000 snapshot "$cadence_medium" --force --event baseline >/dev/null
assert_empty "$(progress_at 2799 snapshot "$cadence_medium")" 'medium ETA suppresses before 30 minutes'
assert_contains "$(progress_at 2800 snapshot "$cadence_medium")" 'SUPERGOAL PROGRESS' 'medium ETA emits at 30 minutes'

cadence_long=$(new_run cadence-long progress-basic.tsv)
tmp_state="$cadence_long/progress.next.tsv"
awk -F '\t' -v OFS='\t' '$1=="workstep" {$5=$5*10; $6=$6*10} {print}' "$cadence_long/progress.tsv" > "$tmp_state"
mv "$tmp_state" "$cadence_long/progress.tsv"
progress_at 1000 init "$cadence_long" >/dev/null
progress_at 1000 snapshot "$cadence_long" --force --event baseline >/dev/null
assert_empty "$(progress_at 4599 snapshot "$cadence_long")" 'long ETA suppresses before 60 minutes'
assert_contains "$(progress_at 4600 snapshot "$cadence_long")" 'SUPERGOAL PROGRESS' 'long ETA emits at 60 minutes'

# Replan carries evidence by milestone ID and exposes the changed denominator.
replan_run=$(new_run replan progress-basic.tsv)
progress_at 1000 init "$replan_run" >/dev/null
progress_at 1000 workstep-start "$replan_run" 1
progress_at 1100 milestone-done "$replan_run" M1.1 'first proof'
progress_at 1200 milestone-done "$replan_run" M1.2 'second proof'
progress_at 1600 workstep-done "$replan_run" 1
progress_at 1700 replan "$replan_run" "$FIXTURES/progress-replan.tsv" 'split compatibility work'
output=$(progress_at 1700 snapshot "$replan_run" --force --event replan)
assert_contains "$output" '17%' 'replan preserves evidence against the new denominator'
assert_contains "$output" '1/4 Worksteps' 'replan updates Workstep count'
assert_contains "$output" '3 → 4 Worksteps' 'replan makes the denominator change explicit'
assert_contains "$output" 'split compatibility work' 'replan reason is visible'
revision=$(awk -F '\t' '$1=="meta" && $2=="plan_revision" {print $3}' "$replan_run/progress.tsv")
assert_equals "$revision" '2' 'replan increments plan revision'

# Repeated replans remain valid for long-run simulations.
progress_at 1800 replan "$replan_run" '' 'resequence remaining work'
progress_at 1900 replan "$replan_run" '' 'second recovery replan'
progress_at 1900 validate "$replan_run" >/dev/null
revision=$(awk -F '\t' '$1=="meta" && $2=="plan_revision" {print $3}' "$replan_run/progress.tsv")
assert_equals "$revision" '4' 'multiple replans remain durable'

# Legacy migration gives full points only to completed Worksteps and no ETA guess.
legacy_run="$TMP/legacy"
mkdir -p "$legacy_run"
cp "$FIXTURES/legacy-state.md" "$legacy_run/STATE.md"
output=$(progress_at 5000 init "$legacy_run")
assert_contains "$output" '3 Worksteps' 'legacy STATE migration finds all Worksteps'
output=$(progress_at 5000 snapshot "$legacy_run" --force --event migration)
assert_contains "$output" '33%' 'legacy migration scores only completed Worksteps'
assert_contains "$output" '1/3 Worksteps' 'legacy migration preserves the completed count'
assert_contains "$output" 'ETA **unavailable**' 'legacy migration does not invent duration estimates'

weighted_legacy_run="$TMP/weighted-legacy"
mkdir -p "$weighted_legacy_run"
cp "$FIXTURES/weighted-state-without-progress.md" "$weighted_legacy_run/STATE.md"
progress_at 5000 init "$weighted_legacy_run" >/dev/null
output=$(progress_at 5000 snapshot "$weighted_legacy_run" --force --event migration)
assert_contains "$output" '50%' 'migration discovers Status after the new Effort column'
assert_contains "$output" '1/2 Worksteps' 'new weighted STATE table remains recoverable without progress.tsv'

# Corrupt state produces a nonblocking three-line fallback.
corrupt_run=$(new_run corrupt progress-corrupt.tsv)
if output=$(progress_at 2000 snapshot "$corrupt_run" --force 2>/dev/null); then pass; else fail_test 'corrupt snapshot must not block the caller'; fi
assert_contains "$output" 'Progress unavailable' 'corrupt state prints fallback'
assert_contains "$output" 'ETA **unavailable**' 'fallback is honest about ETA'
assert_equals "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" '3' 'fallback has three lines'

# Clock skew clamps elapsed time at zero.
clock_run=$(new_run clock progress-basic.tsv)
progress_at 900 init "$clock_run" >/dev/null
output=$(progress_at 900 snapshot "$clock_run" --force --event clock-skew)
assert_contains "$output" '⏱ **0m**' 'clock skew does not produce negative elapsed time'

# Rendering remains compact, safe for long names, and understandable without color.
long_run=$(new_run long-name progress-basic.tsv)
long_name='Integration hardening with an intentionally extremely long operator-facing Workstep name that must be truncated safely'
tmp_state="$long_run/progress.next.tsv"
awk -F '\t' -v OFS='\t' -v name="$long_name" '$1=="workstep" && $2=="1" {$11=name} {print}' "$long_run/progress.tsv" > "$tmp_state"
mv "$tmp_state" "$long_run/progress.tsv"
progress_at 1000 init "$long_run" >/dev/null
progress_at 1000 workstep-start "$long_run" 1
progress_at 1010 workstep-start "$long_run" 1
started=$(awk -F '\t' '$1=="workstep" && $2=="1" {print $7}' "$long_run/progress.tsv")
assert_equals "$started" '1000' 'repeated Workstep start is idempotent'
output=$(progress_at 1000 snapshot "$long_run" --force --event long-name)
assert_equals "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" '3' 'long-name snapshot remains three lines'
if [[ "$output" != *'truncated safely'* ]]; then pass; else fail_test 'displayed Workstep name is truncated'; fi
if [[ "$output" != *$'\033'* && "$output" != *'<span'* ]]; then pass; else fail_test 'renderer must not use ANSI or HTML color'; fi
progress_at 1010 mode "$long_run" recovering
output=$(progress_at 1010 snapshot "$long_run" --force --event recovery-start)
assert_contains "$output" '🟨 SUPERGOAL PROGRESS' 'recovering mode has a visible semantic marker'
assert_contains "$output" '**recovering**' 'recovering mode is readable without color'

# History is append-only and records emitted, not suppressed, snapshots.
history_rows=$(awk 'END {print NR}' "$run/progress-history.tsv")
if [[ "$history_rows" -ge 5 ]]; then pass; else fail_test 'history records emitted snapshots'; fi

# Lifecycle integration remains explicit and preserves legacy anchors.
assert_file_contains "$ROOT/SKILL.md" 'references/progress-reporting.md' 'skill links the detailed progress contract'
assert_file_contains "$ROOT/SKILL.md" 'goal-dispatched' 'skill forces the dispatch snapshot'
assert_file_contains "$ROOT/SKILL.md" 'SUPERGOAL_PHASE_*' 'skill preserves compatibility anchors'
assert_file_contains "$ROOT/templates/PROTOCOL.md" 'recovery-start' 'protocol integrates recovery progress'
assert_file_contains "$ROOT/templates/PROTOCOL.md" 'audit-complete' 'protocol integrates audit progress'
assert_file_contains "$ROOT/references/goal-format.md" 'SUPERGOAL_PROGRESS' 'transcript format documents progress blocks'
assert_file_contains "$ROOT/scripts/audit-run-state.sh" 'progress_validation=' 'stale Goal audit inspects progress evidence'
assert_file_contains "$ROOT/README.md" 'Supergoal does not patch or extend' 'README states the native UI boundary'
assert_file_contains "$ROOT/README.md" 'fortune cookie' 'README keeps the fork voice light'

# Schema validation rejects contradictory completion evidence.
invalid_run=$(new_run invalid-complete progress-basic.tsv)
tmp_state="$invalid_run/progress.next.tsv"
awk -F '\t' -v OFS='\t' '$1=="workstep" && $2=="1" {$3="done"} {print}' "$invalid_run/progress.tsv" > "$tmp_state"
mv "$tmp_state" "$invalid_run/progress.tsv"
if progress_at 1000 validate "$invalid_run" >/dev/null 2>&1; then fail_test 'done Workstep with pending milestones must be invalid'; else pass; fi

# Reconciliation ignores handoff marker definitions in pinned protocol files.
audit_run="$TMP/audit"
mkdir -p "$audit_run"
cp "$FIXTURES/legacy-state.md" "$audit_run/STATE.md"
cp "$ROOT/templates/PROTOCOL.md" "$audit_run/PROTOCOL.md"
cp "$ROOT/references/goal-format.md" "$audit_run/GOAL_FORMAT.md"
output=$(bash "$ROOT/scripts/audit-run-state.sh" "$audit_run")
assert_contains "$output" 'handoff_markers=0' 'audit ignores marker definitions in protocol templates'
printf '\nFAILURE_HANDOFF\n' >> "$audit_run/STATE.md"
output=$(bash "$ROOT/scripts/audit-run-state.sh" "$audit_run")
assert_contains "$output" 'handoff_markers=1' 'audit counts a real handoff recorded in STATE'

if [[ "$failures" -gt 0 ]]; then
  printf 'FAIL: %s assertions passed, %s failed\n' "$passes" "$failures" >&2
  exit 1
fi

printf 'PASS: %s progress-reporting assertions\n' "$passes"
