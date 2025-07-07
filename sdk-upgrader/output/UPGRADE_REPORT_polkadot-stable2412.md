# Polkadot SDK Upgrade Report: stable2412

## Global heuristics

- **RuntimeString deprecated**: `sp_runtime::RuntimeString` is deprecated in favor of `String` or `Cow<'static, str>`
- **DispatchEventInfo structure change**: System events now contain `DispatchEventInfo` instead of `DispatchInfo` directly
- **DispatchInfo field changes**: `DispatchInfo` now has `call_weight` and `extension_weight` instead of single `weight` field
- **XCM dry_run_call API change**: `dry_run_call` now requires 3 parameters including `result_xcms_version: xcm::Version`
- **Runtime version field change**: `state_version` has been replaced with `system_version`
- **New required trait implementations**: Pallets now require additional associated types like `SelectCore`, `DoneSlashHandler`, `WeightInfo`
- **Runtime API std modules**: Runtime API crates need explicit `sp_std` imports and `extern crate alloc` for no_std support

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