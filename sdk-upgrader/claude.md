# SDK Upgrader - LLM Navigation Guide (v2)

## Project Mission
Automated Polkadot SDK upgrade tool that uses AI agents to handle breaking changes and migration patterns between SDK versions. The v2 architecture introduces a Finite State Machine (FSM) approach with Claude Code's native FSM command, enhanced MCP tool support, and improved error handling with circuit breaker patterns.

## Evolution: v1 → v2

### v1 Architecture (Legacy)
- YAML-based orchestrator with state machine in Python
- Separate build_worker.yaml and tests_worker.yaml prompts
- Sequential agent execution via runner.sh
- Basic error grouping and recovery

### v2 Architecture (Current)
- **FSM-based orchestration** using Claude's `/fsm` command
- **Simplified agent structure** with @-notation agents
- **Circuit breaker pattern** for loop detection
- **MCP tools integration** for semantic code understanding
- **Unified error grouping** with improved Rust version detection
- **Flexible agent inputs** supporting natural language and JSON

## Core Architecture

### Multi-Agent System (v2)
- **FSM Orchestrator** (`v2/runner.sh`): Uses Claude's `/fsm` command to orchestrate the entire upgrade workflow
- **@polkadot-bug-fixer** (AI agent): Fixes compilation errors with flexible input handling
- **@polkadot-tests-fixer** (AI agent): Fixes test failures with improved pattern matching
- **Unified Error Grouper** (`tools/unified_error_grouper.py`): Enhanced parser for both cargo check (JSON) and cargo test (text) outputs
- **MCP Tools** (Optional): Semantic code analysis tools for deeper understanding

## The Upgrade Workflow: Step-by-Step Guide

### v1 Workflow (Legacy - Still Supported)
The original workflow uses `run.sh` → `scout.sh` → `runner.sh` with YAML-based orchestration.

### v2 Workflow (Recommended)

#### Entry Point
```bash
# v2 FSM-based upgrade
./sdk-upgrader/v2/runner.sh polkadot-stable2407 polkadot-stable2410

# v1 traditional upgrade (still works)
./sdk-upgrader/run.sh polkadot-stable2407 polkadot-stable2410
```

### Phase 0: Setup
- **v1**: `run.sh` sets up environment, calls scout and runner
- **v2**: `v2/runner.sh` validates prerequisites, prepares FSM prompt

### Phase 1: Scouting (Same for v1 and v2)
- **Goal**: Gather intelligence about target SDK version
- **Script**: `tools/scout.sh`
- **Actions**: Downloads PR artifacts and release notes from GitHub
- **Key Artifacts**: Stores in `resources/polkadot-sdk-<NEW_TAG>/`
  - `release-notes.md`: Official release notes
  - `pr-*/description.md`: Migration guidance from each PR
  - `pr-*/patch.diff`: Actual code changes for reference

### Phase 2: Execution

#### v2 FSM-Based Execution
1. **FSM Initialization**: 
   - `v2/runner.sh` generates FSM prompt from `v2/upgrader.md` template
   - Invokes Claude with `/fsm` command
   - FSM manages entire workflow autonomously

2. **State Machine Flow**:
   ```
   INIT → UPDATE_DEPS → CHECK_ERRORS → GROUP_ERRORS → SPAWN_AGENTS → VALIDATE → COMPLETE
                ↑                                           ↓
                └─────────────── RETRY ←──────────────────┘
   ```

3. **Agent Spawning**:
   - FSM spawns `@polkadot-bug-fixer` for compilation errors
   - FSM spawns `@polkadot-tests-fixer` for test failures
   - Agents accept flexible inputs:
     - Natural language: "fix xcm errors"
     - JSON: `{"file": "xcm.rs", "error_code": "E0308"}`

4. **Loop Detection & Circuit Breaker**:
   - Claude Code hooks monitor cargo check invocations
   - Circuit breaker triggers after 5 identical errors
   - Agent exits gracefully with status code 99
   - Orchestrator handles exit and can restart with fresh context

5. **Validation & Recovery**:
   - Git checkpoints before each fix
   - Commit on success, revert on failure
   - Maximum 2 retries per agent
   - Oscillation detection via state history

#### v1 Traditional Execution
- Uses `tools/runner.sh` with Python orchestrator
- YAML-based agent prompts (`prompts/build_worker.yaml`, `prompts/tests_worker.yaml`)
- Sequential processing with status.json coordination

## File & Directory Quick Reference

### Core Files
| Path | Purpose | When to check this file |
| :--- | :--- | :--- |
| **v2 Architecture** | | |
| `v2/runner.sh` | **v2 Entry Point**. FSM-based orchestration | Starting v2 upgrades or understanding FSM flow |
| `v2/upgrader.md` | FSM prompt template with variable substitution | Modifying FSM behavior or state transitions |
| `v2/agents/polkadot-bug-fixer.md` | Bug fixer agent with flexible input handling | Improving compilation error fixes |
| `v2/agents/polkadot-tests-fixer.md` | Test fixer agent specification | Improving test failure fixes |
| **v1 Architecture (Legacy)** | | |
| `run.sh` | **v1 Entry Point**. Traditional orchestration | Running v1 upgrades |
| `tools/runner.sh` | v1 Python-based orchestrator | Understanding v1 workflow |
| `prompts/orchestrator.yaml` | v1 state machine definition | Modifying v1 phases |
| `prompts/build_worker.yaml` | v1 build worker instructions | v1 build fixes |
| `prompts/tests_worker.yaml` | v1 test worker instructions | v1 test fixes |
| **Shared Components** | | |
| `tools/scout.sh` | **Scout Script**. Downloads PR artifacts | Both v1 and v2 use this |
| `tools/unified_error_grouper.py` | **Enhanced Error Parser**. Groups errors/tests | Improving error detection |
| `prompts/error_recovery_handbook.md` | **Knowledge Base**. Growing fix database | Adding/checking solutions |
| `resources/` | Scout artifacts and PR information | SDK change analysis |
| `output/status.json` | Progress tracking (v1) or FSM state (v2) | Debugging current state |
| `output/UPGRADE_REPORT_*.md` | Fix documentation | Review changes made |

### New Features Documentation
| Path | Purpose | When to check this file |
| :--- | :--- | :--- |
| `cargo_check_loop_detection_plan.md` | Circuit breaker implementation guide | Setting up loop detection |
| `docs/mcp-tools-recommendations.md` | MCP tools for semantic analysis | Enhancing agent capabilities |
| `.claude/settings.local.json` | Claude Code hook configuration | Configuring circuit breaker |
| `.claude/hooks/cargo_check_monitor.sh` | Loop detection script | Debugging loop detection |

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

### Error Grouping Strategy (Enhanced in v2)
- **Unified Error Grouper** handles both cargo check JSON and cargo test text
- **Rust Version Detection**: Special handling for Rust version incompatibilities
- Groups by primary symbol with max 5 errors per group
- Processes high-impact symbols first
- Better pattern extraction for complex trait errors

### Agent Execution Models

#### v2 FSM Model
- **Autonomous FSM** orchestrates entire workflow
- **Flexible agent inputs**: Natural language or structured JSON
- **Parallel validation**: Can spawn multiple agents
- **State tracking**: FSM maintains workflow state
- **Circuit breaker**: Prevents infinite loops

#### v1 Sequential Model
- One agent at a time to prevent conflicts
- Python orchestrator manages queue
- Status.json for coordination

### Loop Detection & Circuit Breaker (New in v2)
- **Hook-based monitoring**: Tracks cargo check invocations
- **Error hash comparison**: Detects repeated identical errors
- **Graceful shutdown**: Exit code 99 for circuit breaker
- **Configurable threshold**: Default 5 identical errors
- **State preservation**: Debugging artifacts retained
- Pattern:
  ```bash
  # Circuit breaker triggers when:
  cargo check → same errors → cargo check → same errors (5x)
  # Result: Agent exits with code 99
  ```

### Collaborative Learning (Enhanced)
- **Mandatory handbook updates**: v2 agents MUST update handbook
- **Structured entries**: JSON format for better parsing
- **Confidence tracking**: Each fix has confidence score
- **Scout PR references**: Links fixes to SDK changes
- **Version-specific sections**: Clear SDK version marking

### MCP Tools Integration (New)
- **rust-analyzer-mcp**: Semantic code understanding
- **cargo-expand-mcp**: Macro expansion for FRAME debugging
- **rustc-json-mcp**: Structured error parsing
- **cargo-semver-mcp**: Breaking change detection
- **substrate-analyzer-mcp**: FRAME-specific patterns
- Priority: Use MCP tools when available for better accuracy

### Safety Mechanisms (Improved)
- **Git checkpointing**: Before each fix attempt
- **Atomic commits**: Group related changes
- **Revert on failure**: Automatic rollback
- **Max retries**: 2 attempts per agent (v2) vs 40 iterations (v1)
- **Oscillation detection**: Last 10 states tracked
- **Exit strategies**: Multiple terminal states for different failures

### Docker Environment
- `docker/` contains containerized setup
- Includes all dependencies and MCP tools
- Consistent environment for CI/CD
- See `docker/README.md` for setup

## Common Pitfalls & Solutions

### Known Issues
1. **base64ct version conflicts**: Always check Error Recovery Handbook's mandatory fixes first
2. **Trait reorganization**: Many traits moved between modules - check PR descriptions
3. **Method renames**: Common in SDK upgrades - scout artifacts contain mappings
4. **Test assertions**: Often need updates due to behavior changes - check release notes
5. **Cargo check loops**: v2 circuit breaker prevents infinite loops (exit code 99)
6. **Rust version errors**: Unified grouper now detects and groups these specially

### v2-Specific Solutions
1. **Natural language confusion**: Be specific ("fix xcm errors" not "fix errors")
2. **Circuit breaker triggers**: Check `/tmp/agent_*_circuit_breaker` for details
3. **FSM stuck states**: Check `output/status.json` for current FSM state
4. **Agent failures**: FSM retries twice before marking as failed

### Debugging Tips
1. **v2 FSM issues**: Add `--verbose` flag to see detailed FSM execution
2. **Agent communication**: Check stderr for agent logs (stdout is JSON only)
3. **MCP tool failures**: Verify tools installed with `which *-mcp` commands
4. **Hook issues**: Check `.claude/settings.local.json` configuration

## Success Metrics

### Primary Metrics
- ✅ All compilation errors resolved
- ✅ All tests passing  
- ✅ Zero manual intervention (fully autonomous)
- ✅ Complete upgrade report generated

### v2 Enhanced Metrics
- 📊 Confidence scores > 0.8 for majority of fixes
- 🔄 No circuit breaker triggers (no infinite loops)
- 📚 All fixes added to error recovery handbook
- ⚡ Reduced iterations vs v1 (target: <20 vs 40)
- 🎯 Higher first-attempt success rate with MCP tools

### Quality Indicators
- Git history shows atomic, well-described commits
- No oscillating fixes (state history clean)
- Handbook grows with each upgrade
- Upgrade reproducible from clean state

## Architecture Decision Records

### Why v2?
The v2 architecture addresses key limitations of v1:
- **Problem**: Complex YAML state machines were hard to debug
- **Solution**: FSM command provides native state machine support
- **Problem**: Rigid error descriptions limited agent effectiveness  
- **Solution**: Flexible natural language and JSON inputs
- **Problem**: Agents could get stuck in cargo check loops
- **Solution**: Circuit breaker pattern with graceful shutdown
- **Problem**: Limited code understanding from text matching
- **Solution**: MCP tools for semantic analysis

### Design Principles
1. **Simplicity**: Fewer moving parts, clearer flow
2. **Flexibility**: Multiple input formats, adaptable agents
3. **Resilience**: Circuit breakers, state tracking, recovery
4. **Intelligence**: Semantic understanding via MCP tools
5. **Learning**: Mandatory handbook updates, confidence tracking

## Migration Guide: v1 → v2

### For Users
```bash
# Instead of:
./sdk-upgrader/run.sh old-tag new-tag

# Use:
./sdk-upgrader/v2/runner.sh old-tag new-tag
```

### For Developers
1. **Agent Development**: Create markdown files in `v2/agents/` with tool lists
2. **FSM Modifications**: Edit `v2/upgrader.md` template
3. **Hook Setup**: Configure `.claude/settings.local.json` for monitoring
4. **MCP Tools**: Install tools from `docs/mcp-tools-recommendations.md`

### Compatibility
- v1 and v2 can coexist in the same repository
- Both use the same scout artifacts and handbook
- `output/status.json` format differs between versions
- Error recovery handbook works with both versions

## Continuous Improvement Directive

### When to Update CLAUDE.md
**IMPORTANT**: This documentation should be updated whenever:
1. **New architectural decisions** are made (v2 → v3?)
2. **Circuit breaker thresholds** need adjustment based on experience
3. **MCP tools** are added or improved
4. **FSM states** are modified or extended
5. **Agent capabilities** are enhanced
6. **Performance metrics** show new patterns
7. **User feedback** reveals workflow improvements

### How to Update
- Document architectural decisions with rationale
- Include performance comparisons (v1 vs v2)
- Add troubleshooting sections for new issues
- Update examples with real-world scenarios
- Mark deprecated features clearly
- Maintain both v1 and v2 documentation until v1 sunset
- Print **CLAUDE.MD UPDATED 🚀** after updates

### Metrics to Track
- Average iterations to completion (v1 vs v2)
- Circuit breaker trigger frequency
- MCP tool usage and impact
- Handbook growth rate
- Agent confidence scores
- Time to successful upgrade

### Future Enhancements Under Consideration
1. **Parallel agent execution** for independent error groups
2. **Incremental compilation** to reduce validation time
3. **ML-based fix prediction** from handbook patterns
4. **Automated PR creation** with upgrade changes
5. **Multi-version upgrades** (e.g., 2407 → 2408 → 2409 → 2410)
6. **Confidence-based commit strategies** (high confidence = auto-commit)