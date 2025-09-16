#!/usr/bin/env bash
# Simple test to verify act is working with our setup

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "${SCRIPT_DIR}/../.." && pwd )"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== Simple Act Test ==="
echo "Testing basic act functionality..."

# Create a simple test workflow
cat > /tmp/test-workflow.yml << 'EOF'
name: Test Workflow
on: push

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test step
        run: |
          echo "Act is working!"
          echo "Mock scenario: ${{ env.MOCK_SCENARIO }}"
EOF

# Create a simple event
cat > /tmp/test-event.json << 'EOF'
{
  "push": {
    "ref": "refs/heads/main"
  }
}
EOF

# Try to pull the image first
echo "Pulling Docker image..."
docker pull catthehacker/ubuntu:act-latest 2>/dev/null || echo "Note: Could not pre-pull image"

# Run act
echo "Running act..."
if act push \
     -W /tmp/test-workflow.yml \
     --eventpath /tmp/test-event.json \
     --container-architecture linux/amd64 \
     -P ubuntu-latest=catthehacker/ubuntu:act-latest \
     --env MOCK_SCENARIO=test \
     --pull=false \
     --no-recurse 2>&1 | tee /tmp/act-simple.log; then
    echo -e "${GREEN}✓ Act is working correctly${NC}"
else
    echo -e "${RED}✗ Act failed to run${NC}"
    echo "Please check:"
    echo "  1. Docker is running"
    echo "  2. act is installed correctly"
    echo "  3. You have internet connection for pulling Docker images"
fi

# Clean up
rm -f /tmp/test-workflow.yml /tmp/test-event.json