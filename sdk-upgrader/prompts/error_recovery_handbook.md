# SDK Upgrade Error Recovery Handbook

This handbook provides step-by-step recovery procedures for common errors encountered during Polkadot SDK upgrades.

## 🚨 MANDATORY VERSION FIXES - CHECK FIRST!

**⚠️ IMPORTANT: Always check this section BEFORE attempting any other error recovery procedures.**

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

## Quick Reference

| Error Type | Tool | Section |
|------------|------|---------|
| Trait not found | rust-analyzer | [Trait Errors](#trait-errors) |
| Method not found | rust-analyzer + ast-grep | [Method Errors](#method-errors) |
| Type mismatch | rust-analyzer | [Type Errors](#type-errors) |
| Import errors | ast-grep | [Import Errors](#import-errors) |
| Breaking changes | cargo-semver-checks | [Breaking Changes](#breaking-changes) |

## Pre-Flight Checks

Before starting error recovery:
```bash
# 1. Ensure tools are available
which rust-analyzer ast-grep cargo-semver-checks

# 2. Create recovery checkpoint
git stash push -m "upgrade_checkpoint_$(date +%s)"

# 3. Check breaking changes
cargo semver-checks check-release --baseline-rev old-tag > breaking_changes.log
```

## Trait Errors

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

### Error: "trait bound not satisfied"
```bash
# 1. Identify missing bounds
cargo check -p pallet-name 2>&1 | grep "trait bound"

# 2. Common fix: Add Send + Sync
ast-grep --pattern 'impl<T: Config> $TYPE<T>' \
         --rewrite 'impl<T: Config + Send + Sync> $TYPE<T>'

# 3. For async traits
ast-grep --pattern 'async fn $NAME($$$) -> $RET' \
         --rewrite 'async fn $NAME($$$) -> $RET where Self: Send + Sync'
```

## Method Errors

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

### Error: "method `transfer` has wrong number of arguments"
```bash
# 1. Check new signature
rust-analyzer signature-help --position error_location

# 2. Update all calls
ast-grep --pattern '::transfer($FROM, $TO, $AMOUNT, $_)' \
         --rewrite '::transfer(&$FROM, &$TO, $AMOUNT, Preservation::Expendable)?'
```

## Type Errors

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

## Breaking Changes

### Using cargo-semver-checks
```bash
# 1. Generate full report
cargo semver-checks check-release \
  --baseline-rev stable2407 \
  --current-rev stable2409 \
  --verbose > full_report.md

# 2. Extract relevant changes for your crates
grep -A10 "BREAKING" full_report.md | grep -E "(pallet-|frame-)"

# 3. Create fix checklist
cat full_report.md | \
  awk '/BREAKING/{print "- [ ] " $0}' > breaking_fixes.md
```

## Recovery Patterns

### Pattern 1: Systematic Fix Application
```bash
#!/bin/bash
# save as fix_pattern.sh

PATTERN=$1
REPLACEMENT=$2
LOG_FILE="fixes_applied.log"

# Find all occurrences
echo "Searching for pattern: $PATTERN" | tee -a $LOG_FILE
ast-grep --pattern "$PATTERN" --json > matches.json

# Review matches
MATCH_COUNT=$(jq '.matches | length' matches.json)
echo "Found $MATCH_COUNT matches" | tee -a $LOG_FILE

# Apply fixes
ast-grep --pattern "$PATTERN" --rewrite "$REPLACEMENT"

# Verify
cargo check -p affected-crate 2>&1 | tee -a $LOG_FILE
```

### Pattern 2: Incremental Migration
```bash
# For large codebases, migrate one module at a time
for module in pallets/*; do
  echo "Migrating $module"
  
  # Apply common fixes
  cd $module
  ast-grep --pattern 'Weight::from_ref_time($_)' \
           --rewrite 'Weight::from_parts($_, 0)'
  
  # Check compilation
  if cargo check -p $(basename $module); then
    echo "✅ $module migrated successfully"
    git add -A && git commit -m "migrate: $module to new SDK"
  else
    echo "❌ $module needs manual intervention"
    echo $module >> needs_manual_fix.log
  fi
  cd ../..
done
```

### Pattern 3: Error Categorization
```bash
# Categorize errors for batch fixing
cargo check --workspace 2>&1 | \
  grep -E "(error|warning)" | \
  awk -F: '{print $5}' | \
  sort | uniq -c | sort -rn > error_categories.txt

# Process by frequency
while read count error; do
  echo "Fixing $count instances of: $error"
  # Apply appropriate fix based on error type
done < error_categories.txt
```

## Emergency Procedures

### Rollback
```bash
# If upgrade fails catastrophically
git stash pop  # Restore checkpoint
git checkout -b failed-upgrade-analysis
git diff > failed_upgrade.patch
```

### Partial Success
```bash
# Commit working crates, isolate problematic ones
for crate in pallets/*; do
  if cargo check -p $(basename $crate) &>/dev/null; then
    git add $crate
  fi
done
git commit -m "partial upgrade: working crates"
```

### Request Help
When escalating to manual intervention:
```markdown
## Upgrade Blocker Report

**Crate**: pallet-example
**Error**: trait bound `T::AccountId: Decode` not satisfied
**Attempted Fixes**:
1. Added Decode bound to Config - failed
2. Checked scout artifacts - no relevant PR
3. rust-analyzer suggests missing import

**Scout Artifacts Checked**: 
- PR #1234: Currency trait deprecation
- PR #5678: Weight system v2

**Current Status**: Blocked, needs manual review
```

## Common Gotchas

1. **Cascading Errors**: Fix imports first, then traits, then methods
2. **Hidden Dependencies**: Check Cargo.toml features after fixing code
3. **Test Mocks**: Update test configurations after fixing runtime
4. **Benchmarks**: May need separate migration from runtime code

## Tool Output Reference

### rust-analyzer useful commands
```bash
rust-analyzer symbols          # List all symbols
rust-analyzer diagnostics      # Get all errors with context  
rust-analyzer ssr             # Structured search and replace
```

### ast-grep patterns
```bash
# Match any trait implementation
'impl$_<$_> $_ for $_ { $$$ }'

# Match any function with specific return type
'fn $NAME($$$) -> Result<$_, $_> { $$$ }'

# Match attribute macros
'#[$ATTR($$$)]'
```

### Verification Commands
```bash
# After fixes, verify:
cargo check --workspace --all-features
cargo test --workspace --all-features
cargo clippy --workspace -- -D warnings
```

## Fixed Errors Database

**DO NOT EDIT THIS SECTION MANUALLY - Automatically updated by worker agents**

This section contains a searchable database of all errors that have been successfully fixed by the SDK upgrade agents. Each entry follows a strict format for LLM parsing.

---