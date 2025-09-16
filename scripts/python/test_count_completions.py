#!/usr/bin/env python3
"""
Unit tests for count_completions.py
"""

import pytest
import json
from count_completions import count_child_markers, extract_expected_count


class TestCountChildMarkers:
    """Test suite for count_child_markers function."""

    def test_empty_comments_list(self):
        """Empty comment list should return 0."""
        assert count_child_markers([]) == 0

    def test_no_child_markers(self):
        """Comments without child markers should return 0."""
        comments = [
            {"body": "Regular comment"},
            {"body": "Another normal comment"},
            {"body": "Status update"}
        ]
        assert count_child_markers(comments) == 0

    def test_single_child_marker(self):
        """Single child marker should return 1."""
        comments = [
            {"body": "Regular comment"},
            {"body": "🤖 Child: Task completed"},
            {"body": "Another comment"}
        ]
        assert count_child_markers(comments) == 1

    def test_multiple_child_markers(self):
        """Multiple child markers should return correct count."""
        comments = [
            {"body": "🤖 Child: Task 1 done"},
            {"body": "Regular comment"},
            {"body": "🤖 Child: Task 2 completed"},
            {"body": "🤖 Child: Task 3 finished"}
        ]
        assert count_child_markers(comments) == 3

    def test_child_marker_case_sensitivity(self):
        """Child marker detection should be case-sensitive."""
        comments = [
            {"body": "🤖 child: lowercase"},
            {"body": "🤖 CHILD: uppercase"},
            {"body": "🤖 Child: correct case"}
        ]
        # Only the correctly cased one should count
        assert count_child_markers(comments) == 1

    def test_child_marker_with_extra_spaces(self):
        """Child marker with extra spaces should still be detected."""
        comments = [
            {"body": "  🤖 Child: extra spaces before  "},
            {"body": "🤖  Child: space after emoji"},
            {"body": "🤖Child: no space after emoji"}
        ]
        # All variations should be detected
        assert count_child_markers(comments) == 3


class TestExtractExpectedCount:
    """Test suite for extract_expected_count function."""

    def test_empty_issue_body(self):
        """Empty issue body should return None."""
        assert extract_expected_count("") is None

    def test_no_count_in_body(self):
        """Issue body without count should return None."""
        body = "This is a parent issue for multiple tasks."
        assert extract_expected_count(body) is None

    def test_expected_children_pattern(self):
        """Should extract count from 'Expected children: N' pattern."""
        body = "Parent issue\nExpected children: 5\nMore details"
        assert extract_expected_count(body) == 5

    def test_child_count_pattern(self):
        """Should extract count from 'Child count: N' pattern."""
        body = "Task breakdown\nChild count: 3\nImplementation plan"
        assert extract_expected_count(body) == 3

    def test_n_child_agents_pattern(self):
        """Should extract count from 'N child agents' pattern."""
        body = "This task requires 4 child agents for completion"
        assert extract_expected_count(body) == 4

    def test_multiple_patterns_first_wins(self):
        """When multiple patterns present, first should be used."""
        body = """
        Expected children: 6
        Child count: 3
        Requires 4 child agents
        """
        assert extract_expected_count(body) == 6

    def test_case_insensitive_matching(self):
        """Pattern matching should be case-insensitive."""
        body = "EXPECTED CHILDREN: 7"
        assert extract_expected_count(body) == 7

    def test_invalid_number_returns_none(self):
        """Invalid number format should return None."""
        body = "Expected children: many"
        assert extract_expected_count(body) is None

    def test_negative_number_returns_none(self):
        """Negative numbers should return None."""
        body = "Expected children: -2"
        assert extract_expected_count(body) is None

    def test_zero_is_valid(self):
        """Zero should be a valid count."""
        body = "Expected children: 0"
        assert extract_expected_count(body) == 0