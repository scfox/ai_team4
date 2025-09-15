#!/usr/bin/env bash
# T012: Branch naming contract test
# Validates branch naming patterns against contract

set -euo pipefail

echo "=== Branch Naming Contract Test ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_valid_branch_names() {
    echo "Testing valid branch names..."

    local valid_branches=(
        "gitaiteams/issue-1"
        "gitaiteams/issue-42"
        "gitaiteams/issue-999"
        "gitaiteams/issue-100-child-1"
        "gitaiteams/issue-100-child-2"
        "gitaiteams/issue-100-child-3"
        "gitaiteams/issue-100-child-4"
        "gitaiteams/issue-100-child-5"
    )

    for branch in "${valid_branches[@]}"; do
        if [[ "$branch" =~ ^gitaiteams/issue-[0-9]+(-child-[1-5])?$ ]]; then
            echo -e "${GREEN}✓${NC} Valid branch: $branch"
        else
            echo -e "${RED}✗${NC} Should be valid: $branch"
            return 1
        fi
    done
}

test_invalid_branch_names() {
    echo "Testing invalid branch names..."

    local invalid_branches=(
        "gitaiteams/issue-42-child-1-child-1"  # No grandchildren
        "gitaiteams/issue-42-child-6"          # Child > 5
        "gitaiteams/issue-42-child-0"          # Child < 1
        "gitaiteams/issue-42-subtask-1"        # Wrong pattern
        "gitaiteams/task-42"                   # Wrong prefix
        "issue-42"                             # Missing namespace
        "gitaiteams/issue-abc"                 # Non-numeric issue
        "gitaiteams/issue-42-task-1"           # Wrong suffix
    )

    for branch in "${invalid_branches[@]}"; do
        local reject_reason=""

        # Check for grandchildren
        if [[ "$branch" =~ child-.*child- ]]; then
            reject_reason="no grandchildren allowed"
            echo -e "${GREEN}✓${NC} Correctly rejected ($reject_reason): $branch"
            continue
        fi

        # Check child number range
        if [[ "$branch" =~ -child-([0-9]+)$ ]]; then
            local child_num="${BASH_REMATCH[1]}"
            if [[ "$child_num" -lt 1 ]] || [[ "$child_num" -gt 5 ]]; then
                reject_reason="child number out of range (1-5)"
                echo -e "${GREEN}✓${NC} Correctly rejected ($reject_reason): $branch"
                continue
            fi
        fi

        # Check for wrong patterns
        if [[ "$branch" =~ subtask|task- ]] || [[ ! "$branch" =~ ^gitaiteams/ ]]; then
            reject_reason="invalid pattern"
            echo -e "${GREEN}✓${NC} Correctly rejected ($reject_reason): $branch"
            continue
        fi

        # Check for non-numeric issue
        if [[ ! "$branch" =~ issue-[0-9]+ ]]; then
            reject_reason="non-numeric issue number"
            echo -e "${GREEN}✓${NC} Correctly rejected ($reject_reason): $branch"
            continue
        fi

        # If we got here and it matches valid pattern, that's wrong
        if [[ "$branch" =~ ^gitaiteams/issue-[0-9]+(-child-[1-5])?$ ]]; then
            echo -e "${RED}✗${NC} Should have rejected: $branch"
            return 1
        else
            echo -e "${GREEN}✓${NC} Correctly rejected: $branch"
        fi
    done
}

test_branch_hierarchy() {
    echo "Testing branch hierarchy rules..."

    # Root branch
    local root="gitaiteams/issue-42"
    if [[ ! "$root" =~ -child- ]]; then
        echo -e "${GREEN}✓${NC} Root branch identified: $root"
    else
        echo -e "${RED}✗${NC} Misidentified root: $root"
        return 1
    fi

    # Child branches
    local children=(
        "gitaiteams/issue-42-child-1"
        "gitaiteams/issue-42-child-2"
    )

    for child in "${children[@]}"; do
        if [[ "$child" =~ ^gitaiteams/issue-42-child-[0-9]+$ ]]; then
            echo -e "${GREEN}✓${NC} Valid child of issue-42: $child"
        else
            echo -e "${RED}✗${NC} Invalid child: $child"
            return 1
        fi
    done

    # Verify parent-child relationship
    local parent_issue="42"
    for child in "${children[@]}"; do
        if [[ "$child" =~ issue-${parent_issue}-child- ]]; then
            echo -e "${GREEN}✓${NC} Child belongs to correct parent: $child"
        else
            echo -e "${RED}✗${NC} Child has wrong parent: $child"
            return 1
        fi
    done
}

# Main
main() {
    local failed=0

    test_valid_branch_names || ((failed++))
    test_invalid_branch_names || ((failed++))
    test_branch_hierarchy || ((failed++))

    echo ""
    if [[ "$failed" -eq 0 ]]; then
        echo -e "${GREEN}=== BRANCH NAMING CONTRACT TEST PASSED ===${NC}"
        exit 0
    else
        echo -e "${RED}=== BRANCH NAMING CONTRACT TEST FAILED ===${NC}"
        exit 1
    fi
}

main "$@"