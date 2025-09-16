#!/usr/bin/env python3
"""
Test case to reproduce the GitHub Actions error for count_completions.py
This simulates the exact conditions in the workflow.
"""

import subprocess
import json
import tempfile
import os
import sys


def test_workflow_simulation():
    """Simulate the exact workflow conditions that cause exit code 127."""

    # Create temporary files like the workflow does
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        comments = [
            {"body": "🤖 Child C1 complete"},
            {"body": "🤖 Child C2 complete"}
        ]
        json.dump(comments, f)
        comments_file = f.name

    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as f:
        f.write("Parent issue with 3 child agents expected")
        issue_body_file = f.name

    try:
        # Test 1: Try calling with 'python' command (as workflow does)
        print("Test 1: Using 'python' command")
        result = subprocess.run([
            'python', 'scripts/python/count_completions.py',
            '--comments', json.dumps(comments),
            '--issue-body', "Parent issue with 3 child agents expected",
            '--threshold', '3'
        ], capture_output=True, text=True)
        print(f"Exit code: {result.returncode}")
        print(f"Stdout: {result.stdout}")
        print(f"Stderr: {result.stderr}")

        # Test 2: Try with python3 explicitly
        print("\nTest 2: Using 'python3' command")
        result = subprocess.run([
            'python3', 'scripts/python/count_completions.py',
            '--comments', json.dumps(comments),
            '--issue-body', "Parent issue with 3 child agents expected",
            '--threshold', '3'
        ], capture_output=True, text=True)
        print(f"Exit code: {result.returncode}")
        print(f"Stdout: {result.stdout}")
        print(f"Stderr: {result.stderr}")

        # Test 3: Try with file inputs (as workflow actually does)
        print("\nTest 3: Using file inputs via cat")
        cmd = f"""
        RESULT=$(python scripts/python/count_completions.py \
          --comments "$(cat {comments_file})" \
          --issue-body "$(cat {issue_body_file})" \
          --threshold 3)
        echo "Result: $RESULT"
        """
        result = subprocess.run(['bash', '-c', cmd], capture_output=True, text=True)
        print(f"Exit code: {result.returncode}")
        print(f"Stdout: {result.stdout}")
        print(f"Stderr: {result.stderr}")

        # Test 4: Check if script exists and is executable
        print("\nTest 4: Script path and permissions")
        script_path = 'scripts/python/count_completions.py'
        if os.path.exists(script_path):
            print(f"Script exists: {script_path}")
            print(f"Is executable: {os.access(script_path, os.X_OK)}")
            print(f"File permissions: {oct(os.stat(script_path).st_mode)}")
        else:
            print(f"ERROR: Script not found at {script_path}")

    finally:
        # Clean up temp files
        os.unlink(comments_file)
        os.unlink(issue_body_file)


def test_edge_cases():
    """Test edge cases that might cause issues."""

    print("\n=== Testing Edge Cases ===")

    # Test with empty comments
    print("\nTest: Empty comments")
    result = subprocess.run([
        sys.executable, 'scripts/python/count_completions.py',
        '--comments', '[]',
        '--threshold', '3'
    ], capture_output=True, text=True)
    print(f"Exit code: {result.returncode}")
    if result.returncode != 0:
        print(f"ERROR: {result.stderr}")
    else:
        output = json.loads(result.stdout)
        print(f"Output: {output}")

    # Test with malformed JSON
    print("\nTest: Malformed JSON")
    result = subprocess.run([
        sys.executable, 'scripts/python/count_completions.py',
        '--comments', '{bad json}',
        '--threshold', '3'
    ], capture_output=True, text=True)
    print(f"Exit code: {result.returncode}")
    print(f"Output: {result.stdout}")

    # Test with special characters in comments
    print("\nTest: Special characters in comments")
    comments = [{"body": "🤖 Child: Test with \"quotes\" and 'apostrophes'"}]
    result = subprocess.run([
        sys.executable, 'scripts/python/count_completions.py',
        '--comments', json.dumps(comments),
        '--threshold', '1'
    ], capture_output=True, text=True)
    print(f"Exit code: {result.returncode}")
    if result.returncode == 0:
        output = json.loads(result.stdout)
        print(f"Output: {output}")
        assert output['child_count'] == 1, "Should count comment with special chars"


if __name__ == "__main__":
    print("Running workflow simulation tests...")
    test_workflow_simulation()
    test_edge_cases()
    print("\nAll tests completed!")