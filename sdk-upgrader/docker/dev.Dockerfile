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
# System dependencies - Install ONLY what requires root privileges
# ---------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential clang lld cmake pkg-config libssl-dev wget jq git zsh ripgrep  \
        librocksdb-dev libpq-dev protobuf-compiler git curl ca-certificates gettext-base \
        python3 python3-pip grep sed coreutils netcat-openbsd locales sudo && \
    # Install GitHub CLI
    mkdir -p -m 755 /etc/apt/keyrings && \
    wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
    apt-get update && \
    apt-get install -y gh && \
    # Install Node 20 LTS (required for TS integration tests)
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    # Generate UTF-8 locale for proper emoji and unicode support
    locale-gen en_US.UTF-8 && \
    # Clean apt caches
    apt-get autoremove -y && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user early
RUN useradd -m -s /bin/bash -u 1000 upgrader && \
    # Allow upgrader to use sudo for development (optional - remove for production)
    echo "upgrader ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ---------------------------------------------------------------------
# Global tools that need to be available system-wide
# ---------------------------------------------------------------------
# Install rust-docs-mcp to /usr/local/bin (as root)
RUN git clone https://github.com/snowmead/rust-docs-mcp /tmp/rust-docs-mcp && \
    cd /tmp/rust-docs-mcp && \
    cargo build --release && \
    cp target/release/rust-docs-mcp /usr/local/bin/rust-docs-mcp && \
    chmod +x /usr/local/bin/rust-docs-mcp && \
    rm -rf /tmp/rust-docs-mcp

# Copy the MCP initialization script
COPY --chown=upgrader:upgrader sdk-upgrader/docker/init-mcp.sh /usr/local/bin/init-mcp.sh
RUN chmod +x /usr/local/bin/init-mcp.sh

# ---------------------------------------------------------------------
# Switch to non-root user for all user-space installations
# ---------------------------------------------------------------------
USER upgrader
WORKDIR /home/upgrader

# Set user environment variables
ENV PATH="/home/upgrader/.npm-global/bin:/home/upgrader/.local/bin:/home/upgrader/.cargo/bin:${PATH}" \
    CARGO_HOME="/home/upgrader/.cargo" \
    RUSTUP_HOME="/home/upgrader/.rustup"

# Install Rust toolchain as user
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable && \
    . "$HOME/.cargo/env" && \
    rustup component add rust-analyzer rust-src && \
    # Install additional Rust utilities
    # ast-grep currently relies on unstable Rust features; install via nightly toolchain.
    # cargo-semver-checks v0.39.0 remains compatible with Rust 1.81.
    rustup toolchain install nightly && \
    cargo +nightly install --locked ast-grep && \
    cargo install --locked --version 0.39.0 cargo-semver-checks

# Install npm global packages as user
RUN npm config set prefix "/home/upgrader/.npm-global" && \
    mkdir -p /home/upgrader/.npm-global && \
    export PATH="/home/upgrader/.npm-global/bin:$PATH" && \
    npm install -g pnpm @anthropic-ai/claude-code

# Install Python tools as user
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    echo 'export PATH="/home/upgrader/.local/bin:$PATH"' >> ~/.bashrc

# Clone and setup Serena MCP server as user
RUN git clone https://github.com/oraios/serena /home/upgrader/serena && \
    cd /home/upgrader/serena && \
    /home/upgrader/.local/bin/uv venv && \
    /home/upgrader/.local/bin/uv pip install -e .

# Set envs for the workspace
ENV API_TIMEOUT_MS=180000 \
    DISABLE_NON_ESSENTIAL_MODEL_CALLS=1

# Accept build args for Anthropic config
ARG ANTHROPIC_BASE_URL
ARG ANTHROPIC_AUTH_TOKEN

# Setup Claude configuration - use BuildKit secrets for sensitive data
RUN --mount=type=secret,id=anthropic_token,uid=1000 \
    mkdir -p ~/.claude && \
    if [ -n "${ANTHROPIC_BASE_URL}" ]; then \
        wget ${ANTHROPIC_BASE_URL}/client-setup/.claude.json -O ~/.claude.json && \
        wget ${ANTHROPIC_BASE_URL}/client-setup/.credentials.json -O ~/.claude/.credentials.json && \
        if [ -f /run/secrets/anthropic_token ]; then \
            token=$(cat /run/secrets/anthropic_token) && \
            jq --arg token "$token" '.claudeAiOauth.accessToken = $token' ~/.claude/.credentials.json > ~/.claude/.credentials.json.tmp && \
            mv ~/.claude/.credentials.json.tmp ~/.claude/.credentials.json; \
        elif [ -n "${ANTHROPIC_AUTH_TOKEN}" ]; then \
            jq --arg token "${ANTHROPIC_AUTH_TOKEN}" '.claudeAiOauth.accessToken = $token' ~/.claude/.credentials.json > ~/.claude/.credentials.json.tmp && \
            mv ~/.claude/.credentials.json.tmp ~/.claude/.credentials.json; \
        fi \
    fi

# ---------------------------------------------------------------------
# Workspace setup
# ---------------------------------------------------------------------
WORKDIR /workspace

# Set the initialization script as entrypoint
ENTRYPOINT ["/usr/local/bin/init-mcp.sh"]

# Default command opens a shell; override in docker-compose if needed
CMD ["bash"]