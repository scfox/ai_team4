#!/usr/bin/env bash
# Test count_completions.py script and workflow integration
# Specifically tests for python vs python3 command issues

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." && pwd )"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Testing count_completions.py and workflow${NC}"
echo -e "${BLUE}================================================${NC}"

PASSED=0
FAILED=0

# Test function
test_command() {
    local description="$1"
    local command="$2"
    local expected_pattern="$3"

    echo -n "Testing: $description ... "

    if output=$(eval "$command" 2>&1); then
        if echo "$output" | grep -q "$expected_pattern"; then
            echo -e "${GREEN}✓${NC}"
            ((PASSED++))
            return 0
        else
            echo -e "${RED}✗${NC} (pattern not found)"
            echo "  Expected pattern: $expected_pattern"
            echo "  Got output: $output"
            ((FAILED++))
            return 1
        fi
    else
        exit_code=$?
        echo -e "${RED}✗${NC} (exit code: $exit_code)"
        echo "  Output: $output"
        ((FAILED++))
        return 1
    fi
}

# Change to project root
cd "$PROJECT_ROOT"

echo ""
echo -e "${BLUE}=== Python Command Availability ===${NC}"

# Test python vs python3 commands
if command -v python &>/dev/null; then
    echo -e "${GREEN}✓${NC} 'python' command exists: $(python --version 2>&1)"
else
    echo -e "${YELLOW}⚠${NC} 'python' command not found (this would cause exit code 127)"
fi

if command -v python3 &>/dev/null; then
    echo -e "${GREEN}✓${NC} 'python3' command exists: $(python3 --version 2>&1)"
else
    echo -e "${RED}✗${NC} 'python3' command not found"
fi

echo ""
echo -e "${BLUE}=== Script Basic Functionality ===${NC}"

# Test 1: Basic functionality with python3
test_command \
    "Basic execution with python3" \
    "python3 scripts/python/count_completions.py --comments '[]' --threshold 3" \
    '"child_count": 0'

# Test 2: Single child marker
test_command \
    "Single child marker detection" \
    'python3 scripts/python/count_completions.py --comments '"'"'[{"body": "🤖 Child C1: Task done"}]'"'"' --threshold 1' \
    '"threshold_met": true'

# Test 3: Multiple child markers
test_command \
    "Multiple child markers" \
    'python3 scripts/python/count_completions.py --comments '"'"'[{"body": "🤖 Child C1: Done"}, {"body": "🤖 Child C2: Done"}]'"'"' --threshold 2' \
    '"child_count": 2'

echo ""
echo -e "${BLUE}=== Workflow Simulation ===${NC}"

# Create temp files like the workflow does
TEMP_COMMENTS=$(mktemp)
TEMP_ISSUE_BODY=$(mktemp)

cat > "$TEMP_COMMENTS" << 'EOF'
[
  {"body": "🤖 Child C1: Task completed"},
  {"body": "Regular comment"},
  {"body": "🤖 Child C2: Task done"}
]
EOF

cat > "$TEMP_ISSUE_BODY" << 'EOF'
Parent issue that needs to be split.
Expected children: 3
EOF

# Test 4: Workflow-style execution
test_command \
    "Workflow-style with file inputs" \
    'RESULT=$(python3 scripts/python/count_completions.py --comments "$(cat '"$TEMP_COMMENTS"')" --issue-body "$(cat '"$TEMP_ISSUE_BODY"')" --threshold 3); echo "$RESULT"' \
    '"expected_count": 3'

# Test 5: Test the exact command that failed (with python instead of python3)
echo ""
echo -e "${BLUE}=== Testing python vs python3 issue ===${NC}"

if command -v python &>/dev/null; then
    test_command \
        "Using 'python' command (original issue)" \
        'python scripts/python/count_completions.py --comments "$(cat '"$TEMP_COMMENTS"')" --issue-body "$(cat '"$TEMP_ISSUE_BODY"')" --threshold 3' \
        '"child_count": 2'
else
    echo -e "${YELLOW}⚠${NC} Cannot test 'python' command (not available) - this reproduces the GitHub Actions issue!"
    ((FAILED++))
fi

# Clean up temp files
rm -f "$TEMP_COMMENTS" "$TEMP_ISSUE_BODY"

echo ""
echo -e "${BLUE}=== Act Workflow Test ===${NC}"

# If act is available, test the actual workflow
if command -v act &>/dev/null && docker info &>/dev/null 2>&1; then
    echo "Testing with act..."

    # Create event file for issue_comment trigger
    EVENT_FILE=$(mktemp)
    cat > "$EVENT_FILE" << 'EOF'
{
  "action": "created",
  "issue": {
    "number": 1,
    "body": "Parent issue\nExpected children: 2",
    "pull_request": null
  },
  "comment": {
    "body": "🤖 Child C1: Task completed"
  },
  "repository": {
    "owner": {
      "login": "test"
    },
    "name": "test-repo"
  }
}
EOF

    # Run just the check-completions job
    if act issue_comment \
        -j check-completions \
        -e "$EVENT_FILE" \
        --secret-file /dev/null \
        --container-architecture linux/amd64 \
        -P ubuntu-latest=catthehacker/ubuntu:act-latest \
        2>&1 | tee /tmp/act-test.log | grep -q "Count completions"; then

        echo -e "${GREEN}✓${NC} Act workflow test passed"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} Act workflow test failed"
        echo "  Check /tmp/act-test.log for details"
        ((FAILED++))
    fi

    rm -f "$EVENT_FILE"
else
    echo -e "${YELLOW}⚠${NC} Skipping act test (act or Docker not available)"
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}Test Results:${NC}"
echo -e "  Passed: ${GREEN}$PASSED${NC}"
echo -e "  Failed: ${RED}$FAILED${NC}"

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed${NC}"
    exit 1
fi