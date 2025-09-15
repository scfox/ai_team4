# Tasks: GitAI Teams - Multi-Agent GitHub Automation System

**Input**: Design documents from `/specs/001-read-the-documents/`
**Prerequisites**: plan.md (✅), research.md (✅), data-model.md (✅), contracts/ (✅)

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → Extract: GitHub Actions workflows, bash/Python scripts
2. Load design documents:
   → data-model.md: Entities (Issue, Agent, Task, Result, WorkflowRun, PullRequest)
   → contracts/: 4 contract files for validation
   → research.md: CLAUDE_CODE_OAUTH_TOKEN requirements
3. Generate tasks by category:
   → Setup: GitHub Actions structure, secrets
   → Tests: Trace tests, contract validation, pytest
   → Core: Workflows, bash scripts, Python logic
   → Integration: Claude action integration
   → Polish: Documentation, trace verification
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001-T030)
6. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Phase 3.1: Setup & Infrastructure
- [x] T001 Create GitHub Actions workflow directory structure at `.github/workflows/`
- [x] T002 Create scripts directory structure at `scripts/bash/` and `scripts/python/`
- [x] T003 Set up CLAUDE_CODE_OAUTH_TOKEN as repository secret (manual step required)
- [x] T004 [P] Create pytest configuration at `tests/python/pytest.ini` with coverage settings
- [x] T005 [P] Initialize Python requirements.txt with pytest, pytest-cov

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**

### Trace Tests (Acceptance Criteria)
- [x] T006 [P] Create single-task trace test at `tests/traces/test_single_task_trace.sh`
- [x] T007 [P] Create parallel-task trace test at `tests/traces/test_parallel_task_trace.sh`
- [x] T008 [P] Create trace verification script at `tests/traces/verify_trace.sh`

### Contract Validation Tests
- [x] T009 [P] Create repository-dispatch contract test at `tests/contracts/test_repository_dispatch.sh`
- [x] T010 [P] Create PR format contract test at `tests/contracts/test_pr_format.sh`
- [x] T011 [P] Create issue comment contract test at `tests/contracts/test_issue_comment.sh`
- [x] T012 [P] Create branch naming contract test at `tests/contracts/test_branch_naming.sh`

### Python Unit Tests (pytest)
- [x] T013 [P] Create test for task analyzer at `scripts/python/test_analyze_task.py`
- [x] T014 [P] Create test for result combiner at `scripts/python/test_combine_results.py`
- [x] T015 [P] Create test for comparison generator at `scripts/python/test_generate_comparison.py`

## Phase 3.3: Core Implementation (ONLY after tests are failing)

### GitHub Actions Workflows
- [x] T016 Implement ai-task-router workflow at `.github/workflows/ai-task-router.yml`
- [x] T017 Implement ai-task-orchestrator workflow at `.github/workflows/ai-task-orchestrator.yml`
- [x] T018 Implement ai-child-executor workflow at `.github/workflows/ai-child-executor.yml`

### Bash Scripts (Git Operations)
- [x] T019 [P] Implement spawn_child.sh at `scripts/bash/spawn_child.sh` for repository_dispatch
- [x] T020 [P] Implement create_pr.sh at `scripts/bash/create_pr.sh` with proper formatting
- [x] T021 [P] Implement derive_state.sh at `scripts/bash/derive_state.sh` for stateless operations
- [x] T022 [P] Implement post_comment.sh at `scripts/bash/post_comment.sh` for issue updates

### Python Scripts (Logic Only)
- [x] T023 [P] Implement analyze_task.py at `scripts/python/analyze_task.py` for parallelization detection
- [x] T024 [P] Implement combine_results.py at `scripts/python/combine_results.py` for merging child outputs
- [x] T025 [P] Implement generate_comparison.py at `scripts/python/generate_comparison.py` for tables

## Phase 3.4: Integration & Claude Action
- [x] T026 Integrate CLAUDE_CODE_OAUTH_TOKEN in orchestrator workflow
- [x] T027 Configure repository_dispatch from Claude action context
- [x] T028 Set up concurrency groups per issue in workflows
- [x] T029 Implement status comment updates during execution

## Phase 3.5: Polish & Verification
- [x] T030 [P] Run full trace verification for single-task example
- [x] T031 [P] Run full trace verification for parallel-task example
- [x] T032 [P] Verify Python test coverage > 80% with pytest
- [x] T033 [P] Create README.md with setup and usage instructions
- [x] T034 Verify branch naming patterns match constitution
- [x] T035 Final validation: No state files, all operations stateless

## Dependencies
- Setup (T001-T005) must complete first
- All tests (T006-T015) before implementation (T016-T025)
- Workflows (T016-T018) before integration (T026-T029)
- Python scripts (T023-T025) require corresponding tests (T013-T015) to pass
- Integration (T026-T029) before polish (T030-T035)

## Parallel Execution Examples

### Launch all contract tests together (T009-T012):
```bash
Task: "Create repository-dispatch contract test at tests/contracts/test_repository_dispatch.sh"
Task: "Create PR format contract test at tests/contracts/test_pr_format.sh"
Task: "Create issue comment contract test at tests/contracts/test_issue_comment.sh"
Task: "Create branch naming contract test at tests/contracts/test_branch_naming.sh"
```

### Launch all Python tests together (T013-T015):
```bash
Task: "Create test for task analyzer at scripts/python/test_analyze_task.py"
Task: "Create test for result combiner at scripts/python/test_combine_results.py"
Task: "Create test for comparison generator at scripts/python/test_generate_comparison.py"
```

### Launch all bash scripts together (T019-T022):
```bash
Task: "Implement spawn_child.sh at scripts/bash/spawn_child.sh"
Task: "Implement create_pr.sh at scripts/bash/create_pr.sh"
Task: "Implement derive_state.sh at scripts/bash/derive_state.sh"
Task: "Implement post_comment.sh at scripts/bash/post_comment.sh"
```

### Launch all Python implementations together (T023-T025):
```bash
Task: "Implement analyze_task.py at scripts/python/analyze_task.py"
Task: "Implement combine_results.py at scripts/python/combine_results.py"
Task: "Implement generate_comparison.py at scripts/python/generate_comparison.py"
```

## Critical Implementation Notes

### Token Requirements (from research.md)
- GITHUB_TOKEN cannot trigger workflows (GitHub security limitation)
- Must use CLAUDE_CODE_OAUTH_TOKEN within Claude action context
- Repository_dispatch only works from Claude execution
- All orchestration logic runs INSIDE Claude action

### Stateless Architecture
- No STATE.json or similar files ever
- All state derived from git branches and GitHub API
- Branch patterns: `gitaiteams/issue-N` and `gitaiteams/issue-N-child-M` only
- No grandchildren (single-level parallelism only)

### Trace Compliance
- Workflow counts must match trace.yml exactly
- Single task: 2 workflows, 0 children, 0 PRs
- Parallel task: 6 workflows, 2 children, 3 PRs
- Any deviation fails acceptance

## Validation Checklist
*GATE: Must pass before marking feature complete*

- [ ] All contracts have corresponding validation tests
- [ ] All Python scripts have pytest tests with >80% coverage
- [ ] All tests written before implementation (TDD)
- [ ] Parallel tasks truly independent (different files)
- [ ] Each task specifies exact file path
- [ ] No task modifies same file as another [P] task
- [ ] Trace tests pass with exact counts
- [ ] No state files created anywhere
- [ ] CLAUDE_CODE_OAUTH_TOKEN properly integrated

## Task Count Summary
- **Total Tasks**: 35
- **Parallel Tasks**: 19 (marked with [P])
- **Sequential Tasks**: 16
- **Test Tasks**: 10 (T006-T015)
- **Implementation Tasks**: 10 (T016-T025)
- **Critical Path Length**: ~8 sequential steps

---
*Generated from GitAI Teams implementation plan - Ready for execution*