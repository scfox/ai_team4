#!/usr/bin/env bash
# T021: Derive state from git branches and GitHub API
# Stateless architecture - no STATE.json files

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to get current issue state
get_issue_state() {
    local issue_number=${1:?Issue number required}

    echo "Deriving state for issue #${issue_number}..."

    # Check if issue exists and is open
    local issue_state=$(gh issue view "${issue_number}" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")

    if [[ "$issue_state" == "CLOSED" ]]; then
        echo "Issue #${issue_number} is closed"
        return 1
    elif [[ "$issue_state" == "UNKNOWN" ]]; then
        echo "Issue #${issue_number} not found" >&2
        return 1
    fi

    echo "Issue #${issue_number} is ${issue_state}"
    return 0
}

# Function to count child branches
count_children() {
    local issue_number=${1:?Issue number required}

    # Count child branches for this issue
    local child_count=0
    local child_branches=$(git branch -r 2>/dev/null | grep "gitaiteams/issue-${issue_number}-child-" || true)

    if [[ -n "$child_branches" ]]; then
        child_count=$(echo "$child_branches" | wc -l | tr -d ' ')
    fi

    echo "$child_count"
}

# Function to check child PR status
get_child_pr_status() {
    local issue_number=${1:?Issue number required}
    local parent_branch="gitaiteams/issue-${issue_number}"

    echo "Checking child PR status..."

    # Get PRs targeting the parent branch
    local pr_data=$(gh pr list --base "${parent_branch}" --json number,state,headRefName 2>/dev/null || echo "[]")

    # Count open and merged PRs
    local open_prs=$(echo "$pr_data" | jq '[.[] | select(.state == "OPEN")] | length')
    local merged_prs=$(echo "$pr_data" | jq '[.[] | select(.state == "MERGED")] | length')

    echo "Open PRs: ${open_prs}"
    echo "Merged PRs: ${merged_prs}"

    # Return status
    echo "open=${open_prs},merged=${merged_prs}"
}

# Function to derive complete system state
derive_system_state() {
    local issue_number=${1:?Issue number required}

    echo ""
    echo "=== System State for Issue #${issue_number} ==="
    echo ""

    # Check issue state
    if ! get_issue_state "${issue_number}"; then
        return 1
    fi

    # Check for parent branch
    local parent_branch="gitaiteams/issue-${issue_number}"
    local parent_exists=$(git branch -r 2>/dev/null | grep -c "origin/${parent_branch}$" || echo "0")

    if [[ "$parent_exists" -eq 0 ]]; then
        echo -e "${YELLOW}State:${NC} NO_PARENT_BRANCH"
        echo "  → No AI agent has started processing this issue yet"
        return 0
    fi

    echo -e "${GREEN}✓${NC} Parent branch exists: ${parent_branch}"

    # Count children
    local child_count=$(count_children "${issue_number}")
    echo "Child agents spawned: ${child_count}"

    if [[ "$child_count" -eq 0 ]]; then
        echo -e "${YELLOW}State:${NC} SINGLE_TASK"
        echo "  → Task is being processed directly (no parallelization)"
    else
        # Check child PR status
        local pr_status=$(get_child_pr_status "${issue_number}")
        eval "$pr_status"  # Sets open and merged variables

        if [[ "$merged" -eq "$child_count" ]]; then
            echo -e "${GREEN}State:${NC} CHILDREN_COMPLETE"
            echo "  → All ${child_count} children have completed and merged"
            echo "  → Ready to combine results and respond"
        elif [[ "$((open + merged))" -eq "$child_count" ]]; then
            echo -e "${YELLOW}State:${NC} CHILDREN_RUNNING"
            echo "  → ${open} children still running"
            echo "  → ${merged} children completed"
        else
            local spawned=$child_count
            local with_prs=$((open + merged))
            local pending=$((spawned - with_prs))
            echo -e "${YELLOW}State:${NC} CHILDREN_SPAWNING"
            echo "  → ${spawned} children spawned"
            echo "  → ${with_prs} have created PRs"
            echo "  → ${pending} still initializing"
        fi
    fi

    # Check for forbidden patterns (constitution violations)
    echo ""
    echo "Constitution compliance check:"

    # Check for grandchildren (forbidden)
    local grandchildren=$(git branch -r 2>/dev/null | grep -c "child-.*child-" || echo "0")
    if [[ "$grandchildren" -gt 0 ]]; then
        echo -e "${RED}✗${NC} VIOLATION: Found grandchildren branches (no recursion allowed)"
    else
        echo -e "${GREEN}✓${NC} No grandchildren (single-level parallelism maintained)"
    fi

    # Check for state files (forbidden)
    local state_files=$(find . -name "STATE.json" -o -name "*.state" 2>/dev/null | head -5)
    if [[ -n "$state_files" ]]; then
        echo -e "${RED}✗${NC} VIOLATION: Found state files (stateless architecture required)"
        echo "$state_files"
    else
        echo -e "${GREEN}✓${NC} No state files (stateless architecture maintained)"
    fi

    # Check child count limit
    if [[ "$child_count" -gt 5 ]]; then
        echo -e "${RED}✗${NC} VIOLATION: Too many children (${child_count} > 5)"
    else
        echo -e "${GREEN}✓${NC} Child count within limit (${child_count} ≤ 5)"
    fi

    echo ""
    return 0
}

# Function to get workflow run status
get_workflow_status() {
    local issue_number=${1:?Issue number required}

    echo "Recent workflow runs for issue #${issue_number}:"

    # Get recent workflow runs
    gh run list --limit 10 --json name,status,conclusion,createdAt \
        --jq '.[] | "\(.createdAt | split("T")[0]) \(.name): \(.status) (\(.conclusion // "running"))"' \
        2>/dev/null | head -5 || echo "No recent runs found"
}

# Main execution
main() {
    local command=${1:-state}
    local issue_number=${2:-}

    case "$command" in
        state)
            if [[ -z "$issue_number" ]]; then
                echo "Usage: $0 state <issue_number>"
                exit 1
            fi
            derive_system_state "$issue_number"
            ;;
        children)
            if [[ -z "$issue_number" ]]; then
                echo "Usage: $0 children <issue_number>"
                exit 1
            fi
            count_children "$issue_number"
            ;;
        prs)
            if [[ -z "$issue_number" ]]; then
                echo "Usage: $0 prs <issue_number>"
                exit 1
            fi
            get_child_pr_status "$issue_number"
            ;;
        workflows)
            if [[ -z "$issue_number" ]]; then
                echo "Usage: $0 workflows <issue_number>"
                exit 1
            fi
            get_workflow_status "$issue_number"
            ;;
        *)
            echo "Commands: state, children, prs, workflows"
            echo "Usage: $0 <command> <issue_number>"
            exit 1
            ;;
    esac
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Ensure we have GH token
    if [[ -z "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
        export GH_TOKEN="${GITHUB_TOKEN:-}"
    fi

    main "$@"
fi