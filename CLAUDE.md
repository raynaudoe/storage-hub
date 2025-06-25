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

## StorageHub Code Review Patterns Reference

This section contains concrete examples of patterns to detect during PR reviews. Each example shows the problematic code and the suggested fix.

### 🐞 BUG Patterns

#### BLOCKING_SLEEP
**Problem**: Synchronous sleep operations block actors and cause test flakiness
```rust
// ❌ BAD
std::thread::sleep(Duration::from_secs(5));
tokio::time::sleep(Duration::from_secs(1)).await;

// ✅ GOOD  
// Use event-driven waiting
while !condition_met {
    if let Ok(event) = receiver.recv_timeout(Duration::from_secs(1)) {
        // Process event
    }
}

// In tests, use proper test utilities
wait_for_block_finalization(&node).await;
```

#### UNBOUNDED_STORAGE
**Problem**: Unbounded collections in pallets can halt the chain
```rust
// ❌ BAD
#[pallet::storage]
pub type Files<T> = StorageMap<_, Blake2_128Concat, T::AccountId, Vec<FileMetadata>>;

// ✅ GOOD
#[pallet::storage]
pub type Files<T> = StorageMap<_, Blake2_128Concat, T::AccountId, BoundedVec<FileMetadata, ConstU32<1000>>>;
```

#### MISSING_ERROR_HANDLING
**Problem**: Unwrap/expect can panic in production
```rust
// ❌ BAD
let account = accounts.get(0).unwrap();
let result = some_operation().expect("This should work");

// ✅ GOOD
let account = accounts.get(0).ok_or(Error::<T>::AccountNotFound)?;
let result = some_operation().map_err(|e| {
    log::error!("Operation failed: {:?}", e);
    Error::<T>::OperationFailed
})?;
```

#### UNBOUNDED_CHANNEL
**Problem**: Unbounded channels can cause memory exhaustion
```rust
// ❌ BAD
let (tx, rx) = mpsc::channel();
let (tx, rx) = tokio::sync::mpsc::unbounded_channel();

// ✅ GOOD
let (tx, rx) = mpsc::channel(100);  // Bounded
let (tx, rx) = tokio::sync::mpsc::channel(1000);  // Bounded
```

#### PANIC_POSSIBLE
**Problem**: Operations that can panic in production code
```rust
// ❌ BAD
let value = u32::from_str(&input).unwrap();
let slice = &data[start..end];  // Can panic if indices invalid

// ✅ GOOD
let value = u32::from_str(&input).map_err(|_| Error::<T>::InvalidInput)?;
let slice = data.get(start..end).ok_or(Error::<T>::InvalidRange)?;
```

### 🔒 SECURITY Patterns

#### MISSING_ORIGIN_CHECK
**Problem**: Extrinsics without proper authorization
```rust
// ❌ BAD
#[pallet::weight(T::WeightInfo::admin_function())]
pub fn admin_function(origin: OriginFor<T>) -> DispatchResult {
    // No origin check!
    Self::do_admin_thing()
}

// ✅ GOOD
#[pallet::weight(T::WeightInfo::admin_function())]
pub fn admin_function(origin: OriginFor<T>) -> DispatchResult {
    ensure_root(origin)?;  // Or ensure_signed, T::AdminOrigin::ensure_origin
    Self::do_admin_thing()
}
```

#### PATH_TRAVERSAL
**Problem**: User input in file paths without validation
```rust
// ❌ BAD
let path = format!("./storage/{}", user_input);
let file = File::open(&path)?;

// ✅ GOOD
let sanitized = user_input.replace("..", "").replace("/", "_");
ensure!(sanitized.chars().all(|c| c.is_alphanumeric() || c == '_'), Error::InvalidPath);
let path = storage_root.join(&sanitized);
```

#### EXPOSED_SECRET
**Problem**: Hardcoded secrets in code
```rust
// ❌ BAD
const API_KEY: &str = "sk_live_abcd1234";
const DATABASE_URL: &str = "postgres://user:password@host/db";

// ✅ GOOD
let api_key = env::var("API_KEY").expect("API_KEY must be set");
let database_url = config.database.url.clone();
```

#### SQL_INJECTION
**Problem**: String concatenation in SQL queries
```rust
// ❌ BAD
let query = format!("SELECT * FROM users WHERE id = {}", user_id);
db.execute(&query)?;

// ✅ GOOD
let query = "SELECT * FROM users WHERE id = $1";
db.execute(query, &[&user_id])?;
```

#### MISSING_VALIDATION
**Problem**: User input used without bounds checking
```rust
// ❌ BAD
pub fn set_price(origin: OriginFor<T>, price: Balance) -> DispatchResult {
    Prices::<T>::insert(&item, price);  // No validation
}

// ✅ GOOD
pub fn set_price(origin: OriginFor<T>, price: Balance) -> DispatchResult {
    ensure!(price >= T::MinPrice::get(), Error::<T>::PriceTooLow);
    ensure!(price <= T::MaxPrice::get(), Error::<T>::PriceTooHigh);
    Prices::<T>::insert(&item, price);
}
```

### 🚀 PERFORMANCE Patterns

#### N_PLUS_ONE_QUERY
**Problem**: Database queries in loops
```rust
// ❌ BAD
for user_id in user_ids {
    let files = db.get_files_for_user(user_id).await?;
    process_files(files);
}

// ✅ GOOD
let all_files = db.get_files_for_users(&user_ids).await?;
let files_by_user = all_files.into_iter().group_by(|f| f.user_id);
```

#### QUADRATIC_ALGORITHM
**Problem**: Nested loops with unbounded collections
```rust
// ❌ BAD
for item in &large_collection {
    for other in &large_collection {
        if item.id == other.parent_id {
            // O(n²) operation
        }
    }
}

// ✅ GOOD
let parent_map: HashMap<_, _> = large_collection
    .iter()
    .map(|item| (item.id, item))
    .collect();
// Now O(n) lookup
```

#### MISSING_INDEX
**Problem**: Queries without proper database indexes
```sql
-- ❌ BAD
-- Frequently queried without index
SELECT * FROM payment_streams WHERE provider_id = $1 AND status = 'active';

-- ✅ GOOD
CREATE INDEX idx_payment_streams_provider_status 
ON payment_streams(provider_id, status) 
WHERE status = 'active';
```

#### SYNC_IN_ASYNC
**Problem**: Blocking operations in async context
```rust
// ❌ BAD
async fn process_file(path: &Path) {
    let contents = std::fs::read_to_string(path).unwrap();  // Blocks thread
}

// ✅ GOOD
async fn process_file(path: &Path) {
    let contents = tokio::fs::read_to_string(path).await?;
}
```

#### INEFFICIENT_WEIGHT
**Problem**: Incorrect weight calculations in pallets
```rust
// ❌ BAD
#[pallet::weight(10_000)]  // Hardcoded weight
pub fn complex_operation(origin: OriginFor<T>, items: Vec<Item>) -> DispatchResult {
    // O(n) operation with fixed weight
}

// ✅ GOOD
#[pallet::weight(T::WeightInfo::complex_operation(items.len() as u32))]
pub fn complex_operation(origin: OriginFor<T>, items: Vec<Item>) -> DispatchResult {
    ensure!(items.len() <= T::MaxItems::get() as usize, Error::<T>::TooManyItems);
}
```

### 💡 SUGGESTION Patterns

#### NON_IDIOMATIC
**Problem**: Code that doesn't follow Rust idioms
```rust
// ❌ LESS IDIOMATIC
if condition == true { }
match option {
    Some(x) => x,
    None => return Err(error),
}

// ✅ IDIOMATIC
if condition { }
option.ok_or(error)?
```

#### MISSING_DOCS
**Problem**: Public APIs without documentation
```rust
// ❌ BAD
pub fn calculate_merkle_root(leaves: &[Hash]) -> Hash {
    // Complex implementation
}

// ✅ GOOD
/// Calculates the Merkle root from a list of leaf hashes.
/// 
/// # Arguments
/// * `leaves` - Slice of hash values representing the leaves
/// 
/// # Returns
/// The computed Merkle root hash
pub fn calculate_merkle_root(leaves: &[Hash]) -> Hash {
```

#### CODE_DUPLICATION
**Problem**: Repeated code blocks
```rust
// ❌ BAD
let user_storage = match get_storage("user") {
    Ok(s) => s,
    Err(e) => {
        log::error!("Failed to get user storage: {:?}", e);
        return Err(Error::StorageError);
    }
};

let system_storage = match get_storage("system") {
    Ok(s) => s,
    Err(e) => {
        log::error!("Failed to get system storage: {:?}", e);
        return Err(Error::StorageError);
    }
};

// ✅ GOOD
fn get_storage_or_error(name: &str) -> Result<Storage, Error> {
    get_storage(name).map_err(|e| {
        log::error!("Failed to get {} storage: {:?}", name, e);
        Error::StorageError
    })
}

let user_storage = get_storage_or_error("user")?;
let system_storage = get_storage_or_error("system")?;
```

#### COMPLEX_FUNCTION
**Problem**: Functions doing too many things
```rust
// ❌ BAD
pub fn process_and_store_and_notify(data: Data) -> Result<()> {
    // 200 lines doing validation, processing, storage, and notification
}

// ✅ GOOD
pub fn process_data(data: Data) -> Result<ProcessedData> { }
pub fn store_data(data: &ProcessedData) -> Result<()> { }
pub fn notify_users(data: &ProcessedData) -> Result<()> { }
```

#### MAGIC_NUMBER
**Problem**: Unexplained numeric constants
```rust
// ❌ BAD
if retries > 3 {
    return Err(Error::TooManyRetries);
}
let timeout = Duration::from_secs(30);

// ✅ GOOD
const MAX_RETRIES: u32 = 3;
const REQUEST_TIMEOUT_SECS: u64 = 30;

if retries > MAX_RETRIES {
    return Err(Error::TooManyRetries);
}
let timeout = Duration::from_secs(REQUEST_TIMEOUT_SECS);
```

### ℹ️ INFO Patterns

#### NEEDS_VERIFICATION
Use when you detect a potential issue but need human verification:
```rust
// Example finding:
"NEEDS_VERIFICATION: This looks like it might cause a race condition 
between actors, but I cannot determine the full execution context. 
Code: `shared_state.lock().unwrap().value += 1;`"
```

#### DESIGN_QUESTION
For architectural concerns that need discussion:
```rust
// Example finding:
"DESIGN_QUESTION: This module has 15 public functions. 
Consider splitting into smaller, focused modules for better maintainability."
```

#### POTENTIAL_ISSUE
For patterns that might be problematic depending on usage:
```rust
// Example finding:
"POTENTIAL_ISSUE: Using `.clone()` on large data structure. 
If this is in a hot path, consider using Arc or borrowing instead."
```

### Context-Specific Exceptions

#### Test Code
- Unwrap/expect generally acceptable in tests
- Hardcoded values and sleeps often necessary
- Less stringent performance requirements

#### Benchmark Code
- May use unwrap for setup
- Performance patterns may differ
- Focus on measuring, not optimizing

#### Migration Code
- One-time execution allows different patterns
- May have relaxed performance requirements
- Still needs security checks

#### Example/Demo Code
- Clarity over performance
- May include intentional anti-patterns for education
- Should be clearly marked as non-production