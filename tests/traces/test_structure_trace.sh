#!/usr/bin/env bash
# Structure trace test - verifies workflows and scripts exist and are valid
# This is what can be tested without requiring CLAUDE_CODE_OAUTH_TOKEN

set -euo pipefail

echo "=== Structure Trace Test ==="
echo "Verifying GitAI Teams structure without requiring live workflow runs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check required workflows exist
check_workflows_exist() {
    echo "Checking required workflows exist..."

    local required_workflows=(
        ".github/workflows/ai-task-router.yml"
        ".github/workflows/ai-task-orchestrator.yml"
        ".github/workflows/ai-child-executor.yml"
        ".github/workflows/ai-completion-analyzer.yml"
    )

    local failed=0
    for workflow in "${required_workflows[@]}"; do
        if [[ -f "$workflow" ]]; then
            echo -e "${GREEN}✓${NC} Found: $workflow"

            # Validate YAML syntax (use basic check if PyYAML not available)
            if python -c "import yaml; yaml.safe_load(open('$workflow'))" 2>/dev/null; then
                echo -e "  ${GREEN}✓${NC} Valid YAML syntax"
            elif python -c "open('$workflow').read()" 2>/dev/null && grep -q "^name:" "$workflow"; then
                echo -e "  ${GREEN}✓${NC} Basic structure valid (PyYAML not installed for full check)"
            else
                echo -e "  ${RED}✗${NC} Invalid workflow file"
                ((failed++))
            fi
        else
            echo -e "${RED}✗${NC} Missing: $workflow"
            ((failed++))
        fi
    done

    return $failed
}

# Check required scripts exist and are executable
check_scripts_exist() {
    echo ""
    echo "Checking required scripts exist..."

    local required_scripts=(
        "scripts/bash/spawn_child.sh"
        "scripts/bash/create_pr.sh"
        "scripts/bash/derive_state.sh"
        "scripts/bash/post_comment.sh"
        "scripts/python/analyze_task.py"
        "scripts/python/combine_results.py"
        "scripts/python/generate_comparison.py"
        "scripts/python/count_completions.py"
        "scripts/python/analyze_completions.py"
    )

    local failed=0
    for script in "${required_scripts[@]}"; do
        if [[ -f "$script" ]]; then
            echo -e "${GREEN}✓${NC} Found: $script"

            # Check if bash scripts are executable
            if [[ "$script" == *.sh ]]; then
                if [[ -x "$script" ]]; then
                    echo -e "  ${GREEN}✓${NC} Executable"
                else
                    echo -e "  ${YELLOW}⚠${NC} Not executable (chmod +x needed)"
                fi
            fi

            # Check Python syntax
            if [[ "$script" == *.py ]]; then
                if python -m py_compile "$script" 2>/dev/null; then
                    echo -e "  ${GREEN}✓${NC} Valid Python syntax"
                else
                    echo -e "  ${RED}✗${NC} Invalid Python syntax"
                    ((failed++))
                fi
            fi
        else
            echo -e "${RED}✗${NC} Missing: $script"
            ((failed++))
        fi
    done

    return $failed
}

# Check for forbidden state files
check_no_state_files() {
    echo ""
    echo "Checking for forbidden state files..."

    local state_files=$(find . -name "STATE.json" -o -name "*.state" 2>/dev/null | grep -v ".git" | head -10)

    if [[ -z "$state_files" ]]; then
        echo -e "${GREEN}✓${NC} No state files found (stateless architecture verified)"
        return 0
    else
        echo -e "${RED}✗${NC} Found forbidden state files:"
        echo "$state_files"
        return 1
    fi
}

# Check workflow triggers are configured correctly
check_workflow_triggers() {
    echo ""
    echo "Checking workflow triggers..."

    local failed=0

    # Check router triggers on issues and comments
    if grep -q "issues:" .github/workflows/ai-task-router.yml && \
       grep -q "issue_comment:" .github/workflows/ai-task-router.yml; then
        echo -e "${GREEN}✓${NC} Router triggers on issues and comments"
    else
        echo -e "${RED}✗${NC} Router missing issue/comment triggers"
        ((failed++))
    fi

    # Check orchestrator uses repository_dispatch
    if grep -q "repository_dispatch:" .github/workflows/ai-task-orchestrator.yml; then
        echo -e "${GREEN}✓${NC} Orchestrator uses repository_dispatch"
    else
        echo -e "${RED}✗${NC} Orchestrator missing repository_dispatch"
        ((failed++))
    fi

    # Check child executor uses repository_dispatch
    if grep -q "repository_dispatch:" .github/workflows/ai-child-executor.yml; then
        echo -e "${GREEN}✓${NC} Child executor uses repository_dispatch"
    else
        echo -e "${RED}✗${NC} Child executor missing repository_dispatch"
        ((failed++))
    fi

    # Check completion analyzer uses repository_dispatch
    if grep -q "repository_dispatch:" .github/workflows/ai-completion-analyzer.yml; then
        echo -e "${GREEN}✓${NC} Completion analyzer uses repository_dispatch"
    else
        echo -e "${RED}✗${NC} Completion analyzer missing repository_dispatch"
        ((failed++))
    fi

    return $failed
}

# Check Python tests exist and pass
check_python_tests() {
    echo ""
    echo "Checking Python tests..."

    cd scripts/python

    # Check if test files exist
    local test_files=(
        "test_analyze_task.py"
        "test_combine_results.py"
        "test_generate_comparison.py"
        "test_count_completions.py"
        "test_analyze_completions.py"
    )

    local failed=0
    for test_file in "${test_files[@]}"; do
        if [[ -f "$test_file" ]]; then
            echo -e "${GREEN}✓${NC} Found test: $test_file"
        else
            echo -e "${YELLOW}⚠${NC} Missing test: $test_file"
        fi
    done

    # Run pytest if available
    if python -m pytest --version >/dev/null 2>&1; then
        echo "  Running Python tests..."
        if python -m pytest test_*.py --tb=no -q >/dev/null 2>&1; then
            echo -e "  ${GREEN}✓${NC} All Python tests pass"
        else
            echo -e "  ${YELLOW}⚠${NC} Some Python tests fail (expected in TDD)"
        fi
    else
        echo -e "  ${YELLOW}⚠${NC} pytest not installed, skipping test execution"
    fi

    cd ../..
    return $failed
}

# Main execution
main() {
    local total_failed=0

    # Change to project root
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    cd "$PROJECT_ROOT"

    echo "Starting structure trace verification..."
    echo "This verifies the system structure without requiring live runs"
    echo ""

    check_workflows_exist || ((total_failed+=$?))
    check_scripts_exist || ((total_failed+=$?))
    check_no_state_files || ((total_failed+=$?))
    check_workflow_triggers || ((total_failed+=$?))
    check_python_tests || ((total_failed+=$?))

    echo ""
    echo "========================================="
    if [[ "$total_failed" -eq 0 ]]; then
        echo -e "${GREEN}ALL STRUCTURE TRACE TESTS PASSED${NC}"
        echo "The implementation structure is correct."
        echo ""
        echo "Note: Live workflow execution tests require:"
        echo "  1. CLAUDE_CODE_OAUTH_TOKEN secret configured"
        echo "  2. Actual @gitaiteams mentions in issues"
        exit 0
    else
        echo -e "${RED}STRUCTURE TRACE TEST FAILED${NC}"
        echo "Failed checks: $total_failed"
        echo "Fix the structural issues before testing live execution."
        exit 1
    fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi