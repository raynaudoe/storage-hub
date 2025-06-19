# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

StorageHub is a storage-optimized parachain built on Substrate/Cumulus for the Polkadot ecosystem. It provides decentralized storage services through Main Storage Providers (MSPs) and Backup Storage Providers (BSPs).

## Common Development Commands

### Build Commands
```bash
# Build the project
cargo build --release

# macOS cross-compilation
pnpm crossbuild:mac

# Build Docker image
pnpm docker:build
```

### Testing Commands
```bash
# Run solo node tests (runtime/RPC tests)
pnpm test:node

# Run BSP network tests (file operations)
pnpm test:bspnet

# Run full network tests (end-to-end)
pnpm test:full

# Run specific test file
pnpm test:node -- test/suites/solo-node/pallet-file-system.test.ts

# Run ZombieNet tests
pnpm zombie:test:native
```

### Linting and Formatting
```bash
# Lint and format TypeScript/JavaScript code
pnpm biome:format
pnpm biome:lint

# Fix linting issues
pnpm biome:fix

# Rust formatting and linting
cargo fmt
cargo clippy
```

### Type Generation
When updating RuntimeApi or RPC calls:
```bash
cd test
pnpm typegen
```

### Development Networks
```bash
# Start local dev node
../target/release/storage-hub --dev

# Start BSP test network (Docker)
pnpm docker:start:bspnet

# Start full test network (Docker)
pnpm docker:start:fullnet

# Run ZombieNet network
pnpm zombie:run:native
```

## High-Level Architecture

### Core Components

1. **Runtime** (`/runtime`): Cumulus-based parachain runtime containing all business logic
   - Custom pallets for file system, payment streams, proofs, and provider management
   - XCM support for cross-chain communication

2. **Node** (`/node`): Node implementation with integrated storage provider services
   - BSP and MSP services running as actors within the node
   - RPC extensions for storage operations

3. **Client Modules** (`/client`): Reusable modules for storage providers
   - File transfer protocols
   - Blockchain interaction utilities
   - Forest storage management
   - Proof generation and verification

4. **Pallets** (`/pallets`): Custom blockchain modules
   - `pallet-file-system`: Core file storage logic
   - `pallet-payment-streams`: Payment handling for storage services
   - `pallet-proofs-dealer`: Proof challenges and verification
   - `pallet-providers`: BSP/MSP registration and management

### Actor-Based Architecture

The storage providers use an actor model for concurrent operations:
- **BlockchainService**: Handles all blockchain interactions
- **FileTransferService**: Manages peer-to-peer file transfers
- **ForestStorageService**: Interfaces with the storage backend
- **TaskSpawner**: Coordinates background tasks

### Testing Infrastructure

- **Solo Node Tests** (`/test/suites/solo-node`): Test individual pallets and RPC methods
- **Integration Tests** (`/test/suites/integration`): Test BSP/MSP functionality
- **ZombieNet Tests** (`/test/suites/zombie`): Test network topology and cross-chain features

### Key Design Patterns

1. **Event-Driven Communication**: Services communicate through events and message passing
2. **Strong Typing**: TypeScript augmentation for runtime types (`/api-augment`)
3. **Docker-First Testing**: All integration tests run in isolated Docker containers
4. **Modular Storage Providers**: BSP and MSP share common client modules

### Code Style

- **TypeScript/JavaScript**: Biome configuration enforces consistent formatting
  - Double quotes, semicolons required
  - 100 character line width
  - No trailing commas
  
- **Rust**: Standard rustfmt with relaxed Clippy rules (see workspace Cargo.toml)

### Development Tips

- When modifying runtime APIs, update type definitions in `/types-bundle/src/`
- Test file operations using BSPNet mode for faster iteration
- Use `pnpm test:node -- <specific-test>` to run individual tests
- The indexer service (`/client/indexer`) tracks blockchain state for storage providers
- Payment streams use a dynamic rate model based on provider reputation

### Environment Requirements

- **Node.js**: Version 23.x.x required for testing
- **pnpm**: Version 9 for package management
- **Docker**: Required for integration testing (BSPNet, FullNet modes)
- **Rust**: See rust-toolchain.toml for exact version

### CI/CD and Code Review

The project uses automated Claude PR reviews that check for:
- 🐞 BUG: Potential bugs and issues
- 🔒 SECURITY: Security vulnerabilities
- 🚀 PERF: Performance improvements
- 💡 SUGGESTION: Code improvements
- 📝 EXPLAIN: Code explanations

### Additional Resources

- **Pallet Documentation**: See `/pallets/file-system/README.md` and `/pallets/proofs-dealer/README.md` for detailed pallet designs
- **Testing Guide**: Comprehensive testing documentation in `/test/README.md`
- **Rust Linting**: The project uses relaxed Clippy rules (see workspace Cargo.toml) to allow pragmatic code patterns