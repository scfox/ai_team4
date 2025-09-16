#!/usr/bin/env python3
"""
count_completions.py - Count child agent completion markers in GitHub issue comments
"""

import sys
import argparse
import json
import re
import logging
from typing import Dict, Any, Optional

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def count_child_markers(comments: list) -> int:
    """
    Count the number of comments containing the '🤖 Child' marker.

    Args:
        comments: List of GitHub issue comments

    Returns:
        Number of comments with child markers
    """
    if not comments:
        logger.debug("No comments provided")
        return 0

    count = 0
    logger.debug(f"Processing {len(comments)} comments")
    for comment in comments:
        if isinstance(comment, dict) and 'body' in comment:
            body = comment['body']
            # Check for the child marker with flexible spacing
            if '🤖' in body and 'Child' in body:
                # More flexible matching for variations
                if '🤖 Child' in body or '🤖  Child' in body or '🤖Child' in body:
                    count += 1
                    logger.debug(f"Found child marker in comment: {body[:50]}...")

    logger.info(f"Found {count} child markers in comments")
    return count


def extract_expected_count(issue_body: str) -> Optional[int]:
    """
    Extract the expected child count from the parent issue body.

    Looks for patterns like:
    - "Expected children: N"
    - "Child count: N"
    - "N child agents"

    Args:
        issue_body: GitHub issue body text

    Returns:
        Expected count if found, None otherwise
    """
    if not issue_body:
        logger.debug("No issue body provided")
        return None

    logger.debug(f"Extracting expected count from issue body: {issue_body[:100]}...")

    # Patterns to search for (case-insensitive)
    patterns = [
        r'expected\s+children:\s*(\d+)',
        r'child\s+count:\s*(\d+)',
        r'(\d+)\s+child\s+agents?'
    ]

    for pattern in patterns:
        match = re.search(pattern, issue_body, re.IGNORECASE)
        if match:
            count = int(match.group(1))
            # Only return non-negative numbers
            if count >= 0:
                logger.info(f"Extracted expected count: {count} using pattern: {pattern}")
                return count

    logger.debug("No expected count found in issue body")
    return None


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(description='Count child agent completion markers')
    parser.add_argument('--comments', type=str, help='JSON string of issue comments')
    parser.add_argument('--issue-body', type=str, help='Issue body text')
    parser.add_argument('--threshold', type=int, default=3, help='Completion threshold')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')

    args = parser.parse_args()

    # Set debug level if requested
    if args.debug:
        logger.setLevel(logging.DEBUG)
        logging.getLogger().setLevel(logging.DEBUG)

    # Parse comments JSON
    comments = []
    if args.comments:
        try:
            comments = json.loads(args.comments)
            logger.debug(f"Successfully parsed {len(comments)} comments")
        except json.JSONDecodeError as e:
            logger.error(f"Failed to parse comments JSON: {e}")
            print(json.dumps({
                "error": f"Failed to parse comments JSON: {e}",
                "child_count": 0,
                "expected_count": None,
                "threshold_met": False
            }))
            return 1

    # Count child markers
    child_count = count_child_markers(comments)

    # Extract expected count from issue body
    expected_count = None
    if args.issue_body:
        expected_count = extract_expected_count(args.issue_body)

    # Check if threshold is met
    threshold_met = child_count >= args.threshold
    logger.info(f"Checking threshold: {child_count} >= {args.threshold} = {threshold_met}")

    # If we have an expected count, also check against that
    if expected_count is not None:
        expected_met = child_count >= expected_count
        logger.info(f"Checking expected: {child_count} >= {expected_count} = {expected_met}")
        threshold_met = threshold_met or expected_met

    result = {
        "child_count": child_count,
        "expected_count": expected_count,
        "threshold_met": threshold_met,
        "threshold": args.threshold
    }

    logger.info(f"Final result: child_count={child_count}, threshold_met={threshold_met}")
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())