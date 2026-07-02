#!/bin/sh
set -eu

apt-get update
apt-get install -y --no-install-recommends docker-cli
git config --global --add safe.directory "$GITHUB_WORKSPACE"

log_file="${RUNNER_TEMP:-/tmp}/atmos-terraform-test.log"

set +e
atmos terraform test app -s fixtures --ci -verbose >"$log_file" 2>&1
status=$?
set -e

cat "$log_file"

strip_ansi() {
  awk '{ gsub(/\033\[[0-9;]*[A-Za-z]/, ""); print }'
}

append_test_summary() {
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] || return 0
  summary_dir="$(dirname "$GITHUB_STEP_SUMMARY")"
  [ -d "$summary_dir" ] || return 0

  result_line="$(strip_ansi <"$log_file" | grep -E 'Success! [0-9]+ passed, [0-9]+ failed, [0-9]+ skipped\.|Failure! [0-9]+ passed, [0-9]+ failed, [0-9]+ skipped\.' | tail -n 1 || true)"
  diagnostics="$(strip_ansi <"$log_file" | grep -E -i -A8 -B4 '(^|[[:space:]])(Error|Failure|failed|assert|Expected)' | tail -n 200 || true)"

  {
    echo
    echo "## Terraform Emulator E2E"
    echo
    echo "| Component | Stack | Test file |"
    echo "| --- | --- | --- |"
    echo "| app | fixtures | terraform/components/ecs-task/ecs_task.tftest.hcl |"
    echo
    echo "### Runs"
    awk '
      /^[[:space:]]*run[[:space:]]+"/ {
        line = $0
        sub(/^[[:space:]]*run[[:space:]]+"/, "", line)
        sub(/".*$/, "", line)
        print "- `" line "`"
      }
    ' terraform/components/ecs-task/*.tftest.hcl 2>/dev/null || true
    echo
    echo "### Result"
    if [ -n "$result_line" ]; then
      printf "> %s\n" "$result_line"
    else
      printf "> Atmos exited with status %s before OpenTofu emitted a test result line.\n" "$status"
    fi

    if [ "$status" -ne 0 ]; then
      echo
      echo "### Failure Diagnostics"
      echo
      echo '```text'
      if [ -n "$diagnostics" ]; then
        printf "%s\n" "$diagnostics"
      else
        tail -n 160 "$log_file" | strip_ansi
      fi
      echo '```'
    fi
  } >>"$GITHUB_STEP_SUMMARY" || true
}

append_test_summary
exit "$status"
