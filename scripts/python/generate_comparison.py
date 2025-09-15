#!/usr/bin/env python3
"""
T025: Comparison table generator
Creates formatted markdown tables for comparing items
"""

import json
import sys
from dataclasses import dataclass
from typing import List, Dict, Any, Optional


@dataclass
class ComparisonTable:
    """Represents a comparison table"""
    headers: List[str]
    rows: List[List[str]]
    title: str


def generate_comparison_table(data: List[Dict[str, Any]], title: str = "Comparison") -> ComparisonTable:
    """
    Generate a comparison table from data.

    Args:
        data: List of dictionaries to compare
        title: Title for the comparison table

    Returns:
        ComparisonTable object
    """
    if not data:
        return ComparisonTable(
            headers=[],
            rows=[],
            title=title
        )

    # Extract all unique keys for headers
    all_keys = set()
    for item in data:
        all_keys.update(flatten_dict(item).keys())

    # Sort headers for consistency
    headers = sorted(all_keys)

    # Build rows
    rows = []
    for item in data:
        flat_item = flatten_dict(item)
        row = []
        for header in headers:
            value = flat_item.get(header, "-")
            # Format value for display
            if isinstance(value, list):
                value = ", ".join(str(v) for v in value[:3])
                if len(value) > 3:
                    value += "..."
            elif isinstance(value, dict):
                value = json.dumps(value)[:50] + "..." if len(json.dumps(value)) > 50 else json.dumps(value)
            elif len(str(value)) > 100:
                value = str(value)[:97] + "..."
            row.append(str(value))
        rows.append(row)

    return ComparisonTable(
        headers=headers,
        rows=rows,
        title=title
    )


def extract_comparison_data(results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """
    Extract comparison data from child results.

    Args:
        results: Raw results from child agents

    Returns:
        List of dictionaries ready for comparison
    """
    comparison_data = []

    for result in results:
        # Extract the framework/item name
        item_name = result.get("framework", result.get("name", result.get("item", "Unknown")))

        # Build comparison entry
        entry = {"Name": item_name}

        # Extract metrics or properties
        if "metrics" in result:
            metrics = result["metrics"]
            if isinstance(metrics, dict):
                for key, value in metrics.items():
                    # Handle nested metrics
                    if isinstance(value, dict) and "score" in value:
                        entry[key] = value["score"]
                        if "note" in value:
                            entry[f"{key}_note"] = value["note"]
                    else:
                        entry[key] = value
        else:
            # Use all top-level properties
            for key, value in result.items():
                if key not in ["framework", "name", "item"]:
                    entry[key] = value

        comparison_data.append(entry)

    return comparison_data


def format_as_markdown_table(headers: List[str], rows: List[List[str]]) -> str:
    """
    Format headers and rows as a markdown table.

    Args:
        headers: List of column headers
        rows: List of row data

    Returns:
        Formatted markdown table string
    """
    if not headers:
        return ""

    lines = []

    # Escape pipe characters in content
    safe_headers = [h.replace("|", "\\|") for h in headers]
    safe_rows = []
    for row in rows:
        safe_row = [cell.replace("|", "\\|") for cell in row]
        safe_rows.append(safe_row)

    # Calculate column widths for better formatting
    col_widths = [len(h) for h in safe_headers]
    for row in safe_rows:
        for i, cell in enumerate(row):
            if i < len(col_widths):
                col_widths[i] = max(col_widths[i], len(cell))

    # Limit column width to prevent extremely wide tables
    max_width = 50
    col_widths = [min(w, max_width) for w in col_widths]

    # Build header row
    header_row = "| " + " | ".join(
        h.ljust(w)[:w] for h, w in zip(safe_headers, col_widths)
    ) + " |"
    lines.append(header_row)

    # Build separator row
    separator = "|" + "|".join("-" * (w + 2) for w in col_widths) + "|"
    lines.append(separator)

    # Build data rows
    for row in safe_rows:
        padded_row = []
        for i, cell in enumerate(row):
            if i < len(col_widths):
                # Truncate if necessary
                if len(cell) > col_widths[i]:
                    cell = cell[:col_widths[i]-3] + "..."
                padded_row.append(cell.ljust(col_widths[i]))
            else:
                padded_row.append(cell)

        row_str = "| " + " | ".join(padded_row) + " |"
        lines.append(row_str)

    return "\n".join(lines)


def flatten_dict(d: Dict[str, Any], parent_key: str = "", sep: str = "_") -> Dict[str, Any]:
    """
    Flatten nested dictionary.

    Args:
        d: Dictionary to flatten
        parent_key: Parent key for nested items
        sep: Separator between parent and child keys

    Returns:
        Flattened dictionary
    """
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k

        if isinstance(v, dict):
            # Don't flatten too deep
            if parent_key:
                items.append((new_key, str(v)))
            else:
                items.extend(flatten_dict(v, new_key, sep=sep).items())
        elif isinstance(v, list):
            # Convert lists to comma-separated strings
            if all(isinstance(item, (str, int, float)) for item in v):
                items.append((new_key, ", ".join(str(item) for item in v)))
            else:
                items.append((new_key, str(v)))
        else:
            items.append((new_key, v))

    return dict(items)


def generate_pros_cons_table(data: List[Dict[str, Any]]) -> str:
    """
    Generate a pros/cons comparison table.

    Args:
        data: List of items with pros and cons

    Returns:
        Formatted markdown table
    """
    headers = ["Item", "Pros", "Cons"]
    rows = []

    for item in data:
        name = item.get("name", "Unknown")
        pros = item.get("pros", [])
        cons = item.get("cons", [])

        # Format pros and cons as bullet lists
        if isinstance(pros, list):
            pros_str = " • ".join(pros)
        else:
            pros_str = str(pros)

        if isinstance(cons, list):
            cons_str = " • ".join(cons)
        else:
            cons_str = str(cons)

        rows.append([name, pros_str, cons_str])

    return format_as_markdown_table(headers, rows)


def main():
    """Main entry point for CLI usage"""
    if len(sys.argv) < 2:
        print("Usage: python generate_comparison.py <data.json> [title]")
        print("   or: python generate_comparison.py --stdin [title]")
        sys.exit(1)

    # Get title if provided
    title = sys.argv[2] if len(sys.argv) > 2 else "Comparison"

    # Read input
    if sys.argv[1] == "--stdin":
        data = json.load(sys.stdin)
    else:
        with open(sys.argv[1], 'r') as f:
            data = json.load(f)

    # Ensure data is a list
    if not isinstance(data, list):
        data = [data]

    # Extract comparison data if needed
    if any("framework" in item or "metrics" in item for item in data):
        data = extract_comparison_data(data)

    # Generate comparison table
    table = generate_comparison_table(data, title)

    # Output the table
    print(f"## {table.title}")
    print()
    if table.headers and table.rows:
        print(format_as_markdown_table(table.headers, table.rows))
    else:
        print("No data to compare")

    # Check for pros/cons format
    if any("pros" in item and "cons" in item for item in data):
        print()
        print("## Pros and Cons")
        print()
        print(generate_pros_cons_table(data))


if __name__ == "__main__":
    main()