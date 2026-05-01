# Classify Agent

The classify agent reads GitHub issues and assigns each one to the most appropriate [workstream category](workstream-categories.md). It also labels issues filed by non-core-team members as `contributor`.

## Execution modes

The classify agent supports six distinct execution modes. Each mode differs in trigger, scope, screening behavior, and expected runtime.

### 1. Auto-trigger on new issue (production path)

| | |
|---|---|
| **Trigger** | `issues.opened` event via shim dispatch |
| **Mode** | `single` |
| **Input** | One issue number extracted from the webhook payload |
| **What happens** | Agent fetches the single issue, reads its title/body/labels, classifies it, sets the project field, and optionally adds a `contributor` label |
| **Screening** | None — one issue, no batch processing |
| **Expected time** | 30–60 seconds |
| **Status** | Covered — `dispatch-classify` job in shim-workflow.yaml triggers `classify.yml` with `event_type=issues` |

This is the primary production use case. Every new issue gets classified within a minute of creation.

### 2. Batch: unclassified issues

| | |
|---|---|
| **Trigger** | `workflow_dispatch` via GitHub Actions UI or `gh workflow run` |
| **Mode** | `unclassified` |
| **Input** | Pre-script queries the GitHub Project board to find issues with no Workstream Category value |
| **What happens** | Agent receives the list of unclassified issue numbers, fetches all open issue metadata, screens by title/labels, fetches full bodies for candidates, classifies them |
| **Screening** | Yes — title/label screening reduces `gh issue view` calls to stay within the 15-minute timeout |
| **Expected time** | 5–15 minutes depending on the number of unclassified issues |
| **Status** | Covered |

Use this after merging the classify agent to backfill existing issues, or periodically to catch any that slipped through.

**Note:** In cross-org testing (e.g., running from `ascerra-fullsend-lab` against `fullsend-ai/fullsend`), the pre-script cannot query the source org's project board and treats all open issues as unclassified.

### 3. Batch: unclassified with category filter

| | |
|---|---|
| **Trigger** | `workflow_dispatch` with `filter_category` set |
| **Mode** | `unclassified` |
| **Input** | Same as mode 2, plus a category filter string |
| **What happens** | Same as mode 2, but the agent may only assign the specified category. Issues that don't match get `workstream_category: null`. |
| **Screening** | Yes — even more aggressive since the agent skips issues whose title/labels are clearly unrelated to the filtered category |
| **Expected time** | 3–8 minutes (fewer candidates than unfiltered batch) |
| **Status** | Covered |

Use this when a workstream lead wants to populate their category across the backlog, or when a new category is added and needs to be retroactively applied.

### 4. Batch: all open issues

| | |
|---|---|
| **Trigger** | `workflow_dispatch` with `classify_mode=all` |
| **Mode** | `all` |
| **Input** | Pre-script sends every open issue number to the agent |
| **What happens** | Agent evaluates all open issues. Still screens by title/labels to stay within the time budget. |
| **Screening** | Yes — required to avoid the 15-minute timeout at scale (228+ issues would take ~21 minutes without screening) |
| **Expected time** | 10–15 minutes |
| **Status** | Covered |

Use this for a complete re-classification, e.g., after significantly updating the category descriptions. **Use with caution in live mode** — this will overwrite existing classifications.

### 5. Manual: single specific issue

| | |
|---|---|
| **Trigger** | `workflow_dispatch` with `classify_mode=single` and `issue_number` set |
| **Mode** | `single` |
| **Input** | One issue number provided by the operator |
| **What happens** | Identical to the auto-trigger path, but manually initiated |
| **Screening** | None |
| **Expected time** | 30–60 seconds |
| **Status** | Covered |

### 6. Local execution

| | |
|---|---|
| **Trigger** | `fullsend run classify` CLI command |
| **Mode** | Any (`single`, `unclassified`, `all`) |
| **Input** | Configured via `.env.classify` environment variables |
| **What happens** | Same agent logic runs locally in a sandbox |
| **Screening** | Same as CI — depends on mode |
| **Expected time** | Same as CI equivalents |
| **Status** | Covered |

```bash
# Single issue
CLASSIFY_MODE=single CLASSIFY_ISSUE_NUMBER=42 fullsend run classify

# All unclassified, filter to one category
CLASSIFY_MODE=unclassified CLASSIFY_FILTER_CATEGORY="New agent capability" fullsend run classify

# All issues (re-classify everything)
CLASSIFY_MODE=all fullsend run classify
```

## Why screening exists

Screening is the agent's strategy for staying within the 15-minute harness timeout during batch runs. The agent:

1. Fetches all open issue **metadata** in one API call (`gh issue list` — fast, returns titles/labels/authors)
2. Uses title and label signals to identify **candidates** worth a deeper look
3. Fetches full **bodies and comments** for candidates (`gh issue view` with `comments` field — one API call per issue, ~1s each)
4. Classifies based on title + body + comments + labels

Without screening, evaluating all 228 open issues would require ~228 individual API calls plus LLM reasoning time — roughly 21 minutes, exceeding the timeout.

**Screening is NOT needed for single-issue mode.** When the agent classifies one issue (modes 1 and 5), it fetches that issue directly with no screening step.

## Screening accuracy

The current screening is done by the LLM inside the agent. It can make mistakes:

- **False negatives:** An issue whose title is misleading gets screened out when it should have been evaluated. The category descriptions in `workstream-categories.md` include "signal keywords" to help with this.
- **False positives:** An issue passes screening but doesn't actually match any category. This is harmless — the agent evaluates it and sets `workstream_category: null`.

Using `filter_category` (mode 3) improves screening accuracy because the agent only needs to decide "could this be X?" rather than "which of 9 categories might this be?"

## Dry run

All modes support `dry_run=true` (CI) or `CLASSIFY_DRY_RUN=true` (local). In dry-run mode:

- The agent runs identically (same API calls, same LLM evaluation)
- No labels are added, no project fields are set
- The post-script produces a full report showing what *would* have been done
- The report and agent transcript are saved as GitHub Actions artifacts

## Configuration reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `CLASSIFY_SOURCE_REPO` | Yes | `$ORG/fullsend` | owner/repo to classify |
| `CLASSIFY_MODE` | Yes | `unclassified` | `single`, `unclassified`, or `all` |
| `CLASSIFY_ISSUE_NUMBER` | single mode | — | Issue number for single mode |
| `CLASSIFY_DRY_RUN` | No | `false` | Skip all writes |
| `CLASSIFY_MIN_CONFIDENCE` | No | `0.7` | Minimum confidence to assign a category |
| `CLASSIFY_FILTER_CATEGORY` | No | — | Restrict to a single category |
| `CLASSIFY_CATEGORIES_PATH` | No | `docs/workstream-categories.md` | Path to the categories document |
| `CLASSIFY_CORE_TEAM` | Yes | — | Comma-separated GitHub usernames |
| `CLASSIFY_PROJECT_NUMBER` | No | `1` | GitHub Project number |
| `CLASSIFY_FIELD_NAME` | No | `Workstream Category` | Project field name |

## Architecture

```
Enrolled repo (fullsend-ai/fullsend)
  └─ issues.opened event
      └─ shim-workflow.yaml  →  dispatch-classify job
          └─ gh workflow run classify.yml (in .fullsend repo)

.fullsend repo ($ORG/.fullsend)
  └─ classify.yml workflow
      ├─ Determine parameters
      ├─ Validate enrollment
      ├─ Generate app token
      ├─ GCP auth (Vertex AI)
      ├─ pre-classify.sh  (host: fetch issues, discover project metadata)
      ├─ fullsend action
      │   ├─ SCP host_files into sandbox
      │   ├─ Agent (classify.md) runs inside sandbox
      │   │   ├─ Load workstream-categories.md
      │   │   ├─ Fetch issue list
      │   │   ├─ Screen candidates (batch modes only)
      │   │   ├─ Fetch candidate bodies
      │   │   ├─ Classify each issue
      │   │   └─ Write agent-result.json
      │   ├─ Validate output against schema
      │   └─ Redact secrets from transcript
      └─ post-classify.sh (host: apply labels, set project fields, write report)
```

## Open items

- [ ] The `workstream-categories.md` document must exist in the `.fullsend` repo's `docs/` directory (added to harness `host_files`). It is NOT yet on `fullsend-ai/fullsend` main branch.
- [ ] Framework-level improvement: inject `GH_TOKEN` via environment instead of `.env.d/` files to prevent potential transcript leakage (affects all agents, not just classify).
- [ ] Consider increasing the harness timeout for `all` mode, or implementing pagination in the agent to handle repos with 500+ issues.
- [ ] The `issues.edited` event is not currently a trigger. If an issue's title or body changes significantly, it won't be re-classified automatically.
