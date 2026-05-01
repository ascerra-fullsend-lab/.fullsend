# GitHub Issue Classify Agent (gh-classify)

The gh-classify agent reads GitHub issues and assigns each one to the most appropriate category defined by the organization's categories document.

This agent is **optional** — it is not included in the default `fullsend admin install` role set. Organizations opt in by adding `gh-classify` to their `--agents` list during installation.

> **GitHub-only:** This agent classifies GitHub Issues using the GitHub API. It does not support Jira, Linear, or other issue trackers.

## Setup for your organization

Before using gh-classify, your organization needs:

1. **A categories document** — a Markdown file describing your classification categories. See [Writing a categories document](#writing-a-categories-document) below.
2. **A GitHub Project (V2)** with a single-select custom field whose options match your category names exactly.
3. **Configuration variables** set on your `.fullsend` repo (see [Configuration reference](#configuration-reference)).

### Installation

```bash
fullsend admin install --agents fullsend,triage,coder,review,gh-classify
```

Then set the required variables:

```bash
# Required: path to your categories doc (relative to .fullsend repo root)
gh variable set FULLSEND_GH_CLASSIFY_CATEGORIES_PATH --repo YOUR-ORG/.fullsend --body "docs/categories.md"

# Required: GitHub Project number containing the classification field
gh variable set FULLSEND_GH_CLASSIFY_PROJECT_NUMBER --repo YOUR-ORG/.fullsend --body "1"

# Required: name of the single-select field on the project board
gh variable set FULLSEND_GH_CLASSIFY_FIELD_NAME --repo YOUR-ORG/.fullsend --body "Category"

# Optional: PAT with org project read access (needed if .fullsend repo is in a different org)
gh secret set FULLSEND_GH_CLASSIFY_PROJECT_PAT --repo YOUR-ORG/.fullsend
```

### Writing a categories document

Create a Markdown file in your `.fullsend` repo (e.g., `docs/categories.md`) with one section per category. Each section should include:

- **Category name** — the exact string that will appear as a project field option
- **Description** — what belongs in this category
- **Exclusions** — what does NOT belong (helps the agent avoid misclassification)
- **Signal keywords** — terms that suggest an issue may belong here

Example structure:

```markdown
# Categories

## Bug fixes
Issues reporting broken functionality in existing features.
Signal keywords: crash, regression, error, broken, fix, doesn't work.
Does NOT belong: feature requests, enhancement proposals, documentation typos.

## New features
Proposals for entirely new capabilities not yet in the product.
Signal keywords: proposal, RFC, new, add support for, implement.
Does NOT belong: improvements to existing features (see Enhancements).
```

The agent reads this document at runtime and uses the category names as the only valid classification values.

## Execution modes

### 1. Auto-trigger on new issue (production path)

| | |
|---|---|
| **Trigger** | `issues.opened` event via shim dispatch |
| **Mode** | `single` |
| **What happens** | Agent fetches the single issue, classifies it, and sets the project field |
| **Screening** | None — one issue, no batch processing |
| **Expected time** | 30–60 seconds |

### 2. Batch: unclassified issues

| | |
|---|---|
| **Trigger** | `workflow_dispatch` via GitHub Actions UI or `gh workflow run` |
| **Mode** | `unclassified` |
| **What happens** | Pre-script queries the GitHub Project to find issues with no category value, then the agent classifies them |
| **Screening** | Yes — title/label screening reduces API calls to stay within the 15-minute timeout |
| **Expected time** | 5–15 minutes depending on issue count |

### 3. Batch: unclassified with category filter

| | |
|---|---|
| **Trigger** | `workflow_dispatch` with `filter_category` set |
| **Mode** | `unclassified` |
| **What happens** | Same as mode 2, but the agent may only assign the specified category |
| **Expected time** | 3–8 minutes (fewer candidates) |

### 4. Batch: all open issues

| | |
|---|---|
| **Trigger** | `workflow_dispatch` with `classify_mode=all` |
| **Mode** | `all` |
| **What happens** | Agent evaluates all open issues. **Use with caution** — this overwrites existing classifications. |
| **Expected time** | 10–15 minutes |

### 5. Manual: single specific issue

| | |
|---|---|
| **Trigger** | `workflow_dispatch` with `classify_mode=single` and `issue_number` set |
| **Mode** | `single` |
| **Expected time** | 30–60 seconds |

### 6. Local execution

```bash
# Single issue
CLASSIFY_MODE=single CLASSIFY_ISSUE_NUMBER=42 fullsend run gh-classify

# All unclassified, filter to one category
CLASSIFY_MODE=unclassified CLASSIFY_FILTER_CATEGORY="Bug fixes" fullsend run gh-classify

# All issues (re-classify everything)
CLASSIFY_MODE=all fullsend run gh-classify
```

## Dry run

All modes support `dry_run=true`. In dry-run mode:

- The agent runs identically (same API calls, same LLM evaluation)
- No project fields are set
- The post-script produces a full report showing what *would* have been done
- The report and agent transcript are saved as GitHub Actions artifacts

## How to trigger

Every variation can be triggered from the **GitHub Actions UI** or the **`gh` CLI**. Replace `YOUR-ORG/.fullsend` with your `.fullsend` repo.

### Workflow input fields

When you click **Actions > GitHub Issue Classify > Run workflow**, you see 9 input fields. Here is what each one does and how to fill it in.

#### 1. Event source (`event_type`)

How this workflow was triggered. The shim sets this to `issues` when auto-dispatching on new issue creation.

| Value | When to use |
|-------|-------------|
| `manual` | You are clicking "Run workflow" yourself. **Always use this for manual runs.** |
| `issues` | Set automatically by the shim dispatch. Never set this manually. |

**Example:** Leave as `manual` (the default).

#### 2. Owner/repo to classify (`source_repo`)

The `owner/repo` whose issues you want to classify. This is the target repository, not the `.fullsend` repo.

| Example | When |
|---------|------|
| `fullsend-ai/fullsend` | Classify issues in the fullsend repo |
| `my-org/my-app` | Classify issues in any enrolled repo |
| *(empty)* | Falls back to the first enabled repo in `config.yaml` |

**Example:** `fullsend-ai/fullsend`

#### 3. JSON payload (`event_payload`)

Raw JSON from the shim dispatch containing the issue number and URL. Only used when `event_type=issues`.

| Value | When to use |
|-------|-------------|
| *(empty)* | **Always leave empty for manual runs.** |
| `{"issue":{"number":42},"repository":"owner/repo"}` | Set by the shim automatically. |

**Example:** Leave empty.

#### 4. Classification mode (`classify_mode`)

What set of issues to evaluate.

| Value | What it does | When to use |
|-------|-------------|-------------|
| `unclassified` | Only evaluate issues that don't already have a category on the project board. | Most common. Monthly batch runs, backlog triage. |
| `single` | Evaluate one specific issue (requires `issue_number`). | Re-classify a specific issue, or test with one issue. |
| `all` | Evaluate every open issue, even ones already classified. **Overwrites existing values.** | Full re-classification after changing categories. Use with caution. |

**Example:** `unclassified`

#### 5. Specific issue number (`issue_number`)

Only used when `classify_mode = single`. Enter the issue number (just the number, no `#`).

| Example | When |
|---------|------|
| `42` | Classify or re-classify issue #42 |
| `590` | Classify or re-classify issue #590 |
| *(empty)* | Leave empty for batch modes (`unclassified` or `all`) |

**Example:** Leave empty for batch runs. Enter `590` for single mode.

#### 6. Dry run (`dry_run`)

Whether to actually write changes to the project board.

| Value | What happens |
|-------|-------------|
| `true` | Agent classifies issues but **nothing is written** to GitHub. You get a full report of what *would* happen. Use this first to review before going live. |
| `false` | Agent classifies issues **and sets the project field values** on the board. |

**Example:** `true` for your first run. `false` once you're confident in the results.

#### 7. Minimum confidence threshold (`min_confidence`)

The agent assigns a confidence score (0.0–1.0) to each classification. Issues below this threshold are skipped.

| Value | Effect |
|-------|--------|
| `0.7` | Default. Agent must be at least 70% confident to assign a category. Good balance. |
| `0.5` | More permissive. Assigns more categories but with more borderline calls. |
| `0.9` | Very strict. Only assigns when the agent is highly certain. |

**Example:** `0.7` (the default). Lower to `0.5` if too many issues are getting skipped. Raise to `0.9` if you're seeing incorrect classifications.

#### 8. Only classify into this category (`filter_category`)

Restricts the agent to a single category. Issues that don't match get `null`. Leave empty to classify into all categories.

| Example | When |
|---------|------|
| *(empty)* | Classify into any category from the categories doc |
| `New agent capability` | Only find issues that belong in "New agent capability" |
| `Support - MVP Follow-through` | Only find issues that belong in "Support - MVP Follow-through" |
| `Installer - web/cli` | Only find issues for the installer workstream |

**Example:** Leave empty for a full classification run. Set to your workstream name if you're a workstream lead reviewing just your category.

**Important:** The value must exactly match a category name from your categories document. Typos or abbreviations will result in zero classifications.

#### 9. Screen issues (`screen_issues`)

Whether the agent should pre-filter issues by title and labels before fetching full details.

| Value | What happens | Runtime |
|-------|-------------|---------|
| `true` | Agent reads issue titles first and only fetches full details for plausible candidates. **Faster but may miss edge cases.** | ~5–8 min for ~170 issues |
| `false` | Agent fetches full details (body + comments) for every candidate issue. **Thorough but slower.** | ~9–12 min for ~170 issues |

**Example:** `true` for routine runs. `false` when you want to verify screening isn't missing anything, or when running with a `filter_category` and you want maximum coverage.

### Example: complete UI walkthrough

To dry-run classification of the "New agent capability" category with screening off:

| Field | Value |
|-------|-------|
| Event source | `manual` |
| Owner/repo | `fullsend-ai/fullsend` |
| JSON payload | *(empty)* |
| Classification mode | `unclassified` |
| Specific issue number | *(empty)* |
| Dry run | `true` |
| Minimum confidence | `0.7` |
| Only classify into this category | `New agent capability` |
| Screen issues | `false` |

### CLI equivalents

Every UI run maps to a `gh workflow run` command. The `-f` flags match the field names:

```bash
# Dry-run all unclassified (screening on)
gh workflow run gh-classify.yml --repo YOUR-ORG/.fullsend \
  -f source_repo="fullsend-ai/fullsend" \
  -f classify_mode="unclassified" \
  -f dry_run="true"
```

```bash
# Dry-run single category, no screening
gh workflow run gh-classify.yml --repo YOUR-ORG/.fullsend \
  -f source_repo="fullsend-ai/fullsend" \
  -f classify_mode="unclassified" \
  -f dry_run="true" \
  -f filter_category="New agent capability" \
  -f screen_issues="false"
```

```bash
# Classify a single issue (live)
gh workflow run gh-classify.yml --repo YOUR-ORG/.fullsend \
  -f source_repo="fullsend-ai/fullsend" \
  -f classify_mode="single" \
  -f issue_number="590"
```

```bash
# Live run: classify all unclassified
gh workflow run gh-classify.yml --repo YOUR-ORG/.fullsend \
  -f source_repo="fullsend-ai/fullsend" \
  -f classify_mode="unclassified" \
  -f dry_run="false"
```

```bash
# Live run: re-classify everything (use with caution)
gh workflow run gh-classify.yml --repo YOUR-ORG/.fullsend \
  -f source_repo="fullsend-ai/fullsend" \
  -f classify_mode="all" \
  -f dry_run="false"
```

### Local execution with fullsend CLI

Run from your machine. Source your `.env.gh-classify` first.

```bash
set -a; source .env.gh-classify; set +a

# Dry-run all unclassified
CLASSIFY_DRY_RUN=true fullsend run gh-classify --fullsend-dir /path/to/.fullsend --target-repo .

# Single category, no screening
CLASSIFY_DRY_RUN=true CLASSIFY_FILTER_CATEGORY="Bug fixes" CLASSIFY_SCREEN_ISSUES=false \
  fullsend run gh-classify --fullsend-dir /path/to/.fullsend --target-repo .

# Single issue
CLASSIFY_MODE=single CLASSIFY_ISSUE_NUMBER=42 \
  fullsend run gh-classify --fullsend-dir /path/to/.fullsend --target-repo .
```

### Quick reference table

| Mode | Dry run | Filter | Screening | CLI flags |
|------|---------|--------|-----------|-----------|
| unclassified | yes | — | on | `-f dry_run=true` |
| unclassified | yes | — | off | `-f dry_run=true -f screen_issues=false` |
| unclassified | yes | category | on | `-f dry_run=true -f filter_category="..."` |
| unclassified | yes | category | off | `-f dry_run=true -f filter_category="..." -f screen_issues=false` |
| single | — | — | n/a | `-f classify_mode=single -f issue_number=42` |
| unclassified | no | — | on | `-f dry_run=false` |
| all | no | — | on | `-f classify_mode=all -f dry_run=false` |
| local | — | — | — | `fullsend run gh-classify` |

## Configuration reference

### GitHub Actions variables (set on `.fullsend` repo)

| Variable | Required | Description |
|----------|----------|-------------|
| `FULLSEND_GH_CLASSIFY_CATEGORIES_PATH` | Yes | Path to categories doc (relative to `.fullsend` root) |
| `FULLSEND_GH_CLASSIFY_PROJECT_NUMBER` | Yes | GitHub Project V2 number |
| `FULLSEND_GH_CLASSIFY_FIELD_NAME` | Yes | Name of the single-select classification field |

### GitHub Actions secrets (set on `.fullsend` repo)

| Secret | Required | Description |
|--------|----------|-------------|
| `FULLSEND_GH_CLASSIFY_APP_PRIVATE_KEY` | Yes (auto) | Created by installer |
| `FULLSEND_GH_CLASSIFY_PROJECT_PAT` | Cross-org | PAT with `Organization projects: Read` for cross-org project access |

### Agent env vars (internal, set by workflow)

| Variable | Default | Description |
|----------|---------|-------------|
| `CLASSIFY_SOURCE_REPO` | first enabled repo | owner/repo to classify |
| `CLASSIFY_MODE` | `unclassified` | `single`, `unclassified`, or `all` |
| `CLASSIFY_ISSUE_NUMBER` | — | Issue number for single mode |
| `CLASSIFY_DRY_RUN` | `false` | Skip all writes |
| `CLASSIFY_MIN_CONFIDENCE` | `0.7` | Minimum confidence to assign a category |
| `CLASSIFY_FILTER_CATEGORY` | — | Restrict to a single category |
| `CLASSIFY_SCREEN_ISSUES` | `true` | Screen by title/labels before fetching details |
| `CLASSIFY_CATEGORIES_PATH` | `categories.md` | Path to the categories document |
| `CLASSIFY_PROJECT_NUMBER` | `1` | GitHub Project number for category field lookup |
| `CLASSIFY_FIELD_NAME` | `Workstream Category` | Name of the single-select project field |
| `CLASSIFY_PROJECT_TOKEN` | `GH_TOKEN` | PAT for cross-org project access |

## Architecture

```
Enrolled repo (your-org/your-repo)
  └─ issues.opened event
      └─ shim-workflow.yaml  →  dispatch-gh-classify job
          └─ gh workflow run gh-classify.yml (in .fullsend repo)

.fullsend repo ($ORG/.fullsend)
  └─ gh-classify.yml workflow
      ├─ Determine parameters
      ├─ Validate enrollment
      ├─ Generate app token
      ├─ GCP auth (Vertex AI)
      ├─ pre-gh-classify.sh  (host: fetch issues, discover project metadata)
      ├─ fullsend action
      │   ├─ SCP host_files into sandbox
      │   ├─ Agent (gh-classify.md) runs inside sandbox
      │   │   ├─ Load categories document
      │   │   ├─ Build candidate list (fetch issues, exclude already classified)
      │   │   ├─ Screen candidates (batch modes only, if enabled)
      │   │   ├─ Fetch candidate bodies + comments
      │   │   ├─ Classify each issue
      │   │   └─ Write agent-result.json
      │   ├─ Validate output against schema
      │   └─ Redact secrets from transcript
      └─ post-gh-classify.sh (host: set project fields, write report)
```

## Open items

- [ ] Framework-level improvement: inject `GH_TOKEN` via environment instead of `.env.d/` files to prevent potential transcript leakage (affects all agents, not just gh-classify).
- [ ] Consider increasing the harness timeout for `all` mode, or implementing pagination in the agent to handle repos with 500+ issues.
- [ ] The `issues.edited` event is not currently a trigger. If an issue's title or body changes significantly, it won't be re-classified automatically.
