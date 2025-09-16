#!/bin/bash
# T021: Integration test for end-to-end completion detection flow

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
TEST_NAME="${1:-all}"
VERBOSE="${2:-false}"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_test() {
    echo -e "${YELLOW}[TEST]${NC} $1"
}

# T022: Test scenario - all children succeed
test_all_success() {
    log_test "Testing scenario: All children succeed"

    # Create mock comments data
    COMMENTS='[
        {
            "id": 1,
            "body": "🤖 Child Agent 1 Status\n\nSuccessfully completed task!\nCreated PR #101",
            "created_at": "2025-01-01T10:00:00Z"
        },
        {
            "id": 2,
            "body": "🤖 Child Agent 2 Status\n\nTask complete.\nPR #102 ready for review",
            "created_at": "2025-01-01T10:05:00Z"
        },
        {
            "id": 3,
            "body": "🤖 Child Agent 3 Status\n\nAll tests passing!\nPR #103 created",
            "created_at": "2025-01-01T10:10:00Z"
        }
    ]'

    ISSUE_BODY="Parent task spawning 3 child agents\nExpected children: 3"

    # Run count_completions
    RESULT=$(python "$PROJECT_ROOT/scripts/python/count_completions.py" \
        --comments "$COMMENTS" \
        --issue-body "$ISSUE_BODY" \
        --threshold 3)

    # Verify results
    CHILD_COUNT=$(echo "$RESULT" | jq -r '.child_count')
    THRESHOLD_MET=$(echo "$RESULT" | jq -r '.threshold_met')
    EXPECTED_COUNT=$(echo "$RESULT" | jq -r '.expected_count')

    if [ "$CHILD_COUNT" == "3" ] && [ "$THRESHOLD_MET" == "true" ] && [ "$EXPECTED_COUNT" == "3" ]; then
        log_info "✓ All success scenario passed"
        return 0
    else
        log_error "✗ All success scenario failed"
        log_error "  Child count: $CHILD_COUNT (expected: 3)"
        log_error "  Threshold met: $THRESHOLD_MET (expected: true)"
        log_error "  Expected count: $EXPECTED_COUNT (expected: 3)"
        return 1
    fi
}

# T023: Test scenario - partial failure
test_partial_failure() {
    log_test "Testing scenario: Partial failure (2 succeed, 1 fails)"

    # Create mock comments with mixed results
    COMMENTS='[
        {
            "id": 1,
            "body": "🤖 Child Agent 1 Status\n\nTask completed successfully!\nPR #201 created",
            "created_at": "2025-01-01T11:00:00Z"
        },
        {
            "id": 2,
            "body": "🤖 Child Agent 2 Status\n\nTask failed due to test errors.\nNo PR created.\nSee error log: https://example.com/logs/123",
            "created_at": "2025-01-01T11:05:00Z"
        },
        {
            "id": 3,
            "body": "🤖 Child Agent 3 Status\n\nCompleted with all tests passing.\nPR #203 ready",
            "created_at": "2025-01-01T11:10:00Z"
        }
    ]'

    ISSUE_BODY="Task requiring 3 child agents\nChild count: 3"

    # Run count_completions
    RESULT=$(python "$PROJECT_ROOT/scripts/python/count_completions.py" \
        --comments "$COMMENTS" \
        --issue-body "$ISSUE_BODY" \
        --threshold 3)

    # All 3 children reported (regardless of success/failure)
    CHILD_COUNT=$(echo "$RESULT" | jq -r '.child_count')
    THRESHOLD_MET=$(echo "$RESULT" | jq -r '.threshold_met')

    if [ "$CHILD_COUNT" == "3" ] && [ "$THRESHOLD_MET" == "true" ]; then
        log_info "✓ Partial failure scenario passed"
        return 0
    else
        log_error "✗ Partial failure scenario failed"
        log_error "  Child count: $CHILD_COUNT (expected: 3)"
        log_error "  Threshold met: $THRESHOLD_MET (expected: true)"
        return 1
    fi
}

# T024: Test scenario - ambiguous status
test_ambiguous_status() {
    log_test "Testing scenario: Ambiguous status handling"

    # Create mock comments with ambiguous status
    COMMENTS='[
        {
            "id": 1,
            "body": "🤖 Child Agent 1 Status\n\nMostly complete, some edge cases remain.\nPR #301 created but needs review",
            "created_at": "2025-01-01T12:00:00Z"
        },
        {
            "id": 2,
            "body": "🤖 Child Agent 2 Status\n\nCore functionality done.\nMinor issues with styling.\nPR #302",
            "created_at": "2025-01-01T12:05:00Z"
        },
        {
            "id": 3,
            "body": "🤖  Child Agent 3 Report\n\nTask is about 90% done.\nNeed clarification on requirements.\nDraft PR #303",
            "created_at": "2025-01-01T12:10:00Z"
        }
    ]'

    ISSUE_BODY="Complex task with 3 subtasks"

    # Run count_completions (should still count all as reported)
    RESULT=$(python "$PROJECT_ROOT/scripts/python/count_completions.py" \
        --comments "$COMMENTS" \
        --issue-body "$ISSUE_BODY" \
        --threshold 3)

    CHILD_COUNT=$(echo "$RESULT" | jq -r '.child_count')
    THRESHOLD_MET=$(echo "$RESULT" | jq -r '.threshold_met')

    # Note: Agent 3 has extra space in marker but should still be counted
    if [ "$CHILD_COUNT" == "3" ] && [ "$THRESHOLD_MET" == "true" ]; then
        log_info "✓ Ambiguous status scenario passed"
        return 0
    else
        log_error "✗ Ambiguous status scenario failed"
        log_error "  Child count: $CHILD_COUNT (expected: 3)"
        log_error "  Threshold met: $THRESHOLD_MET (expected: true)"
        return 1
    fi
}

# Test edge case: more children than expected
test_unexpected_children() {
    log_test "Testing scenario: More children than expected"

    COMMENTS='[
        {
            "id": 1,
            "body": "🤖 Child 1: Task complete, PR #401",
            "created_at": "2025-01-01T13:00:00Z"
        },
        {
            "id": 2,
            "body": "🤖 Child 2: Success! PR #402",
            "created_at": "2025-01-01T13:05:00Z"
        },
        {
            "id": 3,
            "body": "🤖 Child 3: Done, PR #403",
            "created_at": "2025-01-01T13:10:00Z"
        },
        {
            "id": 4,
            "body": "🤖 Child 4 (unexpected): Also completed, PR #404",
            "created_at": "2025-01-01T13:15:00Z"
        }
    ]'

    ISSUE_BODY="Task with expected children: 3"

    RESULT=$(python "$PROJECT_ROOT/scripts/python/count_completions.py" \
        --comments "$COMMENTS" \
        --issue-body "$ISSUE_BODY" \
        --threshold 3)

    CHILD_COUNT=$(echo "$RESULT" | jq -r '.child_count')
    EXPECTED_COUNT=$(echo "$RESULT" | jq -r '.expected_count')
    THRESHOLD_MET=$(echo "$RESULT" | jq -r '.threshold_met')

    # Should count 4 children, note discrepancy with expected 3
    if [ "$CHILD_COUNT" == "4" ] && [ "$EXPECTED_COUNT" == "3" ] && [ "$THRESHOLD_MET" == "true" ]; then
        log_info "✓ Unexpected children scenario passed"
        return 0
    else
        log_error "✗ Unexpected children scenario failed"
        log_error "  Child count: $CHILD_COUNT (expected: 4)"
        log_error "  Expected count: $EXPECTED_COUNT (expected: 3)"
        log_error "  Threshold met: $THRESHOLD_MET (expected: true)"
        return 1
    fi
}

# Test workflow trigger conditions
test_trigger_conditions() {
    log_test "Testing workflow trigger conditions"

    # Test: Comment without robot emoji should not trigger
    COMMENTS_NO_ROBOT='[{"id": 1, "body": "Regular comment without marker"}]'
    RESULT=$(python "$PROJECT_ROOT/scripts/python/count_completions.py" \
        --comments "$COMMENTS_NO_ROBOT" \
        --threshold 3)

    COUNT=$(echo "$RESULT" | jq -r '.child_count')
    if [ "$COUNT" == "0" ]; then
        log_info "✓ Non-robot comment correctly ignored"
    else
        log_error "✗ Non-robot comment wrongly counted"
        return 1
    fi

    # Test: Below threshold should not trigger
    COMMENTS_BELOW='[
        {"id": 1, "body": "🤖 Child 1: Done"},
        {"id": 2, "body": "🤖 Child 2: Complete"}
    ]'
    RESULT=$(python "$PROJECT_ROOT/scripts/python/count_completions.py" \
        --comments "$COMMENTS_BELOW" \
        --threshold 3)

    THRESHOLD_MET=$(echo "$RESULT" | jq -r '.threshold_met')
    if [ "$THRESHOLD_MET" == "false" ]; then
        log_info "✓ Below threshold correctly not triggered"
    else
        log_error "✗ Below threshold wrongly triggered"
        return 1
    fi

    return 0
}

# Main test runner
main() {
    log_info "Starting completion flow integration tests"
    log_info "Project root: $PROJECT_ROOT"

    FAILED=0
    PASSED=0

    # Run specific test or all tests
    case "$TEST_NAME" in
        all)
            for test_func in test_all_success test_partial_failure test_ambiguous_status test_unexpected_children test_trigger_conditions; do
                if $test_func; then
                    ((PASSED++))
                else
                    ((FAILED++))
                fi
                echo ""
            done
            ;;
        success)
            test_all_success && ((PASSED++)) || ((FAILED++))
            ;;
        partial)
            test_partial_failure && ((PASSED++)) || ((FAILED++))
            ;;
        ambiguous)
            test_ambiguous_status && ((PASSED++)) || ((FAILED++))
            ;;
        unexpected)
            test_unexpected_children && ((PASSED++)) || ((FAILED++))
            ;;
        triggers)
            test_trigger_conditions && ((PASSED++)) || ((FAILED++))
            ;;
        *)
            log_error "Unknown test: $TEST_NAME"
            echo "Available tests: all, success, partial, ambiguous, unexpected, triggers"
            exit 1
            ;;
    esac

    # Summary
    echo ""
    log_info "Test Results Summary"
    log_info "===================="
    log_info "Passed: $PASSED"
    log_info "Failed: $FAILED"

    if [ $FAILED -eq 0 ]; then
        log_info "✓ All tests passed!"
        exit 0
    else
        log_error "✗ Some tests failed"
        exit 1
    fi
}

# Run main
main