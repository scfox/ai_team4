#!/usr/bin/env bash
# T023: Update a single status comment instead of creating multiple comments
# Based on ai_team3 implementation

set -euo pipefail

# Configuration
STATUS_MARKER="<!-- gitai-status-comment -->"

# Find existing status comment or create new one
find_or_create_status_comment() {
    local issue_number="$1"
    local initial_status="$2"
    local repo="${GITHUB_REPOSITORY:-}"

    # Try to find existing status comment with our marker
    local comment_id
    comment_id=$(gh api "/repos/${repo}/issues/${issue_number}/comments" \
        --jq ".[] | select(.body | contains(\"${STATUS_MARKER}\")) | .id" \
        2>/dev/null | head -1) || true

    if [[ -z "$comment_id" ]]; then
        # Create new status comment with marker
        local start_time="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
        local body="${STATUS_MARKER}
## ⏳ GitAI Teams Status

**Status:** ${initial_status}
**Started:** ${start_time}
**Task:** Processing your request..."

        # Create comment and extract ID
        comment_id=$(gh issue comment "${issue_number}" \
            --repo "${repo}" \
            --body "${body}" \
            2>&1 | grep -oE '[0-9]+$') || {
            echo "ERROR: Failed to create status comment" >&2
            return 1
        }

        echo "Created new status comment: ${comment_id}" >&2
    else
        echo "Found existing status comment: ${comment_id}" >&2
    fi

    echo "${comment_id}"
}

# Update existing status comment
update_comment() {
    local comment_id="$1"
    local issue_number="$2"
    local status="$3"
    local message="${4:-Processing...}"
    local branch="${5:-}"
    local repo="${GITHUB_REPOSITORY:-}"

    # Get existing comment to preserve start time
    local existing_body
    existing_body=$(gh api "/repos/${repo}/issues/comments/${comment_id}" \
        --jq '.body' 2>/dev/null) || true

    # Extract start time from existing comment
    local start_time
    start_time=$(echo "$existing_body" | grep -oE '\*\*Started:\*\* [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC' | sed 's/\*\*Started:\*\* //') || true

    # If no start time found, use current time
    if [[ -z "$start_time" ]]; then
        start_time="$(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    fi

    # Format status emoji
    local status_emoji
    case "$status" in
        initializing) status_emoji="🔄" ;;
        analyzing) status_emoji="🔍" ;;
        spawning) status_emoji="🚀" ;;
        processing) status_emoji="⚙️" ;;
        completed) status_emoji="✅" ;;
        error) status_emoji="❌" ;;
        *) status_emoji="ℹ️" ;;
    esac

    # Build new body
    local new_body="${STATUS_MARKER}
## ⏳ GitAI Teams Status

**Status:** ${status_emoji} ${status}
**Started:** ${start_time}
**Message:** ${message}"

    # Add branch info if provided
    if [[ -n "$branch" ]]; then
        new_body="${new_body}
**Branch:** \`${branch}\`"
    fi

    # Add child status table if we have child branches
    if [[ -n "$branch" ]] && command -v derive_state.sh &>/dev/null; then
        # Source derive_state to get child status
        source "$(dirname "$0")/../derive_state.sh" 2>/dev/null || true

        if command -v get_child_branches &>/dev/null; then
            local child_branches=($(get_child_branches "$branch" 2>/dev/null || true))
            if [[ ${#child_branches[@]} -gt 0 ]]; then
                new_body="${new_body}

### 📊 Child Task Status

| Child | Branch | Status |
|-------|--------|--------|"

                for child_branch in "${child_branches[@]}"; do
                    local child_id="${child_branch##*-child-}"
                    local child_status="🔄 Running"

                    # Check if PR exists for this child
                    local pr_state=$(gh pr list --head="$child_branch" --json state --jq '.[0].state' 2>/dev/null || echo "")
                    if [[ "$pr_state" == "MERGED" ]]; then
                        child_status="✅ Complete"
                    elif [[ "$pr_state" == "OPEN" ]]; then
                        child_status="📝 PR Open"
                    fi

                    new_body="${new_body}
| C${child_id} | \`${child_branch}\` | ${child_status} |"
                done
            fi
        fi
    fi

    # Update the comment
    gh api "/repos/${repo}/issues/comments/${comment_id}" \
        --method PATCH \
        --field body="${new_body}" || {
        echo "ERROR: Failed to update status comment" >&2
        return 1
    }

    echo "Updated status comment ${comment_id}" >&2
}

# Main function
main() {
    local issue_number="${1:?Issue number required}"
    local status="${2:?Status required}"
    local message="${3:-}"
    local branch="${4:-}"

    # Ensure we have required environment
    if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
        echo "ERROR: GITHUB_REPOSITORY not set" >&2
        exit 1
    fi

    # Ensure we have GH token
    if [[ -z "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
        echo "ERROR: GH_TOKEN or GITHUB_TOKEN required" >&2
        exit 1
    fi

    # Find or create status comment
    local comment_id
    comment_id=$(find_or_create_status_comment "$issue_number" "$status")

    # Update the comment
    update_comment "$comment_id" "$issue_number" "$status" "$message" "$branch"

    # Return the comment ID for further updates
    echo "$comment_id"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}}" ]]; then
    main "$@"
fi