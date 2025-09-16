# Quickstart: Child Agent Completion Tracking

## Overview
This guide demonstrates the child agent completion tracking system in action. Follow these steps to see how the system detects when all child agents have completed and intelligently analyzes their results.

## Prerequisites
- Repository with GitAI Teams system deployed
- GitHub Actions enabled
- Claude API key configured in secrets
- CLAUDE_CODE_OAUTH_TOKEN configured

## Scenario 1: All Children Succeed

### Setup
Create an issue that will spawn 3 child agents:

```markdown
@gitaiteams Please implement these features in parallel:
1. Add user authentication
2. Create dashboard UI
3. Set up monitoring

Splitting into 3 children for parallel execution.
```

### Expected Behavior
1. Parent agent creates 3 child branches
2. Each child works independently
3. Children post completion comments:
   - `🤖 Child C1 complete: PR #10 ready for review`
   - `🤖 Child C2 complete: PR #11 ready for review`
   - `🤖 Child C3 complete: PR #12 ready for review`
4. System detects all 3 have reported
5. Claude analyzes and merges all PRs
6. Final consolidation PR created

### Verification
```bash
# Check that all child PRs were merged
gh pr list --state merged --search "Child C"

# Verify consolidation PR exists
gh pr list --search "Consolidation PR for Issue"

# Check issue for summary comment
gh issue view <issue-number> --comments
```

## Scenario 2: Partial Success

### Setup
Create an issue where some children will fail:

```markdown
@gitaiteams Please analyze these complex modules:
1. Legacy payment system (likely to fail)
2. User profile module
3. Notification service

Creating 3 child agents for analysis.
```

### Expected Behavior
1. Children report mixed results:
   - `🤖 Child C1 failed: Unable to parse legacy code`
   - `🤖 Child C2 complete: PR #20 ready`
   - `🤖 Child C3 complete: PR #21 ready`
2. Claude analyzes the situation
3. Decides on MERGE_PARTIAL strategy
4. Merges successful PRs only
5. Documents failure in summary

### Verification
```bash
# Check merged PRs (should be 2)
gh pr list --state merged --limit 3

# Read Claude's reasoning
gh issue view <issue-number> --comments | grep "reasoning"
```

## Scenario 3: Ambiguous Status

### Setup
Simulate a child with unclear status:

```markdown
@gitaiteams Please refactor the data layer:
1. Database schema updates
2. Migration scripts

Splitting into 2 children.
```

### Expected Behavior
1. Children report:
   - `🤖 Child C1 mostly complete: schema updated but needs review`
   - `🤖 Child C2 complete: PR #30 ready`
2. Claude interprets "mostly complete"
3. May recommend MANUAL_REVIEW
4. Provides detailed analysis in comment

### Verification
```bash
# Check Claude's interpretation
gh issue view <issue-number> --comments | tail -n 1
```

## Manual Testing Steps

### 1. Test Comment Counting
```bash
# Run the count check manually
python3 scripts/python/count_completions.py \
  --issue-body "Splitting into 3 children" \
  --comments '[{"body": "🤖 Child C1 complete"}]'

# Expected output: Count: 1 of 3
```

### 2. Test Status Detection
```bash
# Test status type detection
python3 scripts/python/analyze_completions.py \
  --parse-status "🤖 Child C1 complete: PR #10 ready"

# Expected output: Status: SUCCESS, PR: 10
```

### 3. Test Merge Strategy
```bash
# Test strategy determination
python3 scripts/python/analyze_completions.py \
  --determine-strategy \
  --successful 2 --failed 1 --partial 0

# Expected output: Strategy: MERGE_PARTIAL
```

## Integration Test

### Full Workflow Test
1. Create test issue:
```bash
gh issue create \
  --title "Test: Completion Detection" \
  --body "Splitting into 2 children for testing"
```

2. Simulate child comments:
```bash
ISSUE_NUMBER=<from-above>

gh issue comment $ISSUE_NUMBER \
  --body "🤖 Child C1 complete: PR #100 ready"

gh issue comment $ISSUE_NUMBER \
  --body "🤖 Child C2 failed: test errors"
```

3. Watch the workflow:
```bash
# Monitor workflow runs
gh run list --workflow=ai-task-router.yml

# Check for repository_dispatch
gh run list --workflow=ai-completion-analyzer.yml
```

4. Verify results:
```bash
# Check for Claude's analysis comment
gh issue view $ISSUE_NUMBER --comments | grep "Analysis complete"
```

## Troubleshooting

### Issue: Comments not triggering workflow
- Check workflow permissions
- Verify "🤖 Child" marker is present
- Check workflow logs for errors

### Issue: Claude analysis not running
- Verify CLAUDE_API_KEY is set
- Check repository_dispatch permissions
- Review Claude agent logs

### Issue: PRs not merging
- Check branch protection rules
- Verify PR numbers are correct
- Check for merge conflicts

## Performance Benchmarks

Run these tests to verify performance:

```bash
# Time from last comment to analysis start
time ./tests/integration/measure_trigger_time.sh

# Time for Claude analysis
time ./tests/integration/measure_analysis_time.sh

# Total end-to-end time
time ./tests/integration/measure_e2e_time.sh
```

Expected results:
- Trigger time: < 2 seconds
- Analysis time: < 60 seconds
- End-to-end: < 2 minutes

## Configuration Options

### Customize Child Marker
Edit `.github/workflows/ai-task-router.yml`:
```yaml
env:
  CHILD_MARKER: "🤖 Child"  # Change marker here
```

### Adjust Timeouts
Edit `.github/workflows/ai-completion-analyzer.yml`:
```yaml
timeout-minutes: 8  # Adjust Claude timeout
```

### Change Merge Strategy Thresholds
Edit `scripts/python/analyze_completions.py`:
```python
MERGE_THRESHOLD = 0.5  # Merge if >50% succeed
```

## Next Steps

After verifying the quickstart scenarios:

1. **Monitor Production**: Watch real completion patterns
2. **Tune Claude Prompts**: Refine based on edge cases
3. **Add Metrics**: Track success rates and timing
4. **Extend Features**: Add retry logic, notifications

## Support

For issues or questions:
- Check workflow logs: `gh run view <run-id> --log`
- Review Claude's reasoning in issue comments
- Check constitution compliance: `./tests/verify_constitution.sh`