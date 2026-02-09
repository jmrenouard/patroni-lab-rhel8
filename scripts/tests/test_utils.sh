#!/bin/bash
# test_utils.sh
# Shared utilities for standardized test logging and diagnostics.

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TEST_COUNT=0
FAILURES=0

# Helper for verbose logging
# Usage: run_test "Test Title" "command_to_execute"
run_test() {
    local title="$1"
    local cmd="$2"
    TEST_COUNT=$((TEST_COUNT + 1))
    
    echo -e "${BLUE}[TEST #$TEST_COUNT]${NC} $title"
    echo -e "   [CMD] $cmd"
    
    # Execute command
    eval "$cmd" > /tmp/test_out 2>&1
    local ret=$?
    
    if [ $ret -eq 0 ]; then
        echo -e "   [RESULT] ${GREEN}OK${NC}"
        return 0
    else
        echo -e "   [RESULT] ${RED}FAIL (Exit code: $ret)${NC}"
        echo -e "   --- ERROR OUTPUT ---"
        cat /tmp/test_out | sed 's/^/   | /'
        echo -e "   --------------------"
        FAILURES=$((FAILURES + 1))
        return 1
    fi
}

# Helper to print diagnostic commands
# Usage: print_diagnostics "Component Name" "cmd1" "cmd2" ...
print_diagnostics() {
    local component="$1"
    shift
    echo -e "\n${YELLOW}🛠️  Diagnostic Commands for $component:${NC}"
    for cmd in "$@"; do
        echo -e "   👉 $cmd"
    done
    echo ""
}

# Final summary
print_summary() {
    local script_name="$1"
    if [ $FAILURES -eq 0 ]; then
        echo -e "\n${GREEN}✅ $script_name: All $TEST_COUNT tests passed.${NC}\n"
        return 0
    else
        echo -e "\n${RED}❌ $script_name: $FAILURES/$TEST_COUNT tests failed.${NC}\n"
        return $FAILURES
    fi
}
