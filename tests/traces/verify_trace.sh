#!/usr/bin/env bash
# T008: Trace verification script
# Compares actual execution against expected trace.yml files

set -euo pipefail

echo "=== Trace Verification Script ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Verify single task trace
verify_single_task() {
    echo ""
    echo "Verifying single-task trace..."

    local trace_file="project-spec/examples/single-task/trace.yml"
    if [[ ! -f "$trace_file" ]]; then
        echo -e "${YELLOW}⚠${NC} Trace file not found: $trace_file"
        return 1
    fi

    # Extract expected values from trace.yml
    local expected_total=$(grep "total_runs:" "$trace_file" | awk '{print $2}')
    local expected_children=$(grep "children_spawned:" "$trace_file" | awk '{print $2}')
    local expected_prs=$(grep "prs_created:" "$trace_file" | awk '{print $2}')

    echo "Expected from trace.yml:"
    echo "  Total runs: $expected_total"
    echo "  Children: $expected_children"
    echo "  PRs: $expected_prs"

    # Run the test
    if bash tests/traces/test_single_task_trace.sh 42; then
        echo -e "${GREEN}✓${NC} Single-task trace verified"
        return 0
    else
        echo -e "${RED}✗${NC} Single-task trace verification failed"
        return 1
    fi
}

# Verify parallel task trace
verify_parallel_task() {
    echo ""
    echo "Verifying parallel-task trace..."

    local trace_file="project-spec/examples/parallel-task/trace.yml"
    if [[ ! -f "$trace_file" ]]; then
        echo -e "${YELLOW}⚠${NC} Trace file not found: $trace_file"
        return 1
    fi

    # Extract expected values from trace.yml
    local expected_total=$(grep "total_runs:" "$trace_file" | awk '{print $2}')
    local expected_children=$(grep "children_spawned:" "$trace_file" | awk '{print $2}')
    local expected_prs=$(grep "prs_created:" "$trace_file" | awk '{print $2}')

    echo "Expected from trace.yml:"
    echo "  Total runs: $expected_total"
    echo "  Children: $expected_children"
    echo "  PRs: $expected_prs"

    # Run the test
    if bash tests/traces/test_parallel_task_trace.sh 43; then
        echo -e "${GREEN}✓${NC} Parallel-task trace verified"
        return 0
    else
        echo -e "${RED}✗${NC} Parallel-task trace verification failed"
        return 1
    fi
}

# Check for state files (should not exist)
check_no_state_files() {
    echo ""
    echo "Checking for forbidden state files..."

    local state_files=$(find . -name "STATE.json" -o -name "*.state" 2>/dev/null | head -10)

    if [[ -z "$state_files" ]]; then
        echo -e "${GREEN}✓${NC} No state files found (stateless architecture verified)"
        return 0
    else
        echo -e "${RED}✗${NC} Found forbidden state files:"
        echo "$state_files"
        return 1
    fi
}

# Check branch naming patterns
check_branch_patterns() {
    echo ""
    echo "Checking branch naming patterns..."

    local invalid_branches=$(git branch -r | grep -E "gitaiteams/.*child-.*child-|gitaiteams/.*subtask|gitaiteams/task-" || true)

    if [[ -z "$invalid_branches" ]]; then
        echo -e "${GREEN}✓${NC} All branches follow naming convention"
        return 0
    else
        echo -e "${RED}✗${NC} Found branches with invalid patterns:"
        echo "$invalid_branches"
        return 1
    fi
}

# Main execution
main() {
    local failed=0

    echo "Starting comprehensive trace verification..."

    # Make test scripts executable
    chmod +x tests/traces/*.sh 2>/dev/null || true

    # Run all verifications
    verify_single_task || ((failed++))
    verify_parallel_task || ((failed++))
    check_no_state_files || ((failed++))
    check_branch_patterns || ((failed++))

    echo ""
    echo "========================================="
    if [[ "$failed" -eq 0 ]]; then
        echo -e "${GREEN}ALL TRACE VERIFICATIONS PASSED${NC}"
        echo "The implementation matches the expected traces exactly."
        exit 0
    else
        echo -e "${RED}TRACE VERIFICATION FAILED${NC}"
        echo "Failed checks: $failed"
        echo ""
        echo "Constitution requirement: Traces are acceptance tests."
        echo "If actual execution doesn't match trace, the implementation is wrong."
        exit 1
    fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi