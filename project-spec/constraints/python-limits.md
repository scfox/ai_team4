# Constraint: Python Usage Limitations

## Rule
**Python can be used for logic, NOT for git operations.**

## The Hard Boundary
```python
# ✅ ALLOWED Python Operations:
- JSON/YAML parsing and generation
- Data analysis and transformation
- Complex state calculations
- API calls with urllib/requests
- File reading and writing (non-git)
- Report generation

# ❌ FORBIDDEN Python Operations:
- ANY GitPython usage
- ANY pygit2 usage
- Git commands via subprocess
- GitHub CLI via subprocess
- Branch creation/checkout
- Commit operations
```

## Why This Constraint Exists
GitPython and similar libraries fail in GitHub Actions due to permission restrictions. This is a fundamental incompatibility with GitHub's security model, not a fixable bug.

## Implementation Pattern

### Good: Hybrid Approach
```yaml
# workflow.yml
- name: Git Operations (Bash)
  run: |
    git checkout -b gitaiteams/issue-${{ github.event.issue.number }}
    git add .
    git commit -m "Initialize task"
    
- name: Complex Logic (Python)
  run: |
    python scripts/analyze_task.py
    python scripts/generate_plan.py
```

### Bad: Python Attempting Git
```python
# This WILL FAIL in GitHub Actions
from git import Repo
repo = Repo(".")
repo.create_branch("new-branch")  # Permission denied
```

## Recommended Python Uses

### 1. Task Analysis
```python
# scripts/analyze_task.py
import json
import re

def analyze_task(task_text):
    """Determine if task needs parallel execution."""
    parallel_keywords = ['parallel', 'compare', 'both', 'each']
    return any(keyword in task_text.lower() for keyword in parallel_keywords)
```

### 2. State Derivation
```python
# scripts/derive_state.py
import subprocess
import json

def get_branch_count(pattern):
    """Count branches matching pattern using git CLI."""
    result = subprocess.run(
        ["git", "branch", "-r"],
        capture_output=True,
        text=True
    )
    branches = [b for b in result.stdout.split('\n') if pattern in b]
    return len(branches)
```

### 3. Result Combination
```python
# scripts/combine_results.py
import json
from pathlib import Path

def combine_child_results(child_dirs):
    """Merge results from multiple child agents."""
    combined = {}
    for dir in child_dirs:
        with open(Path(dir) / "RESULTS.json") as f:
            combined.update(json.load(f))
    return combined
```

## Testing Python Code
Python scripts should be tested independently of git operations:
```bash
# Test Python logic without git
python -m pytest tests/test_analyze_task.py

# Integration tests use bash for git setup
./tests/integration/test_with_git.sh
```