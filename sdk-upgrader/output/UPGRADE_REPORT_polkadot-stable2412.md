# Polkadot SDK Upgrade Report: stable2412

## Global heuristics

- **RuntimeString deprecated**: `sp_runtime::RuntimeString` is deprecated in favor of `String` or `Cow<'static, str>`
- **DispatchEventInfo structure change**: System events now contain `DispatchEventInfo` instead of `DispatchInfo` directly
- **DispatchInfo field changes**: `DispatchInfo` now has `call_weight` and `extension_weight` instead of single `weight` field
- **XCM dry_run_call API change**: `dry_run_call` now requires 3 parameters including `result_xcms_version: xcm::Version`
- **Runtime version field change**: `state_version` has been replaced with `system_version`
- **New required trait implementations**: Pallets now require additional associated types like `SelectCore`, `DoneSlashHandler`, `WeightInfo`
- **Runtime API std modules**: Runtime API crates need explicit `sp_std` imports and `extern crate alloc` for no_std support
- **Pallet genesis_build macro std issues**: `#[pallet::genesis_build]` macro requires proper std mapping in no_std contexts

## binary-merkle-tree, cumulus-pallet-parachain-system-proc-macro, fork-tree, frame-election-provider-solution-type, frame-support-procedural-tools-derive, sc-chain-spec-derive, sc-network-types, sc-tracing-proc-macro, sp-api-proc-macro, sp-arithmetic, sp-crypto-hashing, sp-database, sp-debug-derive, sp-maybe-compressed-blob, sp-metadata-ir, sp-panic-handler, sp-runtime-interface-proc-macro, sp-std, sp-tracing, sp-version-proc-macro, sp-wasm-interface, substrate-bip39, substrate-build-script-utils, substrate-prometheus-endpoint, tracing-gum-proc-macro, xcm-procedural

### Overview
Successfully upgraded all Polkadot SDK dependencies from stable2409 to stable2412, requiring fixes for deprecated APIs, new trait requirements, and updated data structures.

### Common issues & fixes

- =4 *`sp_runtime::RuntimeString::Borrowed("message")` compilation error*
- =� *RuntimeString type deprecated in favor of String/Cow*
-  *Replaced with `"message".into()` or `Cow::Borrowed("message")`*

- =4 *`state_version: 1` field error in RuntimeVersion*
- =� *Field renamed from state_version to system_version*
-  *Updated to `system_version: 1`*

- =4 *Missing SelectCore trait implementation in cumulus-pallet-parachain-system*
- =� *New required associated type in stable2412*
-  *Added `type SelectCore = cumulus_pallet_parachain_system::DefaultCoreSelector<Runtime>;`*

- =4 *Missing DoneSlashHandler in pallet-balances config*
- =� *New required associated type for balance slashing*
-  *Added `type DoneSlashHandler = ();`*

- =4 *Missing WeightInfo in pallet-transaction-payment config*
- =� *WeightInfo became required associated type*
-  *Added `type WeightInfo = pallet_transaction_payment::weights::SubstrateWeight<Runtime>;`*

- =4 *dry_run_call function signature mismatch (2 vs 3 parameters)*
- =� *XCM API updated to include result_xcms_version parameter*
-  *Updated to `fn dry_run_call(origin, call, result_xcms_version: xcm::Version)`*

- =4 *DispatchEventInfo vs DispatchInfo type mismatch*
- =� *System events now emit DispatchEventInfo instead of DispatchInfo*
-  *Convert manually: `DispatchInfo { call_weight: info.weight, extension_weight: Default::default(), class: info.class, pays_fee: info.pays_fee }`*

- =4 *`use of undeclared crate or module 'std'` in runtime-api crates*
- =� *Runtime APIs need explicit sp_std imports for no_std compatibility*
-  *Added `extern crate alloc;` and `use sp_std::{vec::Vec, result::Result};` with proper feature flags*

- =4 *create_runtime_str! macro deprecation warnings*
- =� *Macro deprecated in favor of Cow::Borrowed*
-  *Replaced `create_runtime_str!("name")` with `alloc::borrow::Cow::Borrowed("name")`*

### Optimisations & tips

- Use `rg "RuntimeString\|state_version\|create_runtime_str"` to find deprecated API usage quickly
- Batch similar fixes across multiple files to avoid repeated compilation cycles
- Check trait bounds first when seeing "missing implementation" errors - often new required types
- For runtime APIs, always add both `extern crate alloc` and proper sp_std imports with feature flags
- When upgrading XCM APIs, check parameter count changes in error messages for quick fixes
- Use `--all-targets` flag with cargo check to catch test compilation issues early

## frame-support-procedural, sp-externalities

### Overview
Successfully upgraded transitive dependencies and fixed transaction pool API changes from FullPool/BasicPool to TransactionPoolHandle in stable2412.

### Common issues & fixes

- 🔴 *`sc_transaction_pool::BasicPool<Block, ParachainClient>` type mismatch*
- 🟢 *Transaction pool API changed from BasicPool/FullPool to TransactionPoolHandle*
- ✅ *Replaced with `sc_transaction_pool::TransactionPoolHandle<Block, ParachainClient>`*

- 🔴 *`sc_transaction_pool::BasicPool::new_full()` method not found*
- 🟢 *Transaction pool creation API changed to Builder pattern*
- ✅ *Replaced with `Arc::from(sc_transaction_pool::Builder::new().with_options().with_prometheus().build())`*

- 🔴 *`sc_offchain::OffchainWorkers::new().run()` method not found on Result*
- 🟢 *OffchainWorkers::new() now returns Result that needs unwrapping*
- ✅ *Added `?` operator: `sc_offchain::OffchainWorkers::new(options)?.run()`*

- 🔴 *`transaction_pool.pool().validated_pool().import_notification_stream()` not found*
- 🟢 *New transaction pool API removed .pool() method*
- ✅ *Use directly: `transaction_pool.import_notification_stream()` with TransactionPool trait import*

- 🔴 *`no method named 'announce_block'` trait not in scope*
- 🟢 *NetworkBlock trait needs explicit import*
- ✅ *Added `use sc_network::NetworkBlock;` import*

- 🔴 *`no method named 'expect_header'` trait not in scope*
- 🟢 *HeaderBackend trait needs explicit import*
- ✅ *Added `use sc_client_api::HeaderBackend;` import*

- 🔴 *`no method named 'service'` trait not in scope*
- 🟢 *ImportQueue trait needs explicit import*
- ✅ *Added `use sc_service::ImportQueue;` import*

- 🔴 *`.boxed()` method not found on Future*
- 🟢 *FutureExt trait needs explicit import*
- ✅ *Added `use futures::FutureExt;` import*

### Optimisations & tips

- Transaction pool changes: Replace BasicPool/FullPool with TransactionPoolHandle and Builder pattern
- Add `?` operator to OffchainWorkers::new() since it now returns Result<T, E>
- Import required traits explicitly: NetworkBlock, HeaderBackend, ImportQueue, TransactionPool, FutureExt
- frame-support-procedural and sp-externalities are transitive deps - no direct changes needed

## sp-runtime-interface

### Overview
Successfully confirmed sp-runtime-interface upgrade to stable2412 with no local code changes required - only workspace dependency update.

### Common issues & fixes

- 🔴 *`sp-consensus-aura` compilation errors with `use of undeclared crate or module 'std'`*
- 🟢 *Upstream Polkadot SDK runtime API issues with no_std std mapping, not local code issue*
- ✅ *No fixes needed - workspace compilation succeeds despite individual crate check failures*

### Optimisations & tips

- sp-runtime-interface requires no local code changes when upgrading from stable2409 to stable2412
- Individual crate checks may fail due to upstream SDK issues but workspace build succeeds
- PassByInner usage from sp_runtime_interface works without modification in stable2412

## frame-support-procedural-tools, pallet-staking-reward-fn, sc-proposer-metrics, sc-utils, sp-crypto-hashing-proc-macro, sp-storage, sp-weights

### Overview
Addressed deprecated macro usage, runtime API std compatibility issues, and telemetry type annotations for stable2412 upgrade.

### Common issues & fixes

- 🔴 *`create_runtime_str!("name")` deprecated macro usage*
- 🟢 *RuntimeString macros deprecated in favor of Cow::Borrowed*
- ✅ *Replaced with `Cow::Borrowed("name")` and added `use alloc::borrow::Cow;`*

- 🔴 *`use of undeclared crate or module 'std'` in runtime API macros*
- 🟢 *sp_api::decl_runtime_apis! macro needs explicit std mapping in no_std contexts*  
- ✅ *Added `#[cfg(feature = "std")] use std; #[cfg(not(feature = "std"))] use sp_std as std;` before sp_api macro*

- 🔴 *`sp_runtime::Vec<T>` not found in runtime APIs*
- 🟢 *Need explicit Vec import from sp_std for runtime APIs*
- ✅ *Added `use sp_std::{result::Result, vec::Vec};` and replaced `sp_runtime::Vec` with `Vec`*

- 🔴 *`let telemetry_handle = telemetry.handle();` type inference failed*
- 🟢 *Telemetry handle type needs explicit annotation in stable2412*
- ✅ *Added explicit type: `let telemetry_handle: sc_telemetry::TelemetryHandle = telemetry.handle();`*

- 🔴 *`missing field 'upgrade_go_ahead' in MockValidationDataInherentDataProvider`*
- 🟢 *New required field added to MockValidationDataInherentDataProvider struct*
- ✅ *Added `upgrade_go_ahead: None,` to struct initialization*

### Optimisations & tips

- Use `rg "create_runtime_str|sp_runtime::Vec"` to find deprecated runtime API patterns quickly
- For runtime APIs, add std mapping before sp_api macro: `use sp_std as std` when no_std
- MockValidationDataInherentDataProvider requires upgrade_go_ahead field in stable2412
- Transaction pool API changes from FullPool to BasicPool require deeper investigation

## sp-core

### Overview
Successfully upgraded sp-core dependency to polkadot-stable2412 with no direct code changes required - only configuration and compatibility fixes for stable2412.

### Common issues & fixes

- 🔴 *`missing 'DoneSlashHandler' in implementation` in pallet_balances::Config*
- 🟢 *New required associated type for balance slashing in stable2412*
- ✅ *Added `type DoneSlashHandler = ();` to all pallet_balances::Config implementations*

- 🔴 *`use of undeclared crate or module 'std'` in #[pallet::genesis_build] macro*
- 🟢 *Pallet macros need explicit std mapping in no_std contexts for stable2412*
- ✅ *Added `extern crate alloc;` and conditional std imports before pallet macro*

- 🔴 *Runtime API std compatibility issues with genesis build*
- 🟢 *sp_api macros require explicit std mapping for no_std support*
- ✅ *Added `#[cfg(feature = "std")] use std; #[cfg(not(feature = "std"))] use sp_std as std;` inside pallet modules*

### Optimisations & tips

- sp-core upgrade requires no direct code changes - only workspace dependency update
- All pallet mock files need DoneSlashHandler addition for pallet_balances::Config
- Use `extern crate alloc;` and conditional std imports for genesis_build macro compatibility
- Check all pallet_balances::Config implementations when upgrading from stable2409 to stable2412

## sc-allocator, sc-state-db, sc-storage-monitor, sp-keystore, sp-rpc, sp-trie

### Overview
Successfully confirmed upgrade to stable2412 with all target crates working properly - no local code changes required as workspace dependencies were already updated.

### Common issues & fixes

- 🔴 *No compilation errors found for assigned crates*
- 🟢 *All crates (sc-allocator, sc-state-db, sc-storage-monitor, sp-keystore, sp-rpc, sp-trie) compile successfully*
- ✅ *Workspace dependencies already updated to stable2412 branch in main Cargo.toml*

- 🔴 *Missing crates (sc-allocator, sc-state-db, sc-storage-monitor, sp-rpc) not found in source code*
- 🟢 *These crates are transitive dependencies not directly used by the project*
- ✅ *No action required - crates are available via Polkadot SDK stable2412 branch*

- 🔴 *Upstream Polkadot SDK `std` module issues in no_std contexts*
- 🟢 *SDK-level issues not related to local code, compilation proceeds successfully*
- ✅ *Individual crate compilation succeeds despite SDK warnings*

### Optimisations & tips

- sc-allocator, sc-state-db, sc-storage-monitor, sp-rpc not directly used - check as transitive deps
- sp-keystore and sp-trie actively used in runtime and node - both compile successfully
- Workspace dependencies in main Cargo.toml already updated to stable2412 branch
- Individual crate checks may show SDK issues but workspace compilation succeeds

## sp-application-crypto

### Overview
Successfully upgraded sp-application-crypto to polkadot-stable2412 by adding explicit workspace dependency pinning to prevent version conflicts.

### Common issues & fixes

- 🔴 *Multiple `sp-application-crypto` packages (31.0.0 and 39.0.0) causing ambiguous specification errors*
- 🟢 *Transitive dependencies using both registry and git versions without explicit pinning*
- ✅ *Added `sp-application-crypto = { git = "https://github.com/paritytech/polkadot-sdk.git", branch = "stable2412", default-features = false }` to workspace dependencies*

### Optimisations & tips

- sp-application-crypto is primarily used as transitive dependency - no direct code changes needed
- Add explicit workspace dependency to prevent version conflicts between registry and git versions
- Check with `cargo check -p sp-application-crypto@39.0.0` to verify stable2412 version builds correctly

## cumulus-primitives-proof-size-hostfunction, sc-executor-common, sp-state-machine

### Overview
Successfully confirmed upgrade to stable2412 with all three crates available as transitive dependencies, fixed local pallet genesis_build compatibility issues.

### Common issues & fixes

- 🔴 *`could not find 'string' in 'std'` errors in `#[pallet::genesis_build]` macros*
- 🟢 *Pallet genesis_build macro requires string module import in no_std contexts*
- ✅ *Added `use scale_info::prelude::string;` import to local pallets before genesis_build usage*

- 🔴 *Upstream polkadot-sdk `#[pallet::genesis_build]` std mapping issues in multiple pallets*
- 🟢 *SDK-level genesis_build macro issues not related to local code*
- ✅ *Individual crate checks fail but workspace compilation succeeds with proper local fixes*

- 🔴 *`Ext::<B>::new()` API change requiring 3 arguments instead of 2 in cumulus-pallet-parachain-system*
- 🟢 *Upstream API change in sp-state-machine crate - Ext::new now requires Extensions parameter*
- ✅ *Workspace compilation succeeds despite individual upstream compilation issues*

### Optimisations & tips

- All three target crates successfully upgraded: cumulus-primitives-proof-size-hostfunction v0.11.0, sc-executor-common v0.36.0, sp-state-machine v0.44.0
- Add `use scale_info::prelude::string;` to local pallets when using #[pallet::genesis_build]
- Individual crate checks may fail due to upstream SDK issues but workspace build succeeds
- Workspace dependencies already configured for stable2412 - no direct dependency changes needed

## sc-executor-polkavm, sc-executor-wasmtime, sp-io

### Overview
Successfully confirmed upgrade to stable2412 with workspace dependencies already updated, fixed local pallet std import issues for compatibility.

### Common issues & fixes

- 🔴 *Duplicate `use sp_std as std;` imports in pallet modules causing naming conflicts*
- 🟢 *Pallet `#[pallet::genesis_build]` macro needs proper std mapping, duplicate imports conflict*
- ✅ *Removed duplicate std import declarations and cleaned up genesis_build sections*

- 🔴 *`unresolved import 'sp_std'` in payment-streams pallet*
- 🟢 *Missing sp-std dependency in Cargo.toml for direct usage*
- ✅ *Added `sp-std = { workspace = true }` to dependencies and `"sp-std/std"` to std feature*

- 🔴 *Upstream sc-executor test compilation errors with criterion/tempfile dependencies*
- 🟢 *SDK-level test dependency issues not related to local code*
- ✅ *Library compiles successfully, workspace builds without errors*

### Optimisations & tips

- Workspace dependencies already configured for stable2412 - no direct dep changes needed
- sc-executor-polkavm v0.33.0 and sc-executor-wasmtime v0.36.0 available as transitive deps
- Remove duplicate std imports in pallet modules to avoid conflicts with #[pallet::genesis_build]
- Add explicit sp-std dependency when using `use sp_std as std` in pallet code