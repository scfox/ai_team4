# Implementation Plan: GitAI Teams - Multi-Agent GitHub Automation System

**Branch**: `001-read-the-documents` | **Date**: 2025-09-15 | **Spec**: [/specs/001-read-the-documents/spec.md]
**Input**: Feature specification from `/specs/001-read-the-documents/spec.md`

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
5. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file
6. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
7. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
8. STOP - Ready for /tasks command
```

## Summary
A GitHub Actions-based multi-agent system that responds to @gitaiteams mentions in issues, automatically determines whether to parallelize tasks by spawning child agents (max 1 level deep), and posts unified results back to the issue. The system is completely stateless, deriving all state from git branches and GitHub API, with strict trace compliance for verification.

## Technical Context
**Language/Version**: Bash (GitHub Actions), Python 3.11 (logic only)
**Primary Dependencies**: GitHub Actions, GitHub CLI (gh), jq, Python stdlib
**Storage**: No persistent storage - stateless architecture
**Testing**: Trace-based acceptance tests, bash integration tests, pytest for Python
**Target Platform**: GitHub Actions runners (Ubuntu latest)
**Project Type**: single - GitHub Actions workflows with supporting scripts
**Performance Goals**: Single task < 5 min, Parallel task < 10 min
**Constraints**: No recursive spawning, max 5 parallel children, 8 min child timeout
**Scale/Scope**: 10 concurrent workflows, unlimited issues/repos (GitHub account limits)

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Simplicity**:
- Projects: 2 (workflows, scripts) ✅ (max 3)
- Using framework directly? Yes - GitHub Actions native ✅
- Single data model? N/A - stateless system ✅
- Avoiding patterns? Yes - no unnecessary abstractions ✅

**Architecture**:
- EVERY feature as library? N/A - workflow-based architecture
- Libraries listed: Supporting scripts for task analysis, result combination
- CLI per library: Bash scripts with standard arguments
- Library docs: README with workflow documentation

**Testing (NON-NEGOTIABLE)**:
- RED-GREEN-Refactor cycle enforced? Yes - trace files define failures ✅
- Git commits show tests before implementation? Yes - traces before code ✅
- Order: Contract→Integration→E2E→Unit strictly followed? Trace→Integration ✅
- Real dependencies used? Yes - actual GitHub Actions ✅
- Integration tests for: workflow triggers, PR creation, child spawning ✅
- FORBIDDEN: Implementation before test ✅

**Observability**:
- Structured logging included? Via GitHub Actions logs ✅
- Frontend logs → backend? N/A - no frontend ✅
- Error context sufficient? GitHub UI provides full context ✅

**Versioning**:
- Version number assigned? Will use git tags for releases
- BUILD increments on every change? Via GitHub releases
- Breaking changes handled? N/A - internal system

## Project Structure

### Documentation (this feature)
```
specs/001-read-the-documents/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
.github/
├── workflows/
│   ├── ai-task-router.yml      # Detects @gitaiteams mentions
│   ├── ai-task-orchestrator.yml # Main logic, spawns children
│   └── ai-child-executor.yml    # Child agent workflow
│
scripts/
├── bash/
│   ├── spawn_child.sh           # Triggers child via repository_dispatch
│   ├── create_pr.sh             # Creates PRs with proper format
│   ├── derive_state.sh          # Gets state from branches/PRs
│   └── post_comment.sh          # Posts to GitHub issues
│
└── python/
    ├── analyze_task.py          # Determines if parallelization needed
    ├── combine_results.py       # Merges child agent outputs
    ├── generate_comparison.py   # Creates comparison tables
    ├── test_analyze_task.py     # Pytest tests for task analyzer
    ├── test_combine_results.py  # Pytest tests for result combiner
    └── test_generate_comparison.py # Pytest tests for comparison generator

examples/
├── single-task/
│   ├── input.md
│   ├── expected.md
│   └── trace.yml
└── parallel-task/
    ├── input.md
    ├── expected.md
    └── trace.yml

tests/
├── integration/
│   ├── test_single_task.sh
│   └── test_parallel_task.sh
├── traces/
│   └── verify_trace.sh
└── python/
    └── pytest.ini              # Pytest configuration with coverage settings
```

**Structure Decision**: Single project with GitHub Actions workflows and supporting scripts

## Phase 0: Outline & Research ✅ COMPLETED
1. **Unknowns Resolved**:
   - GitHub comment size limits: 65,536 characters
   - Repository dispatch payload limits: 65KB total
   - Workflow concurrency: Using concurrency groups per issue
   - GitHub Actions timeout: Hierarchical (5/8/10 min)

2. **Critical Findings from ai_team3**:
   - GITHUB_TOKEN cannot trigger workflows (security limitation)
   - Must use CLAUDE_CODE_OAUTH_TOKEN within Claude action context
   - Bot-created PRs don't trigger workflows
   - Repository_dispatch only works from Claude execution context

3. **Key Decisions Documented**:
   - Dual token approach (CLAUDE_CODE_OAUTH_TOKEN + GITHUB_TOKEN)
   - Stateless architecture (all state from git/GitHub)
   - Error handling via graceful degradation
   - Branch naming strict enforcement

**Output**: ✅ research.md completed with all findings and lessons from ai_team3

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Issue (number, content, mentions)
   - Agent (type: root/child, status, branch)
   - Task (description, parallelizable, children)
   - Result (content, format, combined)
   - Workflow Run (id, trigger, actions)

2. **Generate API contracts** from functional requirements:
   - repository_dispatch payload schema
   - PR description format
   - Issue comment format
   - Branch naming schema
   - Output to `/contracts/`

3. **Generate contract tests** from contracts:
   - Trace verification tests
   - Workflow count assertions
   - Branch pattern validations
   - PR format checks

4. **Extract test scenarios** from user stories:
   - Single task execution trace
   - Parallel task execution trace
   - Error handling scenarios
   - Timeout scenarios

5. **Create quickstart.md**:
   - How to trigger @gitaiteams
   - Expected behaviors
   - Monitoring execution
   - Debugging failed runs

**Output**: data-model.md, /contracts/*, trace tests, quickstart.md

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Generate tasks from trace files and contracts
- Each workflow → implementation task
- Each script → creation task
- Each trace → verification task
- Integration tests for workflow interactions

**Ordering Strategy**:
- Router workflow first (entry point)
- Core scripts next (utilities)
- Orchestrator workflow (main logic)
- Child executor workflow
- Integration tests last

**Estimated Output**: 20-25 numbered, ordered tasks in tasks.md

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)
**Phase 4**: Implementation (execute tasks.md following traces)
**Phase 5**: Validation (verify traces match exactly)

## Complexity Tracking
*No violations - system adheres to all constitutional principles*

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
- [x] Complexity deviations documented (none)

---
*Based on Constitution v1.0.0 - See `/memory/constitution.md`*