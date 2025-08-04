# SDK Upgrade Error Recovery Handbook

This handbook provides step-by-step recovery procedures for common errors encountered during Polkadot SDK upgrades.

## 📋 SYMBOL Indexing System

**IMPORTANT**: This handbook uses SYMBOL indexing for automated agent searches.

### How Agents Search
- Build workers search: `grep -A5 "^### SYMBOL: ${error_group.symbol}"`
- Test workers search: `grep -A10 "^### TEST: ${module}::${test_name}"`

### Adding New Entries
When documenting a new error fix, always add SYMBOL index lines:
```
### SYMBOL: generic_error_type
### SYMBOL: specific_error_variant
### Error: "actual error message"
```

For test fixes:
```
### TEST: pallet_name::test_function_name
### Test Error: description
```

## 🚨 MANDATORY VERSION FIXES - CHECK FIRST!

**⚠️ IMPORTANT: Always check this section BEFORE attempting any other error recovery procedures.**

### SYMBOL: rust_version
### SYMBOL: rust_version_incompatibility
### base64ct Dependency Version Lock

**MANDATORY**: If encountering ANY errors with the `base64ct` dependency during upgrade:

```bash
cargo update -p base64ct --precise 1.7.3
```

**Why**: Versions of base64ct > 1.7.3 have breaking API changes that are incompatible with the current Polkadot SDK version. This is a known issue that must be addressed before other fixes.

**When to apply**: 
- Any compilation errors mentioning base64ct
- Trait implementation errors related to base64ct types
- Version conflict errors involving base64ct

**Verification**:
```bash
# Verify the version is locked
grep "base64ct.*1.7.3" Cargo.lock
```

---



## Trait Errors

### SYMBOL: trait_not_found
### SYMBOL: Currency_not_found
### Error: "trait `Currency` not found"
```bash
# 1. Diagnose with rust-analyzer
rust-analyzer diagnostics --path src/lib.rs | grep "trait.*not found"

# 2. Search for trait usage
ast-grep --pattern 'use $_::traits::Currency;'

# 3. Find replacement in scout artifacts
grep -r "Currency.*deprecated" sdk-upgrader/scout/

# 4. Apply migration
ast-grep --pattern 'T::Currency::$METHOD($$$)' \
         --rewrite 'T::NativeBalance::$METHOD($$$)'

# 5. Update imports
ast-grep --pattern 'use frame_support::traits::Currency;' \
         --rewrite 'use frame_support::traits::fungible::{Inspect, Mutate};'
```

### SYMBOL: trait_bound_not_satisfied
### Error: "trait bound not satisfied"
```bash
# 1. Identify missing bounds
cargo check -p pallet-name --message-format=json 2>&1 | jq -r 'select(.reason == "compiler-message") | select(.message.message | contains("trait bound")) | .message.rendered'

# 2. Common fix: Add Send + Sync
ast-grep --pattern 'impl<T: Config> $TYPE<T>' \
         --rewrite 'impl<T: Config + Send + Sync> $TYPE<T>'

# 3. For async traits
ast-grep --pattern 'async fn $NAME($$$) -> $RET' \
         --rewrite 'async fn $NAME($$$) -> $RET where Self: Send + Sync'
```

## Method Errors

### SYMBOL: method_not_found
### SYMBOL: set_balance_not_found
### Error: "method `set_balance` not found"
```bash
# 1. Find method signature in old version
rust-analyzer hover --position old_file.rs:line:col

# 2. Search for deprecation notice
grep -r "set_balance.*deprecated" sdk-upgrader/scout/

# 3. Find all usages
ast-grep --pattern '::set_balance($$$)'

# 4. Common replacements
# set_balance → mutate_account
ast-grep --pattern 'T::Currency::set_balance($WHO, $AMOUNT, $$$)' \
         --rewrite 'T::NativeBalance::mutate_account(&$WHO, |account| {
    account.free = $AMOUNT;
    Ok(())
})?'
```

### SYMBOL: wrong_number_of_arguments
### SYMBOL: transfer_wrong_arguments
### Error: "method `transfer` has wrong number of arguments"
```bash
# 1. Check new signature
rust-analyzer signature-help --position error_location

# 2. Update all calls
ast-grep --pattern '::transfer($FROM, $TO, $AMOUNT, $_)' \
         --rewrite '::transfer(&$FROM, &$TO, $AMOUNT, Preservation::Expendable)?'
```

## Type Errors

### SYMBOL: type_mismatch
### SYMBOL: Weight_type_mismatch
### Error: "expected `Weight`, found `u64`"
```bash
# 1. Find all Weight constructions
ast-grep --pattern 'Weight::from_ref_time($TIME)'

# 2. Update to new Weight format
ast-grep --pattern 'Weight::from_ref_time($TIME)' \
         --rewrite 'Weight::from_parts($TIME, 0)'

# 3. Update constants
ast-grep --pattern 'const $NAME: Weight = $_' --json | \
  jq -r '.matches[].file' | xargs -I {} \
  sed -i 's/from_ref_time/from_parts/g' {}
```

### SYMBOL: storage_type_mismatch
### Error: "type mismatch in storage"
```bash
# 1. Find storage definitions
ast-grep --pattern '#[pallet::storage]
$$$
type $NAME = $_'

# 2. Add QueryKind parameter
ast-grep --pattern 'StorageValue<_, $TYPE>' \
         --rewrite 'StorageValue<_, $TYPE, ValueQuery>'
```

## Import Errors

### SYMBOL: unresolved_import
### SYMBOL: import_error
### Error: "unresolved import"
```bash
# 1. Find all imports
ast-grep --pattern 'use $PATH;' | grep -v "^//"

# 2. Check if module moved
rust-analyzer find-all-refs --position import_location

# 3. Common import updates
# Old: use frame_support::traits::Currency;
# New: use frame_support::traits::fungible::{Inspect, Mutate};
sed -i 's/traits::Currency/traits::fungible::{Inspect, Mutate}/g' src/**/*.rs
```






## Test-Specific Errors

### TEST: pallet_template::tests::it_works_for_default_value
### Test Error: Currency trait not available in mock runtime
```bash
# Fix: Update mock runtime to use new traits
ast-grep --pattern 'impl pallet_balances::Config for Test {
    type Currency = $_;
    $$$
}' \
--rewrite 'impl pallet_balances::Config for Test {
    type ExistentialDeposit = ConstU64<1>;
    type AccountStore = System;
    $$$
}'
```

## Fixed Errors Database

**DO NOT EDIT THIS SECTION MANUALLY - Automatically updated by worker agents**

This section contains a searchable database of all errors that have been successfully fixed by the SDK upgrade agents. Each entry follows a strict format for LLM parsing.

---


### SYMBOL: type_mismatch  
### SYMBOL: xcm_v4_to_v5_migration  
### Error: "mismatched types: expected `staging_xcm::v5::Location`, found `staging_xcm::v4::Location`"

**Problem**  
SDK 2409 → 2412 bumps XCM enums to V5; any `Versioned*::V4` usage, old imports, or V3 error types now yield E0308/E0277.

**Agent-Recovery Steps (Compiler-Driven Approach)**

1. **Update XCM imports globally**
   ```bash
   # Update explicit version imports
   mcp__serena__replace_regex(
     regex="use\\s+(.*?)xcm::(v3|v4)",
     repl ="use $1xcm::v5",
     allow_multiple_occurrences=true,
     relative_path="."
   )
   # Change generic imports to latest
   mcp__serena__replace_regex(
     regex="use\\s+xcm::prelude::\\*",
     repl ="use xcm::latest::prelude::*",
     allow_multiple_occurrences=true,
     relative_path="."
   )
   ```

2. **Create migration tracking**
   ```json
   TodoWrite([
     { "id":"v4-imports", "status":"completed", "priority":"high", "content":"Update XCM imports to V5" },
     { "id":"v4-compile", "status":"in_progress", "priority":"high", "content":"Use compiler to find all V4/V3 usage" },
     { "id":"v4-convert", "status":"pending", "priority":"high", "content":"Apply conversions using TryFrom/Into" },
     { "id":"v4-verify", "status":"pending", "priority":"high", "content":"Verify tests pass" }
   ])
   ```

3. **Use compiler as guide (iterative fix)**
   ```bash
   # Run cargo check to get comprehensive error list
   cargo check --all-targets --message-format=json 2>&1 | jq -r 'select(.reason == "compiler-message") | select(.message.rendered | test("(V4|V3|xcm)")) | .message.rendered' > xcm_errors.txt
   
   # For each error type:
   # a) V3 Error types → V5
   mcp__serena__replace_regex(
     regex="xcm::v3::Error",
     repl ="xcm::v5::Error",
     allow_multiple_occurrences=true,
     relative_path="."
   )
   
   # b) For simple enum variants, use conversion functions
   # Find instantiation sites
   Grep(pattern="VersionedLocation::V4\\(", glob="**/*.rs", output_mode="content", -n=true)
   ```

4. **Apply idiomatic conversions (preferred over direct replacement)**
   ```rust
   // Instead of: VersionedLocation::V4(location) → VersionedLocation::V5(location)
   // Use conversion where V4 objects exist:
   
   // Example pattern to apply:
   mcp__serena__edit_pattern(
     pattern="Box::new(VersionedLocation::V4($LOC))",
     replacement="Box::new(VersionedLocation::V4($LOC).try_into().expect(\"V4 to V5 conversion\"))",
     description="Use TryFrom for safe version conversion"
   )
   ```

5. **Handle all usage patterns**
   ```bash
   # Search for ALL V4 references including types and patterns
   Grep(pattern="::V4|xcm::v4", glob="**/*.rs", output_mode="content")
   
   # Check match statements separately
   Grep(pattern="VersionedAssets::V4|VersionedLocation::V4|VersionedXcm::V4", glob="**/*.rs", -B=2, -A=5)
   ```

6. **Compile and test iteratively**
   ```bash
   # Keep running until clean
   while cargo check --all-targets --message-format=json 2>&1 | jq -e 'select(.reason == "compiler-message") | select(.message.rendered | test("(V4|V3|xcm)"))' > /dev/null; do
     echo "Fix remaining XCM version issues"
     # Apply fixes based on compiler errors
   done
   
   # Run tests
   cargo test --all-targets
   ```

7. **Final verification**
   ```bash
   # Ensure no old versions remain
   Grep(pattern="::V4|::V3|xcm::v4|xcm::v3", glob="**/*.rs", output_mode="count")  # expect 0
   
   # Check for warnings
   cargo check --all-targets --message-format=json 2>&1 | jq -r 'select(.reason == "compiler-message") | select(.message.rendered | test("deprecated"; "i")) | .message.rendered'
   ```

**Key Principles:**
- Use compiler errors as your checklist
- Prefer `TryFrom`/`Into` conversions over manual reconstruction
- Update imports before fixing types
- Test thoroughly - XCM changes can have runtime effects