# SDK Upgrader

Automated Polkadot SDK upgrade tool that uses AI agents to handle breaking changes and migration patterns.

## Overview

The SDK Upgrader automates the complex process of upgrading Polkadot SDK dependencies by:
- Analyzing release notes and PR changes
- Applying known migration patterns
- Fixing compilation errors iteratively
- Updating tests to match new APIs

## How It Works

```mermaid
graph TD
    A[Scout Phase] -->|Gather PR data| B[Resources]
    B --> C[Orchestrator]
    C --> D[Upgrade Dependencies]
    D -->|to NEW_TAG| E{Check Errors}
    E -->|Has errors| F[Group by Symbol]
    
    %% Build Workers
    F --> G1[Build Worker Agent 1<br/>Symbol: foo]
    F --> G2[Build Worker Agent 2<br/>Symbol: bar]
    F --> G3[Build Worker Agent N<br/>Symbol: ...]
    
    %% Error Recovery Handbook - Collaborative Learning
    EH[Error Recovery Handbook<br/>Shared Knowledge Base]
    G1 -.->|reads| EH
    G2 -.->|reads| EH
    G3 -.->|reads| EH
    
    G1 --> H[Apply Fixes]
    G2 --> H
    G3 --> H
    
    H -.->|writes successful fixes| EH
    H --> E
    
    E -->|No errors| I{Run Tests}
    I -->|Failures| J[Group by Module]
    
    %% Test Workers
    J --> K1[Test Worker Agent 1<br/>Module: crate_a]
    J --> K2[Test Worker Agent 2<br/>Module: crate_b]
    J --> K3[Test Worker Agent N<br/>Module: ...]
    
    K1 -.->|reads| EH
    K2 -.->|reads| EH
    K3 -.->|reads| EH
    
    K1 --> L[Fix Tests]
    K2 --> L
    K3 --> L
    
    L -.->|writes successful fixes| EH
    L --> I
    I -->|All pass| M[Complete]
    
    %% Style the handbook
    style EH stroke:#333,stroke-width:2px,stroke-dasharray: 5 5
```

### Key Components

- **Scout**: Downloads PR artifacts and release notes from GitHub
- **Orchestrator**: State machine that manages the upgrade workflow
- **Build Worker**: Fixes compilation errors by symbol groups
- **Tests Worker**: Fixes test failures by module
- **Error Groupers**: Python tools that parse and group errors

### Agent Collaboration

The agents collaborate through shared files that enable learning and knowledge transfer:

- **Error Recovery Handbook** (`prompts/error_recovery_handbook.md`): 
  - Worker agents append successful fixes to this handbook
  - Subsequent agents check this file first for known solutions
  - Contains a "Fixed Errors Database" that grows with each successful fix
  - Format includes: symbol, error message, fix applied, and SDK version

- **Status File** (`output/status.json`):
  - Central coordination file tracking all error groups and test groups
  - Updated by orchestrator and workers to track progress
  - Prevents duplicate work and enables resumption

- **Upgrade Report** (`output/UPGRADE_REPORT_<NEW_TAG>.md`):
  - Build workers document all fixes applied
  - Includes confidence scores and manual review recommendations
  - Shared knowledge base for the upgrade session

## Quick Start

### Prerequisites

- GitHub CLI (`gh`) authenticated
- Claude CLI installed
- Python 3.x
- jq

### Usage

```bash
# Run complete upgrade process
./run.sh polkadot-stable2407 polkadot-stable2410

# Or run phases separately:
# 1. Gather PR data
./tools/scout.sh polkadot-stable2410

# 2. Execute upgrade
./tools/runner.sh polkadot-stable2407 polkadot-stable2410
```

## Directory Structure

```
sdk-upgrader/
├── prompts/          # AI agent configurations
├── tools/            # Scripts and utilities  
├── resources/        # Input data (PR artifacts)
└── output/           # Generated reports
```

### Resources Directory

After running scout, the `resources/` directory contains:

```
resources/
└── polkadot-sdk-<NEW_TAG>/
    ├── release-notes.md         # Official release notes
    ├── polkadot_sdk_dependency_tree.md  # Dependency analysis
    └── pr-<number>/             # For each PR in the release
        ├── description.md       # PR description and migration notes
        └── patch.patch         # Actual code changes
```

### Output Directory

The upgrade process generates these artifacts in `output/`:

```
output/
├── status.json                      # Real-time progress tracking
├── UPGRADE_REPORT_<NEW_TAG>.md      # Main upgrade report with all fixes
├── test_report_<NEW_TAG>.md         # Test fixing details
├── error_summary_<NEW_TAG>.md       # Summary of unfixed compilation errors
└── test_error_summary_<NEW_TAG>.md  # Summary of unfixed test failures
```

**File Descriptions:**
- **status.json**: Tracks error groups, test groups, iterations, and completion status
- **UPGRADE_REPORT**: Documents all applied fixes, migration patterns, and manual interventions needed
- **test_report**: Details test fixes applied and patterns discovered
- **error_summary**: Generated only if max iterations reached with remaining errors
- **test_error_summary**: Generated only if max iterations reached with failing tests

## Beta Status

This tool is in public beta. Please report issues and contribute improvements!