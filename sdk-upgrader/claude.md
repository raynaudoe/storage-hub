# SDK Upgrader - LLM Navigation Guide

## Project Mission
Automated Polkadot SDK upgrade tool that uses AI agents to handle breaking changes and migration patterns between SDK versions.

## Core Architecture

### Multi-Agent System
- **Orchestrator** (`run.sh`, `runner.sh`): Project manager that controls the upgrade workflow state machine
- **Build Worker** (AI agent): Specialist that fixes compilation errors grouped by symbol
- **Tests Worker** (AI agent): Specialist that fixes test failures grouped by module
- **Tools** (Python utilities): Error parsing and grouping scripts that analyze compiler output

## The Upgrade Workflow: Step-by-Step Guide

### Phase 0: Setup (`run.sh`)
- **Goal**: Initialize environment and orchestrate complete process
- **Actions**: Sets up paths, validates prerequisites, calls scout and runner
- **Entry**: `./run.sh polkadot-stable2407 polkadot-stable2410`

### Phase 1: Scouting (`tools/scout.sh`)
- **Goal**: Gather intelligence about target SDK version
- **Actions**: Downloads PR artifacts and release notes from GitHub
- **Key Artifacts**: Stores in `resources/polkadot-sdk-<NEW_TAG>/`
  - `release-notes.md`: Official release notes
  - `pr-*/description.md`: Migration guidance from each PR
  - `pr-*/patch.diff`: Actual code changes for reference

### Phase 2: Execution (`tools/runner.sh`)
- **Goal**: Perform upgrade and fix all regressions
- **Sub-steps**:

#### 2.1: Dependency Update
- Updates root `Cargo.toml` to use new SDK branch
- Removes old tag/rev fields
- Creates initial `status.json` for tracking

#### 2.2: Iterative Build-Fix Loop
1. Run `cargo check --workspace`
2. Python script (`tools/cargo_error_grouper.py`) groups errors by symbol
3. **Orchestrator** spawns **Build Worker** for each error group
4. **Build Worker** reads:
   - Error group details from `status.json`
   - Recovery procedures from `prompts/error_recovery_handbook.md`
   - PR patches from `resources/` for context
5. Worker applies fixes and documents in `UPGRADE_REPORT_<NEW_TAG>.md`
6. Loop until no errors or max iterations (40) reached

#### 2.3: Iterative Test-Fix Loop
1. Run `cargo test --workspace`
2. Python script (`tools/tests_error_grouper.py`) groups failures by module
3. **Orchestrator** spawns **Tests Worker** for each test group
4. **Tests Worker** follows similar pattern as Build Worker
5. Loop until all tests pass or max iterations reached

## File & Directory Quick Reference

| Path | Purpose | When to check this file |
| :--- | :--- | :--- |
| `run.sh` | **Main Entry Point**. Complete upgrade orchestration | Understanding overall flow or changing parameters |
| `tools/scout.sh` | **Scout Script**. Downloads PR artifacts and release notes | Debugging artifact gathering or GitHub API issues |
| `tools/runner.sh` | **Orchestrator Runner**. Manages the core upgrade loops | Understanding iteration logic or modifying workflow |
| `prompts/` | **Agent Instructions**. YAML/MD files defining agent behavior | **Primary location for improving agent capabilities** |
| `prompts/orchestrator.yaml` | State machine definition for upgrade workflow | Modifying upgrade phases or error handling strategy |
| `prompts/build_worker.yaml` | Instructions for compilation error fixing | Build Worker failing on specific error types |
| `prompts/tests_worker.yaml` | Instructions for test failure fixing | Tests Worker struggling with test patterns |
| `prompts/error_recovery_handbook.md` | **Collaborative Learning DB**. Growing knowledge base | Adding new error solutions or checking existing fixes |
| `tools/cargo_error_grouper.py` | Parses and groups compilation errors by symbol | Improving error grouping logic or adding error types |
| `tools/tests_error_grouper.py` | Parses and groups test failures by module | Enhancing test failure detection or grouping |
| `resources/` | Downloaded PR artifacts and release notes | Inspecting SDK changes or migration patterns |
| `output/status.json` | **Central Coordination**. Tracks all progress and state | Debugging current state or resuming interrupted runs |
| `output/UPGRADE_REPORT_*.md` | Documents all fixes applied by Build Workers | Reviewing what was changed during upgrade |

## How to Approach Common Tasks

### To debug a failing upgrade:
1. Check `output/status.json` for current state and error groups
2. Identify failing phase: scout, build-fix, or test-fix
3. For build-fix failures:
   - Find the error group in status.json
   - Check if `prompts/error_recovery_handbook.md` has a solution
   - Review `prompts/build_worker.yaml` instructions
   - Consider if error grouping in `tools/cargo_error_grouper.py` needs refinement
4. For test-fix failures:
   - Similar process but with `prompts/tests_worker.yaml`
   - Check test grouping in `tools/tests_error_grouper.py`

### To improve agent problem-solving:
1. Identify recurring failure patterns in `output/UPGRADE_REPORT_*.md`
2. Add specific solutions to `prompts/error_recovery_handbook.md`:
   - Use SYMBOL indexing (e.g., `### SYMBOL: trait_not_found`)
   - Include concrete fix examples
   - Document version-specific issues
3. Enhance agent prompts in `prompts/build_worker.yaml` or `prompts/tests_worker.yaml`:
   - Add new error patterns
   - Improve context usage strategies
   - Refine fix verification steps

### To add collaborative learning:
1. Successful fixes are automatically appended to Error Recovery Handbook
2. Format new entries with SYMBOL indexing for searchability:
   ```markdown
   ### SYMBOL: error_type
   ### Error: "exact error message"
   [Solution steps...]
   ```
3. Test fixes use TEST indexing:
   ```markdown
   ### TEST: module_name::test_function
   ### Test Error: description
   [Fix steps...]
   ```

### To modify the upgrade workflow:
1. Edit `prompts/orchestrator.yaml` for state machine changes
2. Key states: INIT → UPDATE_DEPS → CHECK_ERRORS → GROUP_ERRORS → EXECUTE → SPAWN
3. Modify iteration limits, error thresholds, or add new phases
4. Test with dry runs using modified `tools/runner.sh`

## Key Concepts for LLMs

### Error Grouping Strategy
- Groups related errors by primary symbol (e.g., trait name, function name)
- Maximum 5 errors per group to maintain focused context
- Processes high-impact symbols first (those affecting most files)

### Sequential Agent Execution
- Agents work one at a time to prevent merge conflicts
- Each agent focuses on a single error group or test module
- Status tracking prevents duplicate work

### Collaborative Learning
- Error Recovery Handbook grows with each successful fix
- Agents check handbook first before attempting new solutions
- Version-specific fixes are clearly marked

### Safety Mechanisms
- Maximum iteration limits (40) prevent infinite loops
- Status file enables safe interruption and resumption
- Error summaries generated if unable to fix everything

### Docker Environment (Optional)
- `docker/` contains containerized setup for consistent environment
- Useful for CI/CD integration or isolated testing
- See `docker/README.md` for setup instructions

## Common Pitfalls & Solutions

1. **base64ct version conflicts**: Always check Error Recovery Handbook's mandatory fixes first
2. **Trait reorganization**: Many traits moved between modules - check PR descriptions
3. **Method renames**: Common in SDK upgrades - scout artifacts contain mappings
4. **Test assertions**: Often need updates due to behavior changes - check release notes

## Success Metrics
- All compilation errors resolved
- All tests passing
- Minimal manual intervention required
- Clear documentation of all changes in upgrade reports