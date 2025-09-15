# GitAI Teams Simple - Implementation Handoff

## Your Mission
Build a simplified multi-agent system that makes the examples in `examples/` work exactly as specified.

## Starting Point

### 1. Create Fresh Repository
```bash
# Create new repo (DO NOT CLONE ai_team3)
mkdir gitaiteams-simple
cd gitaiteams-simple
git init
```

### 2. Copy Only This Spec
```bash
# Copy ONLY the spec directory
cp -r ../ai_team3/next-project-spec/* .

# You now have:
# - examples/     (what to build)
# - constraints/  (rules to follow)  
# - patterns/     (reference patterns)
# - This file     (your guide)
```

### 3. Understand the Scope
- Read both examples thoroughly
- Note the workflow traces - these are your acceptance tests
- Review all constraints - these are non-negotiable
- Reference patterns show proven approaches

## Implementation Order

### Phase 1: Single Task (No Children)
Make `examples/single-task/` work:
1. Create basic workflow that responds to @gitaiteams
2. Implement direct task execution (no spawning)
3. Verify trace matches expected behavior

### Phase 2: Parallel Tasks (Two Children)
Make `examples/parallel-task/` work:
1. Add branch creation logic
2. Implement child spawning via repository_dispatch
3. Add PR creation from children to parent
4. Implement parent resume on PR events
5. Add final PR from parent to main

### Phase 3: Polish
1. Add error handling
2. Implement status comments
3. Add Python scripts for complex logic (if needed)

## Key Decisions Already Made

1. **No recursion** - Children cannot spawn grandchildren
2. **Flat branch names** - `issue-N-child-M` format only
3. **Bash for git** - All git operations in bash scripts
4. **Python for logic** - Complex analysis in Python (optional)
5. **Event-driven** - No polling, no waiting

## Reference Points in ai_team3

When you need to understand a pattern:
- **Repository dispatch**: See `scripts/spawn_child.sh`
- **GitHub auth**: See `.github/workflows/ai-task-orchestrator.yml`
- **PR handling**: See `scripts/process_pr.sh`

⚠️ **WARNING**: Do NOT copy these files. Read them for patterns only.

## Success Criteria

Your implementation is complete when:
- [ ] Single-task example executes correctly
- [ ] Parallel-task example executes correctly
- [ ] Workflow counts match traces exactly
- [ ] No recursion is possible
- [ ] Branch names follow the specified format

## What NOT to Build

Do not add ANYTHING not required by the examples:
- ❌ No recursive agent support
- ❌ No STATE.json files
- ❌ No complex state management
- ❌ No features "for the future"
- ❌ No optimization before it works

## Testing Your Implementation

```bash
# Test single task
gh issue create --title "Test Single" --body "@gitaiteams
Please review this function..."

# Verify:
# - 2 workflow runs total
# - No branches created
# - Response in issue comment

# Test parallel task
gh issue create --title "Test Parallel" --body "@gitaiteams
Compare FastAPI and Flask..."

# Verify:
# - 6 workflow runs (per trace)
# - 3 branches created
# - 3 PRs created
# - Final result in issue
```

## Questions to Ask Yourself

Before implementing any feature:
1. "Is this required by an example?" If no, don't build it.
2. "Does this violate a constraint?" If yes, don't do it.
3. "Is there a simpler way?" If yes, do that instead.

## Final Advice

- Start simple, make it work, then refine
- The examples ARE the requirements
- When in doubt, choose the simpler approach
- Every line of code should exist to make an example work

## Handoff Complete

You have everything needed to build GitAI Teams Simple. The examples show what success looks like. The constraints prevent overengineering. The patterns provide proven solutions.

Build only what's specified. Nothing more, nothing less.

Good luck! 🚀