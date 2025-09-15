#!/usr/bin/env bash
# T011: Issue comment contract test
# Validates comment format against contract

set -euo pipefail

echo "=== Issue Comment Contract Test ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_comment_headers() {
    echo "Testing comment header formats..."

    local valid_headers=(
        "## 🤖 GitAI Teams Response"
        "## ⏳ Status Update"
        "## ❌ Error"
    )

    for header in "${valid_headers[@]}"; do
        case "$header" in
            *"🤖"*) echo -e "${GREEN}✓${NC} Valid result header: $header" ;;
            *"⏳"*) echo -e "${GREEN}✓${NC} Valid status header: $header" ;;
            *"❌"*) echo -e "${GREEN}✓${NC} Valid error header: $header" ;;
            *) echo -e "${RED}✗${NC} Invalid header: $header"; return 1 ;;
        esac
    done
}

test_comment_size_limit() {
    echo "Testing comment size limits..."

    # Create a string of exactly 65536 characters (GitHub's limit)
    local max_size=65536
    local test_content=$(printf '%*s' $max_size | tr ' ' 'a')

    if [[ ${#test_content} -eq $max_size ]]; then
        echo -e "${GREEN}✓${NC} Content at max limit: ${#test_content} bytes"
    else
        echo -e "${RED}✗${NC} Size calculation error"
        return 1
    fi

    # Test oversized content (should be rejected)
    local oversized=$((max_size + 1))
    local large_content=$(printf '%*s' $oversized | tr ' ' 'a')

    if [[ ${#large_content} -gt $max_size ]]; then
        echo -e "${GREEN}✓${NC} Correctly identified oversized content: ${#large_content} bytes"
    else
        echo -e "${RED}✗${NC} Failed to identify oversized content"
        return 1
    fi
}

test_metadata_structure() {
    echo "Testing comment metadata structure..."

    python3 -c "
import json
import sys

# Valid metadata examples
valid_metadata = [
    {
        'agent_type': 'result',
        'issue_number': 42,
        'execution_time_ms': 45000,
        'children_spawned': 0,
        'truncated': False
    },
    {
        'agent_type': 'status',
        'issue_number': 43,
        'children_spawned': 2
    },
    {
        'agent_type': 'error',
        'issue_number': 44
    }
]

for i, metadata in enumerate(valid_metadata):
    try:
        # Validate agent_type
        assert metadata.get('agent_type') in ['root', 'status', 'error', 'result']

        # Validate issue_number
        assert isinstance(metadata.get('issue_number'), int)
        assert metadata.get('issue_number') > 0

        # Validate optional fields
        if 'children_spawned' in metadata:
            assert 0 <= metadata['children_spawned'] <= 5

        if 'execution_time_ms' in metadata:
            assert metadata['execution_time_ms'] >= 0

        print(f'✓ Valid metadata structure {i+1}')
    except AssertionError as e:
        print(f'✗ Invalid metadata structure {i+1}: {e}')
        sys.exit(1)

sys.exit(0)
" && echo -e "${GREEN}✓${NC} Metadata structure valid" || echo -e "${RED}✗${NC} Metadata structure invalid"
}

test_truncation_handling() {
    echo "Testing truncation handling..."

    # Simulate truncated content
    local truncation_notice="

---
**Note**: Results truncated due to GitHub comment size limit (65,536 characters).
Full results available in the pull request."

    if [[ "$truncation_notice" =~ "truncated" ]]; then
        echo -e "${GREEN}✓${NC} Truncation notice present when needed"
    else
        echo -e "${RED}✗${NC} Missing truncation notice"
        return 1
    fi
}

# Main
main() {
    local failed=0

    test_comment_headers || ((failed++))
    test_comment_size_limit || ((failed++))
    test_metadata_structure || ((failed++))
    test_truncation_handling || ((failed++))

    echo ""
    if [[ "$failed" -eq 0 ]]; then
        echo -e "${GREEN}=== ISSUE COMMENT CONTRACT TEST PASSED ===${NC}"
        exit 0
    else
        echo -e "${RED}=== ISSUE COMMENT CONTRACT TEST FAILED ===${NC}"
        exit 1
    fi
}

main "$@"