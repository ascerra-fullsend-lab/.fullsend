# GitHub Issue Classify Agent (gh-classify)

The gh-classify agent reads GitHub issues and assigns each one to the most appropriate category defined by the organization's categories document. It also labels issues filed by non-core-team members as `contributor`.

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
# Required: who is core team (comma-separated GitHub usernames)
gh variable set FULLSEND_GH_CLASSIFY_CORE_TEAM --repo YOUR-ORG/.fullsend --body "user1,user2,user3"

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
| **What happens** | Agent fetches the single issue, classifies it, sets the project field, and optionally adds a `contributor` label |
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
- No labels are added, no project fields are set
- The post-script produces a full report showing what *would* have been done
- The report and agent transcript are saved as GitHub Actions artifacts

## Configuration reference

### GitHub Actions variables (set on `.fullsend` repo)

| Variable | Required | Description |
|----------|----------|-------------|
| `FULLSEND_GH_CLASSIFY_CORE_TEAM` | Yes | Comma-separated GitHub usernames of core team |
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
| `CLASSIFY_CATEGORIES_PATH` | `categories.md` | Path to the categories document |

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
      │   │   ├─ Fetch issue list
      │   │   ├─ Screen candidates (batch modes only)
      │   │   ├─ Fetch candidate bodies + comments
      │   │   ├─ Classify each issue
      │   │   └─ Write agent-result.json
      │   ├─ Validate output against schema
      │   └─ Redact secrets from transcript
      └─ post-gh-classify.sh (host: apply labels, set project fields, write report)
```

## Open items

- [ ] Framework-level improvement: inject `GH_TOKEN` via environment instead of `.env.d/` files to prevent potential transcript leakage (affects all agents, not just gh-classify).
- [ ] Consider increasing the harness timeout for `all` mode, or implementing pagination in the agent to handle repos with 500+ issues.
- [ ] The `issues.edited` event is not currently a trigger. If an issue's title or body changes significantly, it won't be re-classified automatically.
