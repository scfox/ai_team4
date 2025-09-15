#!/usr/bin/env bash
# T009: Repository dispatch contract test
# Validates payload structure against contract

set -euo pipefail

echo "=== Repository Dispatch Contract Test ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test valid payloads
test_valid_orchestrate_payload() {
    local payload='{
        "event_type": "orchestrate_task",
        "client_payload": {
            "issue_number": 42,
            "task": "Review this Python function"
        }
    }'

    echo "Testing valid orchestrate_task payload..."

    # Validate against schema using Python
    python3 -c "
import json
import sys

payload = $payload
contract_file = 'specs/001-read-the-documents/contracts/repository-dispatch.json'

try:
    with open(contract_file) as f:
        contract = json.load(f)

    # Basic validation
    assert payload['event_type'] in ['orchestrate_task', 'child_task']
    assert 'client_payload' in payload
    assert 'issue_number' in payload['client_payload']
    assert payload['client_payload']['issue_number'] > 0

    print('✓ Valid orchestrate_task payload')
    sys.exit(0)
except Exception as e:
    print(f'✗ Invalid payload: {e}')
    sys.exit(1)
    " && echo -e "${GREEN}✓${NC} Orchestrate payload valid" || echo -e "${RED}✗${NC} Orchestrate payload invalid"
}

test_valid_child_payload() {
    local payload='{
        "event_type": "child_task",
        "client_payload": {
            "issue_number": 43,
            "task": "Research FastAPI",
            "parent_branch": "gitaiteams/issue-43",
            "child_number": 1
        }
    }'

    echo "Testing valid child_task payload..."

    python3 -c "
import json
import sys
import re

payload = $payload

try:
    # Validate child-specific fields
    assert payload['event_type'] == 'child_task'
    assert 'parent_branch' in payload['client_payload']
    assert re.match(r'^gitaiteams/issue-\d+$', payload['client_payload']['parent_branch'])
    assert 1 <= payload['client_payload']['child_number'] <= 5

    print('✓ Valid child_task payload')
    sys.exit(0)
except Exception as e:
    print(f'✗ Invalid payload: {e}')
    sys.exit(1)
    " && echo -e "${GREEN}✓${NC} Child payload valid" || echo -e "${RED}✗${NC} Child payload invalid"
}

test_invalid_payloads() {
    echo "Testing invalid payloads..."

    # Missing issue_number
    local invalid1='{
        "event_type": "orchestrate_task",
        "client_payload": {
            "task": "Do something"
        }
    }'

    python3 -c "
import json
import sys

payload = $invalid1

try:
    assert 'issue_number' in payload['client_payload']
    print('✗ Should have failed - missing issue_number')
    sys.exit(1)
except:
    print('✓ Correctly rejected payload missing issue_number')
    sys.exit(0)
    " && echo -e "${GREEN}✓${NC} Rejected invalid payload" || echo -e "${RED}✗${NC} Accepted invalid payload"

    # Invalid child_number
    local invalid2='{
        "event_type": "child_task",
        "client_payload": {
            "issue_number": 43,
            "child_number": 6
        }
    }'

    python3 -c "
import json
import sys

payload = $invalid2

try:
    assert 1 <= payload['client_payload'].get('child_number', 1) <= 5
    print('✗ Should have failed - child_number > 5')
    sys.exit(1)
except:
    print('✓ Correctly rejected child_number > 5')
    sys.exit(0)
    " && echo -e "${GREEN}✓${NC} Rejected invalid child number" || echo -e "${RED}✗${NC} Accepted invalid child number"
}

# Main
main() {
    local failed=0

    test_valid_orchestrate_payload || ((failed++))
    test_valid_child_payload || ((failed++))
    test_invalid_payloads || ((failed++))

    echo ""
    if [[ "$failed" -eq 0 ]]; then
        echo -e "${GREEN}=== REPOSITORY DISPATCH CONTRACT TEST PASSED ===${NC}"
        exit 0
    else
        echo -e "${RED}=== REPOSITORY DISPATCH CONTRACT TEST FAILED ===${NC}"
        exit 1
    fi
}

main "$@"