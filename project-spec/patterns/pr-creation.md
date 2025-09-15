# Pattern: Pull Request Creation and Management

## Purpose
Create PRs from child branches back to parent, and from parent to main.

## Reference Implementation
See: `ai_team3/scripts/process_pr.sh`

## Pattern

### Child Creating PR to Parent
```bash
# In child agent after task completion
CHILD_BRANCH="gitaiteams/issue-43-child-1"
PARENT_BRANCH="gitaiteams/issue-43"

# Create PR from child to parent
gh pr create \
  --base "$PARENT_BRANCH" \
  --head "$CHILD_BRANCH" \
  --title "Child 1: FastAPI Research Complete" \
  --body "## Results
  
Research findings for FastAPI:
- High performance async framework
- Built-in validation with Pydantic
- Automatic API documentation

See RESULTS.md for full details."
```

### Parent Merging Child PRs
```bash
# Check for open PRs from children
PARENT_BRANCH="gitaiteams/issue-43"
CHILD_PRS=$(gh pr list --base "$PARENT_BRANCH" --state open --json number,headRefName)

# Merge each child PR
for pr in $(echo "$CHILD_PRS" | jq -r '.[].number'); do
  gh pr merge "$pr" --merge --delete-branch
done
```

### Parent Creating Final PR to Main
```bash
# After all children complete
PARENT_BRANCH="gitaiteams/issue-43"

# Create summary PR to main
gh pr create \
  --base "main" \
  --head "$PARENT_BRANCH" \
  --title "Issue #43: Framework Comparison Complete" \
  --body "## Summary

Parallel analysis of FastAPI and Flask completed by 2 agents.

### Results:
- Child 1: FastAPI research
- Child 2: Flask research

Combined comparison table available in RESULTS.md

Closes #43"
```

## State Detection via PRs

### Check if Children Complete
```python
def are_children_complete(parent_branch):
    """Check if all child PRs are merged."""
    # Get all PRs (open and closed) targeting parent
    all_prs = gh_api(f"pulls?base={parent_branch}&state=all")
    child_prs = [pr for pr in all_prs if "child" in pr['head']['ref']]
    
    if not child_prs:
        return False  # No children yet
    
    # All must be merged
    return all(pr['merged_at'] is not None for pr in child_prs)
```

## Key Points
- PRs serve as both communication and state tracking
- PR merge status indicates task completion
- PR descriptions carry task results
- No separate state files needed

## Best Practices
- Always include issue number in PR title
- Link to parent issue with "Closes #X"
- Delete branches after merge to keep repo clean
- Use PR labels for additional metadata if needed