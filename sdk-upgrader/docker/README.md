# SDK Upgrader Docker Environment

This directory contains Docker configuration for running the SDK upgrader in a containerized environment.

## Prerequisites

- Docker and Docker Compose installed
- GitHub account with access to the repository
- Anthropic API credentials

## Setup

1. Copy the example environment file and add your credentials:
   ```bash
   cp env.example .env
   # Edit .env with your actual credentials
   ```

2. Build and run the container:
   ```bash
   docker-compose -f dev-compose.yml up -d
   ```

3. Enter the container:
   ```bash
   docker-compose -f dev-compose.yml exec dev /bin/bash
   ```

4. Configure GitHub CLI inside the container:
   ```bash
   gh auth login
   ```

5. Navigate to the SDK upgrader and run:
   ```bash
   cd sdk-upgrader
   ./run.sh polkadot-stable2407 polkadot-stable2410
   ```

## What's Included

The Docker image includes all necessary dependencies:
- Rust toolchain (1.81)
- Cargo and related tools (cargo-nextest, cargo-audit, etc.)
- Python 3 for error parsing scripts
- GitHub CLI for fetching PR data
- Claude CLI for AI-powered upgrades
- Node.js 20 LTS
- All system dependencies (git, jq, curl, etc.)
- **Serena MCP server** for semantic code understanding

## Serena Integration

The Docker image includes Serena, a semantic code understanding tool that enhances the SDK upgrader's capabilities:

- **Automatic MCP Setup**: Serena is pre-configured as an MCP server for Claude Code
- **Symbol Resolution**: Helps AI agents understand undefined traits, methods, and types
- **Code Navigation**: Provides semantic understanding of Rust code structure
- **Error Context**: Enhances error resolution with better code understanding

To use Serena within the container:
```bash
# Serena is automatically available to Claude Code via MCP
# The AI agents can leverage it for better code understanding
claude code "Find the definition of trait XYZ"
```

**Note**: The container automatically creates a `.mcp.json` configuration file in your workspace root on first run. This file configures Claude Code to use Serena as an MCP server. You can check this file into version control to share the configuration with your team.

## Volume Mounts

- The entire project repository is mounted at `/workspace`
- Cargo cache is persisted in a named volume
- Target directory is persisted to speed up builds