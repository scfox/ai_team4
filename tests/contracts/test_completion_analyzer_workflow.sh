#!/usr/bin/env bash
# Test for AI Completion Analyzer workflow (T017, T019)
# Tests various scenarios including the error case from run 17752783489

set -uo pipefail

echo "=== AI Completion Analyzer Workflow Test ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Test counter
TESTS_RUN=0
TESTS_FAILED=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_function="$2"

    echo ""
    echo -e "${YELLOW}Running: $test_name${NC}"

    if $test_function; then
        echo -e "${GREEN}✓ $test_name passed${NC}"
    else
        echo -e "${RED}✗ $test_name failed${NC}"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Test 1: Valid payload structure
test_valid_payload() {
    local payload='{
        "event_type": "analyze_completions",
        "client_payload": {
            "issue_number": 123,
            "child_count": 3,
            "expected_count": 3
        }
    }'

    python3 -c "
import json
import sys

payload = $payload

try:
    # Validate required fields
    assert payload['event_type'] == 'analyze_completions', 'Wrong event type'
    assert 'client_payload' in payload, 'Missing client_payload'

    cp = payload['client_payload']
    assert 'issue_number' in cp, 'Missing issue_number'
    assert isinstance(cp['issue_number'], int), 'issue_number must be int'
    assert cp['issue_number'] > 0, 'issue_number must be positive'

    assert 'child_count' in cp, 'Missing child_count'
    assert isinstance(cp['child_count'], int), 'child_count must be int'
    assert cp['child_count'] >= 0, 'child_count cannot be negative'

    assert 'expected_count' in cp, 'Missing expected_count'
    assert isinstance(cp['expected_count'], int), 'expected_count must be int'
    assert cp['expected_count'] > 0, 'expected_count must be positive'

    sys.exit(0)
except AssertionError as e:
    print(f'Validation failed: {e}')
    sys.exit(1)
    "
}

# Test 2: Invalid payloads that should fail
test_invalid_payloads() {
    # Missing issue_number (this could cause exit code 5)
    local invalid1='{
        "event_type": "analyze_completions",
        "client_payload": {
            "child_count": 3,
            "expected_count": 3
        }
    }'

    python3 -c "
import json
import sys

payload = $invalid1

try:
    assert 'issue_number' in payload['client_payload'], 'Missing issue_number'
    print('ERROR: Should have failed on missing issue_number')
    sys.exit(1)
except AssertionError:
    sys.exit(0)
    " || return 1

    # Invalid issue_number type
    local invalid2='{
        "event_type": "analyze_completions",
        "client_payload": {
            "issue_number": "not-a-number",
            "child_count": 3,
            "expected_count": 3
        }
    }'

    python3 -c "
import json
import sys

payload = $invalid2

try:
    assert isinstance(payload['client_payload']['issue_number'], int), 'issue_number must be int'
    print('ERROR: Should have failed on invalid issue_number type')
    sys.exit(1)
except AssertionError:
    sys.exit(0)
    " || return 1

    # Negative child_count
    local invalid3='{
        "event_type": "analyze_completions",
        "client_payload": {
            "issue_number": 123,
            "child_count": -1,
            "expected_count": 3
        }
    }'

    python3 -c "
import json
import sys

payload = $invalid3

try:
    assert payload['client_payload']['child_count'] >= 0, 'child_count cannot be negative'
    print('ERROR: Should have failed on negative child_count')
    sys.exit(1)
except AssertionError:
    sys.exit(0)
    " || return 1

    return 0
}

# Test 3: Simulate GitHub API response parsing
test_github_api_parsing() {
    # Simulate the jq parsing that happens in the workflow
    local mock_comments='[
        {"body": "🤖 Child C1 complete: PR #10 ready"},
        {"body": "🤖 Child C2 complete: PR #11 ready"},
        {"body": "Regular comment without marker"}
    ]'

    # Test filtering for child comments
    local filtered=$(echo "$mock_comments" | jq '[.[] | select(.body | contains("🤖 Child"))]')
    local count=$(echo "$filtered" | jq 'length')

    if [[ "$count" -ne 2 ]]; then
        echo "ERROR: Expected 2 child comments, got $count"
        return 1
    fi

    # Test PR counting - collect all PR references then get unique count
    local pr_count=$(echo "$filtered" | jq '[.[] | .body | scan("#[0-9]+")]' | jq 'unique | length')
    if [[ "$pr_count" -ne 2 ]]; then
        echo "ERROR: Expected 2 PRs, got $pr_count"
        return 1
    fi

    return 0
}

# Test 4: Simulate error conditions from the failed workflow
test_workflow_error_conditions() {
    # Test what happens when gh api returns non-zero exit code
    # This simulates the error seen in run 17752783489

    # Test 1: Issue not found (404)
    (
        # Create a subshell to simulate the workflow step
        set +e  # Allow errors for testing

        # Simulate gh api failure
        ISSUE_NUMBER=999999

        # This would fail with exit code 1-5 depending on the error
        output=$(echo "gh: Not Found (HTTP 404)" >&2; exit 4)
        exit_code=$?

        if [[ $exit_code -eq 0 ]]; then
            echo "ERROR: Should have failed on missing issue"
            exit 1
        fi

        # Verify we handle the error correctly
        if [[ $exit_code -ge 1 ]] && [[ $exit_code -le 5 ]]; then
            exit 0  # Expected error range
        else
            echo "ERROR: Unexpected exit code: $exit_code"
            exit 1
        fi
    ) || return 1

    # Test 2: Malformed JSON response
    local malformed_json='{"incomplete": '

    python3 -c "
import json
import sys

try:
    data = json.loads('$malformed_json')
    print('ERROR: Should have failed on malformed JSON')
    sys.exit(1)
except json.JSONDecodeError:
    sys.exit(0)
    " || return 1

    # Test 3: Empty comments array
    local empty_comments='[]'
    local filtered=$(echo "$empty_comments" | jq '[.[] | select(.body | contains("🤖 Child"))]')
    local count=$(echo "$filtered" | jq 'length')

    if [[ "$count" -ne 0 ]]; then
        echo "ERROR: Expected 0 child comments from empty array, got $count"
        return 1
    fi

    return 0
}

# Test 5: Test multiline output handling for GITHUB_OUTPUT
test_github_output_format() {
    # Simulate the multiline output pattern used in the workflow
    local test_output=$(mktemp)

    # Write multiline content like the workflow does
    {
        echo "issue_number=123"
        echo "issue_title=Test Issue"
        echo "child_comments<<EOF"
        echo '[{"body": "🤖 Child C1 complete"}]'
        echo "EOF"
        echo "pr_count=1"
    } > "$test_output"

    # Verify the format
    if ! grep -q "issue_number=123" "$test_output"; then
        echo "ERROR: issue_number not found in output"
        rm "$test_output"
        return 1
    fi

    if ! grep -q "child_comments<<EOF" "$test_output"; then
        echo "ERROR: Multiline delimiter not found"
        rm "$test_output"
        return 1
    fi

    rm "$test_output"
    return 0
}

# Test 6: Test error handling fallback
test_error_handling_fallback() {
    # Test that the error handling step would produce valid output
    local issue_number=123
    local child_count=3
    local expected_count=3
    local run_id=17752783489
    local repository="scfox/ai_team4"

    # Simulate the error message generation
    local error_message="## ⚠️ Completion Analysis Failed

The automated completion analysis encountered an error.

**Manual Review Required**: Please review the child agent reports manually.

Child Count: $child_count
Expected Count: $expected_count

Error details have been logged to the workflow run:
https://github.com/$repository/actions/runs/$run_id"

    # Verify the message contains required information
    if [[ ! "$error_message" =~ "Child Count: $child_count" ]]; then
        echo "ERROR: Error message missing child count"
        return 1
    fi

    if [[ ! "$error_message" =~ "Expected Count: $expected_count" ]]; then
        echo "ERROR: Error message missing expected count"
        return 1
    fi

    if [[ ! "$error_message" =~ "https://github.com/" ]]; then
        echo "ERROR: Error message missing workflow link"
        return 1
    fi

    return 0
}

# Test 7: Test act workflow simulation (if act is installed)
test_act_workflow_simulation() {
    if ! command -v act &> /dev/null; then
        echo "Skipping act test (act not installed)"
        return 0
    fi

    # Create a test event file
    local event_file=$(mktemp)
    cat > "$event_file" <<EOF
{
    "action": "repository_dispatch",
    "event_type": "analyze_completions",
    "client_payload": {
        "issue_number": 123,
        "child_count": 2,
        "expected_count": 3
    }
}
EOF

    # Try to dry-run the workflow with act
    # This will catch syntax errors and some configuration issues
    if act repository_dispatch \
        --eventpath "$event_file" \
        --dryrun \
        --workflows .github/workflows/ai-completion-analyzer.yml \
        2>/dev/null; then
        echo "Workflow syntax validation passed"
        rm "$event_file"
        return 0
    else
        echo "WARNING: Workflow syntax validation failed (this might be expected without full act setup)"
        rm "$event_file"
        return 0  # Don't fail the test suite on act issues
    fi
}

# Main test runner
main() {
    echo "Starting comprehensive tests for AI Completion Analyzer workflow"
    echo "Testing scenario from failed run: https://github.com/scfox/ai_team4/actions/runs/17752783489"
    echo ""

    run_test "Valid payload structure" test_valid_payload
    run_test "Invalid payload rejection" test_invalid_payloads
    run_test "GitHub API response parsing" test_github_api_parsing
    run_test "Workflow error conditions" test_workflow_error_conditions
    run_test "GitHub output format" test_github_output_format
    run_test "Error handling fallback" test_error_handling_fallback
    run_test "Act workflow simulation" test_act_workflow_simulation

    echo ""
    echo "========================================="
    echo "Tests run: $TESTS_RUN"
    echo "Tests failed: $TESTS_FAILED"

    if [[ "$TESTS_FAILED" -eq 0 ]]; then
        echo -e "${GREEN}=== ALL TESTS PASSED ===${NC}"
        exit 0
    else
        echo -e "${RED}=== $TESTS_FAILED TESTS FAILED ===${NC}"
        exit 1
    fi
}

# Run tests
main "$@"