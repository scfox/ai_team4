# Claude Instructions for GitAI Teams Project

## Task Status Synchronization

When working on this project, ALWAYS keep the following files synchronized:

1. **IMPLEMENTATION_STATUS.md** - Main tracking document
2. **specs/001-read-the-documents/tasks.md** - Detailed task list

### When Completing Tasks

After completing any task (T001-T035), you MUST:

1. Update IMPLEMENTATION_STATUS.md - mark the task with ✅
2. Update specs/001-read-the-documents/tasks.md - change `[ ]` to `[x]`
3. Verify both files show the same completion status

### Quick Check Command

Run this to see task status across both files:
```bash
grep -E "T0[0-9]{2}" IMPLEMENTATION_STATUS.md specs/001-read-the-documents/tasks.md
```

## Project Structure

- **Workflows**: `.github/workflows/ai-*.yml`
- **Scripts**: `scripts/bash/*.sh` and `scripts/python/*.py`
- **Tests**: `tests/` directory with traces, contracts, and python tests
- **Specs**: `specs/001-read-the-documents/` with all design documents
- **Completion Detection**: `specs/002-completion-detection-as/` with completion tracking design

## Testing Commands

```bash
# Run Python tests
pytest scripts/python/test_*.py -v --cov=scripts/python

# Run trace verification
bash tests/traces/verify_trace.sh

# Run contract tests
bash tests/contracts/test_*.sh

# Run completion detection tests
bash specs/002-completion-detection-as/contracts/test_completion_check.sh
bash specs/002-completion-detection-as/contracts/test_analyze_completions.sh

# Test completion detection Python scripts
python3 scripts/python/count_completions.py --comments '[{"body": "🤖 Child C1 complete"}]' --threshold 3
python3 scripts/python/analyze_completions.py --parse-status "🤖 Child C1 complete: PR #10 ready"

# Run integration tests for completion flow
bash tests/integration/test_completion_flow.sh
```

## Important Notes

- Never create STATE.json or similar state files
- All state must be derived from git branches and GitHub API
- Use CLAUDE_CODE_OAUTH_TOKEN for repository_dispatch
- Follow TDD: tests first, then implementation
- Branch naming: `gitaiteams/issue-N` and `gitaiteams/issue-N-child-M` only

## Recent Changes

### 2025-09-15: Completion Detection System
- Added count-triggered completion tracking in `ai-task-router.yml`
- New workflow `ai-completion-analyzer.yml` for Claude analysis
- Python scripts: `count_completions.py`, `analyze_completions.py`
- Child status marker: "🤖 Child" in comments

## Completion Detection Configuration

### Child Marker Format
The system detects child agent completion by looking for the "🤖 Child" marker in issue comments.
Standard format: `🤖 Child C[N] [status]: [details]`

### Python Scripts for Completion Detection

**count_completions.py**: Counts child completion markers
```bash
# Count child markers in comments
python3 scripts/python/count_completions.py \
  --comments '[{"body": "🤖 Child C1 complete"}]' \
  --issue-body "Splitting into 3 children" \
  --threshold 3
```

**analyze_completions.py**: Analyzes completion status and determines merge strategy
```bash
# Parse child status
python3 scripts/python/analyze_completions.py \
  --parse-status "🤖 Child C1 complete: PR #10 ready"

# Determine merge strategy
python3 scripts/python/analyze_completions.py \
  --determine-strategy --successful 2 --failed 1 --partial 0
```

### Performance Requirements
- Detection time: < 2 seconds
- Analysis time: < 60 seconds
- End-to-end completion: < 2 minutes