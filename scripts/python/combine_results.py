#!/usr/bin/env python3
"""
T024: Result combiner for merging child agent outputs
Combines results from multiple child agents into a unified response
"""

import json
import sys
from dataclasses import dataclass, asdict
from typing import Dict, List, Any, Optional


@dataclass
class CombinedResult:
    """Combined result from multiple child agents"""
    content: str
    format_type: str
    metadata: Dict[str, Any]


def combine_child_results(child_results: List[Dict[str, Any]]) -> CombinedResult:
    """
    Combine results from multiple child agents.

    Args:
        child_results: List of result dictionaries from child agents

    Returns:
        CombinedResult with merged content and metadata
    """
    if not child_results:
        return CombinedResult(
            content="",
            format_type="empty",
            metadata={"children_count": 0}
        )

    # Initialize metadata
    metadata = {
        "children_count": len(child_results),
        "children": [],
        "successful_children": 0,
        "failed_children": 0,
        "warnings": []
    }

    # Process each child result
    combined_content = []
    for result in child_results:
        child_id = result.get("child_id", "unknown")
        status = result.get("status", "unknown")

        # Track child metadata
        child_meta = {
            "child_id": child_id,
            "status": status,
            "branch": result.get("branch", ""),
            "execution_time_ms": result.get("execution_time_ms", 0)
        }
        metadata["children"].append(child_meta)

        # Handle different statuses
        if status == "success":
            metadata["successful_children"] += 1
            child_content = result.get("results", {})
            combined_content.append({
                "child_id": child_id,
                "task": result.get("task", ""),
                "results": child_content
            })
        elif status == "failed":
            metadata["failed_children"] += 1
            error_msg = result.get("error", "Unknown error")
            metadata["warnings"].append(f"Child {child_id} failed: {error_msg}")
        elif status == "timeout":
            metadata["failed_children"] += 1
            metadata["warnings"].append(f"Child {child_id} timed out after 8 minutes")

    # Format the combined content
    if combined_content:
        formatted = format_combined_output(combined_content, "markdown")
    else:
        formatted = "No successful results to combine."

    # Check for truncation need
    max_size = 65536
    if len(formatted) > max_size:
        formatted = formatted[:max_size - 100] + "\n\n[Content truncated due to size limit]"
        metadata["truncated"] = True
    else:
        metadata["truncated"] = False

    return CombinedResult(
        content=formatted,
        format_type="markdown",
        metadata=metadata
    )


def merge_json_results(results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Merge JSON results from multiple sources.

    Args:
        results: List of JSON-like dictionaries

    Returns:
        Merged results as a list of dictionaries
    """
    merged = []

    for result in results:
        if isinstance(result, dict):
            merged.append(result)
        elif isinstance(result, list):
            merged.extend(result)

    return merged


def format_combined_output(results: List[Dict[str, Any]], format_type: str) -> str:
    """
    Format combined results for display.

    Args:
        results: List of result dictionaries
        format_type: Output format ('table', 'list', 'markdown')

    Returns:
        Formatted string
    """
    if format_type == "table":
        return format_as_table(results)
    elif format_type == "list":
        return format_as_list(results)
    else:  # markdown
        return format_as_markdown(results)


def format_as_table(results: List[Dict[str, Any]]) -> str:
    """Format results as a markdown table"""
    if not results:
        return ""

    # Extract all unique keys for headers
    all_keys = set()
    for result in results:
        if "results" in result and isinstance(result["results"], dict):
            all_keys.update(result["results"].keys())

    if not all_keys:
        return format_as_list(results)

    # Build table
    headers = ["Task/Item"] + sorted(all_keys)
    lines = []

    # Header row
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("|" + "|".join(["---" for _ in headers]) + "|")

    # Data rows
    for result in results:
        task = result.get("task", result.get("child_id", "Unknown"))
        row = [task]

        result_data = result.get("results", {})
        for key in sorted(all_keys):
            value = result_data.get(key, "-")
            if isinstance(value, (list, dict)):
                value = str(value)[:50] + "..." if len(str(value)) > 50 else str(value)
            row.append(str(value))

        lines.append("| " + " | ".join(row) + " |")

    return "\n".join(lines)


def format_as_list(results: List[Dict[str, Any]]) -> str:
    """Format results as a markdown list"""
    lines = []

    for i, result in enumerate(results, 1):
        child_id = result.get("child_id", i)
        task = result.get("task", "Task")

        lines.append(f"### {i}. {task} (Child {child_id})")
        lines.append("")

        result_data = result.get("results", {})
        if isinstance(result_data, dict):
            for key, value in result_data.items():
                lines.append(f"- **{key}**: {value}")
        else:
            lines.append(str(result_data))

        lines.append("")

    return "\n".join(lines)


def format_as_markdown(results: List[Dict[str, Any]]) -> str:
    """Format results as structured markdown"""
    lines = []

    for result in results:
        child_id = result.get("child_id", "unknown")
        task = result.get("task", "")

        if task:
            lines.append(f"## Child {child_id}: {task}")
        else:
            lines.append(f"## Child {child_id} Results")

        lines.append("")

        result_data = result.get("results", {})
        if isinstance(result_data, dict):
            for key, value in result_data.items():
                lines.append(f"### {key}")
                if isinstance(value, list):
                    for item in value:
                        lines.append(f"- {item}")
                else:
                    lines.append(str(value))
                lines.append("")
        else:
            lines.append(str(result_data))

        lines.append("---")
        lines.append("")

    return "\n".join(lines)


def main():
    """Main entry point for CLI usage"""
    if len(sys.argv) < 2:
        print("Usage: python combine_results.py <results.json>")
        print("   or: python combine_results.py --stdin")
        sys.exit(1)

    # Read input
    if sys.argv[1] == "--stdin":
        data = json.load(sys.stdin)
    else:
        with open(sys.argv[1], 'r') as f:
            data = json.load(f)

    # Ensure data is a list
    if not isinstance(data, list):
        data = [data]

    # Combine results
    result = combine_child_results(data)

    # Output combined result
    print(result.content)

    # Output metadata as JSON to stderr for parsing
    print(json.dumps(result.metadata), file=sys.stderr)


if __name__ == "__main__":
    main()