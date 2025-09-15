#!/usr/bin/env bash
# T022: Post formatted comments to GitHub issues
# Follows constitution comment format requirements

set -euo pipefail

# Comment type headers
HEADER_RESULT="## 🤖 GitAI Teams Response"
HEADER_STATUS="## ⏳ Status Update"
HEADER_ERROR="## ❌ Error"

# Maximum comment size (GitHub limit)
MAX_COMMENT_SIZE=65536

# Function to post a result comment
post_result() {
    local issue_number=${1:?Issue number required}
    local content=${2:?Content required}
    local execution_time_ms=${3:-0}
    local children_spawned=${4:-0}

    local comment_body="${HEADER_RESULT}

${content}

---
*Execution time: $((execution_time_ms / 1000))s | Children spawned: ${children_spawned}*"

    # Check size and truncate if needed
    if [[ ${#comment_body} -gt $MAX_COMMENT_SIZE ]]; then
        local truncate_at=$((MAX_COMMENT_SIZE - 200))  # Leave room for notice
        comment_body="${comment_body:0:$truncate_at}

---
**Note**: Results truncated due to GitHub comment size limit (65,536 characters).
Full results available in the pull request."
    fi

    echo "Posting result comment to issue #${issue_number}"
    gh issue comment "${issue_number}" --body "${comment_body}"
}

# Function to post a status update
post_status() {
    local issue_number=${1:?Issue number required}
    local status_message=${2:?Status message required}
    local children_count=${3:-0}

    local comment_body="${HEADER_STATUS}

${status_message}"

    if [[ "$children_count" -gt 0 ]]; then
        comment_body="${comment_body}

**Child agents spawned**: ${children_count}
- Agents are working in parallel
- Results will be combined when all complete
- Maximum timeout: 8 minutes per child"
    fi

    comment_body="${comment_body}

---
*This is an automated status update*"

    echo "Posting status update to issue #${issue_number}"
    gh issue comment "${issue_number}" --body "${comment_body}"
}

# Function to post an error message
post_error() {
    local issue_number=${1:?Issue number required}
    local error_message=${2:?Error message required}
    local error_type=${3:-"general"}

    local comment_body="${HEADER_ERROR}

${error_message}"

    # Add helpful context based on error type
    case "$error_type" in
        "unclear_task")
            comment_body="${comment_body}

**What I need to help you**:
- A clear description of what you want me to do
- Specific tasks or questions
- Any relevant context or constraints

Please provide more details and mention @gitaiteams again."
            ;;
        "timeout")
            comment_body="${comment_body}

**Timeout Details**:
- Single tasks have a 5-minute limit
- Parallel tasks have a 10-minute limit
- Child agents have an 8-minute limit

The task was too complex or encountered an issue. Please try breaking it down into smaller tasks."
            ;;
        "rate_limit")
            comment_body="${comment_body}

**Rate Limit Information**:
- GitHub API rate limits have been exceeded
- Please wait before trying again
- Check your repository's API usage"
            ;;
        "permission")
            comment_body="${comment_body}

**Permission Issue**:
- The bot may lack necessary permissions
- Check that CLAUDE_CODE_OAUTH_TOKEN is configured
- Verify repository settings allow Actions"
            ;;
        *)
            comment_body="${comment_body}

If this error persists, please check:
1. The task description is clear
2. The repository has proper permissions configured
3. GitHub Actions are enabled"
            ;;
    esac

    echo "Posting error message to issue #${issue_number}"
    gh issue comment "${issue_number}" --body "${comment_body}"
}

# Function to post child results combined
post_combined_results() {
    local issue_number=${1:?Issue number required}
    local combined_content=${2:?Combined content required}
    local child_count=${3:?Child count required}
    local pr_link=${4:-}

    local comment_body="${HEADER_RESULT}

### Combined Results from ${child_count} Child Agents

${combined_content}"

    if [[ -n "$pr_link" ]]; then
        comment_body="${comment_body}

### Next Steps
${pr_link}"
    fi

    comment_body="${comment_body}

---
*All ${child_count} child agents completed successfully*"

    # Check size and truncate if needed
    if [[ ${#comment_body} -gt $MAX_COMMENT_SIZE ]]; then
        local truncate_at=$((MAX_COMMENT_SIZE - 200))
        comment_body="${comment_body:0:$truncate_at}

---
**Note**: Results truncated. See pull request for complete results."
    fi

    echo "Posting combined results to issue #${issue_number}"
    gh issue comment "${issue_number}" --body "${comment_body}"
}

# Function to update existing comment
update_comment() {
    local issue_number=${1:?Issue number required}
    local comment_id=${2:?Comment ID required}
    local new_content=${3:?New content required}

    echo "Updating comment ${comment_id} on issue #${issue_number}"
    gh api "/repos/${GITHUB_REPOSITORY}/issues/comments/${comment_id}" \
        --method PATCH \
        --field body="${new_content}"
}

# Main execution
main() {
    local action=${1:-}

    if [[ -z "$action" ]]; then
        echo "Usage: $0 <action> <issue_number> <content> [additional_args]"
        echo ""
        echo "Actions:"
        echo "  result <issue_number> <content> [execution_time_ms] [children_spawned]"
        echo "  status <issue_number> <message> [children_count]"
        echo "  error <issue_number> <message> [error_type]"
        echo "  combined <issue_number> <content> <child_count> [pr_link]"
        echo "  update <issue_number> <comment_id> <new_content>"
        exit 1
    fi

    # Ensure we have GH token
    if [[ -z "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
        echo "Error: GH_TOKEN or GITHUB_TOKEN required" >&2
        exit 1
    fi

    # Set repository if not set
    if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
        GITHUB_REPOSITORY=$(git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')
        export GITHUB_REPOSITORY
    fi

    case "$action" in
        result)
            shift
            post_result "$@"
            ;;
        status)
            shift
            post_status "$@"
            ;;
        error)
            shift
            post_error "$@"
            ;;
        combined)
            shift
            post_combined_results "$@"
            ;;
        update)
            shift
            update_comment "$@"
            ;;
        *)
            echo "Unknown action: $action"
            exit 1
            ;;
    esac
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi