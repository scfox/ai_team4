#!/usr/bin/env bash
# T019: Spawn child agent via repository_dispatch
# IMPORTANT: Must be called from within Claude action context for permissions

set -euo pipefail

# Function to spawn a child agent
spawn_child() {
    local issue_number=${1:?Issue number required}
    local child_number=${2:?Child number required}
    local task=${3:?Task description required}
    local parent_branch=${4:-"gitaiteams/issue-${issue_number}"}

    # Validate child number (constitution limit: max 5)
    if [[ "$child_number" -lt 1 ]] || [[ "$child_number" -gt 5 ]]; then
        echo "Error: Child number must be between 1 and 5" >&2
        return 1
    fi

    # Validate parent branch pattern
    if [[ ! "$parent_branch" =~ ^gitaiteams/issue-[0-9]+$ ]]; then
        echo "Error: Invalid parent branch pattern: $parent_branch" >&2
        return 1
    fi

    echo "Spawning child agent #${child_number} for issue #${issue_number}"
    echo "Task: ${task}"
    echo "Parent branch: ${parent_branch}"

    # Trigger child via repository_dispatch
    # NOTE: This requires CLAUDE_CODE_OAUTH_TOKEN permissions
    gh api "/repos/${GITHUB_REPOSITORY}/dispatches" \
        --method POST \
        --field event_type="child_task" \
        --field "client_payload[issue_number]=${issue_number}" \
        --field "client_payload[child_number]=${child_number}" \
        --field "client_payload[parent_branch]=${parent_branch}" \
        --field "client_payload[task]=${task}"

    if [[ $? -eq 0 ]]; then
        echo "✓ Successfully spawned child agent #${child_number}"
        return 0
    else
        echo "✗ Failed to spawn child agent #${child_number}" >&2
        return 1
    fi
}

# Main execution
main() {
    if [[ $# -lt 3 ]]; then
        echo "Usage: $0 <issue_number> <child_number> <task> [parent_branch]"
        echo "Example: $0 42 1 'Research FastAPI' 'gitaiteams/issue-42'"
        exit 1
    fi

    # Check if we're in a context with proper permissions
    if [[ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]] && [[ -z "${GITHUB_TOKEN:-}" ]]; then
        echo "Warning: No authentication token found. This script requires proper GitHub permissions." >&2
        echo "It should be run from within a Claude action or with appropriate tokens." >&2
    fi

    # Set GitHub repository if not already set
    if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
        # Try to get from git remote
        GITHUB_REPOSITORY=$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
        export GITHUB_REPOSITORY
    fi

    spawn_child "$@"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi