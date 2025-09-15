#!/usr/bin/env python3
"""
T014: Test for result combiner
Tests merging of child agent outputs
"""

import pytest
import json
import sys
from pathlib import Path
from typing import Dict, List, Any

# Add scripts/python to path for imports
sys.path.insert(0, str(Path(__file__).parent))

# This will fail initially (TDD) - combine_results.py doesn't exist yet
try:
    from combine_results import (
        combine_child_results,
        merge_json_results,
        format_combined_output,
        CombinedResult
    )
except ImportError:
    # Create minimal stubs for tests to run
    class CombinedResult:
        def __init__(self, content, format_type, metadata):
            self.content = content
            self.format_type = format_type
            self.metadata = metadata

    def combine_child_results(child_results):
        """Stub function - will be implemented in T024"""
        raise NotImplementedError("combine_child_results not yet implemented")

    def merge_json_results(results):
        """Stub function - will be implemented in T024"""
        raise NotImplementedError("merge_json_results not yet implemented")

    def format_combined_output(results, format_type):
        """Stub function - will be implemented in T024"""
        raise NotImplementedError("format_combined_output not yet implemented")


class TestCombineResults:
    """Test suite for result combination functionality"""

    def test_combine_two_child_results(self):
        """Should combine results from two children"""
        child1_result = {
            "child_id": 1,
            "task": "Research FastAPI",
            "results": {
                "performance": "Excellent",
                "ease_of_use": "Good",
                "ecosystem": "Growing"
            }
        }

        child2_result = {
            "child_id": 2,
            "task": "Research Flask",
            "results": {
                "performance": "Good",
                "ease_of_use": "Excellent",
                "ecosystem": "Mature"
            }
        }

        combined = combine_child_results([child1_result, child2_result])
        assert len(combined.metadata["children"]) == 2
        assert "FastAPI" in combined.content
        assert "Flask" in combined.content

    def test_combine_empty_results(self):
        """Should handle empty results gracefully"""
        combined = combine_child_results([])
        assert combined.content == ""
        assert combined.metadata["children_count"] == 0

    def test_combine_single_result(self):
        """Should handle single child result"""
        single_result = {
            "child_id": 1,
            "task": "Analyze code",
            "results": {"analysis": "Complete"}
        }

        combined = combine_child_results([single_result])
        assert combined.metadata["children_count"] == 1
        assert "analysis" in combined.content.lower()

    def test_merge_json_results(self):
        """Should merge JSON results correctly"""
        json1 = {"framework": "FastAPI", "score": 9}
        json2 = {"framework": "Flask", "score": 8}

        merged = merge_json_results([json1, json2])
        assert isinstance(merged, dict) or isinstance(merged, list)
        assert len(merged) == 2 if isinstance(merged, list) else True

    def test_format_as_table(self):
        """Should format results as markdown table"""
        results = [
            {"framework": "FastAPI", "performance": "Excellent", "ease": "Good"},
            {"framework": "Flask", "performance": "Good", "ease": "Excellent"}
        ]

        formatted = format_combined_output(results, "table")
        assert "|" in formatted  # Markdown table
        assert "FastAPI" in formatted
        assert "Flask" in formatted
        assert "Performance" in formatted or "performance" in formatted

    def test_format_as_list(self):
        """Should format results as markdown list"""
        results = [
            {"task": "Task 1", "status": "Complete"},
            {"task": "Task 2", "status": "Complete"}
        ]

        formatted = format_combined_output(results, "list")
        assert "- " in formatted or "* " in formatted or "1. " in formatted
        assert "Task 1" in formatted
        assert "Task 2" in formatted

    def test_handle_failed_child(self):
        """Should handle failed child results"""
        results = [
            {"child_id": 1, "status": "success", "results": {"data": "value"}},
            {"child_id": 2, "status": "failed", "error": "Timeout"}
        ]

        combined = combine_child_results(results)
        assert "failed" in combined.metadata.get("warnings", "").lower()
        assert combined.metadata["successful_children"] == 1
        assert combined.metadata["failed_children"] == 1

    def test_handle_timeout_child(self):
        """Should handle timeout scenarios"""
        results = [
            {"child_id": 1, "status": "success", "results": {}},
            {"child_id": 2, "status": "timeout", "error": "8 minute timeout exceeded"}
        ]

        combined = combine_child_results(results)
        assert "timeout" in combined.metadata.get("warnings", "").lower()

    def test_max_children_limit(self):
        """Should handle up to 5 children (constitution limit)"""
        results = [
            {"child_id": i, "results": {f"data{i}": f"value{i}"}}
            for i in range(1, 6)  # 5 children
        ]

        combined = combine_child_results(results)
        assert combined.metadata["children_count"] == 5

    def test_preserve_child_metadata(self):
        """Should preserve important metadata from children"""
        child_result = {
            "child_id": 1,
            "branch": "gitaiteams/issue-43-child-1",
            "execution_time_ms": 45000,
            "task": "Research task",
            "results": {"finding": "important"}
        }

        combined = combine_child_results([child_result])
        child_meta = combined.metadata["children"][0]
        assert child_meta["branch"] == "gitaiteams/issue-43-child-1"
        assert child_meta["execution_time_ms"] == 45000

    def test_truncation_handling(self):
        """Should handle large results that exceed GitHub limits"""
        # Create a large result
        large_content = "x" * 70000  # Over 65536 limit
        results = [{"child_id": 1, "results": {"content": large_content}}]

        combined = combine_child_results(results)
        assert combined.metadata.get("truncated", False) is True
        assert len(combined.content) <= 65536


if __name__ == "__main__":
    pytest.main([__file__, "-v"])