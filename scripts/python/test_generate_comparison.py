#!/usr/bin/env python3
"""
T015: Test for comparison generator
Tests markdown table generation for comparisons
"""

import pytest
import sys
from pathlib import Path
from typing import List, Dict, Any

# Add scripts/python to path for imports
sys.path.insert(0, str(Path(__file__).parent))

# This will fail initially (TDD) - generate_comparison.py doesn't exist yet
try:
    from generate_comparison import (
        generate_comparison_table,
        extract_comparison_data,
        format_as_markdown_table,
        ComparisonTable
    )
except ImportError:
    # Create minimal stubs for tests to run
    class ComparisonTable:
        def __init__(self, headers, rows, title):
            self.headers = headers
            self.rows = rows
            self.title = title

    def generate_comparison_table(data, title="Comparison"):
        """Stub function - will be implemented in T025"""
        raise NotImplementedError("generate_comparison_table not yet implemented")

    def extract_comparison_data(results):
        """Stub function - will be implemented in T025"""
        raise NotImplementedError("extract_comparison_data not yet implemented")

    def format_as_markdown_table(headers, rows):
        """Stub function - will be implemented in T025"""
        raise NotImplementedError("format_as_markdown_table not yet implemented")


class TestGenerateComparison:
    """Test suite for comparison table generation"""

    def test_generate_simple_comparison(self):
        """Should generate a simple comparison table"""
        data = [
            {"name": "FastAPI", "performance": "Excellent", "ease": "Good"},
            {"name": "Flask", "performance": "Good", "ease": "Excellent"}
        ]

        table = generate_comparison_table(data, "Framework Comparison")
        assert "Framework Comparison" in str(table.title)
        assert len(table.headers) >= 3
        assert len(table.rows) == 2

    def test_markdown_table_format(self):
        """Should format as valid markdown table"""
        headers = ["Framework", "Performance", "Ease of Use"]
        rows = [
            ["FastAPI", "Excellent", "Good"],
            ["Flask", "Good", "Excellent"]
        ]

        markdown = format_as_markdown_table(headers, rows)
        assert "|" in markdown
        assert "---" in markdown  # Table separator
        assert "Framework" in markdown
        assert "FastAPI" in markdown
        assert "Flask" in markdown

    def test_extract_comparison_from_child_results(self):
        """Should extract comparison data from child results"""
        child_results = [
            {
                "framework": "FastAPI",
                "metrics": {
                    "performance": "9/10",
                    "documentation": "8/10",
                    "community": "7/10"
                }
            },
            {
                "framework": "Flask",
                "metrics": {
                    "performance": "7/10",
                    "documentation": "9/10",
                    "community": "9/10"
                }
            }
        ]

        data = extract_comparison_data(child_results)
        assert len(data) == 2
        assert all("framework" in item for item in data)

    def test_handle_missing_fields(self):
        """Should handle missing fields gracefully"""
        data = [
            {"name": "FastAPI", "performance": "Excellent"},
            {"name": "Flask", "ease": "Excellent"}  # Missing performance
        ]

        table = generate_comparison_table(data)
        # Should handle missing fields with placeholder
        assert len(table.rows) == 2
        for row in table.rows:
            assert len(row) == len(table.headers)

    def test_empty_comparison(self):
        """Should handle empty data"""
        table = generate_comparison_table([])
        assert len(table.rows) == 0
        assert table.title is not None

    def test_single_item_comparison(self):
        """Should handle single item (no comparison)"""
        data = [{"name": "FastAPI", "score": "9/10"}]

        table = generate_comparison_table(data)
        assert len(table.rows) == 1

    def test_complex_nested_data(self):
        """Should handle nested data structures"""
        data = [
            {
                "name": "FastAPI",
                "metrics": {
                    "performance": {"score": 9, "note": "Async support"},
                    "features": ["OpenAPI", "Type hints", "Fast"]
                }
            },
            {
                "name": "Flask",
                "metrics": {
                    "performance": {"score": 7, "note": "Sync by default"},
                    "features": ["Simple", "Flexible", "Mature"]
                }
            }
        ]

        table = generate_comparison_table(data)
        # Should flatten nested structures appropriately
        assert len(table.rows) == 2

    def test_max_column_width(self):
        """Should handle very long content"""
        data = [
            {"name": "Framework1", "description": "x" * 1000},
            {"name": "Framework2", "description": "y" * 1000}
        ]

        table = generate_comparison_table(data)
        # Should truncate or wrap long content
        markdown = format_as_markdown_table(table.headers, table.rows)
        lines = markdown.split("\n")
        # No single line should be too long for GitHub
        assert all(len(line) < 500 for line in lines)

    def test_special_characters_escaping(self):
        """Should escape special markdown characters"""
        data = [
            {"name": "Fast|API", "note": "Uses | pipes"},
            {"name": "Flask*", "note": "Has * stars"}
        ]

        table = generate_comparison_table(data)
        markdown = format_as_markdown_table(table.headers, table.rows)
        # Should properly escape or handle special chars
        assert "Fast" in markdown
        assert "Flask" in markdown

    def test_comparison_with_scores(self):
        """Should handle numeric scores for sorting"""
        data = [
            {"name": "FastAPI", "score": 9, "rank": 1},
            {"name": "Flask", "score": 8, "rank": 2},
            {"name": "Django", "score": 7, "rank": 3}
        ]

        table = generate_comparison_table(data)
        assert len(table.rows) == 3
        # Could be sorted by score/rank

    def test_generate_pros_cons_table(self):
        """Should generate pros/cons comparison"""
        data = [
            {
                "name": "FastAPI",
                "pros": ["Fast", "Modern", "Type hints"],
                "cons": ["Newer", "Smaller community"]
            },
            {
                "name": "Flask",
                "pros": ["Simple", "Mature", "Flexible"],
                "cons": ["Synchronous", "More boilerplate"]
            }
        ]

        table = generate_comparison_table(data, "Framework Pros/Cons")
        assert "Pros" in str(table.headers) or "pros" in str(table.headers)
        assert "Cons" in str(table.headers) or "cons" in str(table.headers)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])