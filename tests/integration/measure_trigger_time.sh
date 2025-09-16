#!/bin/bash
# measure_trigger_time.sh - Measure time from last comment to analysis start

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}[PERF]${NC} Measuring trigger time from comment to analysis"
echo -e "${BLUE}[PERF]${NC} ============================================"

# Start timer
START_TIME=$(date +%s.%N)

# Simulate comment posting
COMMENTS='[
  {"body": "🤖 Child C1 complete: PR #10 ready"},
  {"body": "🤖 Child C2 complete: PR #11 ready"},
  {"body": "🤖 Child C3 complete: PR #12 ready"}
]'

ISSUE_BODY="Expected children: 3"

# Run the count check
echo -e "${YELLOW}[TIME]${NC} Starting count check..."
COUNT_START=$(date +%s.%N)

RESULT=$(python3 scripts/python/count_completions.py \
  --comments "$COMMENTS" \
  --issue-body "$ISSUE_BODY" \
  --threshold 3 2>/dev/null)

COUNT_END=$(date +%s.%N)
COUNT_TIME=$(echo "$COUNT_END - $COUNT_START" | bc)

echo -e "${GREEN}[RESULT]${NC} $RESULT"
echo -e "${YELLOW}[TIME]${NC} Count check completed in: ${COUNT_TIME}s"

# Check if threshold is met
THRESHOLD_MET=$(echo "$RESULT" | jq -r '.threshold_met')

if [ "$THRESHOLD_MET" == "true" ]; then
    echo -e "${GREEN}[TRIGGER]${NC} Threshold met, analysis would be triggered"

    # Simulate repository_dispatch trigger time (network latency)
    DISPATCH_TIME="0.5" # Estimated GitHub API call time
    echo -e "${YELLOW}[TIME]${NC} Estimated dispatch time: ${DISPATCH_TIME}s"

    TOTAL_TIME=$(echo "$COUNT_TIME + $DISPATCH_TIME" | bc)
    echo -e "${GREEN}[TOTAL]${NC} Total trigger time: ${TOTAL_TIME}s"

    # Check against requirement (< 2s)
    if (( $(echo "$TOTAL_TIME < 2.0" | bc -l) )); then
        echo -e "${GREEN}✓${NC} Performance requirement met: ${TOTAL_TIME}s < 2.0s"
        exit 0
    else
        echo -e "${YELLOW}⚠${NC} Performance requirement not met: ${TOTAL_TIME}s >= 2.0s"
        exit 1
    fi
else
    echo -e "${YELLOW}[SKIP]${NC} Threshold not met, no trigger"
fi

END_TIME=$(date +%s.%N)
ELAPSED=$(echo "$END_TIME - $START_TIME" | bc)
echo -e "${BLUE}[PERF]${NC} Total measurement time: ${ELAPSED}s"