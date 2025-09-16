#!/usr/bin/env python3
"""
Test to simulate the exact GitHub Actions environment issue.
This tests potential issues with the workflow execution.
"""

import subprocess
import json
import os
import sys


def test_github_like_execution():
    """Test the exact way GitHub Actions would execute the script."""

    print("Testing GitHub Actions-like execution...")

    # Simulate what GitHub Actions does with multiline outputs
    comments_json = """[
  {
    "body": "🤖 Child C1: Task completed successfully",
    "created_at": "2024-01-01T00:00:00Z"
  },
  {
    "body": "Regular comment without marker",
    "created_at": "2024-01-01T00:01:00Z"
  },
  {
    "body": "🤖 Child C2: Another task done",
    "created_at": "2024-01-01T00:02:00Z"
  }
]"""

    issue_body = """This is a parent issue that will be split into 3 child agents.
Each child will handle a specific task.
Expected children: 3"""

    # Test 1: Direct execution (like in workflow)
    print("\n1. Testing direct execution with multiline JSON:")
    cmd = f'''
    python scripts/python/count_completions.py \\
      --comments '{comments_json}' \\
      --issue-body '{issue_body}' \\
      --threshold 3
    '''
    result = subprocess.run(['bash', '-c', cmd], capture_output=True, text=True)
    print(f"Exit code: {result.returncode}")
    if result.returncode != 0:
        print(f"ERROR: {result.stderr}")
    else:
        print(f"Output: {result.stdout}")

    # Test 2: With escaped JSON (potential issue)
    print("\n2. Testing with escaped JSON:")
    escaped_json = json.dumps(comments_json)
    cmd = f'''
    python scripts/python/count_completions.py \\
      --comments {escaped_json} \\
      --issue-body "{issue_body}" \\
      --threshold 3
    '''
    result = subprocess.run(['bash', '-c', cmd], capture_output=True, text=True)
    print(f"Exit code: {result.returncode}")
    if result.returncode != 0:
        print(f"ERROR: {result.stderr}")

    # Test 3: Test with empty/null values (edge case)
    print("\n3. Testing with empty values:")
    cmd = '''
    python scripts/python/count_completions.py \\
      --comments "[]" \\
      --issue-body "" \\
      --threshold 3
    '''
    result = subprocess.run(['bash', '-c', cmd], capture_output=True, text=True)
    print(f"Exit code: {result.returncode}")
    print(f"Output: {result.stdout}")

    # Test 4: Test the actual command structure from workflow
    print("\n4. Testing exact workflow command structure:")

    # Write temp files like the workflow does
    with open('/tmp/test_comments.json', 'w') as f:
        f.write(comments_json)
    with open('/tmp/test_issue_body.txt', 'w') as f:
        f.write(issue_body)

    cmd = '''
    RESULT=$(python scripts/python/count_completions.py \\
      --comments "$(cat /tmp/test_comments.json)" \\
      --issue-body "$(cat /tmp/test_issue_body.txt)" \\
      --threshold 3)
    echo "Result: $RESULT"
    echo "Exit code: $?"
    '''
    result = subprocess.run(['bash', '-c', cmd], capture_output=True, text=True)
    print(f"Shell exit code: {result.returncode}")
    print(f"Output: {result.stdout}")
    if result.stderr:
        print(f"Stderr: {result.stderr}")

    # Clean up
    os.unlink('/tmp/test_comments.json')
    os.unlink('/tmp/test_issue_body.txt')


def test_python_availability():
    """Test if python/python3 commands are available."""

    print("\n=== Testing Python Availability ===")

    commands = ['python', 'python3', 'python3.11']
    for cmd in commands:
        result = subprocess.run([cmd, '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print(f"{cmd}: {result.stdout.strip()}")
        else:
            print(f"{cmd}: NOT FOUND (exit code {result.returncode})")


if __name__ == "__main__":
    test_python_availability()
    test_github_like_execution()
    print("\nTests completed!")