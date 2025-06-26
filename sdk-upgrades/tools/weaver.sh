#!/bin/bash
# weaver.sh  -- sequentially apply harvested Polkadot-SDK PRs to a local repo.
#
# Usage: weaver.sh <release-directory>
#   release-directory : folder produced by scout.sh (e.g. sdk-upgrades/polkadot-sdk-polkadot-stable2409)
#
# Requirements:
#   • git workspace is clean and on the desired upgrade branch.
#   • `claude` CLI is available on PATH and authenticated.
#   • `jq` for JSON parsing
#
set -e

RELEASE_DIR=$1
if [ -z "$RELEASE_DIR" ] || [ ! -d "$RELEASE_DIR" ]; then
  echo "Usage: $0 <release-directory>" >&2
  exit 1
fi

PR_DIRS=("$RELEASE_DIR"/pr-*)
TOTAL=${#PR_DIRS[@]}

echo "🔧 Weaver: processing $TOTAL PR folders in $RELEASE_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Simple function to format Claude's streaming output
format_claude_output() {
  while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue
    
    # Try to parse as JSON, if it fails just print the line
    if ! echo "$line" | jq . >/dev/null 2>&1; then
      echo "$line"
      continue
    fi
    
    # Extract type and subtype
    type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
    subtype=$(echo "$line" | jq -r '.subtype // empty' 2>/dev/null)
    
    case "$type" in
      "system")
        case "$subtype" in
          "init")
            echo "🚀 Initializing Claude session..."
            ;;
          *)
            echo "🔧 System: $subtype"
            ;;
        esac
        ;;
      "assistant")
        # Check if this is a message with content
        content=$(echo "$line" | jq -r '.message.content[0].text // .content[0].text // empty' 2>/dev/null)
        if [ -n "$content" ]; then
          echo -n "$content"
        fi
        
        # Check for tool uses
        tool_uses=$(echo "$line" | jq -r '.message.content[]? | select(.type == "tool_use") | .name' 2>/dev/null)
        if [ -n "$tool_uses" ]; then
          echo -e "\n🔧 Using tool: $tool_uses"
        fi
        ;;
      "user")
        # Check for tool results
        tool_result=$(echo "$line" | jq -r '.message.content[]? | select(.type == "tool_result") | .content' 2>/dev/null)
        if [ -n "$tool_result" ]; then
          if [ ${#tool_result} -gt 200 ]; then
            echo -e "\n📋 Tool output: ${tool_result:0:200}..."
          else
            echo -e "\n📋 Tool output: $tool_result"
          fi
        fi
        ;;
      "thinking")
        echo -e "\n🤔 Claude is thinking..."
        ;;
      "error")
        error_msg=$(echo "$line" | jq -r '.error // .message // "unknown error"' 2>/dev/null)
        echo -e "\n❌ Error: $error_msg"
        ;;
      *)
        # For debugging - show the type and a preview
        preview=$(echo "$line" | jq -r '. | tostring' 2>/dev/null | head -c 80)
        echo -e "\n🔍 [$type] $preview..."
        ;;
    esac
  done
}

current=0
for PR_PATH in "${PR_DIRS[@]}"; do
  current=$((current + 1))
  PR_NUM=$(basename "$PR_PATH" | cut -d- -f2)
  DESC_FILE="$PR_PATH/description.md"
  DIFF_FILE="$PR_PATH/patch.diff"

  echo -e "\n▶️  PR #$PR_NUM ($current/$TOTAL)"
  echo "────────────────────────────────────────────────────────────────────────────────"

  if [ ! -f "$DIFF_FILE" ]; then
    echo "  ⚠️  diff file missing, skipping."
    continue
  fi

  # Create the complete prompt
  PROMPT=$(cat <<EOF
You are Weaver, a Rust-aware upgrade agent for Polkadot SDK upgrades.

You have an interactive bash shell with git, cargo, and ripgrep available.
Your mission: Apply the supplied diff, compile impacted crates, and commit the change.

# Polkadot SDK Upgrade Task

## PR #$PR_NUM

### Description
$(cat "$DESC_FILE" 2>/dev/null || echo "No description available")

### Patch to Apply
The patch file is located at: $DIFF_FILE

Please follow this workflow:
1. Apply this patch using \`git apply $DIFF_FILE\` (try \`--3way\` if there are conflicts)
2. Identify which crates are affected by the changes by finding Cargo.toml files near modified files
3. Run \`cargo check\` on the affected crates (or workspace if none identified)
4. If successful, commit with: \`git add -A && git commit -m "Apply upstream Polkadot-SDK PR #$PR_NUM"\`
5. If you encounter unresolvable issues, create \`$PR_PATH/problem.txt\` explaining the problem and exit

Important notes:
- Use \`git apply --3way\` for better conflict resolution
- Focus on compilation success over perfect style
- Document any unresolvable issues in problem.txt
- Cargo operations may take several minutes - be patient with long-running builds
- Provide regular updates on your progress

Start by examining the patch file and then proceed with the application.
EOF
)

  echo "🤖 Starting Claude processing..."
  echo ""

  # Find the actual project root by looking for Cargo.toml
  # Start from the parent of RELEASE_DIR and walk up until we find Cargo.toml
  SEARCH_DIR=$(dirname "$RELEASE_DIR")
  PROJECT_ROOT=""
  
  # Convert to absolute path for reliable searching
  SEARCH_DIR=$(cd "$SEARCH_DIR" && pwd)
  
  while [ "$SEARCH_DIR" != "/" ]; do
    if [ -f "$SEARCH_DIR/Cargo.toml" ]; then
      PROJECT_ROOT="$SEARCH_DIR"
      break
    fi
    SEARCH_DIR=$(dirname "$SEARCH_DIR")
  done
  
  # Fallback to parent of RELEASE_DIR if no Cargo.toml found
  if [ -z "$PROJECT_ROOT" ]; then
    PROJECT_ROOT=$(dirname "$RELEASE_DIR")
    echo "⚠️  No Cargo.toml found, using parent directory: $PROJECT_ROOT"
  else
    echo "📁 Found project root: $PROJECT_ROOT"
  fi

  # Use claude with streaming output and format it
  claude -p "$PROMPT" \
    --model claude-opus-4-20250514 \
    --dangerously-skip-permissions \
    --output-format stream-json \
    --verbose \
    --add-dir "$PROJECT_ROOT" | format_claude_output

  echo -e "\n✅ PR #$PR_NUM completed"
  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Weaver finished processing all PRs ($current/$TOTAL completed)" 