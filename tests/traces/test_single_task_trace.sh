#!/usr/bin/env bash
# T006: Single-task trace test
# Expected: 2 workflows, 0 children, 0 PRs
# This test creates its own test issue and triggers the workflow

set -euo pipefail

echo "=== Single Task Trace Test ==="
echo "Testing @gitaiteams mention with single task (no parallelization)"

# Test configuration
TEST_ISSUE_TITLE="Test: Single Task Trace $(date +%s)"
TEST_ISSUE_BODY="@gitaiteams please analyze this single task that does not require parallelization"
EXPECTED_WORKFLOWS=2
EXPECTED_CHILDREN=0
EXPECTED_PRS=0
ISSUE_NUMBER=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check workflow runs
check_workflows() {
    # Check for workflows related to our test issue
    local router_runs=$(gh run list --workflow=ai-task-router.yml --limit 20 \
        --json name,displayTitle,createdAt \
        --jq "[.[] | select(.displayTitle | contains(\"#${ISSUE_NUMBER}\") or .createdAt > \"$(date -u -d '2 minutes ago' '+%Y-%m-%dT%H:%M:%S')\")] | length" 2>/dev/null || echo "0")

    local orchestrator_runs=$(gh run list --workflow=ai-task-orchestrator.yml --limit 20 \
        --json name,event,createdAt \
        --jq "[.[] | select(.event == \"repository_dispatch\" and .createdAt > \"$(date -u -d '2 minutes ago' '+%Y-%m-%dT%H:%M:%S')\")] | length" 2>/dev/null || echo "0")

    local count=$((router_runs + orchestrator_runs))

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

# Setup test by creating issue
setup_test() {
    echo "Creating test issue..."
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
    echo "Waiting for workflows to complete (max 60 seconds)..."
    local waited=0
    while [[ $waited -lt 60 ]]; do
        local run_count=$(gh run list --workflow=ai-task-router.yml --limit 10 \
            --json name,event,createdAt \
            --jq "[.[] | select(.createdAt > \"$(date -u -d '1 minute ago' '+%Y-%m-%dT%H:%M:%S')\")] | length" 2>/dev/null || echo "0")

        if [[ $run_count -gt 0 ]]; then
            echo "  Workflow triggered, waiting for completion..."
            sleep 10
            break
        fi

        sleep 5
        ((waited+=5))
    done

    return 0
}

# Cleanup test issue
cleanup_test() {
    if [[ -n "$ISSUE_NUMBER" ]]; then
        echo "Cleaning up test issue #${ISSUE_NUMBER}..."
        gh issue close "$ISSUE_NUMBER" --comment "Test completed" 2>/dev/null || true
        echo -e "${GREEN}✓${NC} Cleanup complete"
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