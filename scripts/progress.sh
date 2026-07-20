#!/usr/bin/env bash
# Durable, dependency-light progress state and renderer for Supergoal runs.

set -u

usage() {
  cat >&2 <<'EOF'
usage:
  progress.sh init <run-root>
  progress.sh validate <run-root>
  progress.sh workstep-start <run-root> <workstep-id>
  progress.sh milestone-done <run-root> <milestone-id> <evidence-ref>
  progress.sh workstep-done <run-root> <workstep-id>
  progress.sh mode <run-root> <planning|active|recovering|waiting|auditing|blocked|complete>
  progress.sh replan <run-root> [replacement-progress.tsv] [reason]
  progress.sh snapshot <run-root> [--force] [--event <name>]
EOF
  exit 2
}

fail() {
  printf 'progress.sh: %s\n' "$*" >&2
  exit 2
}

now_epoch() {
  if [[ -n "${SUPERGOAL_PROGRESS_NOW:-}" ]]; then
    [[ "$SUPERGOAL_PROGRESS_NOW" =~ ^[0-9]+$ ]] || fail 'SUPERGOAL_PROGRESS_NOW must be a non-negative epoch'
    printf '%s\n' "$SUPERGOAL_PROGRESS_NOW"
  else
    date +%s
  fi
}

normalize_field() {
  printf '%s' "$1" | tr '\t\r\n' '   ' | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177'
}

validate_file() {
  local file="$1"
  [[ -f "$file" ]] || { printf 'progress state missing: %s\n' "$file" >&2; return 1; }

  awk -F '\t' '
    function bad(message) { print "progress state invalid: " message > "/dev/stderr"; errors++ }
    function uint(value) { return value ~ /^[0-9]+$/ }
    function positive(value) { return uint(value) && value > 0 }
    BEGIN {
      required["schema_version"] = 1
      required["run_started_epoch"] = 1
      required["last_report_epoch"] = 1
      required["last_signature"] = 1
      required["plan_revision"] = 1
      required["previous_total_worksteps"] = 1
      required["mode"] = 1
      required["mode_started_epoch"] = 1
      required["paused_seconds"] = 1
      required["stable_completions"] = 1
      required["last_replan_reason"] = 1
    }
    $1 == "meta" {
      if (NF != 3) bad("meta row " NR " must have 3 columns")
      if (++meta_seen[$2] > 1) bad("duplicate meta key " $2)
      meta[$2] = $3
      next
    }
    $1 == "workstep" {
      if (NF != 11) bad("workstep row " NR " must have 11 columns")
      if ($2 == "" || ++workstep_seen[$2] > 1) bad("duplicate or empty workstep id " $2)
      if ($3 !~ /^(pending|active|done)$/) bad("invalid workstep status " $3)
      if (!positive($4)) bad("workstep " $2 " effort must be positive")
      if (!uint($5) || !uint($6) || $5 > $6) bad("workstep " $2 " invalid planned range")
      if (!uint($7) || !uint($8) || !uint($9) || !uint($10)) bad("workstep " $2 " invalid timestamps")
      effort[$2] = $4 + 0
      workstep_status[$2] = $3
      worksteps++
      next
    }
    $1 == "milestone" {
      if (NF != 6) bad("milestone row " NR " must have 6 columns")
      if ($2 == "" || ++milestone_seen[$2] > 1) bad("duplicate or empty milestone id " $2)
      if (!positive($4)) bad("milestone " $2 " points must be positive")
      if ($5 !~ /^(pending|done)$/) bad("invalid milestone status " $5)
      milestone_parent[$2] = $3
      milestone_points[$3] += $4
      milestone_count[$3]++
      if ($5 != "done") milestone_pending[$3]++
      next
    }
    NF > 0 { bad("unknown row type " $1 " at line " NR) }
    END {
      for (key in required) if (!(key in meta_seen)) bad("missing meta key " key)
      if (meta["schema_version"] != "1") bad("unsupported schema_version " meta["schema_version"])
      if (!uint(meta["run_started_epoch"]) || !uint(meta["last_report_epoch"]) || !positive(meta["plan_revision"]) || !uint(meta["previous_total_worksteps"]) || !uint(meta["mode_started_epoch"]) || !uint(meta["paused_seconds"]) || !uint(meta["stable_completions"])) bad("invalid numeric metadata")
      if (meta["mode"] !~ /^(planning|active|recovering|waiting|auditing|blocked|complete)$/) bad("invalid mode " meta["mode"])
      if (worksteps < 1) bad("at least one workstep is required")
      for (milestone in milestone_parent) if (!(milestone_parent[milestone] in workstep_seen)) bad("milestone " milestone " references missing workstep " milestone_parent[milestone])
      for (workstep in workstep_seen) {
        if (milestone_count[workstep] < 1) bad("workstep " workstep " has no milestones")
        if (milestone_points[workstep] != effort[workstep]) bad("workstep " workstep " milestone points " milestone_points[workstep] " do not equal effort " effort[workstep])
        if (workstep_status[workstep] == "done" && milestone_pending[workstep] > 0) bad("done workstep " workstep " has pending milestones")
        if (meta["mode"] == "complete" && workstep_status[workstep] != "done") bad("complete mode has unfinished workstep " workstep)
      }
      exit(errors ? 1 : 0)
    }
  ' "$file"
}

meta_value() {
  local file="$1"
  local key="$2"
  awk -F '\t' -v key="$key" '$1 == "meta" && $2 == key { print $3; exit }' "$file"
}

workstep_count() {
  awk -F '\t' '$1 == "workstep" { count++ } END { print count + 0 }' "$1"
}

replace_state() {
  local candidate="$1"
  validate_file "$candidate" || { rm -f "$candidate"; return 1; }
  mv "$candidate" "$state_file"
}

new_temp() {
  mktemp "$run_root/.progress.tsv.XXXXXX" 2>/dev/null || fail "cannot create a temporary state file under $run_root"
}

ensure_history() {
  if [[ ! -f "$history_file" ]]; then
    printf 'timestamp\tevent\tpercent\tcompleted_worksteps\ttotal_worksteps\twall_seconds\tactive_seconds\teta_low_minutes\teta_high_minutes\tconfidence\tmode\tplan_revision\n' > "$history_file" || fail "cannot create $history_file"
  fi
}

effective_paused() {
  local at="$1"
  local paused mode mode_started
  paused=$(meta_value "$state_file" paused_seconds)
  mode=$(meta_value "$state_file" mode)
  mode_started=$(meta_value "$state_file" mode_started_epoch)
  if [[ "$mode" == "waiting" && "$at" -ge "$mode_started" ]]; then
    paused=$((paused + at - mode_started))
  fi
  printf '%s\n' "$paused"
}

migrate_legacy() {
  local legacy="$run_root/STATE.md"
  [[ -f "$legacy" ]] || fail "no progress.tsv or legacy STATE.md found under $run_root"
  local now count tmp
  now=$(now_epoch)
  count=$(awk -F '|' '
    function trim(value) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); return value }
    { id = trim($2); if (id ~ /^[0-9]+$/) count++ }
    END { print count + 0 }
  ' "$legacy")
  [[ "$count" -gt 0 ]] || fail 'legacy STATE.md contains no Workstep rows'
  tmp=$(new_temp)
  {
    printf 'meta\tschema_version\t1\n'
    printf 'meta\trun_started_epoch\t%s\n' "$now"
    printf 'meta\tlast_report_epoch\t0\n'
    printf 'meta\tlast_signature\t-\n'
    printf 'meta\tplan_revision\t1\n'
    printf 'meta\tprevious_total_worksteps\t%s\n' "$count"
    printf 'meta\tmode\tactive\n'
    printf 'meta\tmode_started_epoch\t%s\n' "$now"
    printf 'meta\tpaused_seconds\t0\n'
    printf 'meta\tstable_completions\t0\n'
    printf 'meta\tlast_replan_reason\tlegacy STATE.md migration\n'
    awk -F '|' '
      function trim(value) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); return value }
      {
        id = trim($2)
        if (id == "#") {
          for (column=2; column<=NF; column++) {
            heading=tolower(trim($column))
            if (heading == "workstep") name_column=column
            if (heading == "status") status_column=column
          }
          next
        }
        if (id !~ /^[0-9]+$/) next
        if (!name_column) name_column=3
        if (!status_column) status_column=5
        name = trim($name_column); gsub(/[\t\r\n]/, " ", name)
        status = tolower(trim($status_column))
        done = status ~ /^(complete|completed|done)$/
        printf "workstep\t%s\t%s\t1\t0\t0\t0\t0\t0\t0\t%s\n", id, (done ? "done" : "pending"), name
        printf "milestone\tLEGACY-%s\t%s\t1\t%s\t%s\n", id, id, (done ? "done" : "pending"), (done ? "legacy Workstep completion" : "-")
      }
    ' "$legacy"
  } > "$tmp"
  replace_state "$tmp" || fail 'legacy migration produced invalid progress state'
  ensure_history
  printf '%s\tmigration\t0\t0\t%s\t0\t0\t-1\t-1\tunavailable\tactive\t1\n' "$now" "$count" >> "$history_file"
}

command_init() {
  if [[ ! -f "$state_file" ]]; then
    migrate_legacy
  else
    validate_file "$state_file" || fail 'existing progress state failed validation'
    ensure_history
  fi
  printf 'PASS: %s initialized (schema 1, %s Worksteps)\n' "$state_file" "$(workstep_count "$state_file")"
}

command_workstep_start() {
  local id="$1" now paused tmp
  validate_file "$state_file" || fail 'cannot start Workstep with invalid progress state'
  now=$(now_epoch)
  paused=$(effective_paused "$now")
  if awk -F '\t' -v id="$id" '$1 == "workstep" && $2 != id && $3 == "active" { found=1 } END { exit(found ? 0 : 1) }' "$state_file"; then
    fail 'another Workstep is already active'
  fi
  tmp=$(new_temp)
  awk -F '\t' -v OFS='\t' -v id="$id" -v now="$now" -v paused="$paused" '
    $1 == "workstep" && $2 == id {
      found=1
      if ($3 == "done") { print "progress.sh: Workstep " id " is already done" > "/dev/stderr"; exit 3 }
      if ($3 == "pending") { $3="active"; if ($7 == 0) $7=now; $9=paused }
    }
    { print }
    END { if (!found) exit 4 }
  ' "$state_file" > "$tmp" || { rm -f "$tmp"; fail "cannot start Workstep $id"; }
  replace_state "$tmp" || fail "Workstep $id update failed validation"
}

command_milestone_done() {
  local id="$1" evidence="$2" tmp
  [[ -n "$evidence" && "$evidence" != "-" ]] || fail 'milestone evidence is required'
  validate_file "$state_file" || fail 'cannot complete milestone with invalid progress state'
  evidence=$(normalize_field "$evidence")
  tmp=$(new_temp)
  awk -F '\t' -v OFS='\t' -v id="$id" -v evidence="$evidence" '
    $1 == "milestone" && $2 == id { found=1; $5="done"; $6=evidence }
    { print }
    END { if (!found) exit 4 }
  ' "$state_file" > "$tmp" || { rm -f "$tmp"; fail "milestone not found: $id"; }
  replace_state "$tmp" || fail "milestone $id update failed validation"
}

command_workstep_done() {
  local id="$1" now paused tmp stable
  validate_file "$state_file" || fail 'cannot complete Workstep with invalid progress state'
  if awk -F '\t' -v id="$id" '$1 == "milestone" && $3 == id && $5 != "done" { pending++ } END { exit(pending ? 0 : 1) }' "$state_file"; then
    fail "Workstep $id still has pending milestones"
  fi
  now=$(now_epoch)
  paused=$(effective_paused "$now")
  stable=$(meta_value "$state_file" stable_completions)
  stable=$((stable + 1))
  tmp=$(new_temp)
  awk -F '\t' -v OFS='\t' -v id="$id" -v now="$now" -v paused="$paused" -v stable="$stable" '
    $1 == "meta" && $2 == "stable_completions" { $3=stable }
    $1 == "workstep" && $2 == id {
      found=1
      if ($3 != "active") { print "progress.sh: Workstep " id " is not active" > "/dev/stderr"; exit 3 }
      $3="done"; $8=now; $10=paused
    }
    { print }
    END { if (!found) exit 4 }
  ' "$state_file" > "$tmp" || { rm -f "$tmp"; fail "cannot complete Workstep $id"; }
  replace_state "$tmp" || fail "Workstep $id completion failed validation"
}

command_mode() {
  local new_mode="$1" now old_mode old_started paused stable tmp
  [[ "$new_mode" =~ ^(planning|active|recovering|waiting|auditing|blocked|complete)$ ]] || fail "invalid mode: $new_mode"
  validate_file "$state_file" || fail 'cannot change mode with invalid progress state'
  now=$(now_epoch)
  old_mode=$(meta_value "$state_file" mode)
  old_started=$(meta_value "$state_file" mode_started_epoch)
  paused=$(meta_value "$state_file" paused_seconds)
  stable=$(meta_value "$state_file" stable_completions)
  if [[ "$old_mode" == "waiting" && "$new_mode" != "waiting" && "$now" -ge "$old_started" ]]; then
    paused=$((paused + now - old_started))
  fi
  if [[ "$new_mode" == "recovering" && "$old_mode" != "recovering" ]]; then
    stable=0
  fi
  tmp=$(new_temp)
  awk -F '\t' -v OFS='\t' -v mode="$new_mode" -v old_mode="$old_mode" -v now="$now" -v paused="$paused" -v stable="$stable" '
    $1 == "meta" && $2 == "mode" { $3=mode }
    $1 == "meta" && $2 == "mode_started_epoch" { if (mode != old_mode) $3=now }
    $1 == "meta" && $2 == "paused_seconds" { $3=paused }
    $1 == "meta" && $2 == "stable_completions" { $3=stable }
    { print }
  ' "$state_file" > "$tmp"
  replace_state "$tmp" || fail 'mode update failed validation'
}

command_replan() {
  local replacement="${1:-}" reason="${2:-scope-preserving replan}" old_revision old_total now tmp
  validate_file "$state_file" || fail 'cannot replan with invalid current progress state'
  old_revision=$(meta_value "$state_file" plan_revision)
  old_total=$(workstep_count "$state_file")
  now=$(now_epoch)
  reason=$(normalize_field "$reason")

  if [[ -z "$replacement" ]]; then
    tmp=$(new_temp)
    awk -F '\t' -v OFS='\t' -v revision="$((old_revision + 1))" -v total="$old_total" -v reason="$reason" '
      $1 == "meta" && $2 == "plan_revision" { $3=revision }
      $1 == "meta" && $2 == "previous_total_worksteps" { $3=total }
      $1 == "meta" && $2 == "stable_completions" { $3=0 }
      $1 == "meta" && $2 == "last_replan_reason" { $3=reason }
      $1 == "meta" && $2 == "last_signature" { $3="-" }
      { print }
    ' "$state_file" > "$tmp"
    replace_state "$tmp" || fail 'replan metadata update failed validation'
    return
  fi

  [[ -f "$replacement" ]] || fail "replacement state not found: $replacement"
  validate_file "$replacement" || fail 'replacement progress state failed validation'
  tmp=$(new_temp)
  awk -F '\t' -v OFS='\t' -v revision="$((old_revision + 1))" -v old_total="$old_total" -v reason="$reason" -v now="$now" '
    NR == FNR {
      if ($1 == "meta") old_meta[$2]=$3
      if ($1 == "milestone" && $5 == "done") { old_done[$2]=1; old_evidence[$2]=$6 }
      if ($1 == "workstep") { old_status[$2]=$3; old_started[$2]=$7; old_completed[$2]=$8; old_pause_start[$2]=$9; old_pause_complete[$2]=$10 }
      next
    }
    NF == 0 { next }
    {
      line_count++
      type[line_count]=$1
      for (column=1; column<=NF; column++) field[line_count,column]=$column
      if ($1 == "workstep") { workstep_line[$2]=line_count; workstep_ids[++workstep_count]=$2 }
      if ($1 == "milestone") {
        milestone_lines[++milestone_count]=line_count
        milestone_id[line_count]=$2
        milestone_workstep[line_count]=$3
      }
    }
    END {
      for (i=1; i<=milestone_count; i++) {
        line=milestone_lines[i]; id=milestone_id[line]; ws=milestone_workstep[line]
        status=field[line,5]
        if (old_done[id]) { status="done"; field[line,5]="done"; field[line,6]=old_evidence[id] }
        milestones_total[ws]++
        if (status != "done") milestones_pending[ws]++
      }
      for (i=1; i<=line_count; i++) {
        if (type[i] == "meta") {
          key=field[i,2]
          if (key == "run_started_epoch") field[i,3]=old_meta[key]
          else if (key == "last_report_epoch") field[i,3]=old_meta[key]
          else if (key == "last_signature") field[i,3]="-"
          else if (key == "plan_revision") field[i,3]=revision
          else if (key == "previous_total_worksteps") field[i,3]=old_total
          else if (key == "mode") field[i,3]=old_meta[key]
          else if (key == "mode_started_epoch") field[i,3]=old_meta[key]
          else if (key == "paused_seconds") field[i,3]=old_meta[key]
          else if (key == "stable_completions") field[i,3]=0
          else if (key == "last_replan_reason") field[i,3]=reason
        } else if (type[i] == "workstep") {
          id=field[i,2]
          if (milestones_total[id] > 0 && milestones_pending[id] == 0) {
            field[i,3]="done"
            if (old_status[id] == "done") {
              field[i,7]=old_started[id]; field[i,8]=old_completed[id]
              field[i,9]=old_pause_start[id]; field[i,10]=old_pause_complete[id]
            } else {
              field[i,7]=0; field[i,8]=0; field[i,9]=0; field[i,10]=0
            }
          }
        }
        output=field[i,1]
        columns=(type[i] == "meta" ? 3 : (type[i] == "workstep" ? 11 : 6))
        for (column=2; column<=columns; column++) output=output OFS field[i,column]
        print output
      }
    }
  ' "$state_file" "$replacement" > "$tmp"
  replace_state "$tmp" || fail 'merged replacement plan failed validation'
}

fallback_snapshot() {
  local now wall=0 done=0 total=0 started=0
  now=$(now_epoch)
  if [[ -f "$run_root/STATE.md" ]]; then
    total=$(awk -F '|' '$2 ~ /^[[:space:]]*[0-9]+[[:space:]]*$/ { count++ } END { print count + 0 }' "$run_root/STATE.md")
    done=$(awk -F '|' 'tolower($0) ~ /\|[[:space:]]*(complete|completed|done)[[:space:]]*\|/ { count++ } END { print count + 0 }' "$run_root/STATE.md")
  fi
  if [[ -f "$state_file" ]]; then
    started=$(meta_value "$state_file" run_started_epoch 2>/dev/null || printf '0')
  fi
  [[ "$started" =~ ^[0-9]+$ ]] || started=0
  if [[ "$now" -ge "$started" && "$started" -gt 0 ]]; then wall=$((now - started)); fi
  printf '**🟨 SUPERGOAL PROGRESS**\n'
  printf '**Progress unavailable** · **%s/%s Worksteps** · ⏱ **%s** · ETA **unavailable** *(unavailable)*\n' "$done" "$total" "$(format_seconds "$wall")"
  printf 'Now: **progress state repair pending** · **recovering**\n'
}

format_seconds() {
  local seconds="$1" days hours minutes result=""
  [[ "$seconds" -ge 0 ]] || seconds=0
  days=$((seconds / 86400)); seconds=$((seconds % 86400))
  hours=$((seconds / 3600)); minutes=$(((seconds % 3600) / 60))
  if [[ "$days" -gt 0 ]]; then result="${days}d "; fi
  if [[ "$hours" -gt 0 || "$days" -gt 0 ]]; then result="${result}${hours}h "; fi
  result="${result}${minutes}m"
  printf '%s' "$result"
}

format_minutes() {
  local minutes="$1"
  if [[ "$minutes" -lt 60 ]]; then
    printf '%sm' "$minutes"
  elif [[ "$minutes" -lt 1440 ]]; then
    printf '%sh %sm' "$((minutes / 60))" "$((minutes % 60))"
  else
    printf '%sd %sh' "$((minutes / 1440))" "$(((minutes % 1440) / 60))"
  fi
}

format_eta() {
  local low="$1" high="$2" left right
  if [[ "$low" -lt 0 || "$high" -lt 0 ]]; then printf 'unavailable'; return; fi
  left=$(format_minutes "$low"); right=$(format_minutes "$high")
  if [[ "$left" == "$right" ]]; then printf '%s' "$left"; else printf '%s–%s' "$left" "$right"; fi
}

calculate_snapshot() {
  local now="$1"
  awk -F '\t' -v OFS='\t' -v now="$now" '
    $1 == "meta" { meta[$2]=$3; next }
    $1 == "workstep" {
      id=$2; order[++worksteps]=id
      status[id]=$3; effort[id]=$4+0; low[id]=$5+0; high[id]=$6+0
      started[id]=$7+0; completed[id]=$8+0; pause_start[id]=$9+0; pause_complete[id]=$10+0; name[id]=$11
      total_effort += effort[id]
      if ($3 == "done") done_worksteps++
      next
    }
    $1 == "milestone" {
      points=$4+0
      if ($5 == "done") { done_points += points; done_by_workstep[$3] += points }
      next
    }
    END {
      wall=now-(meta["run_started_epoch"]+0); if (wall < 0) wall=0
      paused=meta["paused_seconds"]+0
      if (meta["mode"] == "waiting" && now >= meta["mode_started_epoch"]) paused += now-meta["mode_started_epoch"]
      active=wall-paused; if (active < 0) active=0

      for (i=1; i<=worksteps; i++) {
        id=order[i]
        if (current_id == "" && status[id] == "active") { current_id=id; current_name=name[id] }
        if (status[id] == "done" && completed[id] > started[id] && (low[id]+high[id]) > 0) {
          duration=(completed[id]-started[id])-(pause_complete[id]-pause_start[id])
          midpoint=(low[id]+high[id])/2.0*60.0
          if (duration > 0 && midpoint > 0) ratio[++ratios]=duration/midpoint
        }
      }
      if (current_id == "") for (i=1; i<=worksteps; i++) { id=order[i]; if (status[id] == "pending") { current_id=id; current_name=name[id]; break } }
      if (current_id == "") { current_id="-"; current_name=(meta["mode"] == "complete" ? "all Worksteps complete" : "finalization") }

      pace=1.0
      if (ratios == 1) pace=(1.0+ratio[1])/2.0
      else if (ratios > 1) {
        for (i=2; i<=ratios; i++) { value=ratio[i]; j=i-1; while (j>=1 && ratio[j]>value) { ratio[j+1]=ratio[j]; j-- } ratio[j+1]=value }
        if (ratios % 2) pace=ratio[(ratios+1)/2]; else pace=(ratio[ratios/2]+ratio[ratios/2+1])/2.0
      }

      remaining_low=0; remaining_high=0
      for (i=1; i<=worksteps; i++) {
        id=order[i]
        if (status[id] != "done") {
          fraction=(effort[id]-done_by_workstep[id])/effort[id]
          if (fraction < 0) fraction=0
          remaining_low += low[id]*fraction
          remaining_high += high[id]*fraction
        }
      }
      eta_low=int(remaining_low*pace+0.5); eta_high=int(remaining_high*pace+0.5)
      percent=int(100.0*done_points/total_effort+0.5)
      confidence="low"
      if (done_worksteps == worksteps) { eta_low=0; eta_high=0; confidence="high" }
      else if (meta["mode"] ~ /^(waiting|blocked)$/ || (eta_low == 0 && eta_high == 0)) { eta_low=-1; eta_high=-1; confidence="unavailable" }
      else if (percent > 60 && ratios >= 3 && meta["stable_completions"] >= 3) confidence="high"
      else if (percent >= 20 && ratios >= 2 && meta["stable_completions"] >= 2) confidence="medium"

      if (eta_high < 0 || eta_high*60 > 28800) interval=3600
      else if (eta_high*60 > 7200) interval=1800
      else interval=900
      signature=percent ":" done_worksteps ":" worksteps ":" meta["mode"] ":" meta["plan_revision"] ":" int(eta_high/15) ":" current_id
      print percent+0, done_worksteps+0, worksteps+0, wall+0, active+0, eta_low+0, eta_high+0, confidence, meta["mode"], meta["plan_revision"], meta["previous_total_worksteps"], current_id, current_name, interval+0, signature, meta["last_replan_reason"], ratios+0
    }
  ' "$state_file"
}

command_snapshot() {
  local force=0 event="heartbeat" arg now values percent done total wall active eta_low eta_high confidence mode revision previous current_id current_name interval signature reason ratios
  while [[ $# -gt 0 ]]; do
    arg="$1"; shift
    case "$arg" in
      --force) force=1 ;;
      --event) [[ $# -gt 0 ]] || fail '--event requires a value'; event=$(normalize_field "$1"); shift ;;
      *) fail "unknown snapshot option: $arg" ;;
    esac
  done

  if ! validate_file "$state_file"; then
    fallback_snapshot
    return 0
  fi
  ensure_history
  now=$(now_epoch)
  values=$(calculate_snapshot "$now") || { fallback_snapshot; return 0; }
  IFS=$'\t' read -r percent done total wall active eta_low eta_high confidence mode revision previous current_id current_name interval signature reason ratios <<< "$values"
  local last_report last_signature
  last_report=$(meta_value "$state_file" last_report_epoch)
  last_signature=$(meta_value "$state_file" last_signature)
  if [[ "$force" -eq 0 && "$signature" == "$last_signature" && $((now - last_report)) -lt "$interval" ]]; then
    return 0
  fi

  local tmp
  tmp=$(new_temp)
  awk -F '\t' -v OFS='\t' -v now="$now" -v signature="$signature" -v total="$total" '
    $1 == "meta" && $2 == "last_report_epoch" { $3=now }
    $1 == "meta" && $2 == "last_signature" { $3=signature }
    $1 == "meta" && $2 == "previous_total_worksteps" { $3=total }
    { print }
  ' "$state_file" > "$tmp"
  if ! replace_state "$tmp"; then
    fallback_snapshot
    return 0
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$now" "$event" "$percent" "$done" "$total" "$wall" "$active" "$eta_low" "$eta_high" "$confidence" "$mode" "$revision" >> "$history_file"

  local filled empty bar="" i marker eta elapsed display_name workstep_label
  filled=$((percent / 10))
  empty=$((10 - filled))
  [[ "$filled" -gt 10 ]] && filled=10
  for ((i=0; i<filled; i++)); do bar="${bar}█"; done
  for ((i=0; i<empty; i++)); do bar="${bar}░"; done
  case "$mode" in
    complete) marker='🟩' ;;
    recovering|waiting) marker='🟨' ;;
    blocked) marker='🟥' ;;
    *) marker='🟦' ;;
  esac
  eta=$(format_eta "$eta_low" "$eta_high")
  elapsed=$(format_seconds "$wall")
  display_name=$(printf '%s' "$current_name" | cut -c1-60)
  if [[ "$current_id" =~ ^[0-9]+$ ]]; then workstep_label=$(printf 'W%02d' "$current_id"); else workstep_label="$current_id"; fi
  printf '**%s SUPERGOAL PROGRESS**\n' "$marker"
  printf '**%s %s%%** · **%s/%s Worksteps** · ⏱ **%s** · ETA **%s** *(%s)*\n' "$bar" "$percent" "$done" "$total" "$elapsed" "$eta" "$confidence"
  if [[ "$previous" != "$total" && "$revision" -gt 1 ]]; then
    printf 'Plan rev **%s**: **%s → %s Worksteps** · %s\n' "$revision" "$previous" "$total" "$reason"
  else
    printf 'Now: **%s — %s** · Plan rev **%s** · **%s**\n' "$workstep_label" "$display_name" "$revision" "$mode"
  fi
}

[[ $# -ge 2 ]] || usage
command="$1"
run_root="${2%/}"
[[ -d "$run_root" ]] || fail "run root not found: $run_root"
state_file="$run_root/progress.tsv"
history_file="$run_root/progress-history.tsv"
shift 2

case "$command" in
  init) [[ $# -eq 0 ]] || usage; command_init ;;
  validate) [[ $# -eq 0 ]] || usage; validate_file "$state_file" && printf 'PASS: %s is valid\n' "$state_file" ;;
  workstep-start) [[ $# -eq 1 ]] || usage; command_workstep_start "$1" ;;
  milestone-done) [[ $# -eq 2 ]] || usage; command_milestone_done "$1" "$2" ;;
  workstep-done) [[ $# -eq 1 ]] || usage; command_workstep_done "$1" ;;
  mode) [[ $# -eq 1 ]] || usage; command_mode "$1" ;;
  replan) [[ $# -le 2 ]] || usage; command_replan "${1:-}" "${2:-}" ;;
  snapshot) command_snapshot "$@" ;;
  *) usage ;;
esac
