#!/usr/bin/env python3
"""
Unit tests for analyze_completions.py
"""

import pytest
import json
from analyze_completions import (
    detect_status_type,
    determine_merge_strategy,
    parse_claude_response
)


class TestDetectStatusType:
    """Test suite for detect_status_type function."""

    def test_success_keywords(self):
        """Should detect success status from keywords."""
        assert detect_status_type("Task completed successfully") == "success"
        assert detect_status_type("All tests passing, PR merged") == "success"
        assert detect_status_type("✅ Done") == "success"
        assert detect_status_type("Finished and merged") == "success"

    def test_failure_keywords(self):
        """Should detect failure status from keywords."""
        assert detect_status_type("Failed to complete task") == "failure"
        assert detect_status_type("❌ Error occurred") == "failure"
        assert detect_status_type("Blocked by dependencies") == "failure"
        assert detect_status_type("Cannot proceed") == "failure"

    def test_partial_keywords(self):
        """Should detect partial completion status."""
        assert detect_status_type("Mostly complete") == "partial"
        assert detect_status_type("Partially implemented") == "partial"
        assert detect_status_type("Some tests failing") == "partial"
        assert detect_status_type("90% done") == "partial"

    def test_unknown_status(self):
        """Should return unknown for ambiguous status."""
        assert detect_status_type("Working on it") == "unknown"
        assert detect_status_type("In progress") == "unknown"
        assert detect_status_type("") == "unknown"
        assert detect_status_type("Status unclear") == "unknown"

    def test_case_insensitive(self):
        """Status detection should be case-insensitive."""
        assert detect_status_type("COMPLETED SUCCESSFULLY") == "success"
        assert detect_status_type("FAILED") == "failure"
        assert detect_status_type("PARTIAL") == "partial"

    def test_mixed_signals_precedence(self):
        """When mixed signals, should have precedence: failure > partial > success."""
        assert detect_status_type("Completed but some tests failed") == "partial"
        assert detect_status_type("Failed but mostly done") == "failure"


class TestDetermineMergeStrategy:
    """Test suite for determine_merge_strategy function."""

    def test_all_success(self):
        """All success should recommend merge with high confidence."""
        statuses = ["success", "success", "success"]
        result = determine_merge_strategy(statuses)
        assert result["strategy"] == "merge"
        assert result["confidence"] >= 0.9

    def test_all_failure(self):
        """All failure should recommend no merge with high confidence."""
        statuses = ["failure", "failure", "failure"]
        result = determine_merge_strategy(statuses)
        assert result["strategy"] == "no_merge"
        assert result["confidence"] >= 0.9

    def test_majority_success(self):
        """Majority success should recommend merge with medium confidence."""
        statuses = ["success", "success", "failure"]
        result = determine_merge_strategy(statuses)
        assert result["strategy"] == "merge"
        assert 0.5 <= result["confidence"] < 0.9

    def test_majority_failure(self):
        """Majority failure should recommend no merge."""
        statuses = ["failure", "failure", "success"]
        result = determine_merge_strategy(statuses)
        assert result["strategy"] == "no_merge"
        assert 0.5 <= result["confidence"] < 0.9

    def test_mixed_with_partial(self):
        """Mixed statuses with partial should lower confidence."""
        statuses = ["success", "partial", "failure"]
        result = determine_merge_strategy(statuses)
        assert result["strategy"] in ["merge", "no_merge", "manual_review"]
        assert result["confidence"] < 0.7

    def test_all_unknown(self):
        """All unknown should recommend manual review with low confidence."""
        statuses = ["unknown", "unknown", "unknown"]
        result = determine_merge_strategy(statuses)
        assert result["strategy"] == "manual_review"
        assert result["confidence"] < 0.3

    def test_empty_statuses(self):
        """Empty status list should recommend manual review."""
        result = determine_merge_strategy([])
        assert result["strategy"] == "manual_review"
        assert result["confidence"] == 0

    def test_single_success(self):
        """Single success should recommend merge with adjusted confidence."""
        result = determine_merge_strategy(["success"])
        assert result["strategy"] == "merge"
        assert result["confidence"] > 0.5


class TestParseClaudeResponse:
    """Test suite for parse_claude_response function."""

    def test_structured_json_response(self):
        """Should parse structured JSON response."""
        response = json.dumps({
            "status": "success",
            "confidence": 0.95,
            "summary": "All children completed",
            "details": ["Child 1: done", "Child 2: done"]
        })
        result = parse_claude_response(response)
        assert result["status"] == "success"
        assert result["confidence"] == 0.95
        assert "summary" in result
        assert "details" in result

    def test_text_response_with_keywords(self):
        """Should extract information from plain text response."""
        response = """
        Analysis complete. All child agents have successfully completed their tasks.
        Confidence: HIGH
        Recommendation: Safe to merge
        """
        result = parse_claude_response(response)
        assert result["status"] == "success"
        assert result["confidence"] > 0.7
        assert "recommendation" in result

    def test_markdown_formatted_response(self):
        """Should handle markdown formatted responses."""
        response = """
        ## Completion Analysis

        **Status**: Success
        **Confidence**: 85%

        ### Details:
        - Child 1: ✅ Complete
        - Child 2: ✅ Complete
        - Child 3: ✅ Complete
        """
        result = parse_claude_response(response)
        assert result["status"] == "success"
        assert result["confidence"] == 0.85
        assert len(result.get("children", [])) == 3

    def test_ambiguous_response(self):
        """Should handle ambiguous responses gracefully."""
        response = "The situation is unclear. Some tasks completed, others not."
        result = parse_claude_response(response)
        assert result["status"] in ["partial", "unknown"]
        assert result["confidence"] < 0.5

    def test_empty_response(self):
        """Should handle empty response."""
        result = parse_claude_response("")
        assert result["status"] == "unknown"
        assert result["confidence"] == 0

    def test_response_with_error(self):
        """Should detect error in response."""
        response = "ERROR: Unable to analyze completion status"
        result = parse_claude_response(response)
        assert result["status"] == "error"
        assert result["confidence"] == 0

    def test_percentage_extraction(self):
        """Should extract percentage values as confidence."""
        response = "Task is 75% complete"
        result = parse_claude_response(response)
        assert result.get("completion_percentage") == 75
        assert result["confidence"] == 0.75