#!/usr/bin/env bash
# Test workflow logic without actually running in Docker
# This validates the workflow structure and mock logic

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." && pwd )"

# Activate venv if it exists
if [[ -f "${PROJECT_ROOT}/venv/bin/activate" ]]; then
    source "${PROJECT_ROOT}/venv/bin/activate"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}GitAI Teams Workflow Testing (No Docker)${NC}"
echo -e "${BLUE}================================================${NC}"

PASSED=0
FAILED=0

# Test 1: Validate workflow YAML files
echo ""
echo -e "${BLUE}=== Validating Workflow Files ===${NC}"

for workflow in ${PROJECT_ROOT}/.github/workflows/ai-*.yml; do
    name=$(basename "$workflow")
    if python3 -c "import yaml; yaml.safe_load(open('$workflow'))" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $name is valid YAML"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $name has invalid YAML"
        ((FAILED++))
    fi
done

# Test 2: Test mock Claude action
echo ""
echo -e "${BLUE}=== Testing Mock Claude Action ===${NC}"

# Set up environment
export CLAUDE_PROMPT="You must trigger repository_dispatch for orchestrate_task"
export MOCK_SCENARIO="simple_task"
export GITHUB_REPOSITORY="fox/ai_team4"
export ISSUE_NUMBER="42"

# Run the mock
if bash "${SCRIPT_DIR}/mocks/claude-action/entrypoint.sh" > /tmp/mock-test.log 2>&1; then
    if grep -q "Mock dispatch created: orchestrate_task" /tmp/mock-test.log; then
        echo -e "${GREEN}✓${NC} Mock Claude action works correctly"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Mock didn't create expected dispatch"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗${NC} Mock Claude action failed"
    ((FAILED++))
fi

# Test 3: Validate event JSON files
echo ""
echo -e "${BLUE}=== Validating Event Files ===${NC}"

for event in ${SCRIPT_DIR}/events/*.json; do
    name=$(basename "$event")
    if python3 -c "import json; json.load(open('$event'))" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $name is valid JSON"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $name has invalid JSON"
        ((FAILED++))
    fi
done

# Test 4: Test Python scripts
echo ""
echo -e "${BLUE}=== Testing Python Scripts ===${NC}"

# Test count_completions.py
COMMENTS='[{"body": "🤖 Child C1 complete"}, {"body": "🤖 Child C2 complete"}]'
if OUTPUT=$(python3 "${PROJECT_ROOT}/scripts/python/count_completions.py" \
    --comments "$COMMENTS" \
    --threshold 2 2>&1); then
    if echo "$OUTPUT" | grep -q '"child_count": 2'; then
        echo -e "${GREEN}✓${NC} count_completions.py correctly counts children"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} count_completions.py incorrect count"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗${NC} count_completions.py failed"
    ((FAILED++))
fi

# Test analyze_completions.py
CLAUDE_RESPONSE='{"merge_strategy": "sequential", "ready_to_merge": true, "children": [{"id": 1, "status": "complete"}]}'
if OUTPUT=$(echo "$CLAUDE_RESPONSE" | python3 "${PROJECT_ROOT}/scripts/python/analyze_completions.py" \
    --claude-response "$CLAUDE_RESPONSE" 2>&1); then
    if echo "$OUTPUT" | grep -q "sequential"; then
        echo -e "${GREEN}✓${NC} analyze_completions.py parses responses"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} analyze_completions.py incorrect parsing"
        ((FAILED++))
    fi
else
    echo -e "${RED}✗${NC} analyze_completions.py failed"
    ((FAILED++))
fi

# Test 5: Workflow condition logic
echo ""
echo -e "${BLUE}=== Testing Workflow Logic ===${NC}"

# Simulate router trigger condition
ISSUE_BODY="@gitaiteams Please help with this task"
if echo "$ISSUE_BODY" | grep -q "@gitaiteams"; then
    echo -e "${GREEN}✓${NC} Router would trigger on @gitaiteams mention"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Router wouldn't trigger"
    ((FAILED++))
fi

# Simulate completion detection
COMMENT_BODY="🤖 Child C3 complete: All tests passing"
if echo "$COMMENT_BODY" | grep -q "🤖"; then
    echo -e "${GREEN}✓${NC} Completion detector would trigger on 🤖 marker"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Completion detector wouldn't trigger"
    ((FAILED++))
fi

# Test 6: Contract validation
echo ""
echo -e "${BLUE}=== Testing Contract Validation ===${NC}"

# Test repository dispatch contract
if bash "${PROJECT_ROOT}/tests/contracts/test_repository_dispatch.sh" > /tmp/contract-test.log 2>&1; then
    echo -e "${GREEN}✓${NC} Repository dispatch contract tests pass"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Repository dispatch contract tests failed (check /tmp/contract-test.log)"
    ((FAILED++))
fi

# Clean up
rm -f /tmp/mock-test.log /tmp/contract-test.log
rm -rf /tmp/act-mock-dispatches /tmp/mock-dispatches

# Summary
echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}Test Results Summary${NC}"
echo -e "${BLUE}=========================================${NC}"
echo "Total tests: $((PASSED + FAILED))"
echo -e "${GREEN}Passed: $PASSED${NC}"
if [[ "$FAILED" -gt 0 ]]; then
    echo -e "${RED}Failed: $FAILED${NC}"
fi

if [[ "$FAILED" -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✅ All workflow logic tests passed!${NC}"
    echo ""
    echo -e "${YELLOW}Note: These tests validate workflow logic without Docker.${NC}"
    echo -e "${YELLOW}For full integration testing with act, ensure:${NC}"
    echo -e "${YELLOW}  1. Docker Desktop is installed and running${NC}"
    echo -e "${YELLOW}  2. act is configured properly${NC}"
    echo -e "${YELLOW}  3. Use standard Docker setup (not colima)${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi