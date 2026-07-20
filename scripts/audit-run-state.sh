#!/usr/bin/env bash
# Gather deterministic evidence for native Goal reconciliation.
# This script does not close or classify a Goal; the caller must verify objective-specific truth.

set -uo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: audit-run-state.sh <run-root>" >&2
  exit 2
fi

run_root="${1%/}"
if [[ ! -d "$run_root" ]]; then
  echo "audit-run-state.sh: run root not found: $run_root" >&2
  exit 2
fi

state="$run_root/STATE.md"
roadmap="$run_root/ROADMAP.md"
contract="$run_root/requirement-contract.md"
deferred="$run_root/deferred-work.md"
docs="$run_root/documentation-trace.md"
recallant="$run_root/recallant-closeout.md"
progress="$run_root/progress.tsv"
progress_helper="$run_root/progress.sh"

field_value() {
  local file="$1"
  local label="$2"
  [[ -f "$file" ]] || { printf 'missing'; return; }
  local value
  value=$(grep -Ei "^[[:space:]*-]*${label}[[:space:]*]*:" "$file" | tail -n1 | sed -E 's/^[^:]+:[[:space:]]*//; s/^[[:space:]*]+//; s/[[:space:]*]+$//' || true)
  [[ -n "$value" ]] && printf '%s' "$value" || printf 'unknown'
}

count_specs=0
count_done=0
if [[ -d "$run_root/phases" ]]; then
  count_specs=$(find "$run_root/phases" -type f -name 'phase-[0-9]*.md' | wc -l | tr -d ' ')
fi
if [[ -f "$state" ]]; then
  count_done=$(grep -Eic '\|[[:space:]]*(complete|done)[[:space:]]*\|' "$state" || true)
fi

required_deferred_open=0
if [[ -f "$deferred" ]]; then
  required_deferred_open=$(grep -Ei '\|[[:space:]]*(pending|needs-user-decision)[[:space:]]*\|' "$deferred" | wc -l | tr -d ' ')
fi

coverage=$(field_value "$contract" 'Coverage')
requirement_rows=0
if [[ -f "$contract" ]]; then
  requirement_rows=$(grep -Ec '^\|[[:space:]]*REQ-[0-9]{3}[[:space:]]*\|' "$contract" || true)
fi
acceptance_criteria=0
if [[ -d "$run_root/phases" ]]; then
  acceptance_criteria=$(grep -REh '^[[:space:]]*-[[:space:]]+AC-[0-9]+\.[0-9]+[[:space:]]+\[REQ-[0-9]{3}\]' "$run_root/phases" 2>/dev/null | wc -l | tr -d ' ')
fi
audit_status=$(field_value "$state" 'Final audit status')
documentation_status=$(field_value "$state" 'Documentation trace')
commit_status=$(field_value "$state" 'Auto-commit status')
recallant_status=$(field_value "$state" 'Recallant closeout status')
native_closeout=$(field_value "$state" 'Native Goal closeout status')
run_status=$(field_value "$state" 'Status')
lifecycle=$(field_value "$state" 'Lifecycle state')

progress_artifact='missing'
progress_validation='not-available'
progress_revision='unknown'
progress_mode='unknown'
if [[ -f "$progress" ]]; then
  progress_artifact='present'
  progress_revision=$(awk -F '\t' '$1 == "meta" && $2 == "plan_revision" { print $3; exit }' "$progress")
  progress_mode=$(awk -F '\t' '$1 == "meta" && $2 == "mode" { print $3; exit }' "$progress")
  if [[ -f "$progress_helper" ]] && bash "$progress_helper" validate "$run_root" >/dev/null 2>&1; then
    progress_validation='pass'
  else
    progress_validation='fail-or-helper-missing'
  fi
fi

handoff_count=0
for handoff_evidence in \
  "$state" \
  "$run_root/failure-handoff.md" \
  "$run_root/audit-handoff.md" \
  "$run_root/auto-commit-handoff.md" \
  "$run_root/recallant-handoff.md"; do
  if [[ -f "$handoff_evidence" ]]; then
    count=$(grep -Eic 'FAILURE_HANDOFF|AUDIT_HANDOFF|AUTO_COMMIT_HANDOFF|RECALLANT_HANDOFF' "$handoff_evidence" || true)
    handoff_count=$((handoff_count + count))
  fi
done

docs_artifact='missing'
[[ -f "$docs" ]] && docs_artifact='present'
recallant_artifact='missing'
[[ -f "$recallant" ]] && recallant_artifact='present'
roadmap_artifact='missing'
[[ -f "$roadmap" ]] && roadmap_artifact='present'
contract_artifact='missing'
[[ -f "$contract" ]] && contract_artifact='present'

hint='INDETERMINATE'
if [[ "$run_status $lifecycle" =~ COMPLETE ]] \
  && [[ "$coverage" =~ 100% ]] \
  && [[ "$requirement_rows" -gt 0 ]] \
  && [[ "$acceptance_criteria" -gt 0 ]] \
  && [[ "$audit_status" =~ (complete|pass|clean) ]] \
  && [[ "$documentation_status" =~ (complete|pass|updated|created|not-applicable) ]] \
  && [[ "$commit_status" =~ (complete|skipped) ]] \
  && [[ "$recallant_status" =~ (complete|ready|skipped) ]] \
  && [[ "$required_deferred_open" -eq 0 ]] \
  && [[ "$handoff_count" -eq 0 ]]; then
  hint='STALE_COMPLETE_CANDIDATE'
elif [[ "$roadmap_artifact" == 'present' && "$count_specs" -gt 0 ]]; then
  hint='RECOVERABLE_INCOMPLETE_CANDIDATE'
fi

printf 'run_root=%s\n' "$run_root"
printf 'state_status=%s\n' "$run_status"
printf 'lifecycle_state=%s\n' "$lifecycle"
printf 'roadmap_artifact=%s\n' "$roadmap_artifact"
printf 'requirement_contract_artifact=%s\n' "$contract_artifact"
printf 'requirement_coverage=%s\n' "$coverage"
printf 'requirement_rows=%s\n' "$requirement_rows"
printf 'mapped_acceptance_criteria=%s\n' "$acceptance_criteria"
printf 'workstep_specs=%s\n' "$count_specs"
printf 'workstep_rows_done=%s\n' "$count_done"
printf 'required_deferred_open=%s\n' "$required_deferred_open"
printf 'final_audit_status=%s\n' "$audit_status"
printf 'documentation_status=%s\n' "$documentation_status"
printf 'documentation_artifact=%s\n' "$docs_artifact"
printf 'auto_commit_status=%s\n' "$commit_status"
printf 'recallant_status=%s\n' "$recallant_status"
printf 'recallant_artifact=%s\n' "$recallant_artifact"
printf 'native_goal_closeout=%s\n' "$native_closeout"
printf 'progress_artifact=%s\n' "$progress_artifact"
printf 'progress_validation=%s\n' "$progress_validation"
printf 'progress_plan_revision=%s\n' "$progress_revision"
printf 'progress_mode=%s\n' "$progress_mode"
printf 'handoff_markers=%s\n' "$handoff_count"
printf 'classification_hint=%s\n' "$hint"
