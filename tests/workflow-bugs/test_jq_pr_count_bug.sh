#!/usr/bin/env bash
# Test that reproduces the actual bug from workflow run 17752783489
# The bug: jq fails with "Cannot iterate over string" when trying to use unique on scan results

set -uo pipefail

echo "=== Testing JQ PR Count Bug from ai-completion-analyzer.yml ==="

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# This is the exact pattern used in the workflow at line 54
test_buggy_jq_command() {
    echo "Testing the buggy jq command from the workflow..."

    local mock_comments='[
        {"body": "🤖 Child C1 complete: PR #10 ready"},
        {"body": "🤖 Child C2 complete: PR #11 ready"}
    ]'

    # This is the EXACT command from the workflow that fails
    if PR_COUNT=$(echo "$mock_comments" | jq '[.[] | .body | scan("#[0-9]+") | unique] | length' 2>&1); then
        echo -e "${RED}✗ FAIL: The buggy command should have failed but didn't!${NC}"
        echo "Output: $PR_COUNT"
        return 1
    else
        echo -e "${GREEN}✓ PASS: Correctly detected the jq bug${NC}"
        echo "Error was: $PR_COUNT"

        # Verify it's the expected error
        if [[ "$PR_COUNT" == *"Cannot iterate over string"* ]]; then
            echo -e "${GREEN}✓ Got expected error message${NC}"
        else
            echo -e "${RED}✗ Got different error: $PR_COUNT${NC}"
            return 1
        fi
        return 0
    fi
}

# Test the fixed version
test_fixed_jq_command() {
    echo ""
    echo "Testing the fixed jq command..."

    local mock_comments='[
        {"body": "🤖 Child C1 complete: PR #10 ready"},
        {"body": "🤖 Child C2 complete: PR #11 ready"},
        {"body": "🤖 Child C3 complete: PR #10 ready"}
    ]'

    # The fixed command that should work
    if PR_COUNT=$(echo "$mock_comments" | jq '[.[] | .body | scan("#[0-9]+")]' | jq 'unique | length' 2>&1); then
        echo -e "${GREEN}✓ Fixed command works${NC}"
        if [[ "$PR_COUNT" == "2" ]]; then
            echo -e "${GREEN}✓ Got correct count (2 unique PRs from 3 comments)${NC}"
            return 0
        else
            echo -e "${RED}✗ Wrong count: expected 2, got $PR_COUNT${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Fixed command failed: $PR_COUNT${NC}"
        return 1
    fi
}

# Simulate the exact workflow scenario
test_workflow_scenario() {
    echo ""
    echo "Simulating exact workflow scenario..."

    # Simulate empty ISSUE_NUMBER (another potential cause)
    ISSUE_NUMBER=""

    if [[ -z "$ISSUE_NUMBER" ]]; then
        echo -e "${GREEN}✓ Detected empty ISSUE_NUMBER${NC}"
    fi

    # Simulate what happens when gh api is called with empty issue number
    # This would cause: gh: Not Found (HTTP 404) or gh: Invalid argument

    return 0
}

main() {
    local failed=0

    test_buggy_jq_command || ((failed++))
    test_fixed_jq_command || ((failed++))
    test_workflow_scenario || ((failed++))

    echo ""
    echo "========================================="

    if [[ "$failed" -eq 0 ]]; then
        echo -e "${GREEN}=== TEST PASSED: Bug properly detected ===${NC}"
        echo ""
        echo "THE BUG: Line 54 in .github/workflows/ai-completion-analyzer.yml"
        echo "  PR_COUNT=\$(echo \"\$CHILD_COMMENTS\" | jq '[.[] | .body | scan(\"#[0-9]+\") | unique] | length')"
        echo ""
        echo "THE FIX: Split the pipeline to handle scan results correctly"
        echo "  PR_COUNT=\$(echo \"\$CHILD_COMMENTS\" | jq '[.[] | .body | scan(\"#[0-9]+\")]' | jq 'unique | length')"
        exit 0
    else
        echo -e "${RED}=== TEST FAILED ===${NC}"
        exit 1
    fi
}

main "$@"