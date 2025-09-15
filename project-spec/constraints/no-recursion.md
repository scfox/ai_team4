# Constraint: No Recursive Agent Spawning

## Rule
**Children cannot spawn grandchildren.** The system supports exactly two levels:
1. Root agent (triggered by @gitaiteams)
2. Child agents (spawned by root)

## Rationale
- Eliminates 80% of complexity
- Makes state management trivial
- Prevents infinite spawning bugs
- Simplifies debugging
- Covers 95% of real use cases

## Implementation Impact

### Branch Naming
```
# Allowed:
gitaiteams/issue-43           # Root branch
gitaiteams/issue-43-child-1   # Child branch
gitaiteams/issue-43-child-2   # Child branch

# NOT Allowed:
gitaiteams/issue-43-child-1-subchild-1  # No grandchildren
```

### State Derivation
```python
def get_state(issue_number):
    # Simple: Just count direct children
    children = count_branches(f"gitaiteams/issue-{issue_number}-child-*")
    completed = count_merged_prs(children)
    
    if children == 0:
        return "no_children"
    elif completed < children:
        return "children_running"
    else:
        return "children_complete"
```

### Spawn Logic
```bash
# Root agent CAN do this:
if [[ "$AGENT_TYPE" == "root" ]]; then
    ./spawn_child.sh "task description"
fi

# Child agent CANNOT do this:
if [[ "$AGENT_TYPE" == "child" ]]; then
    # No spawning allowed
    echo "Children cannot spawn grandchildren"
    exit 1
fi
```

## Benefits
- State machine has only 3 states instead of N
- No recursive tree traversal needed
- PR chains are single-level
- Testing is dramatically simpler
- No stack overflow possibilities