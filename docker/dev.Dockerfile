# syntax=docker/dockerfile:1

########################  Builder + Dev Stage  ########################
FROM rust:1.76-slim-bookworm AS dev

LABEL maintainer="Storage Hub Devs <devs@storagehub.local>"
LABEL description="All-in-one development image for Storage Hub (Rust + Node)"

ENV DEBIAN_FRONTEND=noninteractive \
    RUST_BACKTRACE=1 \
    CARGO_TERM_COLOR=always

# ---------------------------------------------------------------------
# System dependencies needed by the Rust workspace and TS utils
# ---------------------------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential clang lld cmake pkg-config libssl-dev wget jq git zsh  \
        librocksdb-dev libpq-dev protobuf-compiler git curl ca-certificates gettext-base && \
# Install Node 20 LTS (required for TS integration tests)
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g pnpm && \
# Clean apt caches
    apt-get autoremove -y && apt-get clean && \
    find /var/lib/apt/lists -type f -not -name lock -delete

# Install Rust tools
# RUN cargo install \
#     cargo-nextest \
#     cargo-expand \
#     cargo-machete \
#     cargo-audit

# Set envs for the workspace
ENV API_TIMEOUT_MS=180000
ENV DISABLE_NON_ESSENTIAL_MODEL_CALLS=1

# Accept build args for Anthropic config
ARG ANTHROPIC_BASE_URL
ARG ANTHROPIC_AUTH_TOKEN
ENV ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL}
ENV ANTHROPIC_AUTH_TOKEN=${ANTHROPIC_AUTH_TOKEN}

# Install Claude Code
RUN npm install -g @anthropic-ai/claude-code
RUN mkdir -p ~/.claude && \
wget ${ANTHROPIC_BASE_URL}/client-setup/.claude.json -O ~/.claude.json && \
wget ${ANTHROPIC_BASE_URL}/client-setup/.credentials.json -O ~/.claude/.credentials.json
RUN cat ~/.claude/.credentials.json | jq '.claudeAiOauth.accessToken = "${ANTHROPIC_AUTH_TOKEN}"' | tee ~/.claude/.credentials.json

# ---------------------------------------------------------------------
# Workspace sources (mounted later during dev; this COPY only enables
# container builds in CI)
# ---------------------------------------------------------------------
WORKDIR /workspace

# Default command opens a shell; override in docker-compose if needed
CMD ["bash"] 