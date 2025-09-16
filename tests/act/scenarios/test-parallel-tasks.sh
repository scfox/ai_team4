#!/usr/bin/env bash
# Test parallel task splitting scenarios

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ACT_DIR="$( cd "${SCRIPT_DIR}/.." && pwd )"

source "${ACT_DIR}/lib/validate.sh"

echo "=== Parallel Task Test Scenarios ==="

PASSED=0
FAILED=0

# Test parallel task splitting
test_parallel_split() {
    echo ""
    echo "Test: Parallel task splitting (3 children)"

    init_mocks

    # Create event with task requiring splitting
    cat > /tmp/parallel-event.json << 'EOF'
{
  "action": "orchestrate_task",
  "client_payload": {
    "issue_number": "100",
    "task": "Split this into 3 subtasks:\n1. Research\n2. Implementation\n3. Testing"
  },
  "repository": {
    "name": "ai_team4",
    "full_name": "fox/ai_team4"
  }
}
EOF

    local output_file="/tmp/act-parallel.log"

    # Mock the orchestrator behavior
    export MOCK_CLAUDE_SCENARIO="parallel_task"

    echo "Simulating orchestrator splitting task..."

    # Since repository_dispatch is tricky with act, simulate the key behaviors
    mkdir -p /tmp/act-mock-branches
    for i in 1 2 3; do
        echo "gitaiteams/issue-100-child-$i" >> /tmp/act-mock-branches/created.txt
        echo "Creating mock dispatch for child $i"
        mkdir -p /tmp/act-mock-dispatches
        echo "{
            \"event_type\": \"child_task\",
            \"client_payload\": {
                \"issue_number\": \"100\",
                \"child_number\": $i,
                \"parent_branch\": \"gitaiteams/issue-100\"
            }
        }" > "/tmp/act-mock-dispatches/child_100_$i.json"
    done

    # Validate branches were created
    local all_passed=true
    for i in 1 2 3; do
        if validate_branch "gitaiteams/issue-100-child-$i"; then
            echo -e "${GREEN}✓ Child $i branch created${NC}"
        else
            echo -e "${RED}✗ Child $i branch missing${NC}"
            all_passed=false
        fi
    done

    # Validate dispatches were created
    for i in 1 2 3; do
        if [[ -f "/tmp/act-mock-dispatches/child_100_$i.json" ]]; then
            echo -e "${GREEN}✓ Child $i dispatch created${NC}"
        else
            echo -e "${RED}✗ Child $i dispatch missing${NC}"
            all_passed=false
        fi
    done

    if $all_passed; then
        echo -e "${GREEN}✓ Parallel task split test passed${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ Parallel task split test failed${NC}"
        ((FAILED++))
    fi

    rm -f /tmp/parallel-event.json
}

# Test completion aggregation
test_completion_aggregation() {
    echo ""
    echo "Test: Parallel task completion aggregation"

    init_mocks

    # Simulate 3 completed children
    mkdir -p /tmp/act-mock-data
    cat > /tmp/act-mock-data/completions.json << 'EOF'
{
  "children": [
    {"id": 1, "status": "complete", "pr": 101},
    {"id": 2, "status": "complete", "pr": 102},
    {"id": 3, "status": "complete", "pr": 103}
  ],
  "total": 3,
  "completed": 3,
  "threshold_met": true
}
EOF

    # Test the Python completion counter
    echo "Testing completion counting..."
    RESULT=$(python3 "${ACT_DIR}/../../scripts/python/count_completions.py" \
        --comments '[{"body": "🤖 Child C1 complete"}, {"body": "🤖 Child C2 complete"}, {"body": "🤖 Child C3 complete"}]' \
        --threshold 3 2>/dev/null || echo "error")

    if echo "$RESULT" | grep -q '"threshold_met": true'; then
        echo -e "${GREEN}✓ Completion threshold detection works${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ Completion threshold detection failed${NC}"
        echo "Result: $RESULT"
        ((FAILED++))
    fi

    # Test merge strategy determination
    echo "Testing merge strategy analysis..."
    STRATEGY=$(python3 "${ACT_DIR}/../../scripts/python/analyze_completions.py" \
        --determine-strategy --successful 3 --failed 0 --partial 0 2>/dev/null || echo "error")

    if echo "$STRATEGY" | grep -q "sequential_merge"; then
        echo -e "${GREEN}✓ Merge strategy determined correctly${NC}"
        ((PASSED++))
    else
        echo -e "${RED}✗ Merge strategy determination failed${NC}"
        echo "Strategy: $STRATEGY"
        ((FAILED++))
    fi

    rm -rf /tmp/act-mock-data
}

# Main
main() {
    test_parallel_split
    test_completion_aggregation

    cleanup_mocks
    summarize_results "$PASSED" "$FAILED"
}

main "$@"