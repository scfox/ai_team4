# Pattern: Repository Dispatch for Child Spawning

## Purpose
Trigger child agent workflows without recursive workflow calls.

## Reference Implementation
See: `ai_team3/scripts/spawn_child.sh` and `ai_team3/scripts/publish_event.sh`

## Pattern

### Triggering Child Workflow
```bash
# Use repository_dispatch to trigger child executor
gh api /repos/${GITHUB_REPOSITORY}/dispatches \
  --method POST \
  --field event_type="child-task" \
  --field client_payload[task]="Research FastAPI" \
  --field client_payload[branch]="gitaiteams/issue-43-child-1" \
  --field client_payload[parent]="gitaiteams/issue-43" \
  --field client_payload[issue_number]=43
```

### Receiving in Child Workflow
```yaml
# .github/workflows/child-executor.yml
on:
  repository_dispatch:
    types: [child-task]

jobs:
  execute:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout child branch
        run: |
          git fetch origin ${{ github.event.client_payload.branch }}
          git checkout ${{ github.event.client_payload.branch }}
      
      - name: Execute task
        run: |
          echo "Task: ${{ github.event.client_payload.task }}"
          # Claude executes task here
```

## Key Points
- `repository_dispatch` events work with GITHUB_TOKEN
- Payload passes all context needed by child
- No workflow recursion or circular dependencies
- Clean separation between orchestrator and executor

## Common Pitfalls to Avoid
- Don't use `workflow_dispatch` - requires different permissions
- Don't try to wait for child completion - be event-driven
- Don't pass sensitive data in payload - use secrets