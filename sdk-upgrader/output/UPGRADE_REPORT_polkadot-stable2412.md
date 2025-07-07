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
- =â *RuntimeString type deprecated in favor of String/Cow*
-  *Replaced with `"message".into()` or `Cow::Borrowed("message")`*

- =4 *`state_version: 1` field error in RuntimeVersion*
- =â *Field renamed from state_version to system_version*
-  *Updated to `system_version: 1`*

- =4 *Missing SelectCore trait implementation in cumulus-pallet-parachain-system*
- =â *New required associated type in stable2412*
-  *Added `type SelectCore = cumulus_pallet_parachain_system::DefaultCoreSelector<Runtime>;`*

- =4 *Missing DoneSlashHandler in pallet-balances config*
- =â *New required associated type for balance slashing*
-  *Added `type DoneSlashHandler = ();`*

- =4 *Missing WeightInfo in pallet-transaction-payment config*
- =â *WeightInfo became required associated type*
-  *Added `type WeightInfo = pallet_transaction_payment::weights::SubstrateWeight<Runtime>;`*

- =4 *dry_run_call function signature mismatch (2 vs 3 parameters)*
- =â *XCM API updated to include result_xcms_version parameter*
-  *Updated to `fn dry_run_call(origin, call, result_xcms_version: xcm::Version)`*

- =4 *DispatchEventInfo vs DispatchInfo type mismatch*
- =â *System events now emit DispatchEventInfo instead of DispatchInfo*
-  *Convert manually: `DispatchInfo { call_weight: info.weight, extension_weight: Default::default(), class: info.class, pays_fee: info.pays_fee }`*

- =4 *`use of undeclared crate or module 'std'` in runtime-api crates*
- =â *Runtime APIs need explicit sp_std imports for no_std compatibility*
-  *Added `extern crate alloc;` and `use sp_std::{vec::Vec, result::Result};` with proper feature flags*

- =4 *create_runtime_str! macro deprecation warnings*
- =â *Macro deprecated in favor of Cow::Borrowed*
-  *Replaced `create_runtime_str!("name")` with `alloc::borrow::Cow::Borrowed("name")`*

### Optimisations & tips

- Use `rg "RuntimeString\|state_version\|create_runtime_str"` to find deprecated API usage quickly
- Batch similar fixes across multiple files to avoid repeated compilation cycles
- Check trait bounds first when seeing "missing implementation" errors - often new required types
- For runtime APIs, always add both `extern crate alloc` and proper sp_std imports with feature flags
- When upgrading XCM APIs, check parameter count changes in error messages for quick fixes
- Use `--all-targets` flag with cargo check to catch test compilation issues early