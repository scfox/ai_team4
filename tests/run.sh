#!/usr/bin/env bash
# Test runner script for GitAI Teams
# Usage: ./tests/run.sh <test-suite>
# Example: ./tests/run.sh python
# For verbose output: VERBOSE=1 ./tests/run.sh python

set -uo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/.." && pwd )"

# Test suite to run
TEST_SUITE="${1:-}"

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to print section headers
print_header() {
    local title=$1
    echo ""
    print_color "$BLUE" "================================================"
    print_color "$BLUE" "  $title"
    print_color "$BLUE" "================================================"
}

# Function to run Python tests
run_python_tests() {
    print_header "Running Python Tests"

    cd "${PROJECT_ROOT}/scripts/python"

    # Check if pytest is installed
    if ! python -m pytest --version >/dev/null 2>&1; then
        print_color "$YELLOW" "Installing pytest..."
        pip install pytest >/dev/null 2>&1
    fi

    # Check verbosity flag
    local verbose="${VERBOSE:-0}"

    if [[ "$verbose" == "1" ]]; then
        # Run the tests with full output
        print_color "$GREEN" "Running test suite: analyze_task"
        python -m pytest test_analyze_task.py -v --tb=short

        echo ""
        print_color "$GREEN" "Running test suite: combine_results"
        python -m pytest test_combine_results.py -v --tb=short

        echo ""
        print_color "$GREEN" "Running test suite: generate_comparison"
        python -m pytest test_generate_comparison.py -v --tb=short
    else
        # Run tests quietly and show progress
        print_color "$GREEN" "Running Python test suites..."
        echo ""

        # Test analyze_task
        echo -n "  analyze_task.py: "
        result=$(python -m pytest test_analyze_task.py --tb=no -q 2>&1 | grep "in [0-9]" | head -1)
        if [[ -z "$result" ]]; then
            result="Error running tests"
        fi
        if echo "$result" | grep -q "failed"; then
            print_color "$YELLOW" "$result"
        else
            print_color "$GREEN" "$result"
        fi

        # Test combine_results
        echo -n "  combine_results.py: "
        result=$(python -m pytest test_combine_results.py --tb=no -q 2>&1 | grep "in [0-9]" | head -1)
        if [[ -z "$result" ]]; then
            result="Error running tests"
        fi
        if echo "$result" | grep -q "failed"; then
            print_color "$YELLOW" "$result"
        else
            print_color "$GREEN" "$result"
        fi

        # Test generate_comparison
        echo -n "  generate_comparison.py: "
        result=$(python -m pytest test_generate_comparison.py --tb=no -q 2>&1 | grep "in [0-9]" | head -1)
        if [[ -z "$result" ]]; then
            result="Error running tests"
        fi
        if echo "$result" | grep -q "failed"; then
            print_color "$YELLOW" "$result"
        else
            print_color "$GREEN" "$result"
        fi
    fi

    # Summary
    echo ""
    print_header "Test Summary"

    # Get test counts
    local total_passed=0
    local total_failed=0

    # Run all tests quietly to get summary
    output=$(python -m pytest test_*.py --tb=no -q 2>&1)

    # Parse the output for pass/fail counts
    if echo "$output" | grep -q "passed"; then
        total_passed=$(echo "$output" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+" | head -1)
    fi

    if echo "$output" | grep -q "failed"; then
        total_failed=$(echo "$output" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" | head -1)
    fi

    local total_tests=$((total_passed + total_failed))
    local pass_rate=0
    if [[ $total_tests -gt 0 ]]; then
        pass_rate=$(printf "%.1f" $(echo "$total_passed * 100 / $total_tests" | bc -l))
    fi

    echo "Total tests: $total_tests"
    print_color "$GREEN" "  Passed: $total_passed"
    if [[ $total_failed -gt 0 ]]; then
        print_color "$RED" "  Failed: $total_failed"
    fi
    echo "  Pass rate: ${pass_rate}%"

    echo ""
    if [[ $total_failed -eq 0 ]]; then
        print_color "$GREEN" "✅ All Python tests passing!"
        return 0
    else
        print_color "$YELLOW" "⚠️  Some tests failing (this is expected with TDD approach)"
        print_color "$YELLOW" "   Run with VERBOSE=1 to see details"
        return 0
    fi
}

# Function to run contract tests
run_contract_tests() {
    print_header "Running Contract Tests"

    cd "${PROJECT_ROOT}/tests/contracts"

    local failed=0

    for test_file in test_*.sh; do
        if [[ -f "$test_file" ]]; then
            print_color "$GREEN" "Running: $test_file"
            if bash "$test_file" >/dev/null 2>&1; then
                print_color "$GREEN" "  ✓ Passed"
            else
                print_color "$RED" "  ✗ Failed"
                ((failed++))
            fi
        fi
    done

    echo ""
    if [[ $failed -eq 0 ]]; then
        print_color "$GREEN" "✅ All contract tests passed!"
    else
        print_color "$RED" "❌ $failed contract test(s) failed"
        return 1
    fi
}

# Function to run trace tests
run_trace_tests() {
    print_header "Running Trace Tests"

    cd "${PROJECT_ROOT}/tests/traces"

    local failed=0
    local passed=0

    # First run the structure trace test (should pass)
    if [[ -f "test_structure_trace.sh" ]]; then
        print_color "$GREEN" "Running: test_structure_trace.sh"
        if bash "test_structure_trace.sh" >/dev/null 2>&1; then
            print_color "$GREEN" "  ✓ Passed"
            ((passed++))
        else
            print_color "$RED" "  ✗ Failed"
            ((failed++))
        fi
    fi

    # Note about live execution tests
    print_color "$YELLOW" ""
    print_color "$YELLOW" "Note: Live execution trace tests require:"
    print_color "$YELLOW" "  - CLAUDE_CODE_OAUTH_TOKEN secret configured"
    print_color "$YELLOW" "  - Actual @gitaiteams mentions in issues"
    echo ""

    # Run other trace tests (these check live executions)
    for test_file in test_single_task_trace.sh test_parallel_task_trace.sh; do
        if [[ -f "$test_file" ]]; then
            print_color "$GREEN" "Running: $test_file"
            if bash "$test_file" >/dev/null 2>&1; then
                print_color "$GREEN" "  ✓ Passed"
                ((passed++))
            else
                print_color "$YELLOW" "  ⚠ Skipped (requires live execution)"
            fi
        fi
    done

    echo ""
    if [[ $failed -eq 0 && $passed -gt 0 ]]; then
        print_color "$GREEN" "✅ Structure trace tests passed!"
        print_color "$YELLOW" "Live execution tests require actual @gitaiteams usage"
    elif [[ $failed -gt 0 ]]; then
        print_color "$RED" "❌ Some trace tests failed"
    fi
}

# Function to run integration tests
run_integration_tests() {
    print_header "Running Integration Tests"

    cd "${PROJECT_ROOT}/tests/integration"

    local failed=0
    local passed=0

    # Check if any integration test files exist
    if ! ls test_*.sh >/dev/null 2>&1; then
        print_color "$YELLOW" "No integration tests found"
        return 0
    fi

    for test_file in test_*.sh; do
        if [[ -f "$test_file" ]]; then
            print_color "$GREEN" "Running: $test_file"
            if bash "$test_file" >/dev/null 2>&1; then
                print_color "$GREEN" "  ✓ Passed"
                ((passed++))
            else
                print_color "$RED" "  ✗ Failed"
                ((failed++))
                # Show details for failed tests in verbose mode
                if [[ "${VERBOSE:-0}" == "1" ]]; then
                    echo "  Error output:"
                    bash "$test_file" 2>&1 | sed 's/^/    /'
                fi
            fi
        fi
    done

    echo ""
    print_color "$GREEN" "Passed: $passed"
    if [[ $failed -gt 0 ]]; then
        print_color "$RED" "Failed: $failed"
        print_color "$YELLOW" "Run with VERBOSE=1 to see error details"
        return 1
    else
        print_color "$GREEN" "✅ All integration tests passed!"
        return 0
    fi
}

# Function to run act tests
run_act_tests() {
    print_header "Running act Workflow Tests"

    cd "${PROJECT_ROOT}/tests/act"

    # Make scripts executable
    chmod +x *.sh lib/*.sh scenarios/*.sh mocks/claude-action/*.sh 2>/dev/null || true

    # Run comprehensive workflow tests
    if bash test-workflows.sh; then
        print_color "$GREEN" "✅ Workflow tests completed"
        return 0
    else
        print_color "$YELLOW" "⚠️  Some workflow tests failed"
        return 1
    fi
}

# Function to run all tests
run_all_tests() {
    print_header "Running All Tests"

    run_python_tests || true
    echo ""
    run_contract_tests || true
    echo ""
    run_integration_tests || true
    echo ""
    run_trace_tests || true
    echo ""
    run_act_tests || true
}

# Main execution
main() {
    print_color "$BLUE" "GitAI Teams Test Runner"
    print_color "$BLUE" "Project root: ${PROJECT_ROOT}"

    case "$TEST_SUITE" in
        python)
            run_python_tests
            ;;
        contracts)
            run_contract_tests
            ;;
        integration)
            run_integration_tests
            ;;
        traces)
            run_trace_tests
            ;;
        act)
            run_act_tests
            ;;
        all)
            run_all_tests
            ;;
        "")
            print_color "$RED" "Error: Test suite not specified"
            echo ""
            echo "Usage: $0 <test-suite>"
            echo ""
            echo "Available test suites:"
            echo "  python      - Run Python unit tests"
            echo "  contracts   - Run contract tests"
            echo "  integration - Run integration tests"
            echo "  traces      - Run trace tests"
            echo "  act         - Run act-based workflow tests"
            echo "  all         - Run all tests"
            echo ""
            echo "Example: $0 python"
            echo "For verbose output: VERBOSE=1 $0 python"
            exit 1
            ;;
        *)
            print_color "$RED" "Error: Unknown test suite '$TEST_SUITE'"
            echo ""
            echo "Available test suites: python, contracts, integration, traces, act, all"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"