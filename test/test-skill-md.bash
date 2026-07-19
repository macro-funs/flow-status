#!/usr/bin/env bash
# Lint: SKILL.md has valid frontmatter (name=flow-status, description) and lists all 23 tools.
# Run: bash test/test-skill-md.bash
set -euo pipefail
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../skills/flow-status" && pwd)"
SKILL_MD="$SKILL_DIR/SKILL.md"
PASS=0; FAIL=0
assert() { if eval "$1"; then printf '  ok %s\n' "$2"; PASS=$((PASS+1)); else printf '  FAIL %s\n' "$2" >&2; FAIL=$((FAIL+1)); fi; }

assert '[[ -f "$SKILL_MD" ]]' "SKILL.md exists"
assert 'grep -q "^name: flow-status$" "$SKILL_MD"' "frontmatter name=flow-status"
assert 'grep -q "^description:" "$SKILL_MD"' "frontmatter has description"

TOOLS="list_tasks get_task list_subtasks list_task_tags create_task update_task delete_task update_task_status bind_task_tag unbind_task_tag batch_complete_tasks batch_delete_tasks batch_migrate_tasks create_list update_list delete_list get_list list_lists create_tag update_tag delete_tag get_tag list_tags"
for t in $TOOLS; do
  assert "grep -qw '$t' \"\$SKILL_MD\"" "SKILL.md mentions $t"
done

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
