# GitAI Teams Constitution

## Core Principles

### I. Event-Driven Stateless Architecture
Every operation is triggered by GitHub events (issues, PRs, repository_dispatch). The system derives all state from git branches and GitHub API - no persistent storage, no state files, no databases. State transitions are atomic and verifiable through git history.

**Verification**:
- Count workflow runs match expected triggers
- No STATE.json or similar files exist
- All decisions derivable from git log and GitHub API

### II. Trace-First Development (NON-NEGOTIABLE)
Every feature must have a trace.yml defining exact workflow execution counts and sequences BEFORE implementation. Traces are acceptance tests - if actual execution doesn't match trace, the implementation is wrong, not the trace.

**Verification**:
- Trace files exist in examples/ before code
- Workflow run counts match trace exactly
- Branch creation patterns match trace
- PR sequences match trace

### III. Single-Level Parallelism Only
Root agents (triggered by @gitaiteams) can spawn child agents. Children CANNOT spawn grandchildren. This constraint eliminates 80% of complexity and makes the system testable.

**Verification**:
- Branch names follow pattern: `gitaiteams/issue-N` (root) or `gitaiteams/issue-N-child-M` (child)
- No branches with pattern `*-child-*-child-*` ever exist
- repository_dispatch events only triggered from root workflows

### IV. GitHub-Native Observability
All system state, progress, and results are visible through GitHub's native UI - issues, PRs, workflow runs, branches. No external monitoring, no custom dashboards, no hidden logs.

**Verification**:
- Every significant action produces a GitHub artifact (comment, PR, or workflow run)
- Debugging possible using only GitHub UI
- No external services or APIs required for monitoring

### V. Bash for Git, Python for Logic
Git operations MUST use bash scripts (GitHub Actions security model). Complex logic MAY use Python but cannot perform git operations. This separation is mandatory. All Python scripts MUST have pytest tests.

**Verification**:
- All `git` commands in .sh files only
- Python files contain no subprocess calls to git
- Clear separation between orchestration (bash) and computation (Python)
- Every Python script has corresponding test_*.py file
- Tests use pytest framework exclusively
- Test coverage for Python scripts > 80%

## Testing & Verification Standards

### Trace Compliance
- Every example in `examples/` must have input.md, expected.md, and trace.yml
- Implementation MUST produce exact trace match
- Workflow counts are hard requirements, not approximations
- CI must verify trace compliance on every PR

### Integration Test Triggers
Integration tests required when:
- Modifying GitHub webhook handling
- Changing repository_dispatch payloads
- Altering PR creation/merge logic
- Modifying child spawning mechanisms
- Adding new Python scripts (must include pytest tests)

### Acceptance Criteria
A feature is complete when:
1. Trace matches exactly (workflow counts, branch patterns)
2. Expected output matches actual output
3. No recursive spawning possible
4. All state derivable from git/GitHub

## Operational Constraints

### Performance Requirements
- Single task completion: < 5 minutes 
- Parallel task completion: < 10 minutes
- Child agent timeout: 8 minutes
- Maximum parallel children: 5

### Resource Limits
- GitHub Actions minutes: No limit (Github account enforced)
- Concurrent workflow runs: 10
- API rate limits: Must respect GitHub's rate limits
- Comment size: Must respect GitHub's comment size limits

### Error Handling
- Child failures: Continue with partial results
- Timeout behavior: Continue with note of child timeout.
- Invalid mentions: Respond with error
- Rate limit exceeded: Stop and give error

## Development Workflow

### Branch Strategy
```
main                           # Production code
├── gitaiteams/issue-N        # Root agent branches (auto-created)
│   └── gitaiteams/issue-N-child-M  # Child agent branches
└── feature/*                  # Development branches
```

### PR Flow
1. Child agents create PRs to their parent branch
2. Parent agents do NOT create PRs directly, but include a link to create the PR to main in the response (allowing user to pick another branch and/or not create the PR at all)
3. Child PRs auto-generated, not manual
4. PR titles follow format: `[AI Agent] Issue #N: Task description`

### Code Review Gates
Before any merge:
- [ ] Trace compliance verified
- [ ] No recursive patterns detected
- [ ] Branch naming conventions followed
- [ ] All git operations in bash
- [ ] No state files created
- [ ] Python scripts have pytest tests with >80% coverage

## Governance

### Constitution Authority
This constitution supersedes all other project documentation. Any conflict between this document and other guides, templates, or code must be resolved in favor of the constitution.

### Amendment Process
1. Proposed changes require trace demonstrating benefit
2. Must not violate single-level parallelism constraint
3. Must maintain GitHub-native observability
4. Requires update to all dependent templates per `constitution_update_checklist.md`

### Violation Handling
Constitution violations block PR merge. Common violations:
- Attempting recursive spawning
- Creating state files
- Git operations in Python
- Missing traces for features
- Workflow counts not matching traces

### Clarification Process
Items marked [NEEDS CLARIFICATION] require:
1. GitHub issue creation with context
2. Decision documented in issue
3. Constitution updated with decision
4. Dependent docs updated per checklist

**Version**: 1.0.0 | **Ratified**: 2025-09-15 | **Last Amended**: N/A

---

## Appendix: Quick Reference

### Valid Branch Patterns
```bash
✅ gitaiteams/issue-42
✅ gitaiteams/issue-42-child-1
✅ gitaiteams/issue-42-child-2
❌ gitaiteams/issue-42-child-1-child-1  # NO GRANDCHILDREN
❌ gitaiteams/issue-42-subtask-1         # WRONG PATTERN
```

### Trace Verification Commands
```bash
# Count workflows for an issue
gh run list --workflow=ai-task-orchestrator.yml --json conclusion | jq length

# Verify branch patterns
git branch -r | grep "gitaiteams/issue-"

# Check for state files (should return nothing)
find . -name "STATE.json" -o -name "*.state"

# Run Python tests with coverage
pytest scripts/python/test_*.py --cov=scripts/python --cov-report=term-missing

# Verify test coverage meets minimum
pytest --cov=scripts/python --cov-fail-under=80
```

### Required Files per Feature
```
examples/[feature-name]/
├── input.md      # What user provides
├── expected.md   # What user sees
└── trace.yml     # Exact execution sequence
```

---

*This constitution defines the immutable laws of the GitAI Teams system. Simplicity through constraints.*