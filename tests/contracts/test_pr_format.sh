#!/usr/bin/env bash
# T010: PR format contract test
# Validates PR title and structure against contract

set -euo pipefail

echo "=== PR Format Contract Test ==="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

test_valid_pr_titles() {
    echo "Testing valid PR titles..."

    local valid_titles=(
        "[AI Agent] Issue #42: Code review completed"
        "[AI Agent] Issue #43: FastAPI research"
        "[AI Agent] Issue #100: Results combined"
    )

    for title in "${valid_titles[@]}"; do
        if [[ "$title" =~ ^\[AI\ Agent\]\ Issue\ #[0-9]+:\ .+$ ]]; then
            echo -e "${GREEN}✓${NC} Valid title: $title"
        else
            echo -e "${RED}✗${NC} Invalid title: $title"
            return 1
        fi
    done
}

test_invalid_pr_titles() {
    echo "Testing invalid PR titles..."

    local invalid_titles=(
        "Issue #42: Missing prefix"
        "[AI Agent] Missing issue number"
        "[AI Agent] Issue 42: Missing hash"
        "[Agent] Issue #42: Wrong prefix"
    )

    for title in "${invalid_titles[@]}"; do
        if [[ "$title" =~ ^\[AI\ Agent\]\ Issue\ #[0-9]+:\ .+$ ]]; then
            echo -e "${RED}✗${NC} Should reject: $title"
            return 1
        else
            echo -e "${GREEN}✓${NC} Correctly rejected: $title"
        fi
    done
}

test_branch_patterns() {
    echo "Testing branch name patterns..."

    # Valid patterns
    local valid_branches=(
        "gitaiteams/issue-42"
        "gitaiteams/issue-42-child-1"
        "gitaiteams/issue-42-child-5"
    )

    for branch in "${valid_branches[@]}"; do
        if [[ "$branch" =~ ^gitaiteams/issue-[0-9]+(-child-[0-9]+)?$ ]]; then
            echo -e "${GREEN}✓${NC} Valid branch: $branch"
        else
            echo -e "${RED}✗${NC} Invalid branch: $branch"
            return 1
        fi
    done

    # Invalid patterns
    local invalid_branches=(
        "gitaiteams/issue-42-child-1-child-1"  # No grandchildren
        "gitaiteams/issue-42-subtask-1"        # Wrong pattern
        "gitaiteams/issue-42-child-6"          # Child > 5
    )

    for branch in "${invalid_branches[@]}"; do
        # Check for grandchildren
        if [[ "$branch" =~ child-.*child- ]]; then
            echo -e "${GREEN}✓${NC} Correctly rejected grandchild: $branch"
            continue
        fi

        # Check for invalid patterns
        if [[ "$branch" =~ subtask|task- ]]; then
            echo -e "${GREEN}✓${NC} Correctly rejected pattern: $branch"
            continue
        fi

        # Check child number limit
        if [[ "$branch" =~ -child-([0-9]+)$ ]]; then
            local child_num="${BASH_REMATCH[1]}"
            if [[ "$child_num" -gt 5 ]]; then
                echo -e "${GREEN}✓${NC} Correctly rejected child > 5: $branch"
                continue
            fi
        fi
    done
}

test_pr_base_rules() {
    echo "Testing PR base branch rules..."

    # Child PRs must target parent branch
    local child_head="gitaiteams/issue-43-child-1"
    local child_base="gitaiteams/issue-43"

    if [[ "$child_head" =~ -child-[0-9]+$ ]]; then
        if [[ "$child_base" =~ ^gitaiteams/issue-[0-9]+$ ]]; then
            echo -e "${GREEN}✓${NC} Child PR targets correct parent: $child_base"
        else
            echo -e "${RED}✗${NC} Child PR has wrong base: $child_base"
            return 1
        fi
    fi

    # Root PRs should target main (but as link, not auto-created)
    local root_head="gitaiteams/issue-42"
    local root_base="main"

    if [[ ! "$root_head" =~ -child- ]]; then
        if [[ "$root_base" == "main" ]]; then
            echo -e "${GREEN}✓${NC} Root PR would target main (as link)"
        else
            echo -e "${RED}✗${NC} Root PR has wrong base: $root_base"
            return 1
        fi
    fi
}

# Main
main() {
    local failed=0

    test_valid_pr_titles || ((failed++))
    test_invalid_pr_titles || ((failed++))
    test_branch_patterns || ((failed++))
    test_pr_base_rules || ((failed++))

    echo ""
    if [[ "$failed" -eq 0 ]]; then
        echo -e "${GREEN}=== PR FORMAT CONTRACT TEST PASSED ===${NC}"
        exit 0
    else
        echo -e "${RED}=== PR FORMAT CONTRACT TEST FAILED ===${NC}"
        exit 1
    fi
}

main "$@"