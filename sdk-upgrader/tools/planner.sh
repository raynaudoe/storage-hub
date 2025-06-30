#!/usr/bin/env zsh
#
# planner.sh — Simplified upgrade planner that feeds Claude Code the SDK crate
# dependency tree and asks it to draft a step-by-step TODO checklist for the
# upcoming Polkadot-SDK bump.
#
# Usage:
#   ./sdk-upgrader/tools/planner.sh <NEW_SDK_TAG>
#
#   NEW_SDK_TAG  – The Polkadot-SDK tag you will upgrade to, e.g. "polkadot-stable2410"
#
# Prerequisites:
#   • scout.sh and weaver.sh already executed with output in the OUTPUT directory
#   • claude CLI (https://github.com/anthropics/claude-cli)
#   • jq (for formatting Claude's output)
#
# The script expects:
#   • Dependency tree at: output/polkadot_sdk_dependency_tree_<NEW_SDK_TAG>.md
#   • Scout data at: output/sdk-upgrades/polkadot-sdk-<NEW_SDK_TAG>/
#
# Output:
#   • Claude writes TODO checklist to: output/TODO_<NEW_SDK_TAG>.md
#   • Claude may create/update: output/UPGRADE_REPORT_<NEW_SDK_TAG>.md
#
set -euo pipefail

#####################################
# 0. Argument parsing & preparation #
#####################################
# Determine project root (top-level Git directory if inside one, otherwise cwd)
PROJECT_ROOT=$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || pwd)

if (( $# != 1 )); then
  echo "Usage: $0 <NEW_SDK_TAG>" >&2
  exit 1
fi

NEW_TAG="$1"            # e.g. polkadot-stable2410
OUTPUT_DIR="${PROJECT_ROOT}/sdk-upgrader/output"

# Set expected file paths
TREE_FILE="${OUTPUT_DIR}/polkadot_sdk_dependency_tree_${NEW_TAG}.md"
SCOUT_DIR="${OUTPUT_DIR}/sdk-upgrades/polkadot-sdk-${NEW_TAG}"

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
# 1. Verify required files #
############################
if [[ ! -f "$TREE_FILE" ]]; then
  echo "error: dependency tree file '$TREE_FILE' not found" >&2
  echo "Please run weaver.sh first to generate the dependency tree" >&2
  exit 1
fi

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
TODO_FILE="${OUTPUT_DIR}/TODO_${NEW_TAG}.md"

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
PROMPT_TEMPLATE_FILE="${PROJECT_ROOT}/sdk-upgrader/tools/upgrade_prompt.md"

if [[ ! -f "$PROMPT_TEMPLATE_FILE" ]]; then
  echo "error: prompt template file '$PROMPT_TEMPLATE_FILE' not found" >&2
  exit 1
fi

# Export variables for template substitution
export NEW_TAG="$NEW_TAG"
export TREE_FILE="$TREE_FILE"
export SCOUT_DIR="$SCOUT_DIR"
export TODO_FILE="$TODO_FILE"
export UPGRADE_REPORT_PATH="$UPGRADE_REPORT_PATH"

# Process template file with environment variable substitution
PROMPT=$(envsubst < "$PROMPT_TEMPLATE_FILE")

###################################
# 3. Invoke Claude with streaming  #
###################################

# Provide project root so Claude Code can read files (already resolved above)

echo "🤖  Calling Claude Code to generate upgrade plan..."

claude -p "$PROMPT" \
       --model claude-opus-4-20250514 \
       --output-format stream-json \
       --verbose \
       --allowedTools "Task" "Read" "Write" "Edit" "Bash" "grep_search" "list_dir" \
   | format_claude_output

echo ""
