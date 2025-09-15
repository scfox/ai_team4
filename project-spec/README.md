# GitAI Teams Simple - Project Specification

## Vision
A simplified multi-agent coordination system that enables parallel AI task execution through GitHub Actions, without the complexity of recursive hierarchies.

## Core Principles
1. **Single-level parallelism only** - Root agent can spawn children, children cannot spawn grandchildren
2. **Stateless operation** - All state derived from git branches and PR status
3. **Event-driven execution** - No polling, no waiting, pure reactive
4. **Hybrid implementation** - Bash for git/GitHub operations, Python for complex logic

## What This Is
- A system for distributing AI tasks across parallel agents
- A way to leverage multiple Claude instances simultaneously
- A clean, maintainable architecture that "just works"

## What This Is NOT
- A recursive task decomposition framework
- A complex orchestration platform
- A general-purpose workflow engine

## Examples Included
1. **single-task**: Direct execution without spawning children
2. **parallel-task**: Two children working simultaneously on related tasks

## Success Metrics
- ✅ All examples execute successfully
- ✅ No more than 4 workflow runs for parallel tasks
- ✅ Clean PR merges without conflicts
- ✅ Python scripts handle complex logic without git operations

## Implementation Approach
Start with examples, build only what's needed to make them work.