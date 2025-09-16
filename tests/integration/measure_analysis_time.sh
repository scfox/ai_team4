#!/bin/bash
# measure_analysis_time.sh - Measure Claude analysis processing time

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}[PERF]${NC} Measuring Claude analysis processing time"
echo -e "${BLUE}[PERF]${NC} ========================================="

# Sample child statuses for analysis
CHILD_STATUSES='[
  {"child": "C1", "status": "🤖 Child C1 complete: PR #10 ready"},
  {"child": "C2", "status": "🤖 Child C2 complete: PR #11 ready"},
  {"child": "C3", "status": "🤖 Child C3 failed: tests not passing"}
]'

# Test 1: Status detection performance
echo -e "${YELLOW}[TEST]${NC} Testing status detection performance..."
DETECT_START=$(date +%s.%N)

for i in {1..100}; do
    python3 -c "
import sys
sys.path.insert(0, 'scripts/python')
from analyze_completions import detect_status_type
status = '🤖 Child C$i complete: PR #$i ready'
result = detect_status_type(status)
" 2>/dev/null
done

DETECT_END=$(date +%s.%N)
DETECT_TIME=$(echo "($DETECT_END - $DETECT_START) / 100" | bc -l)
echo -e "${GREEN}[TIME]${NC} Average status detection: ${DETECT_TIME:0:6}s per status"

# Test 2: Strategy determination performance
echo -e "${YELLOW}[TEST]${NC} Testing merge strategy determination..."
STRATEGY_START=$(date +%s.%N)

python3 -c "
import sys
import json
sys.path.insert(0, 'scripts/python')
from analyze_completions import determine_merge_strategy

# Test various scenarios
scenarios = [
    [2, 1, 0],  # 2 success, 1 fail
    [3, 0, 0],  # all success
    [0, 3, 0],  # all fail
    [1, 1, 1],  # mixed
]

for s in scenarios:
    result = determine_merge_strategy(s)
" 2>/dev/null

STRATEGY_END=$(date +%s.%N)
STRATEGY_TIME=$(echo "$STRATEGY_END - $STRATEGY_START" | bc)
echo -e "${GREEN}[TIME]${NC} Strategy determination: ${STRATEGY_TIME}s for 4 scenarios"

# Test 3: Full analysis pipeline
echo -e "${YELLOW}[TEST]${NC} Testing full analysis pipeline..."
PIPELINE_START=$(date +%s.%N)

ANALYSIS_RESULT=$(python3 scripts/python/analyze_completions.py \
    --child-statuses "$CHILD_STATUSES" 2>/dev/null)

PIPELINE_END=$(date +%s.%N)
PIPELINE_TIME=$(echo "$PIPELINE_END - $PIPELINE_START" | bc)
echo -e "${GREEN}[TIME]${NC} Full pipeline: ${PIPELINE_TIME}s"

# Simulate Claude API call time (this would be actual in production)
CLAUDE_TIME="5.0" # Estimated Claude response time
echo -e "${YELLOW}[TIME]${NC} Estimated Claude API time: ${CLAUDE_TIME}s"

# Calculate total analysis time
TOTAL_TIME=$(echo "$PIPELINE_TIME + $CLAUDE_TIME" | bc)
echo -e "${GREEN}[TOTAL]${NC} Total analysis time: ${TOTAL_TIME}s"

# Performance summary
echo -e "${BLUE}[SUMMARY]${NC} Performance Metrics:"
echo -e "  • Status detection: ${DETECT_TIME:0:6}s per status"
echo -e "  • Strategy determination: ${STRATEGY_TIME}s"
echo -e "  • Full pipeline: ${PIPELINE_TIME}s"
echo -e "  • Claude API (estimated): ${CLAUDE_TIME}s"
echo -e "  • Total: ${TOTAL_TIME}s"

# Check against requirement (< 60s)
if (( $(echo "$TOTAL_TIME < 60.0" | bc -l) )); then
    echo -e "${GREEN}✓${NC} Performance requirement met: ${TOTAL_TIME}s < 60.0s"
    exit 0
else
    echo -e "${RED}✗${NC} Performance requirement not met: ${TOTAL_TIME}s >= 60.0s"
    exit 1
fi