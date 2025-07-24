#!/usr/bin/env zsh
#
# run.sh — Main entrypoint for the SDK upgrader
#
# This orchestrates the complete SDK upgrade process:
#   1. Gathers PR artifacts using scout.sh
#   2. Executes the upgrade using runner.sh
#
# Usage:
#   ./run.sh <OLD_SDK_TAG> <NEW_SDK_TAG>
#
#   OLD_SDK_TAG  – The current Polkadot-SDK tag (e.g. "polkadot-stable2407")
#   NEW_SDK_TAG  – The target Polkadot-SDK tag (e.g. "polkadot-stable2410")
#
# Example:
#   ./run.sh polkadot-stable2407 polkadot-stable2410
#

set -euo pipefail

# Ensure we're in the SDK upgrader directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR"

if (( $# != 2 )); then
  echo "Usage: $0 <OLD_SDK_TAG> <NEW_SDK_TAG>" >&2
  echo "Example: $0 polkadot-stable2407 polkadot-stable2410" >&2
  exit 1
fi

OLD_TAG="$1"
NEW_TAG="$2"

echo "🚀 Starting SDK upgrade process"
echo "   From: $OLD_TAG"
echo "   To:   $NEW_TAG"
echo ""

# Step 1: Run scout to gather PR artifacts
echo "📥 Step 1: Gathering PR artifacts with scout..."
if [[ ! -f "tools/scout.sh" ]]; then
  echo "Error: tools/scout.sh not found" >&2
  exit 1
fi

./tools/scout.sh "$NEW_TAG"

# Check if scout was successful
if [[ ! -d "resources/polkadot-sdk-${NEW_TAG}" ]]; then
  echo "Error: Scout failed to create resources/polkadot-sdk-${NEW_TAG}" >&2
  exit 1
fi

echo ""
echo "✅ Scout completed successfully"
echo ""

# Step 2: Run the upgrade process
echo "🔧 Step 2: Running upgrade process..."
if [[ ! -f "tools/runner.sh" ]]; then
  echo "Error: tools/runner.sh not found" >&2
  exit 1
fi

./tools/runner.sh "$OLD_TAG" "$NEW_TAG"

echo ""
echo "🎉 SDK upgrade process completed!"
echo ""
echo "📁 Results available in:"
echo "   • Status: output/status.json"
echo "   • Report: output/UPGRADE_REPORT_${NEW_TAG}.md"