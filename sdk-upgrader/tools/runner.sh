#!/usr/bin/env zsh
#
# runner.sh — Upgrade runner that executes the error-based SDK upgrade process.
#
# Usage:
#   ./sdk-upgrader/tools/runner.sh <OLD_SDK_TAG> <NEW_SDK_TAG>
#
#   OLD_SDK_TAG  – The current Polkadot-SDK tag you are upgrading from, e.g. "polkadot-stable2407"
#   NEW_SDK_TAG  – The Polkadot-SDK tag you will upgrade to, e.g. "polkadot-stable2410"
#
# Prerequisites:
#   • scout.sh already executed with output in the OUTPUT directory
#   • claude CLI (https://github.com/anthropics/claude-cli)
#   • jq (for formatting Claude's output)
#
# The script expects:
#   • Scout data at: resources/polkadot-sdk-<NEW_SDK_TAG>/
#
# Output:
#   • Claude creates status.json to: output/status.json
#   • Claude may create/update: output/UPGRADE_REPORT_<NEW_SDK_TAG>.md
#
set -euo pipefail

#####################################
# 0. Argument parsing & preparation #
#####################################
# Determine project root (top-level Git directory if inside one, otherwise cwd)
PROJECT_ROOT=$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || pwd)

# Ensure we execute from the project root so Claude Code operates at workspace root
cd "$PROJECT_ROOT"

if (( $# != 2 )); then
  echo "Usage: $0 <OLD_SDK_TAG> <NEW_SDK_TAG>" >&2
  exit 1
fi

OLD_TAG="$1"            # e.g. polkadot-stable2407
NEW_TAG="$2"            # e.g. polkadot-stable2410
# Derive the branch name used inside Cargo.toml (stableXXXX) by stripping the prefix
SDK_BRANCH="${NEW_TAG#polkadot-}"

OUTPUT_DIR="${PROJECT_ROOT}/sdk-upgrader/output"
PROMPT_DIR="${PROJECT_ROOT}/sdk-upgrader/prompts"
RESOURCES_DIR="${PROJECT_ROOT}/sdk-upgrader/resources"

# Set expected file paths
SCOUT_DIR="${RESOURCES_DIR}/polkadot-sdk-${NEW_TAG}"

# Make sure required tools exist
command -v claude >/dev/null 2>&1 || { 
  echo "error: claude CLI not found in PATH" >&2; exit 1; 
}
command -v jq >/dev/null 2>&1 || { 
  echo "error: jq is required but not found" >&2; exit 1; 
}
command -v envsubst >/dev/null 2>&1 || {
  echo "error: envsubst not found (install gettext-base)" >&2; exit 1
}

############################
# 1. Verify scout data     #
############################
if [[ ! -d "$SCOUT_DIR" ]]; then
  echo "error: scout directory '$SCOUT_DIR' not found" >&2
  echo "Please run scout.sh first to gather PR artifacts" >&2
  exit 1
fi

################################
# 2. Construct Claude prompt    #
################################
# Build file paths that will be used in the prompt
UPGRADE_REPORT_PATH="${OUTPUT_DIR}/UPGRADE_REPORT_${NEW_TAG}.md"
STATUS_FILE="${OUTPUT_DIR}/status.json"
TEST_REPORT_PATH="${OUTPUT_DIR}/test_report_${NEW_TAG}.md"

# Ensure the upgrade report file exists so it can be referenced
touch "$UPGRADE_REPORT_PATH"

####################################
# Define inline formatting function #
####################################
format_claude_output() {
  while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Try to parse as JSON; on failure, just echo raw
    if ! echo "$line" | jq . >/dev/null 2>&1; then
      echo "$line"
      continue
    fi

    # Extract envelope fields
    type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
    subtype=$(echo "$line" | jq -r '.subtype // empty' 2>/dev/null)

    case "$type" in
      system)
        case "$subtype" in
          init)
            echo "🚀 Initialising Claude session…"
            ;;
          *)
            echo "🔧 System: $subtype"
            ;;
        esac
        ;;

      assistant)
        content=$(echo "$line" | \
          jq -r '.message.content[0].text // .content[0].text // empty' 2>/dev/null)
        if [[ -n "$content" ]]; then
          # Claude streams one token per JSON line, so do not add newline unless token ends 
          # with it
          printf "%s" "$content"
        fi

        tool_uses=$(echo "$line" | \
          jq -r '.message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null)
        if [[ -n "$tool_uses" ]]; then
          echo -e "\n🔧 Using tool: $tool_uses"
        fi
        ;;

      user)
        tool_result=$(echo "$line" | \
          jq -r '.message.content[]? | select(.type == "tool_result") | .content' 2>/dev/null)
        if [[ -n "$tool_result" ]]; then
          if (( ${#tool_result} > 200 )); then
            echo -e "\n📋 Tool output: ${tool_result:0:200}…"
          else
            echo -e "\n📋 Tool output: $tool_result"
          fi
        fi
        ;;

      thinking)
        echo -e "\n🤔 Claude is thinking…"
        ;;

      error)
        error_msg=$(echo "$line" | jq -r '.error // .message // "unknown error"' 2>/dev/null)
        echo -e "\n❌ Error: $error_msg"
        ;;

      *)
        preview=$(echo "$line" | jq -r '. | tostring' | head -c 80)
        echo -e "\n🔍 [$type] $preview…"
        ;;
    esac
  done
}

##########################################
# Export variables and load prompt file #
##########################################
PROMPT_TEMPLATE_FILE="${PROMPT_DIR}/main_prompt.md"

if [[ ! -f "$PROMPT_TEMPLATE_FILE" ]]; then
  echo "error: prompt template file '$PROMPT_TEMPLATE_FILE' not found" >&2
  exit 1
fi

# Export variables for template substitution
export NEW_TAG="$NEW_TAG"
export OLD_TAG="$OLD_TAG"
export SCOUT_DIR="$SCOUT_DIR"
export STATUS_FILE="$STATUS_FILE"
export UPGRADE_REPORT_PATH="$UPGRADE_REPORT_PATH"
export TEST_REPORT_PATH="$TEST_REPORT_PATH"
export SDK_BRANCH
export PROJECT_ROOT
export PROMPT_DIR
export RESOURCES_DIR
export OUTPUT_DIR

# Set timeout environment variables for cargo operations (15 minutes)
export BASH_DEFAULT_TIMEOUT_MS="900000"  # 15 minutes in milliseconds
export BASH_MAX_TIMEOUT_MS="1800000"     # 30 minutes max
export MCP_TOOL_TIMEOUT="900000"         # 15 minutes for MCP tools

# Process template file with environment variable substitution
PROMPT=$(envsubst < "$PROMPT_TEMPLATE_FILE")

###################################
# 3. Invoke Claude with streaming  #
###################################

# Provide project root so Claude Code can read files (already resolved above)

echo "🤖  Calling Claude Code to execute upgrade..."

claude -p "$PROMPT" \
       --model claude-opus-4-20250514 \
       --output-format stream-json \
       --verbose \
       --allowedTools "Task" "Read" "Write" "Edit" "MultiEdit" "Bash" "Grep" "Glob" "LS" "TodoWrite" "mcp__cursor_rust_tools__cargo_check" "mcp__cursor_rust_tools__cargo_test" "mcp__cursor_rust_tools__symbol_references" "mcp__cursor_rust_tools__symbol_docs" "mcp__cursor_rust_tools__symbol_impl" \
   | format_claude_output

echo ""
