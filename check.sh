#!/usr/bin/env bash
# Exit codes: 0 passed, 1 failed, 2 inconclusive, 3 could not run the check.
set -uo pipefail

summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
output="${GITHUB_OUTPUT:-/dev/null}"

stop() {
    echo "FeedCI: $1" >&2
    exit 3
}

command -v jq >/dev/null || stop "jq is required."
command -v curl >/dev/null || stop "curl is required."

url="${FEEDCI_URL:-}"
file="${FEEDCI_FILE:-}"

[ -n "${FEEDCI_API_KEY:-}" ] || stop "Set the api-key input."
if { [ -n "$url" ] && [ -n "$file" ]; } || { [ -z "$url" ] && [ -z "$file" ]; }; then
    stop "Set either the url input or the file input."
fi
[ -z "$file" ] || [ -f "$file" ] || stop "File not found: $file"

work="$(mktemp -d)" || stop "Could not create a temporary directory."
trap 'rm -rf "$work"' EXIT

contract="$(jq -n \
    --arg failOn "${FEEDCI_FAIL_ON:-fail}" \
    --arg require "${FEEDCI_REQUIRE:-}" \
    --arg minItems "${FEEDCI_MIN_ITEMS:-}" \
    --arg stableIds "${FEEDCI_STABLE_IDS:-}" \
    --arg maxAgeDays "${FEEDCI_MAX_AGE_DAYS:-}" \
    --arg requireLicence "${FEEDCI_REQUIRE_LICENCE:-}" \
    --arg baseline "${FEEDCI_BASELINE:-}" \
    '{fail_on: $failOn}
     + (if $require == "" then {} else {require: ($require | split(",") | map(gsub("^\\s+|\\s+$"; "")))} end)
     + (if $minItems == "" then {} else {min_items: ($minItems | tonumber)} end)
     + (if $stableIds == "true" then {stable_ids: true} else {} end)
     + (if $maxAgeDays == "" then {} else {max_age_days: ($maxAgeDays | tonumber)} end)
     + (if $requireLicence == "true" then {require_licence: true} else {} end)
     + (if $baseline == "" then {} else {baseline: $baseline} end)')" \
    || stop "min-items and max-age-days must be numbers."

if [ -n "$url" ]; then
    jq -n --arg url "$url" --argjson contract "$contract" '{url: $url, contract: $contract}' > "$work/request.json"
else
    jq -n --rawfile document "$file" --argjson contract "$contract" '{document: $document, contract: $contract}' > "$work/request.json" \
        || stop "Could not read $file as text."
fi

# The key goes through a config on stdin, so it never appears in the process list.
status="$(printf 'header = "Authorization: Bearer %s"\n' "$FEEDCI_API_KEY" | curl --silent --show-error --max-time 60 \
    --config - \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --data-binary "@$work/request.json" \
    --output "$work/response.json" \
    --write-out '%{http_code}' \
    "${FEEDCI_API_URL:-https://feeds.one/api/v1/feed-checks}")" || stop "Could not reach the feeds.one API."

if [ "$status" != "200" ]; then
    message="$(jq -r '.message // empty' "$work/response.json" 2>/dev/null)"
    stop "The API returned HTTP $status. ${message}"
fi

outcome="$(jq -r '.outcome // empty' "$work/response.json")"
report_url="$(jq -r '.report_url // empty' "$work/response.json")"
[ -n "$outcome" ] || stop "The API returned an unexpected response."

echo "outcome=$outcome" >> "$output"
echo "report-url=$report_url" >> "$output"

{
    echo "FeedCI: $outcome"
    echo "$(jq -r '.headline' "$work/response.json")"
    jq -r '.violations[] | "  FAILED: \(.message)"' "$work/response.json"
    jq -r '.unverified[] | "  NOT VERIFIED: \(.message)"' "$work/response.json"
    echo "Report: $report_url"
} | tee -a "$summary"

case "$outcome" in
    passed) exit 0 ;;
    inconclusive) [ "${FEEDCI_ALLOW_INCONCLUSIVE:-false}" = "true" ] && exit 0; exit 2 ;;
    *) exit 1 ;;
esac
