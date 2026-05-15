#!/bin/bash
# Quality Gate - Run All Checks
# Usage: bash .claude/skills/quality-gate/scripts/check-all.sh

set -e

echo "========================================"
echo "        QUALITY GATE - ALL CHECKS"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

FAILED=0

# 1. TypeCheck
echo "1/5 Running TypeCheck..."
if bun run typecheck 2>&1; then
    echo -e "${GREEN}✓ TypeCheck passed${NC}"
else
    echo -e "${RED}✗ TypeCheck failed${NC}"
    FAILED=1
fi
echo ""

# 2. Lint
echo "2/5 Running Lint..."
if bun run lint 2>&1; then
    echo -e "${GREEN}✓ Lint passed${NC}"
else
    echo -e "${RED}✗ Lint failed${NC}"
    FAILED=1
fi
echo ""

# 3. Unit Tests
echo "3/5 Running Unit Tests..."
if bun run test 2>&1; then
    echo -e "${GREEN}✓ Unit tests passed${NC}"
else
    echo -e "${RED}✗ Unit tests failed${NC}"
    FAILED=1
fi
echo ""

# 4. E2E Tests (optional - check if exists)
echo "4/5 Running E2E Tests..."
if [ -f "playwright.config.ts" ]; then
    if bun run test:e2e 2>&1; then
        echo -e "${GREEN}✓ E2E tests passed${NC}"
    else
        echo -e "${YELLOW}⚠ E2E tests failed (non-blocking)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ E2E tests skipped (no playwright config)${NC}"
fi
echo ""

# 5. Build
echo "5/5 Running Build..."
if bun run build 2>&1; then
    echo -e "${GREEN}✓ Build passed${NC}"
else
    echo -e "${RED}✗ Build failed${NC}"
    FAILED=1
fi
echo ""

# Summary
echo "========================================"
echo "                SUMMARY"
echo "========================================"
if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All quality gates passed!${NC}"
    exit 0
else
    echo -e "${RED}Some quality gates failed!${NC}"
    exit 1
fi
