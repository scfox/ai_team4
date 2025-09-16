#!/usr/bin/env bash
# T007: Parallel-task trace test
# Expected: 6 workflows, 2 children, 3 PRs
# This test creates its own test issue and triggers the workflow

set -euo pipefail

echo "=== Parallel Task Trace Test ==="
echo "Testing @gitaiteams mention with parallel tasks"

# Test configuration
TEST_ISSUE_TITLE="Test: Parallel Task Trace $(date +%s)"
TEST_ISSUE_BODY="@gitaiteams please perform these tasks:\n1. Task A - requires child agent\n2. Task B - requires child agent\nExpected children: 2"
EXPECTED_WORKFLOWS=6
EXPECTED_CHILDREN=2
EXPECTED_PRS=3
ISSUE_NUMBER=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Setup test by creating issue
setup_test() {
    echo "Creating test issue with parallel tasks..."
    ISSUE_NUMBER=$(gh issue create \
        --title "$TEST_ISSUE_TITLE" \
        --body "$TEST_ISSUE_BODY" \
        --label "test:trace" \
        2>/dev/null | grep -oE '[0-9]+$')

    if [[ -z "$ISSUE_NUMBER" ]]; then
        echo -e "${RED}✗${NC} Failed to create test issue"
        return 1
    fi

    echo -e "${GREEN}✓${NC} Created test issue #${ISSUE_NUMBER}"

    # Wait for workflows to trigger and complete
    echo "Waiting for workflows to complete (max 90 seconds)..."
    local waited=0
    while [[ $waited -lt 90 ]]; do
        local run_count=$(gh run list --workflow=ai-task-router.yml --limit 10 \
            --json name,event,createdAt \
            --jq "[.[] | select(.createdAt > \"$(date -u -d '2 minutes ago' '+%Y-%m-%dT%H:%M:%S')\")] | length" 2>/dev/null || echo "0")

        if [[ $run_count -gt 0 ]]; then
            echo "  Workflows triggered, waiting for completion..."
            sleep 15  # Give more time for parallel tasks
            break
        fi

        sleep 5
        ((waited+=5))
    done

    return 0
}

# Cleanup test issue and branches
cleanup_test() {
    if [[ -n "$ISSUE_NUMBER" ]]; then
        echo "Cleaning up test issue #${ISSUE_NUMBER}..."
        gh issue close "$ISSUE_NUMBER" --comment "Test completed" 2>/dev/null || true

        # Clean up test branches
        git branch -r | grep "gitaiteams/issue-${ISSUE_NUMBER}" | while read branch; do
            branch_name=${branch#origin/}
            echo "  Deleting branch $branch_name"
            git push origin --delete "$branch_name" 2>/dev/null || true
        done

        echo -e "${GREEN}✓${NC} Cleanup complete"
    fi
}

# Check workflow runs
check_workflows() {
    # Count workflow runs created in the last few minutes for our test
    local router_count=$(gh run list --workflow=ai-task-router.yml --limit 20 \
        --json name,displayTitle,createdAt \
        --jq "[.[] | select(.createdAt > \"$(date -u -d '3 minutes ago' '+%Y-%m-%dT%H:%M:%S')\")] | length" 2>/dev/null || echo "0")

    local orchestrator_count=$(gh run list --workflow=ai-task-orchestrator.yml --limit 20 \
        --json name,event,createdAt \
        --jq "[.[] | select(.event == \"repository_dispatch\" and .createdAt > \"$(date -u -d '3 minutes ago' '+%Y-%m-%dT%H:%M:%S')\")] | length" 2>/dev/null || echo "0")

    local child_count=$(gh run list --workflow=ai-child-executor.yml --limit 20 \
        --json name,event,createdAt \
        --jq "[.[] | select(.event == \"repository_dispatch\" and .createdAt > \"$(date -u -d '3 minutes ago' '+%Y-%m-%dT%H:%M:%S')\")] | length" 2>/dev/null || echo "0")

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

    # Set up the test
    if ! setup_test; then
        echo -e "${RED}=== TEST SETUP FAILED ===${NC}"
        exit 1
    fi

    # Ensure cleanup happens on exit
    trap cleanup_test EXIT

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