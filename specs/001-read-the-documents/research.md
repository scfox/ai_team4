# Research Findings: GitAI Teams Implementation

## GitHub API and Actions Limits

### GitHub Issue Comment Size Limits
**Decision**: Limit responses to 65,000 characters with continuation strategy
**Rationale**: GitHub's API limit is 65,536 characters per comment. Need buffer for formatting.
**Alternatives considered**:
- Splitting into multiple comments (rejected - poor UX)
- Using gists for large outputs (rejected - adds complexity)
- Truncating with link to PR (selected as fallback)

### Repository Dispatch Payload Limits
**Decision**: Keep payloads under 64KB with essential data only
**Rationale**: GitHub's repository_dispatch event has a 65KB limit for the entire payload
**Alternatives considered**:
- Storing data in artifacts (rejected - adds latency)
- Using environment variables (rejected - not persistent across workflows)
- Minimal payload with branch reference (selected - state from git)

### GitHub Actions Workflow Concurrency
**Decision**: Use concurrency groups with cancel-in-progress for child workflows
**Rationale**: Prevents duplicate child execution and resource waste
**Alternatives considered**:
- No concurrency control (rejected - allows duplicates)
- Queue-based execution (rejected - adds complexity)
- Concurrency groups per issue (selected - clean isolation)

### GitHub Actions Timeout Handling
**Decision**: Set explicit timeouts: 5 min router, 8 min children, 10 min orchestrator
**Rationale**: Aligns with constitution requirements, provides clear failure modes
**Alternatives considered**:
- Default 6-hour timeout (rejected - too long for user experience)
- Dynamic timeouts (rejected - adds complexity)
- Fixed hierarchical timeouts (selected - predictable behavior)

## Workflow Architecture Decisions

### State Management Strategy
**Decision**: Derive all state from git branches and GitHub API
**Rationale**: Constitution requirement - stateless architecture
**Implementation**:
- Branch existence = task active
- PR existence = child complete
- PR merged = result available
- Issue comments = execution history

### Child Spawning Mechanism
**Decision**: Use repository_dispatch with custom event types
**Rationale**: Allows passing context while maintaining separation
**Payload Structure**:
```json
{
  "event_type": "child_task",
  "client_payload": {
    "parent_issue": 42,
    "child_number": 1,
    "task": "Research FastAPI",
    "parent_branch": "gitaiteams/issue-42"
  }
}
```

### PR Creation Strategy
**Decision**: Children auto-create PRs, parent provides PR link (not auto-create)
**Rationale**: Constitution specifies parent should not auto-create to main
**Implementation**:
- Children: gh pr create --base {parent_branch}
- Parent: Generate PR URL in comment for user to click

### Error Handling Patterns
**Decision**: Graceful degradation with clear status reporting
**Rationale**: Better UX than hard failures
**Strategies**:
- Child timeout: Continue with partial results, note timeout
- Child failure: Continue with successful children, note failures
- Invalid mention: Post helpful error message
- Rate limit: Fail fast with clear error

## Technical Implementation Details

### Branch Naming Convention
**Decision**: Strict pattern enforcement via regex
**Pattern**: `^gitaiteams/issue-\d+(-child-\d+)?$`
**Validation Points**:
- Workflow start
- PR creation
- State derivation

### Workflow Communication
**Decision**: Use GitHub native features only
**Mechanisms**:
- repository_dispatch for parent→child
- PR events for child→parent
- Issue comments for status updates
- Workflow artifacts for large data

### Trace Verification Method
**Decision**: Post-execution trace comparison
**Implementation**:
- Count workflow runs via gh api
- Match against trace.yml expected counts
- Fail CI if mismatch
**Rationale**: Ensures implementation matches specification exactly

### Python Script Boundaries
**Decision**: Python for logic only, never for git operations
**Rationale**: Constitution requirement - GitHub Actions security model
**Allowed Python Uses**:
- Task analysis (parallelization detection)
- Result combination (JSON merging)
- Report generation (markdown formatting)
**Forbidden**:
- Any git commands
- Any gh CLI calls
- Any file operations on .git/

## Performance Optimizations

### Parallel Execution Strategy
**Decision**: Fire-and-forget child spawning with PR-based collection
**Rationale**: Maximizes parallelism without polling
**Implementation**:
- Spawn all children immediately
- Each child works independently
- Parent resumes on PR events
- No busy-waiting or polling

### Workflow Startup Time
**Decision**: Minimize setup actions, use pre-installed tools
**Rationale**: Reduces time to actual work
**Optimizations**:
- Use actions/checkout@v4 (faster)
- Rely on pre-installed gh CLI
- Avoid unnecessary dependency installation
- Use Python stdlib only

### Result Caching
**Decision**: No caching - always fresh execution
**Rationale**: Stateless principle, avoid cache invalidation complexity
**Trade-off**: Accepts repeated work for simplicity

## Security Considerations

### Token Permissions
**Decision**: Use CLAUDE_CODE_OAUTH_TOKEN for AI operations, GITHUB_TOKEN for basic operations
**Rationale**: GITHUB_TOKEN has critical limitations discovered in ai_team3:
- Cannot trigger workflows via workflow_dispatch (GitHub security feature)
- Bot-created PRs don't trigger workflows (prevents infinite loops)
- Cannot use repository_dispatch from regular workflow context (401/403 errors)
- Push events from bot commits don't trigger workflows by default

**Previous Iteration Findings** (from ai_team3):
1. **The Core Problem**: GITHUB_TOKEN cannot trigger repository_dispatch or workflow_dispatch events to prevent infinite loops. This breaks parent→child spawning.
2. **Why It Matters**: Child agents must be spawned via repository_dispatch, but this fails with GITHUB_TOKEN.
3. **PAT Rejected**: Personal Access Tokens work but are insecure (too broad, tied to user, hard to rotate).
4. **The Discovery**: CLAUDE_CODE_OAUTH_TOKEN (from anthropics/claude-code-action@v1) has special permissions that allow repository_dispatch within Claude's execution context.

**Implementation Pattern** (proven in ai_team3):
```yaml
# This WORKS - Claude context has permissions
- uses: anthropics/claude-code-action@v1
  with:
    claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
    # Claude executes spawn_child.sh → repository_dispatch ✓

# This FAILS - Regular workflow context lacks permissions
- run: |
    gh api /repos/${{ github.repository }}/dispatches \
      --method POST \
      -H "Authorization: token ${{ secrets.GITHUB_TOKEN }}"
    # Results in 401/403 error ✗
```

**Critical Constraint**: CLAUDE_CODE_OAUTH_TOKEN is NOT a regular secret - it's only available within the Claude action context. This means:
- Parent orchestrator must run within Claude action
- Child spawning must happen from Claude's execution
- Cannot use token outside Claude action steps

**Required Permissions**:
- issues: write (for comments)
- contents: write (for branches/commits)
- pull-requests: write (for PR creation)
- actions: write (for repository_dispatch)
- workflows: write (for workflow triggering)
- id-token: write (for OIDC authentication with Claude)

### Input Validation
**Decision**: Validate all user input before execution
**Validation Points**:
- Issue number format
- Task description length
- Branch name patterns
- PR title/body content

### Secret Management
**Decision**: Dual token approach - CLAUDE_CODE_OAUTH_TOKEN + GITHUB_TOKEN
**Rationale**:
- CLAUDE_CODE_OAUTH_TOKEN for operations requiring elevated permissions
- GITHUB_TOKEN for standard operations
- Avoids PAT security risks
**Implication**: Requires setting up CLAUDE_CODE_OAUTH_TOKEN as repository secret

## Testing Strategy

### Trace Compliance Testing
**Decision**: Exact trace matching as primary acceptance test
**Implementation**:
- Run example scenarios
- Capture actual workflow counts
- Compare to trace.yml
- Fail if any deviation

### Integration Test Approach
**Decision**: Use real GitHub Actions in test repository
**Rationale**: Tests actual environment and permissions
**Test Cases**:
- Single task execution
- Parallel task execution
- Child failure handling
- Timeout scenarios

### Local Development Testing
**Decision**: Provide local simulation scripts
**Rationale**: Faster development iteration
**Components**:
- Mock gh CLI responses
- Simulate repository_dispatch
- Verify script logic
- Cannot test actual workflows locally

---

## Workflow Triggering Strategy (Lessons from ai_team3)

### The Triggering Challenge
**Problem**: GitHub's security model prevents workflows from triggering other workflows to avoid infinite loops.
**Impact**: Parent agents cannot spawn children using standard GitHub Actions.

### Failed Approaches (from ai_team3)
1. **Push Events**: Bot commits don't trigger workflows
2. **PR Events**: Bot-created PRs don't trigger workflows
3. **workflow_dispatch**: GITHUB_TOKEN cannot trigger it
4. **Regular repository_dispatch**: Fails with 401/403 from standard workflow context

### Working Solution
**Approach**: Use Claude action context for all workflow triggering
**Implementation**:
```yaml
# Router workflow (triggered by issue comment)
on:
  issue_comment:
    types: [created]
jobs:
  route:
    if: contains(github.event.comment.body, '@gitaiteams')
    steps:
      - uses: actions/checkout@v4
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          prompt: |
            Analyze task and spawn children if needed using:
            gh api /repos/$GITHUB_REPOSITORY/dispatches \
              --method POST \
              --field event_type=child_task \
              --field client_payload[issue_number]=$ISSUE_NUMBER
```

### Key Insight
The entire orchestration logic must run INSIDE the Claude action, not as separate workflow steps. This is because only the Claude action context has the permissions to trigger repository_dispatch events.

## Summary of Resolved Clarifications

All NEEDS CLARIFICATION items from the specification have been resolved:

1. **GitHub comment size**: 65,536 character limit
2. **Repository dispatch payload**: 65KB total limit
3. **Workflow concurrency**: Concurrency groups per issue
4. **Timeout strategy**: Hierarchical fixed timeouts
5. **State derivation**: From git branches and GitHub API
6. **Error handling**: Graceful degradation with status reporting
7. **PR creation**: Children auto-create, parent provides link
8. **Security model**: GITHUB_TOKEN only, validated inputs