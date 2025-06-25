---
description: "Verify and filter findings from all agents"
allowed-tools: ["Read", "Bash"]
---

Usage: /project:verify_findings [input_dir] [output_dir]

Parse arguments:
- First argument or default: input directory (default: `raw-findings/`)
- Second argument: output directory (if provided)
- If no output dir AND `$OUTPUT_DIR` env var is set: use `$OUTPUT_DIR`
- If neither: print to console

**CRITICAL: Determine output directory:**
```bash
# Priority order:
if [ -n "$2" ]; then
  OUTPUT_DIR="$2"
elif [ -n "$OUTPUT_DIR" ]; then
  # Use environment variable
  OUTPUT_DIR="$OUTPUT_DIR"
else
  # No output dir - print to console
  OUTPUT_DIR=""
fi
```

**REQUIRED FIRST STEPS if OUTPUT_DIR is set:**
1. Create output directory: `mkdir -p "$OUTPUT_DIR"` (NOT raw-findings!)
2. Check if input directory exists and has JSON files
3. If no JSON files in input, create `$OUTPUT_DIR/summary.json` with empty findings
4. Process all JSON files and write verified versions to `$OUTPUT_DIR/` (NOT back to input!)

Read all JSON files from input directory, verify each finding, output to the CORRECT directory.

**Verification steps per finding:**
1. Read actual file at reported line
2. Confirm issue exists in context
3. Check confidence >= 0.7
4. Reject if:
   - Test/benchmark file
   - Known safe pattern
   - Context shows proper handling

**False positive patterns:**
- Sleep in tests → OK
- Unwrap in benchmarks → OK
- Bounded types aliased → OK
- Errors handled elsewhere → OK

**Cross-validation:**
- If multiple agents flag same line → boost confidence
- If conflicting findings → investigate deeper

**Output:**
If `$OUTPUT_DIR` is set (from env var or argument):
- **CRITICAL**: Do NOT write to `raw-findings/` - that's the INPUT directory!
- **REQUIRED**: Create output directory: `mkdir -p "$OUTPUT_DIR"` (e.g., `verified-findings/`)
- **REQUIRED**: Write JSON files to `$OUTPUT_DIR/` with filtered findings
- **REQUIRED**: Write a file for EVERY input file (even if findings=[])
- **REQUIRED**: If no input files found, create `$OUTPUT_DIR/summary.json`:
  ```json
  {
    "verified": true,
    "files_checked": 0,
    "findings": [],
    "message": "No files to verify"
  }
  ```
- Same filename structure as input, updated confidence scores
- Remove findings that don't pass verification, keep empty arrays
- **WRONG**: Writing to `raw-findings/` when OUTPUT_DIR=verified-findings
- **RIGHT**: Writing to `verified-findings/` when OUTPUT_DIR=verified-findings

If `$OUTPUT_DIR` is not set:
- Print each verified JSON to stdout
- One JSON object per line for easy parsing
- Include verification summary at the end

Log verification stats to stderr in both cases.