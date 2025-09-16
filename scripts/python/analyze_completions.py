#!/usr/bin/env python3
"""
analyze_completions.py - Analyze child agent completion status from Claude's response
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


def detect_status_type(child_status: str) -> str:
    """
    Detect the status type from a child agent's reported status.

    Args:
        child_status: Status text from child agent

    Returns:
        Status type: 'success', 'failure', 'partial', or 'unknown'
    """
    if not child_status:
        logger.debug("No child status provided")
        return "unknown"

    logger.debug(f"Detecting status type for: {child_status[:100]}...")

    status_lower = child_status.lower()

    # Check for partial completion first (special cases)
    if "some tests failing" in status_lower:
        logger.info(f"Detected partial status: some tests failing")
        return "partial"
    if "completed but" in status_lower and "failed" in status_lower:
        logger.info(f"Detected partial status: completed but failed")
        return "partial"

    # Check for failure (high precedence)
    failure_keywords = ['fail', 'error', 'block', 'cannot', '❌']
    if any(keyword in status_lower for keyword in failure_keywords):
        logger.info(f"Detected failure status based on keywords")
        return "failure"

    # Check for partial completion
    partial_keywords = ['partial', 'mostly', '%']
    if any(keyword in status_lower for keyword in partial_keywords):
        # Special case: percentage values
        if '%' in status_lower and not '100%' in status_lower:
            return "partial"
        elif any(kw in status_lower for kw in partial_keywords[:-1]):
            return "partial"

    # Check for success
    success_keywords = ['complet', 'success', 'done', 'finish', 'merg', 'pass', '✅']
    if any(keyword in status_lower for keyword in success_keywords):
        # But if it says "failed" along with completed, it's partial
        if 'fail' in status_lower:
            logger.info(f"Detected partial status: completed but has 'fail' keyword")
            return "partial"
        logger.info(f"Detected success status based on keywords")
        return "success"

    # Check for in-progress or unknown
    progress_keywords = ['in progress', 'working on']
    if any(keyword in status_lower for keyword in progress_keywords):
        logger.info(f"Detected in-progress status")
        return "unknown"

    logger.warning(f"Could not determine status type, defaulting to unknown")
    return "unknown"


def determine_merge_strategy(statuses: list) -> Dict[str, Any]:
    """
    Determine the merge strategy based on child statuses.

    Args:
        statuses: List of child status types

    Returns:
        Dictionary with merge strategy and confidence
    """
    logger.info(f"Determining merge strategy for statuses: {statuses}")

    if not statuses:
        logger.warning("No statuses provided")
        return {
            "strategy": "manual_review",
            "confidence": 0
        }

    # Count status types
    counts = {
        "success": statuses.count("success"),
        "failure": statuses.count("failure"),
        "partial": statuses.count("partial"),
        "unknown": statuses.count("unknown")
    }

    total = len(statuses)

    # All success - high confidence merge
    if counts["success"] == total:
        return {
            "strategy": "merge",
            "confidence": 0.95 if total > 1 else 0.7
        }

    # All failure - high confidence no merge
    if counts["failure"] == total:
        return {
            "strategy": "no_merge",
            "confidence": 0.95 if total > 1 else 0.7
        }

    # All unknown - manual review with low confidence
    if counts["unknown"] == total:
        return {
            "strategy": "manual_review",
            "confidence": 0.2
        }

    # Mixed statuses - calculate based on majority
    success_ratio = counts["success"] / total
    failure_ratio = counts["failure"] / total

    # If we have partials, reduce confidence
    confidence_penalty = 0.2 if counts["partial"] > 0 else 0

    if success_ratio > 0.5:
        # Majority success
        confidence = 0.7 - confidence_penalty
        return {
            "strategy": "merge",
            "confidence": max(confidence, 0.5)
        }
    elif failure_ratio > 0.5:
        # Majority failure
        confidence = 0.7 - confidence_penalty
        return {
            "strategy": "no_merge",
            "confidence": max(confidence, 0.5)
        }
    else:
        # No clear majority - manual review
        return {
            "strategy": "manual_review",
            "confidence": 0.4 - confidence_penalty
        }


def parse_claude_response(response_text: str) -> Dict[str, Any]:
    """
    Parse Claude's response to extract completion analysis.

    Args:
        response_text: Claude's response text

    Returns:
        Parsed analysis with status and recommendations
    """
    if not response_text:
        logger.debug("No response text provided")
        return {
            "status": "unknown",
            "confidence": 0
        }

    logger.debug(f"Parsing Claude response: {response_text[:200]}...")

    result = {
        "status": "unknown",
        "confidence": 0
    }

    # Try to parse as JSON first
    try:
        data = json.loads(response_text)
        if isinstance(data, dict):
            result["status"] = data.get("status", "unknown")
            result["confidence"] = data.get("confidence", 0)
            if "summary" in data:
                result["summary"] = data["summary"]
            if "details" in data:
                result["details"] = data["details"]
            logger.info(f"Successfully parsed JSON response: status={result['status']}, confidence={result['confidence']}")
            return result
    except (json.JSONDecodeError, ValueError):
        # Not JSON, parse as text
        logger.debug("Response is not JSON, parsing as text")
        pass

    # Check for error
    if "ERROR:" in response_text.upper():
        result["status"] = "error"
        result["confidence"] = 0
        logger.warning("Detected error in Claude response")
        return result

    response_lower = response_text.lower()

    # Extract status from text
    # Check for ambiguous or unclear first
    if "unclear" in response_lower or "ambiguous" in response_lower:
        result["status"] = "unknown"
    elif any(word in response_lower for word in ["partial", "mostly", "some"]):
        result["status"] = "partial"
    elif any(word in response_lower for word in ["fail", "error", "problem"]):
        result["status"] = "failure"
    elif any(word in response_lower for word in ["success", "complete", "done", "safe to merge"]):
        result["status"] = "success"
    else:
        result["status"] = "unknown"

    # Extract confidence level
    if "high" in response_lower and "confidence" in response_lower:
        result["confidence"] = 0.9
    elif "medium" in response_lower and "confidence" in response_lower:
        result["confidence"] = 0.6
    elif "low" in response_lower and "confidence" in response_lower:
        result["confidence"] = 0.3

    # Extract percentage if present
    percentage_match = re.search(r'(\d+)%', response_text)
    if percentage_match:
        percentage = int(percentage_match.group(1))
        result["completion_percentage"] = percentage
        if result["confidence"] == 0:  # Use percentage as confidence if not set
            result["confidence"] = percentage / 100.0

    # Extract children from markdown
    if '✅' in response_text:
        children_count = response_text.count('✅')
        result["children"] = [f"Child {i+1}" for i in range(children_count)]

    # Add recommendation if present
    if "recommendation:" in response_lower:
        result["recommendation"] = True

    # Adjust confidence based on status
    if result["status"] == "success" and result["confidence"] == 0:
        result["confidence"] = 0.7
    elif result["status"] == "unknown" and result["confidence"] > 0.5:
        result["confidence"] = 0.4

    return result


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(description='Analyze child agent completion status')
    parser.add_argument('--claude-response', type=str, help='Claude response text')
    parser.add_argument('--child-statuses', type=str, help='JSON array of child statuses')
    parser.add_argument('--issue-number', type=int, help='Parent issue number')
    parser.add_argument('--debug', action='store_true', help='Enable debug logging')

    args = parser.parse_args()

    # Set debug level if requested
    if args.debug:
        logger.setLevel(logging.DEBUG)
        logging.getLogger().setLevel(logging.DEBUG)

    # Parse Claude response if provided
    claude_analysis = {}
    if args.claude_response:
        claude_analysis = parse_claude_response(args.claude_response)

    # Parse and analyze child statuses if provided
    merge_strategy = {"strategy": "unknown", "confidence": 0}
    if args.child_statuses:
        try:
            statuses_data = json.loads(args.child_statuses)
            logger.debug(f"Parsed {len(statuses_data)} child statuses")
            # Extract status types from the data
            status_types = []

            if isinstance(statuses_data, list):
                for status in statuses_data:
                    if isinstance(status, str):
                        status_types.append(detect_status_type(status))
                    elif isinstance(status, dict) and 'status' in status:
                        status_types.append(detect_status_type(status['status']))
                    elif isinstance(status, dict) and 'body' in status:
                        status_types.append(detect_status_type(status['body']))

            # Determine merge strategy based on statuses
            if status_types:
                merge_strategy = determine_merge_strategy(status_types)

        except json.JSONDecodeError as e:
            print(json.dumps({
                "error": f"Failed to parse child statuses JSON: {e}",
                "parent_issue": args.issue_number,
                "analysis": claude_analysis,
                "merge_strategy": "manual_review",
                "confidence": 0.0
            }))
            return 1

    # Combine results
    result = {
        "parent_issue": args.issue_number,
        "analysis": claude_analysis,
        "merge_strategy": merge_strategy.get("strategy", "unknown"),
        "confidence": merge_strategy.get("confidence", claude_analysis.get("confidence", 0.0)),
        "recommendation": claude_analysis.get("recommendation", merge_strategy.get("strategy", "manual_review"))
    }

    # If Claude provided a status, include it
    if "status" in claude_analysis:
        result["claude_status"] = claude_analysis["status"]

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())