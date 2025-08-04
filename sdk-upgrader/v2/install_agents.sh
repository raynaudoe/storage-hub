#!/bin/bash

# Install agents script for SDK Upgrader v2
# Copies all agents from v2/agents/ to project's .claude/agents/

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_SOURCE_DIR="${SCRIPT_DIR}/agents"

# Find the project root (traverse up until we find .git or reach root)
find_project_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]]; then
            echo "$dir"
            return 0
        fi
        dir="$(dirname "$dir")"
    done
    echo "Error: Could not find project root (.git directory)" >&2
    return 1
}

# Main execution
main() {
    echo "🚀 Installing SDK Upgrader v2 agents..."
    
    # Find project root
    PROJECT_ROOT=$(find_project_root)
    if [[ $? -ne 0 ]]; then
        exit 1
    fi
    
    AGENTS_TARGET_DIR="${PROJECT_ROOT}/.claude/agents"
    
    echo "📍 Project root: ${PROJECT_ROOT}"
    echo "📂 Source directory: ${AGENTS_SOURCE_DIR}"
    echo "📂 Target directory: ${AGENTS_TARGET_DIR}"
    
    # Check if source directory exists
    if [[ ! -d "${AGENTS_SOURCE_DIR}" ]]; then
        echo "❌ Error: Agents source directory not found: ${AGENTS_SOURCE_DIR}"
        exit 1
    fi
    
    # Create target directory if it doesn't exist
    mkdir -p "${AGENTS_TARGET_DIR}"
    
    # Count agents to install
    agent_count=$(find "${AGENTS_SOURCE_DIR}" -name "*.md" -type f | wc -l)
    
    if [[ $agent_count -eq 0 ]]; then
        echo "⚠️  No agents found in ${AGENTS_SOURCE_DIR}"
        exit 0
    fi
    
    echo "📦 Found ${agent_count} agent(s) to install"
    
    # Copy all .md files from agents directory
    for agent_file in "${AGENTS_SOURCE_DIR}"/*.md; do
        if [[ -f "$agent_file" ]]; then
            agent_name=$(basename "$agent_file")
            target_file="${AGENTS_TARGET_DIR}/${agent_name}"
            
            # Check if file already exists
            if [[ -f "$target_file" ]]; then
                echo "  🔄 Updating existing agent: ${agent_name}"
            else
                echo "  ✓ Installing ${agent_name}"
            fi
            
            # Copy file (will overwrite if exists)
            cp -f "$agent_file" "${AGENTS_TARGET_DIR}/"
        fi
    done
    
    echo "✅ Installation complete! Agents are now available in ${AGENTS_TARGET_DIR}"
    echo ""
    echo "You can now use these agents with the /agents command or by invoking them directly."
}

# Run main function
main "$@"