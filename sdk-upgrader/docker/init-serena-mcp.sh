#!/bin/bash
# Initialize MCP configuration for Claude Code with Serena

init_serena_mcp() {
  # Create Serena MCP wrapper script in user-writable location
  WRAPPER_PATH="$HOME/.local/bin/serena-mcp-wrapper.sh"
  mkdir -p "$HOME/.local/bin"
  
  if [ ! -f "$WRAPPER_PATH" ]; then
    echo "Creating Serena MCP wrapper script..."
    cat > "$WRAPPER_PATH" << 'EOF'
#!/bin/bash
cd /opt/serena
exec uv run serena-mcp-server "$@"
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

# Always run initialization
init_serena_mcp

# If no arguments provided, start bash
if [ $# -eq 0 ]; then
  exec /bin/bash
else
  # Execute the provided command
  exec "$@"
fi