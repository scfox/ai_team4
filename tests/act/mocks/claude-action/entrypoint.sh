#!/usr/bin/env bash
# Mock Claude Code Action entrypoint
# Simulates Claude responses based on the scenario

set -euo pipefail

# Extract scenario from environment or prompt
SCENARIO="${MOCK_SCENARIO:-simple_task}"
PROMPT="${CLAUDE_PROMPT:-}"
REPO="${GITHUB_REPOSITORY:-fox/ai_team4}"
ISSUE="${ISSUE_NUMBER:-42}"

echo "=== Mock Claude Code Action ==="
echo "Scenario: $SCENARIO"
echo "Repository: $REPO"
echo "Issue: $ISSUE"

# Parse the prompt to determine what action to simulate
if echo "$PROMPT" | grep -q "repository_dispatch"; then
    echo "Detected repository_dispatch request in prompt"

    # Simulate executing the gh command
    if echo "$PROMPT" | grep -q "orchestrate_task"; then
        echo "Simulating orchestrator trigger..."
        echo "::notice::Mock: Would dispatch orchestrate_task event"

        # Create a mock dispatch record
        mkdir -p /tmp/act-mock-dispatches
        echo "{
            \"event_type\": \"orchestrate_task\",
            \"client_payload\": {
                \"issue_number\": \"$ISSUE\",
                \"comment_id\": \"0\",
                \"task\": \"Mock task from issue $ISSUE\"
            }
        }" > "/tmp/act-mock-dispatches/orchestrate_$ISSUE.json"

        echo "✓ Mock dispatch created: orchestrate_task for issue #$ISSUE"

    elif echo "$PROMPT" | grep -q "analyze_completions"; then
        echo "Simulating completion analyzer trigger..."
        echo "::notice::Mock: Would dispatch analyze_completions event"

        # Create mock completion analysis dispatch
        echo "{
            \"event_type\": \"analyze_completions\",
            \"client_payload\": {
                \"issue_number\": \"$ISSUE\",
                \"child_count\": \"3\",
                \"expected_count\": \"3\"
            }
        }" > "/tmp/act-mock-dispatches/completion_$ISSUE.json"

        echo "✓ Mock dispatch created: analyze_completions for issue #$ISSUE"
    fi

elif echo "$PROMPT" | grep -q "split.*into.*children"; then
    echo "Detected task splitting request"
    echo "Simulating task analysis and child creation..."

    # Simulate creating child branches and dispatches
    for i in 1 2 3; do
        echo "::notice::Mock: Would create branch gitaiteams/issue-$ISSUE-child-$i"
        echo "::notice::Mock: Would dispatch child_task event for child $i"

        mkdir -p /tmp/act-mock-branches
        echo "gitaiteams/issue-$ISSUE-child-$i" >> /tmp/act-mock-branches/created.txt
    done

    echo "✓ Mock: Created 3 child tasks"

elif echo "$PROMPT" | grep -q "merge.*strategy"; then
    echo "Detected merge strategy request"
    echo "Simulating completion analysis..."

    # Simulate Claude's merge strategy response
    cat << EOF
Based on the completion status:
- 3 children completed successfully
- All PRs ready for review

Recommended strategy: Sequential merge with validation
1. Merge child C1 PR first (foundational changes)
2. Merge child C2 PR (depends on C1)
3. Merge child C3 PR (integration)
EOF

    echo "✓ Mock: Provided merge strategy"

else
    echo "Generic task execution simulation"
    echo "::notice::Mock: Would perform task on issue #$ISSUE"

    # Based on scenario, simulate different behaviors
    case "$SCENARIO" in
        simple_task)
            echo "Executing simple task..."
            echo "✓ Task completed successfully"
            ;;
        parallel_task)
            echo "Analyzing task for parallelization..."
            echo "Task requires 3 parallel subtasks"
            ;;
        completion_detection)
            echo "Checking completion status..."
            echo "3 of 3 children completed"
            ;;
        error_case)
            echo "::error::Mock error: Simulated failure"
            exit 1
            ;;
        *)
            echo "Unknown scenario: $SCENARIO"
            ;;
    esac
fi

echo "=== Mock Claude Action Complete ====="