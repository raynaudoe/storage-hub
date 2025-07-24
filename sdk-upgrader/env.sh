#!/bin/bash
# Simple environment setup for SDK Upgrader

# Core paths
export PROJECT_ROOT="/Users/eze/Repos/storage-hub"
export OUTPUT_DIR="$PROJECT_ROOT/output"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# SDK versions
export OLD_TAG="polkadot-stable2407-1"
export NEW_TAG="polkadot-stable2409"
export SDK_BRANCH="stable2409"

# Status tracking
export STATUS_FILE="$OUTPUT_DIR/status.json"
export UPGRADE_REPORT_PATH="$OUTPUT_DIR/upgrade_report.md"
export TEST_REPORT_PATH="$OUTPUT_DIR/test_report.md"

# Optional: Set Python path if needed
export PYTHONPATH="$PROJECT_ROOT/sdk-upgrader/tools:$PYTHONPATH"

echo "SDK Upgrader environment configured:"
echo "  PROJECT_ROOT: $PROJECT_ROOT"
echo "  Upgrading: $OLD_TAG -> $NEW_TAG"
echo "  Status file: $STATUS_FILE"