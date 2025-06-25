---
description: "Stage 1: Analyze files for StorageHub-specific issues"
allowed-tools: ["Bash", "Read", "Grep"]
---

Usage: /project:pr_checks [file1 file2 ...] [output_dir]

Parse arguments:
- If `$ARGUMENTS` provided: use as space-separated file list
- Otherwise: use `$CHANGED_FILES` environment variable
- Last argument if it ends with `/` or contains `output`: use as output directory
- Default output: `raw-findings/`

Analyze the files for StorageHub-specific issues. Create JSON findings in output directory.

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

**Output Format:**
For each file, create `raw-findings/<sanitized_filename>.json`:
```json
{
  "id": "CHK-YYYYMMDD-HHMMSS",
  "agent_name": "pr-checker",
  "agent_type": "checks",
  "source_file": "<file_path>",
  "commit_id": "$COMMIT_SHA",
  "timestamp": "ISO8601",
  "findings": [{
    "path": "<file_path>",
    "line": N,
    "severity": "BUG|SECURITY|PERFORMANCE|SUGGESTION",
    "category": "blocking_operation|missing_origin_check|etc",
    "rule_id": "RULE_ID",
    "summary": "Brief description",
    "body": "**[EMOJI] [SEVERITY]: [Brief description]**\n\n[Details]\n\n**Suggestion:**\n```rust\n[fix]\n```\n\n**Why this matters:** [Impact]",
    "confidence": 0.9
  }]
}
```

Process each file in `$CHANGED_FILES`. Skip test/benchmark files unless relevant. Empty findings array if clean.