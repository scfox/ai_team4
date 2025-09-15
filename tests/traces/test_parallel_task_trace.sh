#!/usr/bin/env bash
# T007: Parallel-task trace test
# Expected: 6 workflows, 2 children, 3 PRs

set -euo pipefail

echo "=== Parallel Task Trace Test ==="
echo "Testing @gitaiteams mention with parallel tasks"

# Test configuration
ISSUE_NUMBER=${1:-43}
EXPECTED_WORKFLOWS=6
EXPECTED_CHILDREN=2
EXPECTED_PRS=3

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check workflow runs
check_workflows() {
    # Count all workflow runs related to this issue
    local router_count=$(gh run list --workflow=ai-task-router.yml --limit 100 \
        --json name,event --jq "[.[] | select(.event == \"issue_comment\")] | length" 2>/dev/null || echo "0")

    local orchestrator_count=$(gh run list --workflow=ai-task-orchestrator.yml --limit 100 \
        --json name,event --jq "[.[] | select(.event == \"repository_dispatch\")] | length" 2>/dev/null || echo "0")

    local child_count=$(gh run list --workflow=ai-child-executor.yml --limit 100 \
        --json name,event --jq "[.[] | select(.event == \"repository_dispatch\")] | length" 2>/dev/null || echo "0")

    local total=$((router_count + orchestrator_count + child_count))

    if [[ "$total" -eq "$EXPECTED_WORKFLOWS" ]]; then
        echo -e "${GREEN}✓${NC} Workflow count: $total (expected: $EXPECTED_WORKFLOWS)"
        echo "  Router: $router_count, Orchestrator: $orchestrator_count, Children: $child_count"
        return 0
    else
        echo -e "${RED}✗${NC} Workflow count: $total (expected: $EXPECTED_WORKFLOWS)"
        echo "  Router: $router_count, Orchestrator: $orchestrator_count, Children: $child_count"
        return 1
    fi
}

# Check child branches
check_children() {
    local count=$(git branch -r | grep -c "gitaiteams/issue-${ISSUE_NUMBER}-child-" || true)

    if [[ "$count" -eq "$EXPECTED_CHILDREN" ]]; then
        echo -e "${GREEN}✓${NC} Child branches: $count (expected: $EXPECTED_CHILDREN)"

        # List the child branches
        git branch -r | grep "gitaiteams/issue-${ISSUE_NUMBER}-child-" || true
        return 0
    else
        echo -e "${RED}✗${NC} Child branches: $count (expected: $EXPECTED_CHILDREN)"
        return 1
    fi
}

# Check PRs (2 from children to parent, 1 suggestion from parent to main)
check_prs() {
    # PRs from children to parent branch
    local child_prs=$(gh pr list --state all --base "gitaiteams/issue-${ISSUE_NUMBER}" \
        --json number --jq length 2>/dev/null || echo "0")

    # Check for parent branch existence (should have PR link, not auto-created)
    local parent_branch_exists=$(git branch -r | grep -c "gitaiteams/issue-${ISSUE_NUMBER}$" || true)

    local total=$((child_prs + parent_branch_exists))

    if [[ "$total" -eq "$EXPECTED_PRS" ]]; then
        echo -e "${GREEN}✓${NC} Pull requests: $total (expected: $EXPECTED_PRS)"
        echo "  Child PRs to parent: $child_prs"
        echo "  Parent branch exists: $parent_branch_exists"
        return 0
    else
        echo -e "${RED}✗${NC} Pull requests: $total (expected: $EXPECTED_PRS)"
        echo "  Child PRs to parent: $child_prs"
        echo "  Parent branch exists: $parent_branch_exists"
        return 1
    fi
}

# Run all checks
main() {
    local failed=0

    echo "Checking parallel-task execution trace for issue #${ISSUE_NUMBER}..."
    echo ""

    check_workflows || ((failed++))
    check_children || ((failed++))
    check_prs || ((failed++))

    echo ""
    if [[ "$failed" -eq 0 ]]; then
        echo -e "${GREEN}=== PARALLEL TASK TRACE TEST PASSED ===${NC}"
        exit 0
    else
        echo -e "${RED}=== PARALLEL TASK TRACE TEST FAILED ===${NC}"
        echo "Failed checks: $failed"
        exit 1
    fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi