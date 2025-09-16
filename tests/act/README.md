# Act-Based GitHub Actions Testing

This directory contains a comprehensive testing framework for GitHub Actions workflows using [act](https://github.com/nektos/act).

## Overview

Act allows you to run GitHub Actions locally in Docker containers, enabling:
- Fast iteration without pushing to GitHub
- Testing of complex workflow scenarios
- Mocking external dependencies (like Claude Code Action)
- Validation of workflow logic and contracts

## Prerequisites

1. **Python Environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Install act** (optional, for full Docker testing):
   ```bash
   # macOS
   brew install act

   # Linux
   curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash

   # Windows
   choco install act-cli
   ```

3. **Install Docker** (optional, for full Docker testing):
   - Download Docker Desktop from https://www.docker.com/products/docker-desktop
   - Ensure Docker is running before running tests
   - Note: colima users may experience bind mount issues

4. **Set up secrets** (optional):
   ```bash
   cp .env.act.example .env.act
   # Edit .env.act with your test values (can use mock tokens)
   ```

## Quick Start

```bash
# Run all workflow tests (including non-Docker tests)
./tests/run.sh act

# Run comprehensive test suite
./tests/act/test-workflows.sh

# Run tests without Docker requirement
./tests/act/run-test-no-docker.sh

# Run with verbose output
VERBOSE=1 ./tests/run.sh act
```

## Directory Structure

```
tests/act/
├── README.md                  # This file
├── run-workflow-test.sh       # Main test runner
├── events/                    # GitHub event JSON files
│   ├── issue-opened.json      # Issue with @gitaiteams mention
│   ├── issue-comment.json     # Comment with @gitaiteams
│   ├── repository-dispatch.json # Orchestrator trigger
│   └── completion-comment.json # Child completion marker
├── lib/
│   └── validate.sh            # Validation helper functions
├── mocks/
│   └── claude-action/         # Mock Claude Code Action
│       ├── action.yml         # Action definition
│       └── entrypoint.sh      # Mock logic
└── scenarios/                 # Test scenarios
    ├── test-error-handling.sh # Error case tests
    └── test-parallel-tasks.sh # Parallel execution tests
```

## Test Scenarios

### 1. Router Workflow
Tests the `ai-task-router.yml` workflow:
- Issue opened with @gitaiteams mention
- Comment with @gitaiteams mention
- Validates dispatch events are created
- Checks reaction and label addition

### 2. Completion Detection
Tests child completion tracking:
- Comments with 🤖 Child markers
- Threshold detection logic
- Trigger of completion analyzer

### 3. Orchestrator Workflow
Tests task orchestration:
- Task analysis and splitting
- Child branch creation
- Repository dispatch events

### 4. Child Executor
Tests child task execution:
- Branch checkout
- Task execution (mocked)
- PR creation simulation

### 5. Error Handling
Tests failure scenarios:
- Missing tokens
- Invalid payloads
- API failures

## Mock Claude Action

The mock Claude action (`mocks/claude-action/`) simulates Claude responses based on scenarios:

```bash
# Control mock behavior with environment variable
export MOCK_CLAUDE_SCENARIO="simple_task"  # or parallel_task, completion_detection, error_case
```

Mock behaviors:
- `simple_task`: Single task execution
- `parallel_task`: Task splitting into children
- `completion_detection`: Child completion checking
- `error_case`: Simulated failures

## Writing New Tests

1. **Create event file**:
   ```json
   // tests/act/events/my-event.json
   {
     "issue": {
       "number": 100,
       "body": "Test content"
     }
   }
   ```

2. **Create test scenario**:
   ```bash
   #!/usr/bin/env bash
   # tests/act/scenarios/test-my-scenario.sh

   source ../lib/validate.sh

   test_my_scenario() {
       init_mocks

       run_workflow ".github/workflows/my-workflow.yml" \
                   "../events/my-event.json" \
                   "/tmp/output.log" \
                   "my_scenario"

       validate_output "/tmp/output.log" "Expected text"
   }
   ```

3. **Add to main runner**:
   Update `run-workflow-test.sh` to include your test.

## Validation Helpers

The `lib/validate.sh` provides helper functions:

```bash
# Check if dispatch was created
validate_dispatch "orchestrate" "42"

# Check if branch was created
validate_branch "gitaiteams/issue-42-child-1"

# Check workflow output
validate_output "/tmp/output.log" "Expected text"

# Validate JSON structure
validate_json "/tmp/data.json" ".field.subfield" "expected_value"
```

## Troubleshooting

### Docker not running
```
Error: Docker is not running
```
**Solution**: Start Docker Desktop

### Act not installed
```
Error: act is not installed
```
**Solution**: Install act using brew/curl/choco

### Workflow not found
```
Error: Could not find workflow
```
**Solution**: Ensure you're running from project root

### Permission denied
```
Error: Permission denied
```
**Solution**: Make scripts executable
```bash
chmod +x tests/act/*.sh
chmod +x tests/act/lib/*.sh
chmod +x tests/act/scenarios/*.sh
```

### Mock action not found
```
Error: Could not find action
```
**Solution**: The test runner automatically copies mocks to `.github/actions/`

## Advanced Usage

### Run specific workflow
```bash
act -W .github/workflows/ai-task-router.yml \
    -e tests/act/events/issue-opened.json \
    --secret-file .env.act
```

### Debug mode
```bash
act -W .github/workflows/ai-task-router.yml \
    -e tests/act/events/issue-opened.json \
    --verbose \
    --secret-file .env.act
```

### Different Docker images
```bash
# Use smaller image (200MB)
act -P ubuntu-latest=catthehacker/ubuntu:act-20.04

# Use larger image (17GB, more tools)
act -P ubuntu-latest=catthehacker/ubuntu:full-latest
```

## CI/CD Integration

To run act tests in CI:

```yaml
name: Act Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install act
        run: |
          curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
      - name: Run act tests
        run: |
          ./tests/run.sh act
```

## Performance Tips

1. **Reuse containers**: The `.actrc` includes `--reuse` flag
2. **Use medium image**: Balance between size and features
3. **Local action mode**: Uses `--action-offline-mode` for speed
4. **Parallel tests**: Run independent tests concurrently

## Contributing

When adding new workflows:
1. Create corresponding test scenarios
2. Add mock behaviors as needed
3. Update this documentation
4. Ensure tests pass locally before pushing

## Related Documentation

- [act Documentation](https://github.com/nektos/act)
- [GitHub Actions Events](https://docs.github.com/en/actions/reference/events-that-trigger-workflows)
- [Project Workflows](../../.github/workflows/)