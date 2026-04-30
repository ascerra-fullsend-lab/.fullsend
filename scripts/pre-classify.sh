#!/usr/bin/env bash
# pre-classify.sh — Prepare metadata for the classify agent's post-script.
#
# Runs on the host via the harness pre_script mechanism. Determines which
# issues to classify and discovers GitHub Project metadata needed by the
# post-script. All output goes to /tmp/workspace/context/ (host-side only;
# the agent sandbox does NOT see these files).
#
# Required env vars:
#   GH_TOKEN              — GitHub token with issues:read, contents:read scope
#   CLASSIFY_SOURCE_REPO  — owner/repo to classify issues in
#   CLASSIFY_MODE         — "single" | "unclassified" | "all"
#   CLASSIFY_ISSUE_NUMBER — (single mode) specific issue number to classify
#   CLASSIFY_CORE_TEAM    — comma-separated core team usernames
#   CLASSIFY_PROJECT_NUMBER — GitHub Project number for the org
#   CLASSIFY_FIELD_NAME   — name of the Workstream Category field in the project
#
# SECURITY: This script runs in public CI logs. Never log tokens, credentials,
# or issue bodies (which may contain sensitive content from private repos).

set -euo pipefail

CONTEXT_DIR="/tmp/workspace/context"
mkdir -p "${CONTEXT_DIR}"

# --- Mask sensitive values ---
# ::add-mask:: only works in GitHub Actions; skip locally to avoid printing tokens.
if [[ -n "${GH_TOKEN:-}" && "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "::add-mask::${GH_TOKEN}"
fi

# Log mode info (::notice:: only renders in GitHub Actions).
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
  echo "::notice::Classify agent — mode=${CLASSIFY_MODE}, repo=${CLASSIFY_SOURCE_REPO}"
  echo "::notice::All issue fetches are scoped exclusively to ${CLASSIFY_SOURCE_REPO}"
else
  echo "Classify agent — mode=${CLASSIFY_MODE}, repo=${CLASSIFY_SOURCE_REPO}"
fi

# Validate required vars.
if [[ -z "${CLASSIFY_SOURCE_REPO:-}" ]]; then
  echo "ERROR: CLASSIFY_SOURCE_REPO is required"
  exit 1
fi
if [[ ! "${CLASSIFY_SOURCE_REPO}" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
  echo "ERROR: CLASSIFY_SOURCE_REPO format invalid"
  exit 1
fi

ORG="${CLASSIFY_SOURCE_REPO%%/*}"

# --- Fetch all open issues (metadata only, used to determine unclassified set) ---
# gh handles pagination internally; --limit sets the max results.
echo "Fetching open issues from ${CLASSIFY_SOURCE_REPO}..."
gh issue list --repo "${CLASSIFY_SOURCE_REPO}" --state open \
  --json number,title,labels,author,createdAt --limit 5000 \
  > "${CONTEXT_DIR}/open-issues.json"
ISSUE_COUNT=$(jq length "${CONTEXT_DIR}/open-issues.json")
echo "✓ ${ISSUE_COUNT} open issues fetched"

# --- Determine which issues to classify ---
ISSUE_NUMBERS_FILE="${CONTEXT_DIR}/issue-numbers.txt"

case "${CLASSIFY_MODE}" in
  single)
    if [[ -z "${CLASSIFY_ISSUE_NUMBER:-}" ]]; then
      echo "ERROR: CLASSIFY_ISSUE_NUMBER required in single mode"
      exit 1
    fi
    if [[ ! "${CLASSIFY_ISSUE_NUMBER}" =~ ^[0-9]+$ ]]; then
      echo "ERROR: CLASSIFY_ISSUE_NUMBER must be a positive integer"
      exit 1
    fi
    echo "${CLASSIFY_ISSUE_NUMBER}" > "${ISSUE_NUMBERS_FILE}"
    echo "✓ Single issue mode: #${CLASSIFY_ISSUE_NUMBER}"
    ;;

  unclassified)
    echo "Discovering unclassified issues via GitHub Project..."
    PROJECT_NUMBER="${CLASSIFY_PROJECT_NUMBER:-1}"
    FIELD_NAME="${CLASSIFY_FIELD_NAME:-Workstream Category}"

    ALL_ISSUE_NUMBERS=$(jq -r '.[].number' "${CONTEXT_DIR}/open-issues.json")

    # Validate FIELD_NAME: alphanumeric, spaces, hyphens, commas only.
    if [[ ! "${FIELD_NAME}" =~ ^[a-zA-Z0-9\ ,._-]+$ ]]; then
      echo "ERROR: CLASSIFY_FIELD_NAME contains disallowed characters"
      exit 1
    fi

    # Page through ALL project items (100 per page).
    # Timeout each GraphQL call at 15s to avoid hanging on cross-org tokens.
    ALL_PROJECT_ITEMS="[]"
    HAS_NEXT="true"
    END_CURSOR=""
    PROJECT_ACCESS_OK="true"
    while [[ "${HAS_NEXT}" == "true" ]]; do
      CURSOR_ARG=""
      if [[ -n "${END_CURSOR}" ]]; then
        CURSOR_ARG="-f afterCursor=${END_CURSOR}"
      fi

      PAGE=$(timeout 15 gh api graphql -f query='
        query($org: String!, $num: Int!, $fieldName: String!, $afterCursor: String) {
          organization(login: $org) {
            projectV2(number: $num) {
              items(first: 100, after: $afterCursor) {
                nodes {
                  content {
                    ... on Issue {
                      number
                      repository { nameWithOwner }
                    }
                  }
                  fieldValueByName(name: $fieldName) {
                    ... on ProjectV2ItemFieldSingleSelectValue {
                      name
                    }
                  }
                }
                pageInfo { hasNextPage endCursor }
              }
            }
          }
        }' -f org="${ORG}" -F num="${PROJECT_NUMBER}" -f fieldName="${FIELD_NAME}" \
           ${CURSOR_ARG:+"${CURSOR_ARG}"} 2>/dev/null) || {
        echo "⚠ Could not query project items (timeout or access denied)"
        PROJECT_ACCESS_OK="false"
        break
      }

      if [[ -z "${PAGE}" ]] || ! echo "${PAGE}" | jq -e '.data.organization.projectV2.items' >/dev/null 2>&1; then
        echo "⚠ Project query returned no data — treating all issues as unclassified"
        PROJECT_ACCESS_OK="false"
        break
      fi

      PAGE_NODES=$(echo "${PAGE}" | jq -c '.data.organization.projectV2.items.nodes // []')
      ALL_PROJECT_ITEMS=$(echo "${ALL_PROJECT_ITEMS}" "${PAGE_NODES}" | jq -sc '.[0] + .[1]')
      HAS_NEXT=$(echo "${PAGE}" | jq -r '.data.organization.projectV2.items.pageInfo.hasNextPage // false')
      END_CURSOR=$(echo "${PAGE}" | jq -r '.data.organization.projectV2.items.pageInfo.endCursor // empty')
    done

    if [[ "${PROJECT_ACCESS_OK}" == "true" ]]; then
      PROJECT_ITEMS="${ALL_PROJECT_ITEMS}"
      CLASSIFIED_NUMBERS=$(printf '%s' "${PROJECT_ITEMS}" | jq -r --arg repo "${CLASSIFY_SOURCE_REPO}" '
        .[]
        | select(.content.repository.nameWithOwner == $repo)
        | select(.fieldValueByName.name != null and .fieldValueByName.name != "")
        | .content.number' 2>/dev/null | sort -n || true)

      while IFS= read -r num; do
        if [[ -n "${num}" ]] && ! printf '%s\n' "${CLASSIFIED_NUMBERS}" | grep -qx "${num}"; then
          echo "${num}"
        fi
      done <<< "${ALL_ISSUE_NUMBERS}" > "${ISSUE_NUMBERS_FILE}"

      UNCLASSIFIED_COUNT=$(wc -l < "${ISSUE_NUMBERS_FILE}" | tr -d ' ')
      echo "✓ Found ${UNCLASSIFIED_COUNT} unclassified issues"
    else
      echo "${ALL_ISSUE_NUMBERS}" > "${ISSUE_NUMBERS_FILE}"
      TOTAL_COUNT=$(wc -l < "${ISSUE_NUMBERS_FILE}" | tr -d ' ')
      echo "✓ Treating all ${TOTAL_COUNT} open issues as unclassified (no project access)"
    fi
    ;;

  all)
    jq -r '.[].number' "${CONTEXT_DIR}/open-issues.json" > "${ISSUE_NUMBERS_FILE}"
    ALL_COUNT=$(wc -l < "${ISSUE_NUMBERS_FILE}" | tr -d ' ')
    echo "✓ All mode: ${ALL_COUNT} open issues to classify"
    ;;

  *)
    echo "ERROR: Unknown CLASSIFY_MODE: ${CLASSIFY_MODE}"
    exit 1
    ;;
esac

# --- Discover GitHub Project field IDs for the post-script ---
echo "Discovering project field metadata..."
PROJECT_NUMBER="${CLASSIFY_PROJECT_NUMBER:-1}"
FIELD_NAME="${CLASSIFY_FIELD_NAME:-Workstream Category}"

# Validate FIELD_NAME (may not have been validated yet in non-unclassified modes).
if [[ ! "${FIELD_NAME}" =~ ^[a-zA-Z0-9\ ,._-]+$ ]]; then
  echo "ERROR: CLASSIFY_FIELD_NAME contains disallowed characters"
  exit 1
fi

PROJECT_META=$(timeout 15 gh api graphql -f query='
  query($org: String!, $num: Int!, $fieldName: String!) {
    organization(login: $org) {
      projectV2(number: $num) {
        id
        field(name: $fieldName) {
          ... on ProjectV2SingleSelectField {
            id
            options {
              id
              name
            }
          }
        }
      }
    }
  }' -f org="${ORG}" -F num="${PROJECT_NUMBER}" -f fieldName="${FIELD_NAME}" 2>/dev/null || echo '{}')

# Write only the structural metadata the post-script needs.
# Project/field/option IDs are not secrets (discoverable via public API).
printf '%s' "${PROJECT_META}" | jq '{
  project_id: .data.organization.projectV2.id,
  field_id: (.data.organization.projectV2.field.id // null),
  options: [(.data.organization.projectV2.field.options // [])[] | {name: .name, id: .id}]
}' > "${CONTEXT_DIR}/project-meta.json" 2>/dev/null || echo '{"project_id":null,"field_id":null,"options":[]}' > "${CONTEXT_DIR}/project-meta.json"

PROJECT_ID_CHECK=$(jq -r '.project_id // empty' "${CONTEXT_DIR}/project-meta.json")
if [[ -z "${PROJECT_ID_CHECK}" ]]; then
  echo "⚠ Could not fetch project metadata — project field updates will be skipped."
  echo "  Check that your token has organization projects read/write access."
else
  echo "✓ Project metadata saved"
  jq -r '.options[].name' "${CONTEXT_DIR}/project-meta.json" 2>/dev/null | while read -r opt; do
    echo "  - ${opt}"
  done
fi

TOTAL_ISSUES=$(wc -l < "${ISSUE_NUMBERS_FILE}" | tr -d ' ')
echo ""
echo "=== Pre-classify complete ==="
echo "Issues to classify: ${TOTAL_ISSUES}"
echo "Mode: ${CLASSIFY_MODE}"
echo "Filter category: ${CLASSIFY_FILTER_CATEGORY:-<all>}"
echo "Dry run: ${CLASSIFY_DRY_RUN:-false}"
