#!/bin/bash
set -e

echo "=== Running Starforge RPG Test Suite ==="

# Run unit tests
echo ""
echo "--- Unit Tests ---"
godot --headless --script addons/gut/gut_cmdln.gd \
    -gtest=tests/unit/ \
    -gexit

# Run integration tests
echo ""
echo "--- Integration Tests ---"
godot --headless --script addons/gut/gut_cmdln.gd \
    -gtest=tests/integration/ \
    -gexit

# Run dialogue validation
echo ""
echo "--- Dialogue Path Validation ---"
godot --headless --script addons/gut/gut_cmdln.gd \
    -gtest=tests/integration/test_dialogue_paths.gd \
    -gexit

echo ""
echo "--- Dialogue Content Validation ---"
godot --headless --script addons/gut/gut_cmdln.gd \
    -gtest=tests/integration/test_dialogue_content.gd \
    -gexit

echo ""
echo "=== All Tests Passed ==="
