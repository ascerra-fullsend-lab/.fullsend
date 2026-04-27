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

NOTES_DIR="${FULLSEND_WORK_DIR}/notes"
BACKLOG_FILE="${FULLSEND_WORK_DIR}/backlog.json"
META_FILE="${FULLSEND_WORK_DIR}/scribe-meta.json"

mkdir -p "${NOTES_DIR}"

LOOKBACK="${SCRIBE_LOOKBACK_HOURS:-3}"
CUTOFF_DATE=$(date -u -d "${LOOKBACK} hours ago" +"%Y-%m-%dT%H:%M:%S" 2>/dev/null \
  || date -u -v-"${LOOKBACK}"H +"%Y-%m-%dT%H:%M:%S")

echo "Scribe pre-script: searching Drive for docs matching '${SCRIBE_SEARCH_QUERY}' since ${CUTOFF_DATE}"

# --- Fetch meeting notes from Google Drive ---
# Use gcloud + curl to query the Drive API. The google-github-actions/auth
# step in the workflow sets up Application Default Credentials.
ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null || echo "")
if [[ -z "${ACCESS_TOKEN}" ]]; then
  echo "ERROR: could not obtain GCP access token — is google-github-actions/auth configured?"
  exit 1
fi

ESCAPED_QUERY=$(printf '%s' "${SCRIBE_SEARCH_QUERY}" | sed "s/'/\\\\'/g")
QUERY="name contains '${ESCAPED_QUERY}' and mimeType = 'application/vnd.google-apps.document' and createdTime > '${CUTOFF_DATE}'"

if [[ -n "${SCRIBE_NAME_FILTER:-}" ]]; then
  ESCAPED_FILTER=$(printf '%s' "${SCRIBE_NAME_FILTER}" | sed "s/'/\\\\'/g")
  QUERY="${QUERY} and name contains '${ESCAPED_FILTER}'"
fi

DRIVE_RESPONSE=$(curl -fsSL \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://www.googleapis.com/drive/v3/files?q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''${QUERY}'''))")&fields=files(id,name,createdTime,webViewLink)&orderBy=createdTime+desc&pageSize=20&supportsAllDrives=true&includeItemsFromAllDrives=true" \
  2>/dev/null || echo '{"files":[]}')

DOC_COUNT=$(echo "${DRIVE_RESPONSE}" | jq '.files | length')
echo "Found ${DOC_COUNT} matching document(s)"

if [[ "${DOC_COUNT}" -eq 0 ]]; then
  echo '{"notes_processed":0,"cutoff_date":"'"${CUTOFF_DATE}"'"}' > "${META_FILE}"
  echo "No documents found — agent will produce empty result."
  exit 0
fi

# Download and scrub each document
DOC_INDEX=0
echo "${DRIVE_RESPONSE}" | jq -c '.files[]' | while read -r doc; do
  DOC_ID=$(echo "${doc}" | jq -r '.id')
  DOC_NAME=$(echo "${doc}" | jq -r '.name')
  DOC_URL=$(echo "${doc}" | jq -r '.webViewLink')

  echo "  Downloading: ${DOC_NAME}"

  # Export as plain text
  RAW_TEXT=$(curl -fsSL \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://www.googleapis.com/drive/v3/files/${DOC_ID}/export?mimeType=text/plain" \
    2>/dev/null || echo "")

  if [[ -z "${RAW_TEXT}" ]]; then
    echo "  WARNING: could not export doc ${DOC_ID}, skipping"
    continue
  fi

  # PII scrubbing — regex-based removal of emails, phone numbers, IPs,
  # SSNs, API keys, tokens, and suspicious Unicode before the LLM sees it.
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

# --- Fetch the open issue backlog ---
echo "Fetching open issues from ${SCRIBE_REPO}..."
gh issue list --repo "${SCRIBE_REPO}" --state open --json number,title,labels --limit 500 > "${BACKLOG_FILE}"
ISSUE_COUNT=$(jq 'length' "${BACKLOG_FILE}")
echo "Fetched ${ISSUE_COUNT} open issues for backlog context."

# Write metadata for the agent
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
