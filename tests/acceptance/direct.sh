#!/bin/bash
# Quick system test script

echo "=== GitAI Teams System Test ==="

# Check if CLAUDE_CODE_OAUTH_TOKEN is set
if ! gh secret list | grep -q CLAUDE_CODE_OAUTH_TOKEN; then
    echo "❌ CLAUDE_CODE_OAUTH_TOKEN not found in secrets"
    echo "Please set it up first: gh secret set CLAUDE_CODE_OAUTH_TOKEN"
    exit 1
fi

echo "✅ Token configured"

# Create test issue
echo "Creating test issue..."
ISSUE_NUM=$(gh issue create \
    --title "Test: Single Task $(date +%s)" \
    --body "@gitaiteams Please analyze our current codebase structure" \
    2>/dev/null | grep -o '[0-9]*$')

if [ -z "$ISSUE_NUM" ]; then
    echo "❌ Failed to create issue"
    exit 1
fi

echo "✅ Created issue #$ISSUE_NUM"
echo "📎 URL: $(gh issue view $ISSUE_NUM --json url -q .url)"

# Wait for workflows to trigger
echo "Waiting 30s for workflows to trigger..."
sleep 30

# Check if workflows triggered
echo ""
echo "Checking workflow runs..."
ROUTER_RUN=$(gh run list --workflow=ai-task-router.yml --limit 1 --json status,conclusion,databaseId -q '.[0]')

if [ -z "$ROUTER_RUN" ]; then
    echo "❌ Router workflow didn't trigger"
    echo "Check: Is the workflow file enabled? Does it have the right trigger?"
else
    echo "✅ Router workflow triggered"

    # Check orchestrator
    ORCH_RUN=$(gh run list --workflow=ai-task-orchestrator.yml --limit 1 --json status,conclusion -q '.[0]')
    if [ -n "$ORCH_RUN" ]; then
        echo "✅ Orchestrator workflow triggered"
    else
        echo "⚠️  Orchestrator workflow not found (may still be starting)"
    fi
fi

# Check for branches
echo ""
echo "Checking for branches..."
git fetch --all 2>/dev/null
BRANCH=$(git branch -r | grep "gitaiteams/issue-$ISSUE_NUM" | head -1)

if [ -n "$BRANCH" ]; then
    echo "✅ Branch created: $BRANCH"
else
    echo "⚠️  Branch not created yet (workflows may still be running)"
fi

# Summary
echo ""
echo "=== Test Summary ==="
echo "Issue #$ISSUE_NUM created"
echo "Check progress at: $(gh issue view $ISSUE_NUM --json url -q .url)"
echo ""
echo "Monitor workflows at:"
echo "  gh run watch"
echo ""
echo "View logs with:"
echo "  gh run list --limit 5"
echo "  gh run view [run-id] --log"