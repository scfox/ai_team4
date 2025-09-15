#!/usr/bin/env bash
# T006: Single-task trace test
# Expected: 2 workflows, 0 children, 0 PRs

set -euo pipefail

echo "=== Single Task Trace Test ==="
echo "Testing @gitaiteams mention with single task (no parallelization)"

# Test configuration
ISSUE_NUMBER=${1:-42}
EXPECTED_WORKFLOWS=2
EXPECTED_CHILDREN=0
EXPECTED_PRS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check workflow runs
check_workflows() {
    local count=$(gh run list --workflow=ai-task-orchestrator.yml --limit 100 \
        --json name,event,conclusion \
        --jq "[.[] | select(.event == \"repository_dispatch\")] | length" 2>/dev/null || echo "0")

    if [[ "$count" -eq "$EXPECTED_WORKFLOWS" ]]; then
        echo -e "${GREEN}✓${NC} Workflow count: $count (expected: $EXPECTED_WORKFLOWS)"
        return 0
    else
        echo -e "${RED}✗${NC} Workflow count: $count (expected: $EXPECTED_WORKFLOWS)"
        return 1
    fi
}

# Check child branches
check_children() {
    local count=$(git branch -r | grep -c "gitaiteams/issue-${ISSUE_NUMBER}-child-" || true)

    if [[ "$count" -eq "$EXPECTED_CHILDREN" ]]; then
        echo -e "${GREEN}✓${NC} Child branches: $count (expected: $EXPECTED_CHILDREN)"
        return 0
    else
        echo -e "${RED}✗${NC} Child branches: $count (expected: $EXPECTED_CHILDREN)"
        return 1
    fi
}

# Check PRs
check_prs() {
    local count=$(gh pr list --state all --search "base:gitaiteams/issue-${ISSUE_NUMBER}" --json number --jq length 2>/dev/null || echo "0")

    if [[ "$count" -eq "$EXPECTED_PRS" ]]; then
        echo -e "${GREEN}✓${NC} Pull requests: $count (expected: $EXPECTED_PRS)"
        return 0
    else
        echo -e "${RED}✗${NC} Pull requests: $count (expected: $EXPECTED_PRS)"
        return 1
    fi
}

# Run all checks
main() {
    local failed=0

    echo "Checking single-task execution trace for issue #${ISSUE_NUMBER}..."
    echo ""

    check_workflows || ((failed++))
    check_children || ((failed++))
    check_prs || ((failed++))

    echo ""
    if [[ "$failed" -eq 0 ]]; then
        echo -e "${GREEN}=== SINGLE TASK TRACE TEST PASSED ===${NC}"
        exit 0
    else
        echo -e "${RED}=== SINGLE TASK TRACE TEST FAILED ===${NC}"
        echo "Failed checks: $failed"
        exit 1
    fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi