#!/bin/bash
# Initialize MCP configuration for Claude Code with Serena and Rust Docs

init_serena_mcp() {
  # Create Serena MCP wrapper script in user-writable location
  WRAPPER_PATH="$HOME/.local/bin/serena-mcp-wrapper.sh"
  mkdir -p "$HOME/.local/bin"
  
  if [ ! -f "$WRAPPER_PATH" ]; then
    echo "Creating Serena MCP wrapper script..."
    cat > "$WRAPPER_PATH" << 'EOF'
#!/bin/bash
cd /home/upgrader/serena
exec /home/upgrader/.local/bin/uv run serena-mcp-server "$@"
EOF
    chmod +x "$WRAPPER_PATH"
    echo "✓ Serena wrapper script created at $WRAPPER_PATH"
  fi

  # Register Serena MCP server with Claude CLI
  if ! claude mcp list 2>/dev/null | grep -q "serena:"; then
    echo "Registering Serena MCP server..."
    claude mcp add --scope user --transport stdio serena "$WRAPPER_PATH"
    echo "✓ Serena MCP server registered with Claude Code"
    echo "  Serena will be available for semantic code understanding"
  else
    echo "✓ Serena MCP server already registered"
  fi
}

init_rust_docs_mcp() {
  WRAPPER_PATH="$HOME/.local/bin/rust-docs-mcp-wrapper.sh"
  mkdir -p "$HOME/.local/bin"

  if [ ! -f "$WRAPPER_PATH" ]; then
    echo "Creating Rust Docs MCP wrapper script..."
    cat > "$WRAPPER_PATH" << 'EOF'
#!/bin/bash
exec rust-docs-mcp "$@"
EOF
    chmod +x "$WRAPPER_PATH"
    echo "✓ Rust Docs wrapper script created at $WRAPPER_PATH"
  fi

  # Register Rust Docs MCP server with Claude CLI
  if ! claude mcp list 2>/dev/null | grep -q "rust-docs:"; then
    echo "Registering Rust Docs MCP server..."
    claude mcp add --scope user --transport stdio rust-docs "$WRAPPER_PATH"
    echo "✓ Rust Docs MCP server registered with Claude Code"
  else
    echo "✓ Rust Docs MCP server already registered"
  fi

  # Start Rust Docs MCP server in the background if not already running
  if ! pgrep -f "rust-docs-mcp" >/dev/null; then
    echo "Starting Rust Docs MCP server in background..."
    "$WRAPPER_PATH" >/dev/null 2>&1 &
  else
    echo "✓ Rust Docs MCP server already running"
  fi
}

# Always run initialization
init_serena_mcp
init_rust_docs_mcp

# If no arguments provided, start bash
if [ $# -eq 0 ]; then
  exec /bin/bash
else
  # Execute the provided command
  exec "$@"
fi 