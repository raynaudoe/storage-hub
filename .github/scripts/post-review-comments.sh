#!/bin/bash
set -euo pipefail

PR_NUMBER="${1:-$PR_NUMBER}"
VERIFIED_DIR="${2:-verified-findings}"

if [ -z "$PR_NUMBER" ]; then
  echo "Error: PR_NUMBER required"
  exit 1
fi

# Stats
TOTAL_COMMENTS=0
CRITICAL_COUNT=0
FILES_REVIEWED=0
HAS_FINDINGS=false

# Process each verified JSON
shopt -s nullglob  # Handle case where no files match
for file in "$VERIFIED_DIR"/*.json; do
  FILES_REVIEWED=$((FILES_REVIEWED + 1))
  
  # Count findings by severity (handle both regular findings and empty findings arrays)
  if jq -e '.findings | length > 0' "$file" >/dev/null 2>&1; then
    HAS_FINDINGS=true
    FINDINGS=$(jq -c '.findings[]' "$file")
    
    while IFS= read -r finding; do
      TOTAL_COMMENTS=$((TOTAL_COMMENTS + 1))
      
      SEVERITY=$(echo "$finding" | jq -r '.severity')
      if [ "$SEVERITY" = "SECURITY" ] || [ "$SEVERITY" = "BUG" ]; then
        CRITICAL_COUNT=$((CRITICAL_COUNT + 1))
      fi
      
      # Post as PR comment (simpler than line comments for now)
      BODY=$(echo "$finding" | jq -r '.body')
      echo "$BODY" | gh pr comment "$PR_NUMBER" --body-file -
    done <<< "$FINDINGS"
  fi
done

# Post summary
if [ "$HAS_FINDINGS" = "false" ]; then
  if [ "$FILES_REVIEWED" -gt 0 ]; then
    gh pr comment "$PR_NUMBER" --body "## ✅ Automated Review Complete

No issues found across $FILES_REVIEWED files analyzed."
  else
    echo "No files to review" >&2
    exit 0
  fi
else
  SUMMARY="## 📋 PR Review Summary

**Found:** $TOTAL_COMMENTS issues ($CRITICAL_COUNT critical)
**Files reviewed:** $FILES_REVIEWED

See individual comments above for details."
  
  echo "$SUMMARY" | gh pr comment "$PR_NUMBER" --body-file -
fi

echo "Posted $TOTAL_COMMENTS comments for PR #$PR_NUMBER" >&2