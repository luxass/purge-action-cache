#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -CeEuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# check for jq
check_jq

# check for gh
check_gh

# verify that filter key option is valid
if [[ ! "${INPUT_FILTER_KEY:-}" =~ ^(created_at|last_accessed_at)$ ]]; then
  bail "Invalid filter key option: ${INPUT_FILTER_KEY:-}. Valid options are: created_at, last_accessed_at."
fi

if ! [[ "${INPUT_MAX_AGE:-604800}" =~ ^[0-9]+$ ]]; then
  bail "Invalid INPUT_MAX_AGE value: '${INPUT_MAX_AGE:-604800}'. Please provide a valid number of seconds."
fi


MAX_DATE=$(( $(date +%s) - INPUT_MAX_AGE ))

info "Purging caches older than ${INPUT_MAX_AGE} seconds (max date: ${MAX_DATE})."

ALL_CACHE_ENTRIES=$(gh cache list \
    --repo "${GITHUB_REPOSITORY:-}" \
    --ref "${GITHUB_REF:-}" \
    --limit "100" \
    --json='createdAt,id,key,lastAccessedAt,ref,sizeInBytes,version')


# Filter based on the filter key option
case "${INPUT_FILTER_KEY:-last_accessed_at}" in
  "created_at")
    JQ_FILTER='.[] | select((.createdAt | .[0:19] +"Z" | fromdateiso8601) < '${MAX_DATE}')'
    ;;
  "last_accessed_at")
    JQ_FILTER='.[] | select((.lastAccessedAt | .[0:19] +"Z" | fromdateiso8601) < '${MAX_DATE}')'
    ;;
esac

info "Filtering cache entries older than ${INPUT_MAX_AGE} seconds using filter key: ${INPUT_FILTER_KEY:-last_accessed_at}"

CACHE_ENTRIES=$(echo "${ALL_CACHE_ENTRIES}" | jq "${JQ_FILTER} | {
  id: .id,
  key: .key,
  created_at: .createdAt,
  last_accessed_at: .lastAccessedAt,
  size_in_bytes: .sizeInBytes,
  ref: .ref,
  version: .version
}")



# print length of cache entries
ALL_CACHE_COUNT=$(echo "${ALL_CACHE_ENTRIES}" | jq -s '.[] | length')
CACHE_COUNT=$(echo "${CACHE_ENTRIES}" | jq -s length)
info "Found ${ALL_CACHE_COUNT} total cache entries, ${CACHE_COUNT} of which are older than ${INPUT_MAX_AGE} seconds."

# if no cache entries found, exit
if [[ ${CACHE_COUNT} -eq 0 ]]; then
  info "No cache entries to purge."
  exit 0
fi

debug "Cache entries to purge:"
echo "${CACHE_ENTRIES}" | jq -c '.' | while IFS= read -r ENTRY; do
  debug "cache entry: $(echo "${ENTRY}" | jq -r '"key=\(.key), id=\(.id), size=\(.size_in_bytes) bytes, created=\(.created_at), last_accessed=\(.last_accessed_at)"')"
done

# loop through cache entries and purge them
echo "${CACHE_ENTRIES}" | jq -c '.' | while IFS= read -r ENTRY; do
  CACHE_KEY=$(echo "${ENTRY}" | jq -r '.key')

  debug "purging cache entry key=(${CACHE_KEY}), id=($(echo "${ENTRY}" | jq -r '.id'))"

  if ! gh cache delete "${CACHE_KEY}" --repo "${GITHUB_REPOSITORY:-}"; then
    bail "Failed to purge cache entry with key: ${CACHE_KEY}"
  fi
done
