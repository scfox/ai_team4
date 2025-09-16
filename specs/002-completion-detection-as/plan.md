# Implementation Plan: Child Agent Completion Tracking System


**Branch**: `002-completion-detection-as` | **Date**: 2025-09-15 | **Spec**: `/specs/002-completion-detection-as/spec.md`
**Input**: Feature specification from `/specs/002-completion-detection-as/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
4. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
5. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, or `GEMINI.md` for Gemini CLI).
6. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
7. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
8. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Implement a count-triggered completion tracking system that detects when all child agents have reported status via issue comments, then triggers intelligent analysis using Claude to make context-aware decisions about merging pull requests and finalizing work. The system uses natural language processing to interpret child status reports containing the marker "🤖 Child" and handles both successful and failed child tasks gracefully.

## Technical Context
**Language/Version**: Python 3.11 (for scripts), Bash (for git operations), YAML (GitHub Actions)
**Primary Dependencies**: GitHub Actions, GitHub API (via actions/github-script), Claude API (via scfox/claude-agent-run@v3.7)
**Storage**: N/A (stateless - derives all state from GitHub issues/PRs)
**Testing**: pytest (Python scripts), bash (contract tests)
**Target Platform**: GitHub Actions runners (ubuntu-latest)
**Project Type**: single (GitHub Actions workflows + support scripts)
**Performance Goals**: < 5 min single task completion, < 10 min parallel completion
**Constraints**: Stateless architecture, single-level parallelism only, GitHub API rate limits
**Scale/Scope**: Max 5 parallel children per parent, unlimited total agents

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Simplicity**:
- Projects: 1 (workflows + scripts)
- Using framework directly? YES (GitHub Actions, Python stdlib)
- Single data model? YES (GitHub issue/PR data only)
- Avoiding patterns? YES (direct API calls, no abstractions)

**Architecture**:
- EVERY feature as library? YES (count_completions.py, analyze_completions.py)
- Libraries listed:
  - count_completions.py: Count child markers in comments
  - analyze_completions.py: Parse Claude's analysis response
- CLI per library: YES (each script callable with args)
- Library docs: llms.txt format planned? YES

**Testing (NON-NEGOTIABLE)**:
- RED-GREEN-Refactor cycle enforced? YES
- Git commits show tests before implementation? YES
- Order: Contract→Integration→E2E→Unit strictly followed? YES
- Real dependencies used? YES (actual GitHub API in integration tests)
- Integration tests for: new libraries, contract changes, shared schemas? YES
- FORBIDDEN: Implementation before test, skipping RED phase ✓

**Observability**:
- Structured logging included? YES (workflow logs, Python logging)
- Frontend logs → backend? N/A (no frontend)
- Error context sufficient? YES (full trace in workflow logs)

**Versioning**:
- Version number assigned? YES (follows repo versioning)
- BUILD increments on every change? YES
- Breaking changes handled? N/A (new feature)

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
# Option 1: Single project (DEFAULT)
src/
├── models/
├── services/
├── cli/
└── lib/

tests/
├── contract/
├── integration/
└── unit/

# Option 2: Web application (when "frontend" + "backend" detected)
backend/
├── src/
│   ├── models/
│   ├── services/
│   └── api/
└── tests/

frontend/
├── src/
│   ├── components/
│   ├── pages/
│   └── services/
└── tests/

# Option 3: Mobile + API (when "iOS/Android" detected)
api/
└── [same as backend above]

ios/ or android/
└── [platform-specific structure]
```

**Structure Decision**: Option 1 (Single project - GitHub Actions workflows with supporting Python scripts)

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `/scripts/bash/update-agent-context.sh claude` for your AI assistant
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Contract tests: `test_completion_check.sh`, `test_analyze_completions.sh` [P]
- Python scripts: `count_completions.py`, `analyze_completions.py` [P]
- Workflow modifications: `ai-task-router.yml` completion check job
- New workflow: `ai-completion-analyzer.yml`
- Integration tests for full flow
- Implementation tasks to make tests pass

**Ordering Strategy**:
- TDD order: Contract tests first (must fail)
- Python script tests next
- Implementation to make tests pass
- Workflow changes after scripts work
- Integration tests last
- Mark [P] for parallel execution where possible

**Estimated Output**: 20-25 numbered, ordered tasks in tasks.md

**Task Categories**:
1. Contract Tests (2 tasks) - Must fail initially
2. Python Unit Tests (4 tasks) - Test harness setup
3. Python Implementation (2 tasks) - Core logic
4. Workflow Updates (2 tasks) - GitHub Actions
5. Integration Tests (3 tasks) - End-to-end validation
6. Documentation (2 tasks) - Update README, CLAUDE.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none required)

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*