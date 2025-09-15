# Data Model: GitAI Teams

## Core Entities

### Issue
Represents a GitHub issue where @gitaiteams is mentioned.

**Attributes**:
- `number`: Integer - Issue number (e.g., 42)
- `title`: String - Issue title
- `body`: String - Issue description/comment with @gitaiteams mention
- `author`: String - GitHub username who created the issue
- `created_at`: Timestamp - When issue was created
- `repository`: String - Repository full name (owner/repo)

**State Transitions**:
- Created → Mentioned → Processing → Completed
- Created → Mentioned → Processing → Failed

**Validation Rules**:
- Number must be positive integer
- Body must contain "@gitaiteams"
- Repository must exist and be accessible

### Agent
Represents an AI agent (root or child) processing a task.

**Attributes**:
- `type`: Enum["root", "child"] - Agent hierarchy level
- `issue_number`: Integer - Parent issue number
- `child_number`: Integer|null - Child identifier (1-5) if child agent
- `branch_name`: String - Git branch for this agent
- `status`: Enum["spawned", "running", "completed", "failed", "timeout"]
- `task_description`: String - What the agent is doing
- `created_at`: Timestamp - When agent was spawned
- `completed_at`: Timestamp|null - When agent finished

**State Transitions**:
- Spawned → Running → Completed
- Spawned → Running → Failed
- Spawned → Running → Timeout

**Validation Rules**:
- Root agents: branch_name = "gitaiteams/issue-{number}"
- Child agents: branch_name = "gitaiteams/issue-{number}-child-{child_number}"
- Child_number must be between 1-5 if type is "child"
- Only root agents can spawn children
- Children cannot spawn grandchildren

### Task
Represents work to be performed by agents.

**Attributes**:
- `description`: String - Task description from issue
- `parallelizable`: Boolean - Whether task can be split
- `subtasks`: Array[String] - List of parallel subtasks if parallelizable
- `requires_children`: Boolean - Whether child agents needed
- `estimated_duration`: Integer - Expected minutes to complete

**State Transitions**:
- Received → Analyzed → Executing → Complete
- Received → Analyzed → Splitting → Executing → Complete

**Validation Rules**:
- Description must be non-empty
- If parallelizable, subtasks must have 2+ items
- Subtasks limited to 5 maximum
- Estimated duration must respect timeouts (5 min single, 10 min parallel)

### Result
Represents output from agent execution.

**Attributes**:
- `agent_branch`: String - Branch that produced this result
- `content`: String - Result content (markdown formatted)
- `format`: Enum["text", "table", "code", "mixed"] - Content format
- `size_bytes`: Integer - Size of content
- `truncated`: Boolean - Whether content was truncated
- `error`: String|null - Error message if failed

**State Transitions**:
- Generating → Available → Collected
- Generating → Failed

**Validation Rules**:
- Content must be valid markdown
- Size must be under 65,536 bytes for comments
- If truncated, must include truncation notice

### WorkflowRun
Represents a GitHub Actions workflow execution.

**Attributes**:
- `id`: Integer - GitHub's workflow run ID
- `workflow_name`: String - Name of workflow file
- `trigger_type`: Enum["issue_comment", "repository_dispatch", "pull_request"]
- `issue_number`: Integer - Related issue
- `branch`: String|null - Branch if applicable
- `status`: Enum["queued", "in_progress", "completed", "failed"]
- `conclusion`: Enum["success", "failure", "timeout", "cancelled"]|null
- `started_at`: Timestamp - Execution start time
- `completed_at`: Timestamp|null - Execution end time

**State Transitions**:
- Queued → In_progress → Completed
- Queued → Cancelled
- In_progress → Failed

**Validation Rules**:
- Workflow_name must be one of: ai-task-router, ai-task-orchestrator, ai-child-executor
- Trigger_type must match workflow (router=issue_comment, etc.)
- Must respect concurrency groups

### PullRequest
Represents PRs created by agents.

**Attributes**:
- `number`: Integer - PR number
- `title`: String - PR title with format "[AI Agent] Issue #{n}: {description}"
- `source_branch`: String - Branch with changes
- `target_branch`: String - Branch to merge into
- `agent_type`: Enum["child", "root"] - Creator type
- `issue_number`: Integer - Related issue
- `state`: Enum["open", "merged", "closed"]
- `created_at`: Timestamp - PR creation time
- `merged_at`: Timestamp|null - When merged

**State Transitions**:
- Open → Merged
- Open → Closed

**Validation Rules**:
- Child PRs target parent branch
- Root PRs target main (link only, not auto-created)
- Title must follow format convention
- Source branch must exist
- Target branch must exist

## Relationships

```mermaid
graph TD
    Issue ||--|| RootAgent : triggers
    RootAgent ||--o{ ChildAgent : spawns
    RootAgent ||--|| Task : processes
    Task ||--o{ Subtask : contains
    ChildAgent ||--|| Subtask : processes
    RootAgent ||--o{ WorkflowRun : executes
    ChildAgent ||--o{ WorkflowRun : executes
    ChildAgent ||--|| PullRequest : creates
    RootAgent ||--o| PullRequest : suggests
    ChildAgent ||--|| Result : produces
    RootAgent ||--|| Result : combines
    PullRequest ||--|| Result : contains
```

## State Derivation

Since the system is stateless, all entity states are derived:

### Issue State
```bash
# Derive from GitHub API
gh issue view {number} --json state,labels,comments
```

### Agent State
```bash
# Derive from branches
git branch -r | grep "gitaiteams/issue-{number}"
# If branch exists: agent active
# If PR exists: agent completed
# If PR merged: result available
```

### Task State
```bash
# Derive from workflow runs
gh run list --workflow=ai-task-orchestrator.yml \
  --json status,conclusion,createdAt
```

### Result State
```bash
# Derive from PR files
gh pr view {pr_number} --json files
# Check for RESULTS.md or similar
```

## Data Flow

1. **Issue Comment** → Creates Issue entity
2. **Router Workflow** → Creates WorkflowRun entity
3. **Orchestrator** → Creates RootAgent, analyzes Task
4. **Child Spawn** → Creates ChildAgent entities
5. **Child Execution** → Creates child WorkflowRun, Result
6. **Child PR** → Creates PullRequest entity
7. **Parent Resume** → Collects Results, combines
8. **Final Comment** → Updates Issue with combined Result

## Constraints

- No persistent storage - all data derived from GitHub
- No state files (STATE.json, etc.)
- Maximum 5 child agents per issue
- Single level hierarchy (no grandchildren)
- All operations atomic via git commits
- State transitions verified via traces