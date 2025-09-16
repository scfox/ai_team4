#!/usr/bin/env bash
# Test error handling scenarios

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ACT_DIR="$( cd "${SCRIPT_DIR}/.." && pwd )"

source "${ACT_DIR}/lib/validate.sh"

echo "=== Error Handling Test Scenarios ==="

PASSED=0
FAILED=0

# Test 1: Missing CLAUDE_CODE_OAUTH_TOKEN
test_missing_token() {
    echo ""
    echo "Test: Missing CLAUDE_CODE_OAUTH_TOKEN"

    init_mocks

    local output_file="/tmp/act-error-token.log"

    # Run without token
    if act -W .github/workflows/ai-task-router.yml \
           -e "${ACT_DIR}/events/issue-opened.json" \
           --action-offline-mode \
           --env MOCK_CLAUDE_SCENARIO="error_case" \
           > "$output_file" 2>&1; then
        echo -e "${RED}✗ Should have failed without token${NC}"
        ((FAILED++))
    else
        if grep -q "error" "$output_file"; then
            echo -e "${GREEN}✓ Correctly failed without token${NC}"
            ((PASSED++))
        else
            echo -e "${RED}✗ Failed but no error message${NC}"
            ((FAILED++))
        fi
    fi
}

# Test 2: Invalid event payload
test_invalid_payload() {
    echo ""
    echo "Test: Invalid event payload"

    # Create invalid event
    cat > /tmp/invalid-event.json << 'EOF'
{
  "issue": {
    "body": "Missing required fields"
  }
}
EOF

    local output_file="/tmp/act-error-payload.log"

    if act -W .github/workflows/ai-task-router.yml \
           -e /tmp/invalid-event.json \
           --action-offline-mode \
           --secret CLAUDE_CODE_OAUTH_TOKEN=mock_token \
           > "$output_file" 2>&1; then
        echo -e "${YELLOW}⚠ Workflow ran with invalid payload${NC}"
        ((PASSED++))
    else
        echo -e "${GREEN}✓ Workflow correctly rejected invalid payload${NC}"
        ((PASSED++))
    fi

    rm -f /tmp/invalid-event.json
}

# Test 3: API failure simulation
test_api_failure() {
    echo ""
    echo "Test: API failure handling"

    init_mocks

    local output_file="/tmp/act-error-api.log"

    export MOCK_CLAUDE_SCENARIO="error_case"

    if run_workflow ".github/workflows/ai-task-router.yml" \
                   "${ACT_DIR}/events/issue-opened.json" \
                   "$output_file" \
                   "error_case"; then
        echo -e "${RED}✗ Should have failed with error scenario${NC}"
        ((FAILED++))
    else
        if grep -q "Mock error: Simulated failure" "$output_file"; then
            echo -e "${GREEN}✓ API failure handled correctly${NC}"
            ((PASSED++))
        else
            echo -e "${RED}✗ API failure not properly reported${NC}"
            ((FAILED++))
        fi
    fi
}

# Main
main() {
    test_missing_token
    test_invalid_payload
    test_api_failure

    cleanup_mocks
    summarize_results "$PASSED" "$FAILED"
}

main "$@"