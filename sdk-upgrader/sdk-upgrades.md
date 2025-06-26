# Project: Automating Polkadot SDK Upgrades

This document outlines the strategy and design for a set of tools and AI agents to automate the process of upgrading Substrate-based projects to new Polkadot SDK versions.

## 1. Project Goal

The primary goal is to simplify and eventually automate the time-consuming and complex task of updating a Substrate-based codebase to keep up with Polkadot SDK releases. The project will start by building assistive tools for engineers and evolve towards a fully autonomous system.

## 2. Initial Idea

The initial concept involved a series of steps:

1.  **Static Tooling**: Leverage shell scripts and `git` commands to interact with GitHub. This includes creating patch files from Pull Requests (PRs) and gathering comments.
2.  **Web Scraping**: A tool to crawl a Polkadot SDK release page on GitHub to find all the individual PRs that constitute that release.
3.  **Structured Data**: Organize the gathered information into a directory structure for each release, for example:
    ```
    /polkadot-sdk-2409/
    |-- /pr-001/
    |   |-- description.md
    |   |-- patch.patch
    |   |-- notes.md (optional)
    |-- /pr-002/
    |   ...
    ```
4.  **LLM-based Patching**: An LLM agent would process each PR directory sequentially. It would read the description, notes, and the patch file, and then attempt to apply the changes to the target project's codebase. After each successful application, the agent would commit the changes and move to the next one.

## 3. Proposed Architecture: The "Upgrade Weaver"

While the initial idea is a solid starting point, a more robust and sophisticated architecture is needed to handle the complexities of real-world upgrades. The "Upgrade Weaver" is a multi-stage pipeline designed for this purpose.

The core idea is to move from a simple linear process to a more intelligent, context-aware workflow that analyzes, plans, acts, and verifies.

### Core Principles

*   **Rich Context**: Rely on comprehensive data, not just git diffs. This includes release notes, PR metadata (descriptions, comments, labels), and the code itself.
*   **Analysis Before Action**: Understand the nature of changes before applying them.
*   **Hybrid Approach**: Use deterministic tools for simple, clear-cut changes and leverage LLMs for complex, fuzzy tasks like conflict resolution.
*   **Continuous Verification**: Build a tight feedback loop by compiling and testing after changes to catch errors early.
*   **Assistance First**: The initial output should be a detailed report for engineers, making the tool immediately useful even before full automation.

### The Stages

#### Stage 1: Information Gatherer ("The Scout")

*   **Input**: A Polkadot SDK release tag (e.g., `polkadot-stable2409`).
*   **Process**:
    1.  Use the GitHub API (not scraping) to fetch the release notes for the given tag.
    2.  Parse the release notes to identify all constituent PRs.
    3.  For each PR, fetch its metadata: title, description, labels, comments, and the diff/patch file.
*   **Output**: A structured directory containing all the gathered information, as outlined in the initial idea. This provides a comprehensive, local dataset for the subsequent stages.

#### Stage 2: Change Analyzer ("The Oracle")

*   **Input**: The data structure created by the Scout.
*   **Process**:
    1.  Iterate through each PR's data.
    2.  **Classify PRs**: Use a combination of heuristics (e.g., file paths, labels like `B-release-notes`) and an LLM to categorize each PR. Categories could include:
        *   `Runtime-Breaking`
        *   `Node-Breaking`
        *   `API-Change`
        *   `Dependency-Update`
        *   `Documentation`
        *   `Low-Risk`
    3.  **Generate Upgrade Plan**: Based on the classifications, create a strategic plan for applying the changes. This plan will define the order of application and highlight high-risk changes that require special attention.
*   **Output**: An `upgrade-plan.json` or `upgrade-plan.md` file that details the proposed sequence of operations and risk assessment for each step.

#### Stage 3: Patch Applicator ("The Weaver")

*   **Input**: The upgrade plan and the gathered data.
*   **Process**:
    1.  Execute the upgrade plan step-by-step.
    2.  For each PR, attempt to apply the change using a hybrid strategy:
        *   **Deterministic Patching**: For simple, clean patches (`git apply`).
        *   **LLM-assisted Patching**: If `git apply` fails due to conflicts, invoke an LLM. The LLM will be given the original file, the patch file, and the PR description to intelligently resolve the conflict.
*   **Output**: A modified codebase with the changes applied, ready for verification.

#### Stage 4: Verification & Debugging ("The Auditor")

*   **Input**: The modified codebase.
*   **Process**:
    1.  After each significant change (or at the end of the process), trigger a build/compilation (`cargo check`, `cargo build`).
    2.  If the build fails, capture the compiler errors.
    3.  **Debugging Loop**: Feed the compiler errors and the relevant code snippet back to an LLM to attempt to fix the issue.
*   **Output**:
    *   **Success**: A compiled, upgraded branch of the target project.
    *   **Failure/Assistance Mode**: A detailed report that includes:
        *   Successfully applied changes.
        *   A list of conflicts that could not be resolved.
        *   Compilation errors that could not be fixed.
        *   A clear to-do list for the human engineer.

## 4. Initial Implementation Plan

We will start by building **Stage 1: Information Gatherer (the "Scout")**.

This will involve creating a script that:
1.  Takes a Polkadot SDK release tag as input.
2.  Uses the GitHub API to fetch release information.
3.  Creates the structured directory output.

We will begin by creating a `README.md` for the project and a `tools/` directory to house our scripts. 