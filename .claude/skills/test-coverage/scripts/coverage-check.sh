#!/bin/bash
# Test Coverage Check Script
# Usage: bash .claude/skills/test-coverage/scripts/coverage-check.sh [threshold]

set -e

THRESHOLD=${1:-80}

echo "========================================"
echo "      TEST COVERAGE CHECK"
echo "      Threshold: ${THRESHOLD}%"
echo "========================================"
echo ""

# Run tests with coverage
echo "Running tests with coverage..."
bun test --coverage 2>&1 | tee coverage-output.txt

# Extract coverage percentage (adjust regex based on your test framework)
COVERAGE=$(grep -E "All files.*\|" coverage-output.txt | awk '{print $4}' | tr -d '%' || echo "0")

echo ""
echo "========================================"
echo "           RESULTS"
echo "========================================"

if [ -z "$COVERAGE" ] || [ "$COVERAGE" = "0" ]; then
    echo "⚠ Could not determine coverage percentage"
    echo "Check coverage-output.txt for details"
    exit 1
fi

echo "Coverage: ${COVERAGE}%"
echo "Threshold: ${THRESHOLD}%"
echo ""

# Compare (using bc for decimal comparison)
PASS=$(echo "$COVERAGE >= $THRESHOLD" | bc -l 2>/dev/null || echo "0")

if [ "$PASS" = "1" ]; then
    echo "✓ Coverage meets threshold!"
    rm -f coverage-output.txt
    exit 0
else
    echo "✗ Coverage below threshold!"
    echo ""
    echo "Files needing more coverage:"
    grep -E "^\s+[a-zA-Z].*\|.*\|.*\|.*\|" coverage-output.txt | \
        awk -F'|' '{if ($2 < '$THRESHOLD' || $3 < '$THRESHOLD') print $1, $2"%", $3"%"}' || true
    rm -f coverage-output.txt
    exit 1
fi
