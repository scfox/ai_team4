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

## Testing Commands

```bash
# Run Python tests
pytest scripts/python/test_*.py -v --cov=scripts/python

# Run trace verification
bash tests/traces/verify_trace.sh

# Run contract tests
bash tests/contracts/test_*.sh
```

## Important Notes

- Never create STATE.json or similar state files
- All state must be derived from git branches and GitHub API
- Use CLAUDE_CODE_OAUTH_TOKEN for repository_dispatch
- Follow TDD: tests first, then implementation
- Branch naming: `gitaiteams/issue-N` and `gitaiteams/issue-N-child-M` only