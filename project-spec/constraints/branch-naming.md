# Constraint: Simplified Branch Naming

## Rule
Branch names follow a flat, predictable pattern with no nested hierarchies.

## Naming Convention

### Root Branch
```
gitaiteams/issue-{issue_number}
```

### Child Branches
```
gitaiteams/issue-{issue_number}-child-{sequential_number}
```

## Examples
```bash
# Issue #43 with 3 children:
gitaiteams/issue-43           # Root coordination branch
gitaiteams/issue-43-child-1   # First child
gitaiteams/issue-43-child-2   # Second child
gitaiteams/issue-43-child-3   # Third child

# Issue #100 with no children:
# No branches created (direct execution on main)
```

## NOT Allowed
```bash
# No nested hierarchies:
gitaiteams/issue-43/child-1/subchild-1  ❌

# No complex paths:
gitaiteams/main/issue-43/task-1/worker-1  ❌

# No UUID or timestamps:
gitaiteams/issue-43-child-a4f3d2e1  ❌
gitaiteams/issue-43-child-20240112-153022  ❌
```

## Implementation

### Creating Child Branch
```bash
# Simple sequential numbering
ISSUE_NUMBER=43
CHILD_COUNT=$(git branch -r | grep -c "gitaiteams/issue-${ISSUE_NUMBER}-child-" || echo 0)
NEXT_CHILD=$((CHILD_COUNT + 1))
CHILD_BRANCH="gitaiteams/issue-${ISSUE_NUMBER}-child-${NEXT_CHILD}"
```

### Identifying Branch Type
```python
def get_branch_type(branch_name):
    if "-child-" in branch_name:
        return "child"
    elif branch_name.startswith("gitaiteams/issue-"):
        return "root"
    else:
        return "unknown"
```

### Finding Parent Branch
```python
def get_parent_branch(child_branch):
    # gitaiteams/issue-43-child-1 -> gitaiteams/issue-43
    return child_branch.rsplit("-child-", 1)[0]
```

## Benefits
- Branch type immediately obvious from name
- Parent-child relationship explicit
- No parsing of complex paths needed
- Easy to grep/filter branches
- Sequential numbering prevents collisions