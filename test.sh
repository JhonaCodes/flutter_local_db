#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Running Flutter Tests...${NC}"
echo "======================================="

# Run flutter test and capture output
flutter test > test_output.tmp 2>&1
test_exit_code=$?

# Extract summary
echo -e "\n${YELLOW}📊 TEST SUMMARY${NC}"
echo "======================================="

# Get the final result line
tail -n 10 test_output.tmp | grep -E "^\d+:\d+ \+\d+ -\d+:" | tail -1

# Check if tests passed or failed
if [ $test_exit_code -eq 0 ]; then
    echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
else
    echo -e "${RED}❌ SOME TESTS FAILED${NC}"
    echo ""
    
    # Extract failed test information
    echo -e "${RED}🚨 FAILED TESTS:${NC}"
    echo "======================================="
    
    # Find failed tests with file names
    grep -n "FAILED:" test_output.tmp | while read line; do
        echo -e "${RED}$line${NC}"
    done
    
    # Extract test file names that had failures
    echo -e "\n${RED}📁 FILES WITH FAILING TESTS:${NC}"
    echo "======================================="
    
    # Look for file patterns in the output
    grep -o "test/[^[:space:]]*\.dart" test_output.tmp | sort | uniq | while read file; do
        # Check if this file had failures by looking at the context
        if grep -B5 -A5 "$file" test_output.tmp | grep -q "FAILED\|Some tests failed"; then
            echo -e "${RED}❌ $file${NC}"
        fi
    done
    
    # Show error details
    echo -e "\n${RED}🔍 ERROR DETAILS:${NC}"
    echo "======================================="
    
    # Extract error messages
    grep -A3 -B3 "FAILED\|Some tests failed\|Error:" test_output.tmp | head -20
fi

# Show test files that were run
echo -e "\n${BLUE}📋 TEST FILES EXECUTED:${NC}"
echo "======================================="
grep -o "test/[^[:space:]]*\.dart" test_output.tmp | sort | uniq | while read file; do
    if grep -B5 -A5 "$file" test_output.tmp | grep -q "All tests passed\|+.*:"; then
        echo -e "${GREEN}✅ $file${NC}"
    else
        echo -e "${YELLOW}⚠️  $file${NC}"
    fi
done

# Clean up temporary file
rm -f test_output.tmp

echo ""
echo "======================================="

if [ $test_exit_code -eq 0 ]; then
    echo -e "${GREEN}🎉 Test run completed successfully!${NC}"
else
    echo -e "${RED}💥 Test run completed with failures!${NC}"
    echo -e "${YELLOW}💡 Check the error details above for specific issues.${NC}"
fi

exit $test_exit_code