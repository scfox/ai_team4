#!/usr/bin/env bash
# Basic workflow test without complex conditions

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." && pwd )"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Basic Act Workflow Test ===${NC}"

# Check prerequisites
if ! command -v act &> /dev/null; then
    echo -e "${RED}✗ act is not installed${NC}"
    echo "Install with: brew install act"
    exit 1
fi

if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}✗ Docker is not running${NC}"
    echo "Please start Docker Desktop"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites met${NC}"

# Create a test workflow that simulates our router
cat > /tmp/test-router.yml << 'EOF'
name: Test Router
on: workflow_dispatch

jobs:
  test-route:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        run: echo "Simulating checkout"

      - name: Mock Eyes Reaction
        run: |
          echo "Adding eyes reaction to issue #42"
          echo "::notice::Would add eyes reaction via GitHub API"

      - name: Mock Add Label
        run: |
          echo "Adding trigger:ai-task label"
          echo "::notice::Would add label via GitHub API"

      - name: Mock Claude Action
        run: |
          echo "=== Mock Claude Code Action ==="
          echo "Simulating repository_dispatch trigger"

          # Simulate the dispatch
          mkdir -p /tmp/mock-dispatches
          cat > /tmp/mock-dispatches/orchestrate_42.json << 'JSON'
          {
            "event_type": "orchestrate_task",
            "client_payload": {
              "issue_number": "42",
              "task": "Test task"
            }
          }
          JSON

          echo "✓ Mock dispatch created"

      - name: Validate
        run: |
          if [[ -f /tmp/mock-dispatches/orchestrate_42.json ]]; then
            echo "✅ Test passed: Dispatch was created"
          else
            echo "❌ Test failed: Dispatch not found"
            exit 1
          fi
EOF

# Create simple event
cat > /tmp/test-event.json << 'EOF'
{
  "workflow_dispatch": {}
}
EOF

# Pull a small image first
echo "Preparing Docker image..."
docker pull alpine:latest 2>/dev/null || echo "Note: Will pull on first run"

# Run the test with alpine (smaller image)
echo ""
echo "Running test workflow..."
if act workflow_dispatch \
     -W /tmp/test-router.yml \
     --container-architecture linux/amd64 \
     -P ubuntu-latest=alpine:latest \
     --bind \
     -q 2>&1 | tee /tmp/act-basic.log; then

    echo -e "${GREEN}✅ Basic workflow test passed${NC}"
    PASSED=1
else
    echo -e "${RED}❌ Basic workflow test failed${NC}"
    echo "Check /tmp/act-basic.log for details"
    PASSED=0
fi

# Test Python scripts
echo ""
echo -e "${BLUE}Testing Python completion scripts...${NC}"

# Test count_completions.py
if python3 "${PROJECT_ROOT}/scripts/python/count_completions.py" \
    --comments '[{"body": "🤖 Child C1 complete"}]' \
    --threshold 1 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ count_completions.py works${NC}"
else
    echo -e "${RED}✗ count_completions.py failed${NC}"
    PASSED=0
fi

# Test analyze_completions.py with correct arguments
TEST_RESPONSE='{"merge_strategy": "sequential", "ready": true}'
if echo "$TEST_RESPONSE" | python3 "${PROJECT_ROOT}/scripts/python/analyze_completions.py" \
    --claude-response "$TEST_RESPONSE" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ analyze_completions.py works${NC}"
else
    echo -e "${RED}✗ analyze_completions.py failed${NC}"
    PASSED=0
fi

# Clean up
rm -f /tmp/test-router.yml /tmp/test-event.json /tmp/act-basic.log
rm -rf /tmp/mock-dispatches

# Summary
echo ""
if [[ "$PASSED" -eq 1 ]]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ All basic tests passed!${NC}"
    echo -e "${GREEN}========================================${NC}"
    exit 0
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}❌ Some tests failed${NC}"
    echo -e "${RED}========================================${NC}"
    exit 1
fi