# Research: Child Agent Completion Tracking System

## Overview
Research findings for implementing the count-triggered completion detection system with Claude analysis.

## Key Decisions

### 1. Detection Mechanism
**Decision**: Count-based trigger using "🤖 Child" marker in comments
**Rationale**:
- Simple and reliable - no complex parsing needed
- Natural language friendly - agents can add context
- Webhook-driven - immediate response to comments
**Alternatives considered**:
- PR status checks (too rigid, doesn't handle failures well)
- Dedicated API endpoints (adds complexity, state management)
- File-based markers (violates stateless principle)

### 2. Comment Analysis Approach
**Decision**: Pass all child comments to Claude for intelligent interpretation
**Rationale**:
- Handles ambiguous status naturally ("mostly done", "blocked", etc.)
- Context-aware decision making
- Gracefully handles format variations
**Alternatives considered**:
- Strict JSON format (too rigid for natural language)
- Regex pattern matching (can't handle edge cases)
- Rule-based logic (lacks flexibility)

### 3. Workflow Triggering Strategy
**Decision**: Use repository_dispatch event after count threshold
**Rationale**:
- Separates detection from analysis cleanly
- Allows for complex Claude analysis in dedicated workflow
- Maintains single responsibility principle
**Alternatives considered**:
- Single monolithic workflow (too complex, hard to debug)
- Direct API calls (lacks observability)
- Polling mechanism (inefficient, adds latency)

### 4. Expected Count Storage
**Decision**: Extract from parent issue body using pattern matching
**Rationale**:
- Stateless - no external storage needed
- Visible in GitHub UI
- Set at spawn time by parent agent
**Alternatives considered**:
- Environment variables (not persistent across runs)
- GitHub secrets (not dynamic per issue)
- External database (violates constitution)

### 5. Merge Strategy
**Decision**: Claude determines merge strategy based on context
**Rationale**:
- Intelligent handling of partial failures
- Can understand nuanced situations
- Provides reasoning for decisions
**Alternatives considered**:
- All-or-nothing merging (too rigid)
- Manual review always (defeats automation)
- Percentage-based rules (lacks context)

## Technical Research

### GitHub Actions Capabilities
- **issue_comment event**: Triggers on any comment, includes full payload
- **actions/github-script**: Provides authenticated GitHub API access
- **repository_dispatch**: Custom event type for cross-workflow communication
- **Concurrent runs**: Up to 10 workflows can run simultaneously

### Claude Integration via scfox/claude-agent-run
- **Version**: v3.7 (latest stable)
- **Capabilities**: Full GitHub context, OAUTH token support
- **Limitations**: 8-minute timeout (matches child agent timeout)
- **Error handling**: Returns structured errors in workflow logs

### Python Script Requirements
- **Python 3.11**: Available on ubuntu-latest runners
- **Dependencies**: Use stdlib only to avoid installation overhead
- **Testing**: pytest pre-installed on runners
- **Logging**: Use standard logging module for structured output

### Comment Counting Logic
```python
def count_child_markers(comments):
    """Count unique child identifiers in comments."""
    child_ids = set()
    for comment in comments:
        if "🤖 Child" in comment:
            # Extract child ID (e.g., C1, C2)
            match = re.search(r'🤖 Child (\w+)', comment)
            if match:
                child_ids.add(match.group(1))
    return len(child_ids)
```

### Expected Count Extraction
```python
def extract_expected_count(issue_body):
    """Extract expected child count from issue."""
    # Look for patterns like "Splitting into 3 children"
    patterns = [
        r'Splitting into (\d+) children',
        r'Creating (\d+) child agents',
        r'(\d+) parallel tasks'
    ]
    for pattern in patterns:
        match = re.search(pattern, issue_body, re.IGNORECASE)
        if match:
            return int(match.group(1))
    return 0  # Default if not found
```

## Integration Points

### Workflow Integration
1. **ai-task-router.yml**: Add completion check job
2. **ai-completion-analyzer.yml**: New workflow for Claude analysis
3. **Permissions**: Requires write access to issues, PRs, contents

### Script Integration
- Place Python scripts in `scripts/python/`
- Follow existing naming convention (e.g., `count_completions.py`)
- Include corresponding test files (`test_count_completions.py`)

### Error Recovery
1. **Missing expected count**: Proceed with warning, Claude handles
2. **Claude timeout**: Fall back to simple merge-all strategy
3. **Merge conflicts**: Claude recommends resolution, may require manual intervention

## Performance Considerations

### Timing Analysis
- Comment webhook: ~1s
- Count check: < 1s
- Repository dispatch: ~2s
- Claude analysis: 30-60s
- PR merging: 5-10s per PR
- **Total**: 1-2 minutes from last child completion

### Optimization Opportunities
1. Batch PR merges in single operation
2. Cache comment counts (within workflow run)
3. Parallel PR status checks

## Security Considerations

### Token Management
- Use `CLAUDE_CODE_OAUTH_TOKEN` for repository_dispatch
- Use `GITHUB_TOKEN` for read operations
- Never log or expose tokens

### Comment Validation
- Verify comment author is expected bot account
- Sanitize comment content before processing
- Limit comment size to prevent abuse

## Testing Strategy

### Unit Test Coverage
- Comment counting logic
- Expected count extraction
- Claude response parsing
- Error handling paths

### Integration Test Scenarios
1. Happy path: All children succeed
2. Partial failure: Some children fail
3. Count mismatch: More/fewer children than expected
4. Timeout handling: Child doesn't report
5. Format variations: Different comment styles

### Contract Tests
- Workflow trigger conditions
- Repository dispatch payload format
- Claude prompt structure
- GitHub API response schemas

## Documentation Requirements

### Inline Documentation
- Workflow YAML comments for each job/step
- Python docstrings with examples
- README updates for new feature

### User Documentation
- How to interpret completion summaries
- Troubleshooting guide for common issues
- Configuration options (if any)

## Phase 1 Readiness
All technical decisions have been made and validated against the constitution:
- ✅ Stateless architecture maintained
- ✅ Single-level parallelism respected
- ✅ GitHub-native observability preserved
- ✅ Clear bash/Python separation
- ✅ Test-first development planned

Ready to proceed with Phase 1: Design & Contracts.