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

# ANSI color codes - work in Docker with proper TERM env
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Unicode box drawing characters
BOX_TOP='─'
BOX_VERTICAL='│'
BOX_CORNER='└'

# Helper function to format JSON nicely but compact
format_json_compact() {
  local json="$1"
  # Try to extract key info from common patterns
  if echo "$json" | grep -q "compiler-message"; then
    local level=$(echo "$json" | jq -r '.message.level // "unknown"' 2>/dev/null)
    local msg=$(echo "$json" | jq -r '.message.message // ""' 2>/dev/null | head -n1)
    echo "[${level}] $(echo "$msg" | head -c 80)${msg:80:1}…"
  else
    echo "$json" | head -c 100
  fi
}

format_claude_output() {
  # Ensure UTF-8 locale for emojis in Docker
  export LC_ALL=C.UTF-8 2>/dev/null || export LC_ALL=en_US.UTF-8 2>/dev/null || true
  
  while IFS= read -r line; do
    # Skip empty lines
    [[ -z "$line" ]] && continue

    # Try to parse as JSON; on failure, just echo raw
    if ! echo "$line" | jq . >/dev/null 2>&1; then
      echo "${DIM}$line${RESET}"
      continue
    fi

    # Extract envelope fields
    type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
    subtype=$(echo "$line" | jq -r '.subtype // empty' 2>/dev/null)

    case "$type" in
      system)
        case "$subtype" in
          init)
            echo -e "\n${GREEN}${BOLD}🚀 Initializing Claude session${RESET}"
            echo -e "${DIM}──────────${RESET}\n"
            ;;
          *)
            echo -e "${YELLOW}⚙️  System: ${subtype}${RESET}"
            ;;
        esac
        ;;

      assistant)
        # Extract text content - try multiple paths
        content=$(echo "$line" | \
          jq -r '.message.content[0].text // .content[0].text // empty' 2>/dev/null)
        if [[ -n "$content" ]]; then
          # Claude streams one token per JSON line, so do not add newline unless token ends with it
          printf "${CYAN}%s${RESET}" "$content"
        fi

        # Extract tool uses
        tool_uses=$(echo "$line" | \
          jq -r '.message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null)
        if [[ -n "$tool_uses" ]]; then
          echo -e "\n\n${BLUE}${BOLD}🔧 Tool Call: ${tool_uses}${RESET}"
          echo -e "${DIM}────────${RESET}"
        fi
        ;;

      user)
        tool_result=$(echo "$line" | \
          jq -r '.message.content[]? | select(.type == "tool_result") | .content' 2>/dev/null)
        if [[ -n "$tool_result" ]]; then
          echo -e "\n${GREEN}📤 Tool Output:${RESET}"
          # Format based on content type
          if echo "$tool_result" | jq . >/dev/null 2>&1; then
            # It's JSON - format it nicely but compact
            formatted=$(format_json_compact "$tool_result")
            echo -e "${DIM}│ ${formatted}${RESET}"
          else
            # Regular text - truncate if needed
            truncated=$(echo "$tool_result" | head -c 200)
            echo -e "${DIM}│ ${truncated}${RESET}"
          fi
          echo -e "${DIM}└────${RESET}\n"
        fi
        ;;

      thinking)
        echo -e "\n${PURPLE}🤔 Thinking...${RESET}"
        ;;

      error)
        error_msg=$(echo "$line" | jq -r '.error // .message // "unknown error"' 2>/dev/null)
        echo -e "\n${RED}${BOLD}❌ Error: ${error_msg}${RESET}\n"
        ;;

      message_start)
        # Silently skip - don't show model info
        ;;

      message_delta)
        delta_type=$(echo "$line" | jq -r '.delta.type // empty' 2>/dev/null)
        if [[ "$delta_type" == "message_stop" ]]; then
          # Add newline after streaming completes
          echo ""
        fi
        ;;

      ping)
        # Just a keepalive, don't print anything
        ;;

      *)
        # Other message types - show briefly
        if [[ -n "$type" ]]; then
          preview=$(format_json_compact "$line")
          echo -e "\n${DIM}ℹ️  [${type}] ${preview}${RESET}"
        fi
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

# Ensure terminal supports colors and UTF-8 in Docker
export TERM=${TERM:-xterm-256color}
export LANG=${LANG:-C.UTF-8}
export LC_ALL=${LC_ALL:-C.UTF-8}

####################################
# Check if Claude completed tasks   #
####################################
check_claude_completed() {
  local status_file="$1"
  
  # If status file doesn't exist, return false (needs to run)
  if [[ ! -f "$status_file" ]]; then
    return 1
  fi
  
  # Check for pending error groups
  local pending_error_groups=$(jq -r '.error_groups[]? | select(.status == "pending") | .id' "$status_file" 2>/dev/null | wc -l)
  
  # Check for pending test groups
  local pending_test_groups=$(jq -r '.test_phase.test_groups[]? | select(.status == "pending") | .id' "$status_file" 2>/dev/null | wc -l)
  
  # If any groups are pending, return false (not completed)
  if [[ $pending_error_groups -gt 0 || $pending_test_groups -gt 0 ]]; then
    echo "⏳ Found $pending_error_groups pending error groups and $pending_test_groups pending test groups"
    return 1
  fi
  
  # Check if the upgrade has started at all (status file should have error_groups or test_phase)
  local has_error_groups=$(jq -e '.error_groups' "$status_file" 2>/dev/null && echo "yes" || echo "no")
  local has_test_phase=$(jq -e '.test_phase' "$status_file" 2>/dev/null && echo "yes" || echo "no")
  
  if [[ "$has_error_groups" == "no" && "$has_test_phase" == "no" ]]; then
    # Status file exists but upgrade hasn't really started
    return 1
  fi
  
  # All groups completed
  return 0
}

####################################
# Run Claude with retry logic       #
####################################
run_claude_upgrade() {
  local attempt=1
  local max_attempts=10  # Prevent infinite loops
  
  while true; do
    echo ""
    echo "🤖  Calling Claude Code to execute upgrade (attempt $attempt)..."
    
    claude -p "$PROMPT" \
           --model claude-opus-4-20250514 \
           --output-format stream-json \
           --verbose \
           --dangerously-skip-permissions \
       | format_claude_output
    
    echo ""
    
    # Check if Claude completed all tasks
    if check_claude_completed "$STATUS_FILE"; then
      echo "✅ Claude completed all tasks successfully!"
      break
    fi
    
    # Check if we've exceeded max attempts
    if [[ $attempt -ge $max_attempts ]]; then
      echo "⚠️  Maximum attempts ($max_attempts) reached. Check status.json for pending tasks."
      break
    fi
    
    echo "🔄 Claude didn't complete all tasks. Retrying..."
    ((attempt++))
    
    # Brief pause before retry
    sleep 2
  done
}

###################################
# 3. Invoke Claude with streaming  #
###################################

# Provide project root so Claude Code can read files (already resolved above)

run_claude_upgrade

echo ""
