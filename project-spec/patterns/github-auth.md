# Pattern: GitHub Authentication in Actions

## Purpose
Properly authenticate git and GitHub CLI operations within workflows.

## Reference Implementation
See: `ai_team3/.github/workflows/ai-task-orchestrator.yml`

## Pattern

### Basic Setup
```yaml
# In workflow file
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # Automatically available
  GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}      # For gh CLI

permissions:
  contents: write      # For git operations
  issues: write        # For commenting
  pull-requests: write # For PR operations
  actions: write       # For workflow dispatch
```

### Git Configuration
```bash
# Configure git for commits
git config --global user.name "github-actions[bot]"
git config --global user.email "41898282+github-actions[bot]@users.noreply.github.com"
```

### Using GitHub CLI
```bash
# gh CLI automatically uses GH_TOKEN from environment
gh issue comment $ISSUE_NUMBER --body "Task started"
gh pr create --title "Results" --body "Task complete"
gh api /repos/{owner}/{repo}/dispatches --method POST
```

### Important Notes
- GITHUB_TOKEN is automatically provided, no setup needed
- Token has permissions based on workflow `permissions:` block
- Token CANNOT trigger other workflows directly (by design)
- Use repository_dispatch for cross-workflow communication

## What Works vs What Doesn't

### ✅ Works with GITHUB_TOKEN
- Git push to same repository
- Creating/updating issues and PRs
- repository_dispatch events
- Reading repository content

### ❌ Doesn't Work with GITHUB_TOKEN  
- Triggering workflows via workflow_dispatch
- Cross-repository operations (need PAT)
- Some GitHub App operations

## Security Best Practices
- Never log or echo tokens
- Use minimal required permissions
- Prefer GITHUB_TOKEN over custom PATs
- Don't pass tokens in command arguments (use env vars)