# syntax=docker/dockerfile:1

########################  Builder + Dev Stage  ########################
FROM rust:1.83-slim-bookworm AS dev

LABEL maintainer="Storage Hub Devs <devs@storagehub.local>"
LABEL description="SDK Upgrader development image with Rust, Node, Python, GitHub CLI, and Claude"

ENV DEBIAN_FRONTEND=noninteractive \
    RUST_BACKTRACE=1 \
    CARGO_TERM_COLOR=always \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    TERM=xterm-256color

# ---------------------------------------------------------------------
# System dependencies needed by the Rust workspace, TS utils, and SDK upgrader
# ---------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential clang lld cmake pkg-config libssl-dev wget jq git zsh ripgrep  \
        librocksdb-dev libpq-dev protobuf-compiler git curl ca-certificates gettext-base \
        python3 python3-pip grep sed coreutils netcat-openbsd locales && \
# Install Node 20 LTS (required for TS integration tests)
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g pnpm && \
# Generate UTF-8 locale for proper emoji and unicode support
    locale-gen en_US.UTF-8 && \
# Clean apt caches
    apt-get autoremove -y && apt-get clean && \
    find /var/lib/apt/lists -type f -not -name lock -delete

# Install Rust tools
RUN rustup component add rust-analyzer rust-src
# Install additional Rust utilities
# ast-grep currently relies on unstable Rust features; install via nightly toolchain.
# cargo-semver-checks v0.39.0 remains compatible with Rust 1.81.
RUN rustup toolchain install nightly && \
    cargo +nightly install --locked ast-grep && \
    cargo install --locked --version 0.39.0 cargo-semver-checks

# Set envs for the workspace
ENV API_TIMEOUT_MS=180000
ENV DISABLE_NON_ESSENTIAL_MODEL_CALLS=1

# Accept build args for Anthropic config
ARG ANTHROPIC_BASE_URL
ARG ANTHROPIC_AUTH_TOKEN
ENV ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL}
ENV ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN}

# Create a non-root user for running Claude Code
RUN useradd -m -s /bin/bash -u 1000 upgrader

# Install Claude Code globally (as root)
RUN npm install -g @anthropic-ai/claude-code

# Install uv package manager for Python and Serena MCP server in one step
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    export PATH="/root/.local/bin:$PATH" && \
    which uv && \
    git clone https://github.com/oraios/serena /opt/serena && \
    cd /opt/serena && \
    uv venv && \
    uv pip install -e . && \
    chown -R upgrader:upgrader /opt/serena

# Setup paths
ENV PATH="/root/.local/bin:/root/.cargo/bin:$PATH"

# Ensure upgrader user can access necessary binaries
RUN cp /root/.local/bin/uv /usr/local/bin/uv && \
    chmod +x /usr/local/bin/uv && \
    chmod -R 755 /root/.local/bin 2>/dev/null || true && \
    chmod -R 755 /root/.cargo/bin 2>/dev/null || true

# Fix permissions for Cargo and Rustup directories
RUN chown -R upgrader:upgrader /usr/local/cargo /usr/local/rustup || true

# Copy the Serena MCP initialization script
COPY sdk-upgrader/docker/init-serena-mcp.sh /usr/local/bin/init-serena-mcp.sh
RUN chmod +x /usr/local/bin/init-serena-mcp.sh

# Set the initialization script as entrypoint
ENTRYPOINT ["/usr/local/bin/init-serena-mcp.sh"]

# Switch to non-root user for runtime
USER upgrader
WORKDIR /home/upgrader

# Setup Claude configuration for the upgrader user
RUN mkdir -p ~/.claude && \
    wget ${ANTHROPIC_BASE_URL}/client-setup/.claude.json -O ~/.claude.json && \
    wget ${ANTHROPIC_BASE_URL}/client-setup/.credentials.json -O ~/.claude/.credentials.json && \
    jq --arg token "${ANTHROPIC_AUTH_TOKEN}" '.claudeAiOauth.accessToken = $token' ~/.claude/.credentials.json > ~/.claude/.credentials.json.tmp && \
    mv ~/.claude/.credentials.json.tmp ~/.claude/.credentials.json

# ---------------------------------------------------------------------
# Workspace sources (mounted later during dev; this COPY only enables
# container builds in CI)
# ---------------------------------------------------------------------
WORKDIR /workspace

# Note: /workspace will be mounted as a volume, so we don't change ownership here
# to avoid permission issues with the host filesystem

# Default command opens a shell; override in docker-compose if needed
CMD ["bash"] 