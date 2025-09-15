# Testing Guide - GitAI Teams System

## Prerequisites

1. **GitHub Repository Setup**
   - Repository with Actions enabled
   - `CLAUDE_CODE_OAUTH_TOKEN` secret configured
   - Main branch protection rules (optional but recommended)

2. **Local Testing First**
   ```bash
   # Run all unit tests
   pytest scripts/python/test_*.py -v

   # Run contract tests
   bash tests/contracts/test_repository_dispatch.sh
   bash tests/contracts/test_pr_format.sh
   bash tests/contracts/test_issue_comment.sh
   bash tests/contracts/test_branch_naming.sh

   # Run trace verification
   bash tests/traces/verify_trace.sh
   ```

## End-to-End Testing Scenarios

### Test 1: Single Task Execution
**Purpose**: Verify basic workflow triggering and execution

1. Create a new issue:
   ```markdown
   Title: Test Single Task
   Body: @gitaiteams Please analyze the performance of our current API endpoints
   ```

2. **Expected Behavior**:
   - `ai-task-router` workflow triggers within 1 minute
   - `ai-task-orchestrator` workflow starts
   - No child workflows spawn (single task)
   - Branch `gitaiteams/issue-{number}` is created
   - Status comment posted to issue
   - PR created to main branch

3. **Verification Commands**:
   ```bash
   # Check workflow runs
   gh run list --workflow=ai-task-router.yml --limit 5
   gh run list --workflow=ai-task-orchestrator.yml --limit 5

   # Check branches
   git fetch --all
   git branch -r | grep gitaiteams

   # Check PR
   gh pr list --state all | grep gitaiteams
   ```

### Test 2: Parallel Task Execution
**Purpose**: Verify parallelization and child spawning

1. Create a new issue:
   ```markdown
   Title: Test Parallel Tasks
   Body: @gitaiteams Please compare FastAPI vs Flask for our new project
   ```

2. **Expected Behavior**:
   - `ai-task-router` workflow triggers
   - `ai-task-orchestrator` detects "compare" keyword
   - 2 `ai-child-executor` workflows spawn
   - Branches created:
     - `gitaiteams/issue-{number}` (parent)
     - `gitaiteams/issue-{number}-child-1` (FastAPI)
     - `gitaiteams/issue-{number}-child-2` (Flask)
   - 3 PRs created:
     - Child 1 → Parent
     - Child 2 → Parent
     - Parent → Main (with comparison table)

3. **Verification Commands**:
   ```bash
   # Check all workflow runs
   gh run list --limit 10

   # Verify child branches
   git branch -r | grep "gitaiteams/issue-.*-child"

   # Check repository_dispatch events (in Actions tab)
   gh api /repos/{owner}/{repo}/actions/runs \
     --jq '.workflow_runs[] | select(.event == "repository_dispatch")'
   ```

### Test 3: Multiple Subtasks
**Purpose**: Test numbered list detection

1. Create issue:
   ```markdown
   Title: Test Multiple Tasks
   Body:
   @gitaiteams Please help with:
   1. Set up authentication system
   2. Configure database connections
   3. Create API documentation
   ```

2. **Expected**: 3 child workflows, 4 total PRs

### Test 4: Error Handling
**Purpose**: Verify timeout and failure handling

1. Create issue with impossible task:
   ```markdown
   Title: Test Error Handling
   Body: @gitaiteams Please analyze all files in a 1TB repository
   ```

2. **Expected**: Timeout after 8 minutes, error comment posted

## Manual Verification Checklist

### Workflow Triggers
- [ ] Issue comment with @gitaiteams triggers router
- [ ] Router workflow completes successfully
- [ ] Orchestrator receives correct issue number
- [ ] Repository_dispatch events fire for children

### Branch Management
- [ ] Parent branch follows pattern: `gitaiteams/issue-{N}`
- [ ] Child branches follow pattern: `gitaiteams/issue-{N}-child-{M}`
- [ ] No grandchildren branches created
- [ ] Branches contain expected commits

### Pull Requests
- [ ] PRs have correct base/head branches
- [ ] PR descriptions follow template format
- [ ] Child PRs target parent branch
- [ ] Parent PR targets main branch
- [ ] Comparison tables rendered correctly

### State Management
- [ ] No STATE.json files created
- [ ] All state derived from git/GitHub API
- [ ] Workflows are idempotent
- [ ] Re-runs don't duplicate work

## Debugging Commands

```bash
# View workflow logs
gh run view {run-id} --log

# Check workflow dispatch payload
gh api /repos/{owner}/{repo}/actions/runs/{run-id} | jq .inputs

# List repository_dispatch events
gh api /repos/{owner}/{repo}/events | jq '.[] | select(.type == "RepositoryDispatchEvent")'

# Check branch protection
gh api /repos/{owner}/{repo}/branches/{branch}/protection

# View issue comments
gh issue view {number} --comments
```

## Common Issues & Solutions

### Issue: Workflows not triggering
**Solution**: Check CLAUDE_CODE_OAUTH_TOKEN is set correctly
```bash
gh secret list
```

### Issue: Repository_dispatch not working
**Solution**: Ensure using CLAUDE_CODE_OAUTH_TOKEN, not GITHUB_TOKEN
```yaml
# Correct
token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}

# Wrong - won't trigger workflows
token: ${{ secrets.GITHUB_TOKEN }}
```

### Issue: Child workflows timeout
**Solution**: Check 8-minute timeout limit, break down tasks further

### Issue: PRs not created
**Solution**: Verify branch exists and has commits
```bash
git log gitaiteams/issue-{number} --oneline
```

## Automated Test Suite

Run the full test suite:
```bash
#!/bin/bash
# test_system.sh

echo "=== GitAI Teams System Test ==="

# 1. Local tests
echo "Running local tests..."
pytest scripts/python/test_*.py -v
bash tests/contracts/test_*.sh
bash tests/traces/verify_trace.sh

# 2. Create test issue
echo "Creating test issue..."
ISSUE_NUM=$(gh issue create \
  --title "Automated Test $(date +%s)" \
  --body "@gitaiteams compare Python vs JavaScript" \
  | grep -o '[0-9]*$')

echo "Created issue #$ISSUE_NUM"

# 3. Wait and monitor
echo "Waiting for workflows..."
sleep 30

# 4. Check results
echo "Checking workflow runs..."
gh run list --workflow=ai-task-router.yml --limit 1

echo "Checking branches..."
git fetch --all
git branch -r | grep "gitaiteams/issue-$ISSUE_NUM"

echo "Test complete!"
```

## Success Criteria

The system is working correctly when:

1. **Single Task**: 2 workflows run, 1 PR created
2. **Parallel Task**: 6 workflows run, 3 PRs created
3. **Trace Compliance**: Actual counts match expected traces
4. **No State Files**: Find returns empty for STATE.json
5. **Proper Branching**: All branches follow naming convention
6. **Claude Integration**: CLAUDE_CODE_OAUTH_TOKEN triggers workflows

## Next Steps

After verifying the system works:

1. Add to production repository
2. Configure branch protection rules
3. Set up monitoring/alerts
4. Document team workflows
5. Create runbooks for common scenarios