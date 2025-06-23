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

### Type Generation Workflow (Critical for TypeScript Development)

When modifying runtime types, pallets, or RPC interfaces, you MUST regenerate TypeScript types:

```bash
# 1. Ensure your node is running with the latest changes
../target/release/storage-hub --dev

# 2. In another terminal, scrape metadata and generate types
cd api-augment
pnpm metadata:scrape  # Scrapes metadata from running node
pnpm build           # Generates TypeScript type definitions

# 3. Also update types in the test directory
cd ../test
pnpm typegen        # Updates test-specific type definitions
```

Type definition locations:
- `/types-bundle/src/` - Custom runtime and RPC type definitions
- `/api-augment/src/interfaces/` - Generated pallet interfaces
- `/test/types/` - Test-specific generated types

### Database and Indexer Setup

The indexer service requires PostgreSQL for tracking blockchain state:

```bash
# 1. Install PostgreSQL (if not already installed)
# macOS: brew install postgresql
# Ubuntu: sudo apt-get install postgresql

# 2. Create database
createdb storage_hub

# 3. Configure connection (in config.toml or environment)
# Format: postgres://username:password@localhost/storage_hub

# 4. Run migrations
cd client/indexer-db
diesel migration run

# 5. Verify migrations
psql storage_hub -c "\dt"  # Should show tables like bsps, buckets, files, etc.
```

Common indexer queries for debugging:
```sql
-- Check registered BSPs
SELECT * FROM bsps;

-- View active payment streams
SELECT * FROM payment_streams WHERE status = 'active';

-- Track file operations
SELECT * FROM files ORDER BY created_at DESC LIMIT 10;
```

### Configuration Management

Node configuration uses a layered approach (environment variables override config.toml):

```bash
# 1. Create config from template
cp config.example.toml config.toml

# 2. Edit config.toml for your provider type
[provider]
type = "bsp"  # Options: "bsp", "msp", "user"

[storage]
backend = "rocksdb"  # Options: "memory" (testing), "rocksdb" (production)
capacity = 1000000000  # Storage capacity in bytes

[database]
url = "postgres://localhost/storage_hub"

# 3. Or use environment variables
PROVIDER_TYPE=bsp STORAGE_BACKEND=rocksdb ./target/release/storage-hub --dev
```

### Common Development Workflows

#### Adding a New Pallet Feature
1. Modify pallet logic in `/pallets/<pallet-name>/src/lib.rs`
2. Add tests in `/pallets/<pallet-name>/src/tests.rs`
3. Update runtime integration in `/runtime/src/lib.rs`
4. Run `cargo build --release` to verify compilation
5. Regenerate types (see Type Generation Workflow)
6. Write integration tests in `/test/suites/`
7. Run tests: `pnpm test:node` → `pnpm test:bspnet` → `pnpm test:full`

#### Adding or Modifying RPC Methods
1. Define RPC interface in `/pallets/<pallet-name>/rpc/src/lib.rs`
2. Implement runtime API in `/pallets/<pallet-name>/runtime-api/src/lib.rs`
3. Wire up in `/node/src/rpc.rs`
4. Update type definitions in `/types-bundle/src/rpc.ts`
5. Regenerate types and test

#### Debugging Storage Provider Issues
1. Enable detailed logging:
   ```bash
   RUST_LOG=debug,storage_hub_node=trace ./target/release/storage-hub --dev
   ```
2. Monitor actor communications (search logs for):
   - `BlockchainService`: Blockchain interactions
   - `FileTransferService`: P2P file transfers
   - `ForestStorageService`: Storage backend operations
3. Check indexer database for state
4. Use RPC methods to query on-chain state

### Debugging Strategies

#### Component-Specific Debugging

**Pallet Errors:**
```bash
# Decode error from failed extrinsic
# Error format: Module { index: X, error: Y }
# Check runtime/src/lib.rs for pallet index
# Check pallet's Error enum for error index
```

**Storage Issues:**
```bash
# Inspect forest storage
forest-cli inspect --path <storage-path>

# Check file metadata in indexer
psql storage_hub -c "SELECT * FROM files WHERE file_key = '<key>'"
```

**Payment Stream Issues:**
```bash
# Query payment stream state
curl -X POST http://localhost:9944 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"fileSystem_getPaymentStreams","params":[],"id":1}'
```

**Network/P2P Issues:**
```bash
# Check peer connections
curl http://localhost:9615/metrics | grep substrate_sub_libp2p_peers_count

# Monitor file transfer events
RUST_LOG=file_transfer=trace ./target/release/storage-hub --dev
```

### Script Utilities Reference

Located in `/test/scripts/`:

- `buildLocalDocker.ts` - Build Docker images with local changes
- `crossBuildMac.ts` - Cross-compile for macOS from Linux
- `generateFileSystemBenchmarkProofs.ts` - Generate proofs for benchmarking
- `modifyPlainSpec.ts` - Modify chain specifications programmatically
- `downloadPolkadot.ts` - Download compatible Polkadot relay binary
- `bspNetBootstrap.ts` - Bootstrap BSP test network
- `fullNetBootstrap.ts` - Bootstrap full test network with relay chain

### Network Fault Testing

Test network resilience using Toxiproxy:

```bash
# Start tests with network fault injection
pnpm test:bspnet -- --toxiproxy

# Toxiproxy configuration in docker/toxiproxy.json
# Simulates: latency, bandwidth limits, connection drops, packet loss
```

### Development Tips

- When modifying runtime APIs, update type definitions in `/types-bundle/src/`
- Test file operations using BSPNet mode for faster iteration
- Use `pnpm test:node -- <specific-test>` to run individual tests
- The indexer service (`/client/indexer`) tracks blockchain state for storage providers
- Payment streams use a dynamic rate model based on provider reputation
- Always run `pnpm biome:fix` before committing TypeScript/JavaScript changes
- Use bounded types (BoundedVec, BoundedBTreeMap) in pallets to prevent DoS

### Environment Requirements

- **Node.js**: Version 23.x.x required for testing
- **pnpm**: Version 9 for package management
- **Docker**: Required for integration testing (BSPNet, FullNet modes)
- **Rust**: See rust-toolchain.toml for exact version

### PR Review Guidelines (CRITICAL FOR CODE REVIEWS)

The project uses automated Claude PR reviews. When reviewing PRs, follow this structured approach:

#### Review Categories and What to Look For

**🐞 BUG - Critical Issues That Must Be Fixed:**
- Memory leaks (unbounded collections, missing drops)
- Race conditions in actor communication
- Incorrect error handling or panics
- Off-by-one errors in pallet logic
- Missing validation or bounds checking
- Incorrect type conversions
- Database transaction issues
- File descriptor leaks

**🔒 SECURITY - Security Vulnerabilities:**
- Missing authentication/authorization checks
- Exposed private keys or secrets
- SQL injection possibilities
- Path traversal vulnerabilities
- Unchecked user inputs in pallets
- Missing `ensure_signed` or origin checks
- Overflow/underflow possibilities
- DoS vectors (unbounded loops, storage)

**🚀 PERF - Performance Concerns:**
- O(n²) or worse algorithms
- Unnecessary database queries
- Missing indexes on frequently queried fields
- Synchronous operations that should be async
- Excessive memory allocations
- Inefficient pallet weight calculations
- Missing batch operations
- Redundant file I/O

**💡 SUGGESTION - Code Quality Improvements:**
- Better error messages
- Code deduplication opportunities
- More idiomatic Rust patterns
- Missing tests for edge cases
- Documentation improvements
- Better type safety
- Cleaner abstractions

**📝 EXPLAIN - Code That Needs Explanation:**
- Complex algorithms without comments
- Non-obvious design decisions
- Magic numbers or constants
- Workarounds that need context
- Integration points between components

### Additional Resources

- **Pallet Documentation**: See `/pallets/file-system/README.md` and `/pallets/proofs-dealer/README.md` for detailed pallet designs
- **Testing Guide**: Comprehensive testing documentation in `/test/README.md`
- **Rust Linting**: The project uses relaxed Clippy rules (see workspace Cargo.toml) to allow pragmatic code patterns

#### StorageHub-Specific Review Checklist

**MANDATORY: Check these in EVERY PR review:**

1. **🐞 Sleep/Blocking Operations**
   - Search for: `sleep`, `std::thread::sleep`, `tokio::time::sleep`, `setTimeout`, shell `sleep`
   - Why it matters: Causes flaky tests, wastes CPU, blocks actors
   - Action: Suggest event-driven alternatives or async patterns
   - Example fix:
     ```rust
     // ❌ BAD: Blocking sleep
     std::thread::sleep(Duration::from_secs(5));
     
     // ✅ GOOD: Event-driven waiting
     while !condition_met {
         if let Ok(event) = receiver.recv_timeout(Duration::from_secs(1)) {
             // Process event
         }
     }
     ```

2. **🔒 Pallet Security Checks**
   - All extrinsics have `ensure_signed!` or appropriate origin checks
   - User inputs are validated with proper error types
   - Storage items use bounded types (BoundedVec, BoundedBTreeMap)
   - Weight calculations prevent DoS attacks

3. **🐞 Actor Communication**
   - No unbounded channels (use bounded channels)
   - Proper error handling for send/recv operations
   - Graceful shutdown handling
   - No actor deadlocks possible

4. **🚀 Database Performance**
   - New queries have appropriate indexes
   - Batch operations used where possible
   - No N+1 query patterns
   - Transactions used correctly

5. **🐞 Type Generation**
   - If runtime types changed: "Did you run type generation?"
   - If new RPC methods: "Are types defined in types-bundle?"
   - If pallet changes: "Did you update api-augment?"

6. **💡 Testing Coverage**
   - Unit tests for new pallet functionality
   - Integration tests for BSP/MSP features
   - Error cases tested
   - Edge cases covered

#### Review Comment Format

Always use this format for review comments:

```markdown
**🐞 BUG: [Brief description]**

[Detailed explanation of the issue]

**Suggestion:**
```rust
// Proposed fix code here
```

**Why this matters:** [Impact explanation]
```

#### Example Review Comments

```markdown
**🐞 BUG: Unbounded vector can cause storage DoS**

The `files` storage item uses Vec<T> which can grow unbounded and cause the chain to halt.

**Suggestion:**
```rust
#[pallet::storage]
pub type Files<T> = StorageMap<_, Blake2_128Concat, T::AccountId, BoundedVec<FileMetadata, ConstU32<1000>>>;
```

**Why this matters:** Unbounded storage can be exploited to fill blocks and halt the chain.
```

```markdown
**🔒 SECURITY: Missing origin check in privileged extrinsic**

The `force_delete_file` extrinsic doesn't verify the caller has permission.

**Suggestion:**
```rust
#[pallet::weight(T::WeightInfo::force_delete_file())]
pub fn force_delete_file(origin: OriginFor<T>, file_key: FileKey) -> DispatchResult {
    ensure_root(origin)?;  // Add this line
    // ... rest of implementation
}
```

**Why this matters:** Anyone could delete files without authorization.
```