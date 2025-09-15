# GitAI Teams - Quick Start Guide

## 🚀 Getting Started

GitAI Teams is a GitHub Actions-based multi-agent system that responds to @gitaiteams mentions in issues, automatically parallelizes tasks when beneficial, and posts comprehensive results back to your issues.

## Prerequisites

- GitHub repository with Actions enabled
- Write permissions for issues and pull requests
- GitHub Actions minutes available on your account

## Installation

1. **Copy the workflow files** to your repository:
   ```
   .github/workflows/
   ├── ai-task-router.yml
   ├── ai-task-orchestrator.yml
   └── ai-child-executor.yml
   ```

2. **Copy the supporting scripts**:
   ```
   scripts/
   ├── bash/
   │   ├── spawn_child.sh
   │   ├── create_pr.sh
   │   ├── derive_state.sh
   │   └── post_comment.sh
   └── python/
       ├── analyze_task.py
       ├── combine_results.py
       └── generate_comparison.py
   ```

3. **Ensure permissions** in your repository settings:
   - Actions: Read and write permissions
   - Pull requests: Allow GitHub Actions to create and approve pull requests

## Basic Usage

### Single Task Execution

1. **Create an issue or add a comment** with @gitaiteams mention:

   You can trigger GitAI Teams in two ways:
   - **New Issue**: Include @gitaiteams in the issue body when creating it
   - **Issue Comment**: Add @gitaiteams in any comment on an existing issue

   Example:
   ```markdown
   @gitaiteams

   Please review this Python function and suggest improvements:

   ```python
   def calculate_average(numbers):
       total = 0
       count = 0
       for n in numbers:
           total = total + n
           count = count + 1
       return total / count
   ```
   ```

2. **Watch the execution**:
   - A label `trigger:ai-task` will be added
   - Check Actions tab for workflow progress
   - Results will be posted as a comment within 5 minutes

### Parallel Task Execution

1. **Request parallel work**:
   ```markdown
   @gitaiteams

   Compare these two web frameworks in parallel:
   1. FastAPI - Research performance, features, and ecosystem
   2. Flask - Research performance, features, and ecosystem

   Create a comparison table with your findings.
   ```

2. **Monitor parallel execution**:
   - Status comment shows "Spawning 2 child agents"
   - Multiple branches created: `gitaiteams/issue-N-child-1`, `gitaiteams/issue-N-child-2`
   - Child PRs created to parent branch
   - Final combined results posted within 10 minutes

## Expected Behaviors

### Successful Execution Flow

1. **Router Stage** (1-2 seconds):
   - Detects @gitaiteams mention
   - Adds label to issue
   - Triggers orchestrator

2. **Orchestrator Stage** (varies):
   - Analyzes task complexity
   - For simple tasks: Executes directly
   - For parallel tasks: Creates branches and spawns children

3. **Child Execution** (if parallel):
   - Each child works independently
   - Creates PR when complete
   - Parent resumes on PR creation

4. **Result Posting**:
   - Combined results posted to issue
   - Link to create PR provided (not auto-created)

### Status Updates

The system provides updates during long-running operations:

```markdown
## ⏳ Status Update

Spawning 2 child agents to research frameworks in parallel...
- Child 1: Researching FastAPI
- Child 2: Researching Flask

This may take a few minutes.
```

### Error Handling

If something goes wrong, you'll see:

```markdown
## ❌ Error

Not sure what you are asking me to do here. Could you please:
- Provide a clear task description
- Specify what you'd like me to analyze or create
```

## Monitoring Execution

### Via GitHub UI

1. **Actions Tab**: See all workflow runs
   - Filter by workflow name
   - Check run status and logs

2. **Branches**: Monitor agent branches
   ```bash
   gitaiteams/issue-42        # Root agent branch
   gitaiteams/issue-42-child-1 # Child agent branch
   ```

3. **Pull Requests**: Track child completions
   - Child PRs to parent branch
   - Final PR link in issue comment

### Via GitHub CLI

```bash
# Check workflow runs
gh run list --workflow=ai-task-orchestrator.yml

# Monitor branches
git branch -r | grep gitaiteams

# View child PRs
gh pr list --base gitaiteams/issue-42

# Check issue comments
gh issue view 42 --comments
```

## Debugging Failed Runs

### Common Issues and Solutions

1. **No response to @gitaiteams**:
   - Check if Actions are enabled
   - Verify workflow files are in `.github/workflows/`
   - Check Actions tab for failed router workflow

2. **Timeout errors**:
   - Single tasks have 5-minute limit
   - Parallel tasks have 10-minute limit
   - Child agents timeout after 8 minutes

3. **Child agent failures**:
   - System continues with partial results
   - Check individual child workflow logs
   - Failed children noted in final response

4. **Rate limit errors**:
   - GitHub API rate limits apply
   - Wait before retrying
   - Consider reducing parallel children

### Viewing Logs

```bash
# Get latest run ID
RUN_ID=$(gh run list --workflow=ai-task-orchestrator.yml --limit 1 --json databaseId -q '.[0].databaseId')

# View run logs
gh run view $RUN_ID --log

# Download logs for detailed analysis
gh run download $RUN_ID
```

## Verification

### Running Trace Tests

Verify your installation works correctly:

```bash
# Run single task test
./tests/integration/test_single_task.sh

# Run parallel task test
./tests/integration/test_parallel_task.sh

# Verify traces match expected
./tests/traces/verify_trace.sh
```

Expected output:
```
✅ Single task trace matches (2 workflows, 0 children)
✅ Parallel task trace matches (6 workflows, 2 children)
✅ All tests passed
```

## Limitations

- **No recursive spawning**: Children cannot create grandchildren
- **Max 5 parallel children**: Resource constraint
- **65K character limit**: GitHub comment size restriction
- **Stateless operation**: No persistence between runs
- **GitHub-only**: Cannot interact with external services

## Best Practices

1. **Clear task descriptions**: Be specific about what you want
2. **Indicate parallelization**: Use words like "compare", "both", "each"
3. **Break down complex tasks**: Explicitly list subtasks for parallel execution
4. **Monitor long tasks**: Check Actions tab for tasks over 3 minutes
5. **Review PRs before merging**: System provides links but doesn't auto-merge to main

## Troubleshooting

### Enable Debug Logging

Add to your workflow:
```yaml
env:
  ACTIONS_RUNNER_DEBUG: true
  ACTIONS_STEP_DEBUG: true
```

### Manual Cleanup

If agents leave branches behind:
```bash
# List all GitAI branches
git branch -r | grep gitaiteams

# Delete specific branch
git push origin --delete gitaiteams/issue-42-child-1

# Clean all GitAI branches for an issue
for branch in $(git branch -r | grep "gitaiteams/issue-42"); do
  git push origin --delete ${branch#origin/}
done
```

## Example Scenarios

### Code Review
```markdown
@gitaiteams review this code for security issues and performance
```

### Documentation Generation
```markdown
@gitaiteams generate API documentation for the functions in api.py
```

### Parallel Research
```markdown
@gitaiteams research these topics in parallel:
1. Best practices for GitHub Actions
2. Python async programming patterns
3. Docker container optimization
```

### Comparison Task
```markdown
@gitaiteams compare pytest vs unittest frameworks across:
- Ease of use
- Features
- Performance
- Community support
```

---

## Next Steps

1. Try a simple task with @gitaiteams
2. Test parallel execution with a comparison task
3. Review the generated branches and PRs
4. Customize scripts for your specific needs

For more details, see the [Implementation Plan](plan.md) and [Data Model](data-model.md).