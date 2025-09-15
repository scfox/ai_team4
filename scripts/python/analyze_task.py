#!/usr/bin/env python3
"""
T023: Task analyzer for parallelization detection
Determines if a task should be split into parallel subtasks
"""

import re
import sys
from dataclasses import dataclass
from typing import List, Optional


@dataclass
class TaskAnalysis:
    """Result of task analysis"""
    parallelizable: bool
    subtasks: List[str]
    reason: str


def analyze_task(task_text: str) -> TaskAnalysis:
    """
    Analyze a task to determine if it should be parallelized.

    Args:
        task_text: The task description from the user

    Returns:
        TaskAnalysis with parallelization decision and subtasks
    """
    if not task_text or not task_text.strip():
        return TaskAnalysis(
            parallelizable=False,
            subtasks=[],
            reason="Empty task"
        )

    task_lower = task_text.lower()

    # Keywords that suggest parallelization
    parallel_keywords = ['parallel', 'compare', 'both', 'each', 'multiple', 'and also']
    has_parallel_keyword = any(keyword in task_lower for keyword in parallel_keywords)

    # Extract potential subtasks
    subtasks = extract_subtasks(task_text)

    # Decision logic
    if has_parallel_keyword and len(subtasks) >= 2:
        # Limit to 5 subtasks (constitution requirement)
        subtasks = subtasks[:5]
        return TaskAnalysis(
            parallelizable=True,
            subtasks=subtasks,
            reason=f"Task contains parallel keywords and {len(subtasks)} subtasks"
        )
    elif len(subtasks) >= 2 and any(marker in task_text for marker in ['1.', '•', '-', '*']):
        # Has numbered/bulleted list
        subtasks = subtasks[:5]
        return TaskAnalysis(
            parallelizable=True,
            subtasks=subtasks,
            reason=f"Task contains list with {len(subtasks)} items"
        )
    elif 'compare' in task_lower:
        # Special case for comparison tasks
        items = extract_comparison_items(task_text)
        if len(items) >= 2:
            subtasks = [f"Research {item}" for item in items[:5]]
            return TaskAnalysis(
                parallelizable=True,
                subtasks=subtasks,
                reason=f"Comparison task with {len(items)} items"
            )

    # Default: single task
    return TaskAnalysis(
        parallelizable=False,
        subtasks=[],
        reason="Single task without clear parallelization opportunity"
    )


def extract_subtasks(task_text: str) -> List[str]:
    """
    Extract subtasks from text that might contain lists.

    Args:
        task_text: Text potentially containing subtasks

    Returns:
        List of subtask descriptions
    """
    subtasks = []

    # Try numbered lists (1., 2., etc.)
    numbered_pattern = r'^\s*\d+\.\s+(.+?)(?=^\s*\d+\.|$)'
    numbered_matches = re.findall(numbered_pattern, task_text, re.MULTILINE | re.DOTALL)
    if numbered_matches:
        subtasks = [match.strip() for match in numbered_matches]
        return subtasks

    # Try bullet points (-, *, •)
    bullet_pattern = r'^\s*[-*•]\s+(.+?)(?=^\s*[-*•]|$)'
    bullet_matches = re.findall(bullet_pattern, task_text, re.MULTILINE | re.DOTALL)
    if bullet_matches:
        subtasks = [match.strip() for match in bullet_matches]
        return subtasks

    # Try to extract from "and" separated items
    if 'and' in task_text.lower():
        parts = re.split(r'\s+and\s+', task_text)
        if 2 <= len(parts) <= 5:
            # Clean up parts
            subtasks = [part.strip() for part in parts]
            # Filter out very short parts (likely not real tasks)
            subtasks = [s for s in subtasks if len(s) > 10]

    return subtasks


def extract_comparison_items(task_text: str) -> List[str]:
    """
    Extract items to compare from a comparison task.

    Args:
        task_text: Text containing comparison request

    Returns:
        List of items to compare
    """
    items = []

    # Pattern: "compare X and Y"
    compare_pattern = r'compare\s+(.+?)\s+(?:and|vs\.?|versus)\s+(.+?)(?:\s|$|\.)'
    match = re.search(compare_pattern, task_text.lower())
    if match:
        items = [match.group(1).strip(), match.group(2).strip()]
        # Clean up the items
        items = [item.strip('.,;:') for item in items]
        return items

    # Pattern: "compare/comparison of X, Y, Z"
    list_pattern = r'(?:compare|comparison of)\s+(.+)'
    match = re.search(list_pattern, task_text.lower())
    if match:
        item_text = match.group(1)
        # Split by common separators
        if ',' in item_text:
            items = item_text.split(',')
        elif ' and ' in item_text:
            items = item_text.split(' and ')
        items = [item.strip('.,;:') for item in items]
        return items

    return items


def main():
    """Main entry point for CLI usage"""
    if len(sys.argv) < 2:
        print("Usage: python analyze_task.py '<task description>'")
        print("Example: python analyze_task.py 'Compare FastAPI and Flask'")
        sys.exit(1)

    task_text = ' '.join(sys.argv[1:])

    # Analyze the task
    result = analyze_task(task_text)

    # Output result
    print(f"Parallelizable: {result.parallelizable}")
    print(f"Reason: {result.reason}")

    if result.subtasks:
        print(f"Subtasks ({len(result.subtasks)}):")
        for i, subtask in enumerate(result.subtasks, 1):
            print(f"  {i}. {subtask}")

    # Return exit code based on parallelization decision
    sys.exit(0 if result.parallelizable else 1)


if __name__ == "__main__":
    main()