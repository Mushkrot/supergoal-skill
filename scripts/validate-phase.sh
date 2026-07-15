#!/usr/bin/env bash
# Validate a rendered Workstep spec or the bundled template.

set -uo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: validate-phase.sh <phase-spec.md>" >&2
  exit 2
fi

f="$1"
if [[ ! -f "$f" ]]; then
  echo "validate-phase.sh: file not found: $f" >&2
  exit 2
fi

errors=0

require_pattern() {
  local pattern="$1"
  local label="$2"
  if ! grep -Eq "$pattern" "$f"; then
    echo "ERROR: $f: missing $label" >&2
    errors=$((errors + 1))
  fi
}

require_section() {
  local heading="$1"
  require_pattern "^##[[:space:]]+$heading([[:space:]]|$)" "section '$heading'"
}

require_pattern '^SUPERGOAL_PHASE_START$' 'SUPERGOAL_PHASE_START marker'
require_pattern '^Workstep:[[:space:]]+' 'Workstep header'
require_pattern '^Requirements:[[:space:]]+' 'Requirements header'
require_pattern '^Depends on worksteps:[[:space:]]+' 'Workstep dependency header'

require_section 'Requirements covered'
require_section 'Work'
require_section 'Acceptance criteria'
require_section 'Mandatory commands'
require_section 'Evidence required in transcript'
require_section 'Recovery boundaries'

if grep -Eq '^Depends on phases:' "$f"; then
  echo "ERROR: $f: legacy human-facing dependency label 'Depends on phases'" >&2
  errors=$((errors + 1))
fi

criteria_lines=$(grep -Ec '^[[:space:]]*-[[:space:]]+AC-([0-9]+|\{\{N\}\})\.[0-9]+[[:space:]]+\[' "$f" || true)
if [[ "$criteria_lines" -lt 1 ]]; then
  echo "ERROR: $f: no criterion IDs such as AC-2.1 with requirement mapping" >&2
  errors=$((errors + 1))
fi

unmapped_criteria=$(grep -E '^[[:space:]]*-[[:space:]]+AC-' "$f" | grep -Evc '\[(REQ-[0-9]{3}|\{\{REQ_[A-Z0-9_]+\}\})\]' || true)
if [[ "$unmapped_criteria" -gt 0 ]]; then
  echo "ERROR: $f: $unmapped_criteria acceptance criterion line(s) lack [REQ-nnn] mapping" >&2
  errors=$((errors + 1))
fi

if (( errors > 0 )); then
  echo "FAIL: $f: $errors structural error(s)" >&2
  exit 1
fi

lines=$(wc -l < "$f" | tr -d ' ')
echo "PASS: $f: structure ok ($lines lines, $criteria_lines mapped criteria)"

