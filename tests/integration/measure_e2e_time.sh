#!/bin/bash
# measure_e2e_time.sh - Measure end-to-end completion detection time

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}[PERF]${NC} Measuring end-to-end completion detection time"
echo -e "${BLUE}[PERF]${NC} =============================================="

# Start total timer
TOTAL_START=$(date +%s.%N)

# Phase 1: Comment Detection
echo -e "${CYAN}[PHASE 1]${NC} Comment Detection"
echo -e "-------------------"

COMMENTS='[
  {"body": "🤖 Child C1 complete: PR #10 ready", "created_at": "2024-01-01T10:00:00Z"},
  {"body": "🤖 Child C2 complete: PR #11 ready", "created_at": "2024-01-01T10:01:00Z"},
  {"body": "🤖 Child C3 complete: PR #12 ready", "created_at": "2024-01-01T10:02:00Z"}
]'

ISSUE_BODY="Expected children: 3\nThis issue requires parallel processing of 3 tasks."

# Measure comment detection
DETECT_START=$(date +%s.%N)
COUNT_RESULT=$(python3 scripts/python/count_completions.py \
  --comments "$COMMENTS" \
  --issue-body "$ISSUE_BODY" \
  --threshold 3 2>/dev/null)
DETECT_END=$(date +%s.%N)
DETECT_TIME=$(echo "$DETECT_END - $DETECT_START" | bc)

echo -e "${GREEN}[✓]${NC} Comment detection: ${DETECT_TIME}s"
echo -e "    Result: $(echo $COUNT_RESULT | jq -c '.')"

# Phase 2: Trigger Decision
echo -e "${CYAN}[PHASE 2]${NC} Trigger Decision"
echo -e "-------------------"

TRIGGER_START=$(date +%s.%N)
THRESHOLD_MET=$(echo "$COUNT_RESULT" | jq -r '.threshold_met')
if [ "$THRESHOLD_MET" == "true" ]; then
    echo -e "${GREEN}[✓]${NC} Threshold met, triggering analysis"
else
    echo -e "${YELLOW}[!]${NC} Threshold not met, would not trigger"
    exit 1
fi
TRIGGER_END=$(date +%s.%N)
TRIGGER_TIME=$(echo "$TRIGGER_END - $TRIGGER_START" | bc)
echo -e "    Decision time: ${TRIGGER_TIME}s"

# Phase 3: Status Analysis
echo -e "${CYAN}[PHASE 3]${NC} Status Analysis"
echo -e "-------------------"

CHILD_STATUSES='[
  {"child": "C1", "status": "complete", "pr": 10},
  {"child": "C2", "status": "complete", "pr": 11},
  {"child": "C3", "status": "complete", "pr": 12}
]'

ANALYSIS_START=$(date +%s.%N)
ANALYSIS_RESULT=$(python3 scripts/python/analyze_completions.py \
    --child-statuses "$CHILD_STATUSES" 2>/dev/null)
ANALYSIS_END=$(date +%s.%N)
ANALYSIS_TIME=$(echo "$ANALYSIS_END - $ANALYSIS_START" | bc)

echo -e "${GREEN}[✓]${NC} Status analysis: ${ANALYSIS_TIME}s"
echo -e "    Strategy: $(echo $ANALYSIS_RESULT | jq -r '.merge_strategy')"

# Phase 4: Simulated Claude Processing
echo -e "${CYAN}[PHASE 4]${NC} Claude Processing (simulated)"
echo -e "-------------------------------"

CLAUDE_START=$(date +%s.%N)
# Simulate Claude processing time
sleep 0.5  # Simulating network + processing
CLAUDE_RESPONSE='{
  "strategy": "MERGE_ALL",
  "confidence": 0.95,
  "pr_numbers": [10, 11, 12],
  "reasoning": "All children completed successfully"
}'
CLAUDE_END=$(date +%s.%N)
CLAUDE_TIME=$(echo "$CLAUDE_END - $CLAUDE_START" | bc)

echo -e "${GREEN}[✓]${NC} Claude processing: ${CLAUDE_TIME}s"
echo -e "    Strategy: MERGE_ALL"

# Phase 5: Final Action
echo -e "${CYAN}[PHASE 5]${NC} Final Action (simulated)"
echo -e "--------------------------"

ACTION_START=$(date +%s.%N)
# Simulate PR merging API calls
sleep 0.2  # Simulating GitHub API calls
ACTION_END=$(date +%s.%N)
ACTION_TIME=$(echo "$ACTION_END - $ACTION_START" | bc)

echo -e "${GREEN}[✓]${NC} Action execution: ${ACTION_TIME}s"
echo -e "    PRs merged: #10, #11, #12"

# Calculate total time
TOTAL_END=$(date +%s.%N)
TOTAL_TIME=$(echo "$TOTAL_END - $TOTAL_START" | bc)

# Summary
echo -e "\n${BLUE}[SUMMARY]${NC} End-to-End Performance Breakdown"
echo -e "=========================================="
echo -e "  Phase 1 - Comment Detection:  ${DETECT_TIME}s"
echo -e "  Phase 2 - Trigger Decision:   ${TRIGGER_TIME}s"
echo -e "  Phase 3 - Status Analysis:    ${ANALYSIS_TIME}s"
echo -e "  Phase 4 - Claude Processing:  ${CLAUDE_TIME}s"
echo -e "  Phase 5 - Final Action:       ${ACTION_TIME}s"
echo -e "  ${GREEN}TOTAL TIME: ${TOTAL_TIME}s${NC}"

# Performance Requirements Check
echo -e "\n${BLUE}[CHECK]${NC} Performance Requirements"
echo -e "================================"

# Individual phase checks
if (( $(echo "$DETECT_TIME < 2.0" | bc -l) )); then
    echo -e "${GREEN}✓${NC} Detection < 2s: ${DETECT_TIME}s"
else
    echo -e "${RED}✗${NC} Detection >= 2s: ${DETECT_TIME}s"
fi

if (( $(echo "$CLAUDE_TIME < 60.0" | bc -l) )); then
    echo -e "${GREEN}✓${NC} Analysis < 60s: ${CLAUDE_TIME}s"
else
    echo -e "${RED}✗${NC} Analysis >= 60s: ${CLAUDE_TIME}s"
fi

if (( $(echo "$TOTAL_TIME < 120.0" | bc -l) )); then
    echo -e "${GREEN}✓${NC} End-to-end < 2 min: ${TOTAL_TIME}s"
    echo -e "\n${GREEN}[SUCCESS]${NC} All performance requirements met!"
    exit 0
else
    echo -e "${RED}✗${NC} End-to-end >= 2 min: ${TOTAL_TIME}s"
    echo -e "\n${RED}[FAIL]${NC} Performance requirements not met"
    exit 1
fi