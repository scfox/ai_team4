# GitAI Teams - Multi-Agent GitHub Automation System

A distributed GitHub automation system that orchestrates multiple AI agents to handle complex software development tasks through parallel execution and automatic pull request generation.

## Overview

GitAI Teams enables automated task parallelization and coordination through GitHub Actions workflows. When mentioned via `@gitaiteams` in an issue, the system:

1. Analyzes the task for parallelization opportunities
2. Spawns child agents for independent subtasks
3. Coordinates execution and collects results
4. Creates pull requests with combined solutions

## Architecture

### Core Components

- **Task Router** (`.github/workflows/ai-task-router.yml`): Entry point that handles @gitaiteams mentions
- **Task Orchestrator** (`.github/workflows/ai-task-orchestrator.yml`): Manages task analysis and child spawning
- **Child Executor** (`.github/workflows/ai-child-executor.yml`): Executes individual subtasks in parallel

### Scripts

#### Bash Scripts (`scripts/bash/`)
- `spawn_child.sh`: Triggers child workflows via repository_dispatch
- `create_pr.sh`: Creates pull requests with proper formatting
- `derive_state.sh`: Derives state from git branches (stateless architecture)
- `post_comment.sh`: Posts status updates to issues

#### Python Scripts (`scripts/python/`)
- `analyze_task.py`: Detects parallelization keywords and extracts subtasks
- `combine_results.py`: Merges results from multiple child agents
- `generate_comparison.py`: Creates comparison tables for results

## Setup

### Prerequisites

1. GitHub repository with Actions enabled
2. Claude Code OAuth token for workflow triggering

### Installation

1. Clone this repository
2. Set up the required GitHub secret:
   ```
   CLAUDE_CODE_OAUTH_TOKEN: <your-token>
   ```
3. Ensure Python dependencies are installed:
   ```bash
   pip install pytest pyyaml
   ```

## Usage

### Basic Example

Create an issue with a @gitaiteams mention:

```markdown
@gitaiteams Please analyze and compare FastAPI vs Flask for our new API project
```

The system will:
1. Detect the comparison keyword
2. Spawn two parallel agents (one for FastAPI, one for Flask)
3. Combine results into a comparison table
4. Create a pull request with the analysis

### Parallelization Keywords

The system detects these keywords for automatic parallelization:
- `parallel`
- `compare`
- `both`
- `each`
- `multiple`
- Numbered lists (1., 2., etc.)
- Bullet points (-, *)

### Branch Naming Convention

- Parent branch: `gitaiteams/issue-{issue_number}`
- Child branches: `gitaiteams/issue-{issue_number}-child-{child_id}`

## Testing

### Run All Tests

```bash
# Python unit tests
pytest scripts/python/test_*.py -v

# Contract validation tests
bash tests/contracts/test_repository_dispatch.sh
bash tests/contracts/test_pr_format.sh
bash tests/contracts/test_issue_comment.sh
bash tests/contracts/test_branch_naming.sh

# Trace verification
bash tests/traces/verify_trace.sh
```

### Test Coverage

The test suite includes:
- Unit tests for all Python modules
- Contract tests for GitHub API interactions
- Trace tests for workflow execution patterns
- Integration tests for end-to-end scenarios

## Design Principles

### Stateless Architecture
- No STATE.json or persistent state files
- All state derived from git branches and GitHub API
- Idempotent operations throughout

### Single-Level Parallelism
- Parent spawns children directly
- No grandchildren (nested parallelism)
- Maximum 8 children per parent

### Trace Compliance
- Exact workflow counts must match specifications
- Single task: 2 workflows, 0 children
- Parallel task: 6 workflows, 2 children, 3 PRs

## Limitations

- Maximum 8 parallel subtasks
- 8-minute timeout per child execution
- 65KB limit for GitHub issue comments
- Single-level parallelism only

## Token Requirements

**Important**: Standard `GITHUB_TOKEN` cannot trigger workflows due to GitHub security limitations. You must use `CLAUDE_CODE_OAUTH_TOKEN` for repository_dispatch events.

## Contributing

1. Follow TDD: Write tests before implementation
2. Maintain stateless architecture
3. Use exact branch naming patterns
4. Ensure trace compliance

## License

MIT

## Support

For issues and questions, please open a GitHub issue in this repository.