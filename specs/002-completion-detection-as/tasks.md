# Tasks: Child Agent Completion Tracking System

**Input**: Design documents from `/specs/002-completion-detection-as/`
**Prerequisites**: plan.md (required), research.md, data-model.md, contracts/

## Execution Flow (main)
```
1. Load plan.md from feature directory
   → Extract: Python 3.11, GitHub Actions, pytest
   → Structure: Single project (workflows + scripts)
2. Load optional design documents:
   → data-model.md: ParentIssue, ChildStatus, CompletionAnalysis
   → contracts/: completion-check.yml, analyze-completions.yml
   → research.md: Count-based detection, Claude analysis
3. Generate tasks by category:
   → Setup: Python script structure, test harness
   → Tests: contract tests (bash), unit tests (pytest)
   → Core: Python scripts for counting and analysis
   → Integration: GitHub workflows, repository dispatch
   → Polish: documentation, integration tests
4. Apply task rules:
   → Different files = mark [P] for parallel
   → Same file = sequential (no [P])
   → Tests before implementation (TDD)
5. Number tasks sequentially (T001-T025)
6. Generate dependency graph
7. Create parallel execution examples
8. Validate task completeness:
   → All contracts have tests? YES
   → All Python scripts have tests? YES
   → All workflows updated? YES
9. Return: SUCCESS (tasks ready for execution)
```

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (different files, no dependencies)
- Include exact file paths in descriptions

## Path Conventions
- **Scripts**: `scripts/python/` for Python, `scripts/bash/` for shell
- **Workflows**: `.github/workflows/`
- **Tests**: `tests/` at repository root, contract tests in `specs/002-completion-detection-as/contracts/`
- **Documentation**: Repository root for CLAUDE.md, specs directory for feature docs

## Phase 3.1: Setup
- [x] T001 Create Python script structure in scripts/python/ for count_completions.py and analyze_completions.py
- [x] T002 [P] Set up pytest test files: test_count_completions.py and test_analyze_completions.py in scripts/python/
- [x] T003 [P] Make contract test scripts executable: chmod +x specs/002-completion-detection-as/contracts/*.sh

## Phase 3.2: Tests First (TDD) ⚠️ MUST COMPLETE BEFORE 3.3
**CRITICAL: These tests MUST be written and MUST FAIL before ANY implementation**
- [x] T004 [P] Run contract test for completion check: bash specs/002-completion-detection-as/contracts/test_completion_check.sh (must fail)
- [x] T005 [P] Run contract test for analyze completions: bash specs/002-completion-detection-as/contracts/test_analyze_completions.sh (must fail)
- [x] T006 [P] Write unit test for count_child_markers() in scripts/python/test_count_completions.py
- [x] T007 [P] Write unit test for extract_expected_count() in scripts/python/test_count_completions.py
- [x] T008 [P] Write unit test for detect_status_type() in scripts/python/test_analyze_completions.py
- [x] T009 [P] Write unit test for determine_merge_strategy() in scripts/python/test_analyze_completions.py
- [x] T010 [P] Write unit test for parse_claude_response() in scripts/python/test_analyze_completions.py

## Phase 3.3: Core Implementation (ONLY after tests are failing)
- [x] T011 Implement count_completions.py with count_child_markers() and extract_expected_count() functions
- [x] T012 Implement analyze_completions.py with detect_status_type() and determine_merge_strategy() functions
- [x] T013 Add CLI argument parsing to count_completions.py for workflow integration
- [x] T014 Add CLI argument parsing to analyze_completions.py for Claude response handling
- [x] T015 Verify all Python unit tests pass: pytest scripts/python/test_count_completions.py scripts/python/test_analyze_completions.py

## Phase 3.4: Workflow Integration
- [x] T016 Add completion check job to .github/workflows/ai-task-router.yml with comment trigger condition
- [x] T017 Create .github/workflows/ai-completion-analyzer.yml for repository_dispatch handling
- [x] T018 Add repository_dispatch trigger in ai-task-router.yml when count threshold is met
- [x] T019 Configure Claude agent invocation in ai-completion-analyzer.yml with proper system prompt
- [x] T020 Add error handling and fallback strategy to both workflows

## Phase 3.5: Integration Tests
- [x] T021 Create integration test script tests/integration/test_completion_flow.sh for end-to-end validation
- [x] T022 Test scenario: all children succeed (3 children, all report success with PRs)
- [x] T023 Test scenario: partial failure (2 succeed, 1 fails)
- [x] T024 Test scenario: ambiguous status handling ("mostly complete" comment)

## Phase 3.6: Polish & Documentation
- [x] T025 [P] Update CLAUDE.md with completion detection commands and configuration
- [x] T026 [P] Add logging to Python scripts using standard logging module
- [x] T027 [P] Create llms.txt documentation for count_completions.py and analyze_completions.py
- [x] T028 Run quickstart scenarios from specs/002-completion-detection-as/quickstart.md
- [x] T029 Performance validation: ensure detection < 2s, analysis < 60s

## Dependencies
- Setup (T001-T003) must complete first
- Tests (T004-T010) before implementation (T011-T015)
- Python implementation (T011-T015) before workflow integration (T016-T020)
- Workflow integration before integration tests (T021-T024)
- All implementation before polish (T025-T029)

## Parallel Execution Examples

### Launch test writing in parallel (T006-T010):
```
Task: "Write unit test for count_child_markers() in scripts/python/test_count_completions.py"
Task: "Write unit test for extract_expected_count() in scripts/python/test_count_completions.py"
Task: "Write unit test for detect_status_type() in scripts/python/test_analyze_completions.py"
Task: "Write unit test for determine_merge_strategy() in scripts/python/test_analyze_completions.py"
Task: "Write unit test for parse_claude_response() in scripts/python/test_analyze_completions.py"
```

### Launch contract tests in parallel (T004-T005):
```
Task: "Run contract test for completion check: bash specs/002-completion-detection-as/contracts/test_completion_check.sh"
Task: "Run contract test for analyze completions: bash specs/002-completion-detection-as/contracts/test_analyze_completions.sh"
```

### Polish tasks in parallel (T025-T027):
```
Task: "Update CLAUDE.md with completion detection commands"
Task: "Add logging to Python scripts using standard logging module"
Task: "Create llms.txt documentation for Python scripts"
```

## Notes
- [P] tasks = different files, no dependencies
- Verify tests fail before implementing (RED phase of TDD)
- Commit after each task with descriptive message
- Python scripts must be executable: chmod +x scripts/python/*.py
- Workflows must maintain idempotency

## Task Generation Rules Applied
1. **From Contracts**:
   - completion-check.yml → T004 (contract test)
   - analyze-completions.yml → T005 (contract test)
   - Workflow endpoints → T016-T019 (implementation)

2. **From Data Model**:
   - ParentIssue entity → extract_expected_count() (T007, T011)
   - ChildStatus entity → detect_status_type() (T008, T012)
   - CompletionAnalysis → determine_merge_strategy() (T009, T012)

3. **From Quickstart Scenarios**:
   - All children succeed → T022 (integration test)
   - Partial success → T023 (integration test)
   - Ambiguous status → T024 (integration test)

4. **Ordering**:
   - Setup → Tests → Core Scripts → Workflows → Integration → Polish
   - Dependencies clearly marked, parallel tasks identified

## Validation Checklist
- [x] All contracts have corresponding tests (T004-T005)
- [x] All Python functions have unit tests (T006-T010)
- [x] All tests come before implementation (Phase 3.2 before 3.3)
- [x] Parallel tasks truly independent (different files)
- [x] Each task specifies exact file path
- [x] No task modifies same file as another [P] task in same phase