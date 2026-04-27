#!/usr/bin/env bash
# pre-scribe.sh — Fetch meeting notes from Google Drive, scrub PII, prepare
# workspace for the scribe agent.
#
# Runs on the host before the sandbox starts. Downloads recent meeting notes,
# strips sensitive content, and prepares input files the agent will read.
#
# Required env vars:
#   SCRIBE_REPO           — GitHub repository (owner/name)
#   SCRIBE_SEARCH_QUERY   — Drive doc name search (e.g. "team sync")
#   GH_TOKEN              — GitHub token for backlog fetch
#   GOOGLE_APPLICATION_CREDENTIALS — path to GCP SA credentials
#
# Optional env vars:
#   SCRIBE_NAME_FILTER    — substring filter on doc names
#   SCRIBE_LOOKBACK_HOURS — how far back to search (default: 3)

set -euo pipefail

WORK_DIR="${RUNNER_TEMP:-/tmp}/scribe-workspace"
NOTES_DIR="${WORK_DIR}/notes"
BACKLOG_FILE="${WORK_DIR}/backlog.json"
META_FILE="${WORK_DIR}/scribe-meta.json"

mkdir -p "${NOTES_DIR}"

LOOKBACK="${SCRIBE_LOOKBACK_HOURS:-3}"
CUTOFF_DATE=$(date -u -d "${LOOKBACK} hours ago" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null \
  || date -u -v-"${LOOKBACK}"H +"%Y-%m-%dT%H:%M:%S")

echo "Scribe pre-script: searching Drive for docs matching '${SCRIBE_SEARCH_QUERY}' since ${CUTOFF_DATE}"

# --- Fetch the open issue backlog (always needed) ---
echo "Fetching open issues from ${SCRIBE_REPO}..."
gh issue list --repo "${SCRIBE_REPO}" --state open --json number,title,labels --limit 500 > "${BACKLOG_FILE}"
ISSUE_COUNT=$(jq 'length' "${BACKLOG_FILE}")
echo "Fetched ${ISSUE_COUNT} open issues for backlog context."

# --- Fetch meeting notes from Google Drive ---
# The Drive API is a Workspace API that requires its own OAuth scope
# (drive.readonly). The default cloud-platform scope from gcloud doesn't
# cover it. Mint a Drive-scoped token from the SA key directly, matching
# what the Go implementation does with google.CredentialsFromJSON.
SA_KEY_FILE="${GOOGLE_APPLICATION_CREDENTIALS:-}"
if [[ -z "${SA_KEY_FILE}" || ! -f "${SA_KEY_FILE}" ]]; then
  echo "ERROR: GOOGLE_APPLICATION_CREDENTIALS not set or file missing"
  exit 1
fi

ACCESS_TOKEN=$(python3 -c "
from google.oauth2 import service_account
import google.auth.transport.requests
creds = service_account.Credentials.from_service_account_file(
    '${SA_KEY_FILE}',
    scopes=['https://www.googleapis.com/auth/drive.readonly']
)
creds.refresh(google.auth.transport.requests.Request())
print(creds.token)
" 2>/dev/null || echo "")

if [[ -z "${ACCESS_TOKEN}" ]]; then
  echo "ERROR: could not obtain Drive-scoped access token from SA key"
  exit 1
fi
echo "Obtained Drive-scoped access token from SA credentials"

ESCAPED_QUERY=$(printf '%s' "${SCRIBE_SEARCH_QUERY}" | sed "s/'/\\\\'/g")
QUERY="name contains '${ESCAPED_QUERY}' and mimeType = 'application/vnd.google-apps.document' and createdTime > '${CUTOFF_DATE}'"

if [[ -n "${SCRIBE_NAME_FILTER:-}" ]]; then
  ESCAPED_FILTER=$(printf '%s' "${SCRIBE_NAME_FILTER}" | sed "s/'/\\\\'/g")
  QUERY="${QUERY} and name contains '${ESCAPED_FILTER}'"
fi

ENCODED_QUERY=$(printf '%s' "${QUERY}" | jq -sRr @uri)

DRIVE_RESPONSE=$(curl -fsSL \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://www.googleapis.com/drive/v3/files?q=${ENCODED_QUERY}&fields=files(id,name,createdTime,webViewLink)&orderBy=createdTime+desc&pageSize=20&supportsAllDrives=true&includeItemsFromAllDrives=true" \
  2>/dev/null || echo '{"files":[]}')

DOC_COUNT=$(echo "${DRIVE_RESPONSE}" | jq '.files | length')
echo "Found ${DOC_COUNT} matching document(s)"

if [[ "${DOC_COUNT}" -eq 0 ]]; then
  echo "No documents found — agent will produce empty result."
  jq -n \
    --arg cutoff "${CUTOFF_DATE}" \
    --arg repo "${SCRIBE_REPO}" \
    --argjson doc_count 0 \
    --argjson issue_count "${ISSUE_COUNT}" \
    '{cutoff_date: $cutoff, notes_url: "", repo: $repo, docs_downloaded: $doc_count, backlog_issues: $issue_count}' \
    > "${META_FILE}"
  echo "Workspace: ${WORK_DIR}"
  exit 0
fi

DOC_INDEX=0
echo "${DRIVE_RESPONSE}" | jq -c '.files[]' | while read -r doc; do
  DOC_ID=$(echo "${doc}" | jq -r '.id')
  DOC_NAME=$(echo "${doc}" | jq -r '.name')
  DOC_URL=$(echo "${doc}" | jq -r '.webViewLink')

  echo "  Downloading: ${DOC_NAME}"

  RAW_TEXT=$(curl -fsSL \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://www.googleapis.com/drive/v3/files/${DOC_ID}/export?mimeType=text/plain" \
    2>/dev/null || echo "")

  if [[ -z "${RAW_TEXT}" ]]; then
    echo "  WARNING: could not export doc ${DOC_ID}, skipping"
    continue
  fi

  SCRUBBED=$(echo "${RAW_TEXT}" \
    | sed -E 's/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/[REDACTED]/g' \
    | sed -E 's/\b(\+?1[-. ]?)?\(?\d{3}\)?[-. ]?\d{3}[-. ]?\d{4}\b/[REDACTED]/g' \
    | sed -E 's/\+\d{1,3}[-. ]?\d{4,14}\b/[REDACTED]/g' \
    | sed -E 's/\b\d{3}-\d{2}-\d{4}\b/[REDACTED]/g' \
    | sed -E 's/\b(ghp|gho|ghs|ghr)_[A-Za-z0-9_]{36,255}\b/[REDACTED]/g' \
    | sed -E 's/\b(AKIA|ABIA|ACCA|ASIA)[0-9A-Z]{16}\b/[REDACTED]/g' \
    | sed -E 's/-----BEGIN[[:space:]]+(RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----.*-----END[[:space:]]+(RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----/[REDACTED]/g')

  echo "${SCRUBBED}" > "${NOTES_DIR}/doc-${DOC_INDEX}.txt"
  echo "${DOC_URL}" > "${NOTES_DIR}/doc-${DOC_INDEX}.url"

  DOC_INDEX=$((DOC_INDEX + 1))
done

NOTES_URL=""
if [[ -f "${NOTES_DIR}/doc-0.url" ]]; then
  NOTES_URL=$(cat "${NOTES_DIR}/doc-0.url")
fi

jq -n \
  --arg cutoff "${CUTOFF_DATE}" \
  --arg notes_url "${NOTES_URL}" \
  --arg repo "${SCRIBE_REPO}" \
  --argjson doc_count "${DOC_COUNT}" \
  --argjson issue_count "${ISSUE_COUNT}" \
  '{
    cutoff_date: $cutoff,
    notes_url: $notes_url,
    repo: $repo,
    docs_downloaded: $doc_count,
    backlog_issues: $issue_count
  }' > "${META_FILE}"

echo "Pre-scribe complete. ${DOC_COUNT} docs scraped, ${ISSUE_COUNT} issues in backlog."
echo "Workspace: ${WORK_DIR}"
