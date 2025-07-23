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

RECURSIVE_PAGE=1
CACHE_ENTRIES=()

while true; do
  # list all cache entries by recursively calling `gh cache list`
  ALL_PAGE_ENTRIES=$(gh cache list \
    --repo "${GITHUB_REPOSITORY:-}" \
    --ref "${GITHUB_REF:-}" \
    --limit "100" \
    --page "${RECURSIVE_PAGE}" \
    --json='createdAt,id,key,lastAccessedAt,ref,sizeInBytes,version')

  # Filter based on the filter key option
  case "${INPUT_FILTER_KEY:-last_accessed_at}" in
    "created_at")
      JQ_FILTER='.[] | select((.createdAt | fromdateiso8601) < '${MAX_DATE}')'
      ;;
    "last_accessed_at")
      JQ_FILTER='.[] | select((.lastAccessedAt | fromdateiso8601) < '${MAX_DATE}')'
      ;;
  esac

  PAGE_ENTRIES=$(echo "${ALL_PAGE_ENTRIES}" | jq "${JQ_FILTER} | {
    id: .id,
    key: .key,
    created_at: .createdAt,
    last_accessed_at: .lastAccessedAt,
    size_in_bytes: .sizeInBytes,
    ref: .ref,
    version: .version
  }")

  if [[ -z "${PAGE_ENTRIES}" ]]; then
    info "No cache entries found on page ${RECURSIVE_PAGE}."
    break
  fi

  # append entries to CACHE_ENTRIES array
  if [[ -z "${CACHE_ENTRIES[0]}" ]]; then
    CACHE_ENTRIES="${PAGE_ENTRIES}"
  else
    CACHE_ENTRIES=$(echo "${CACHE_ENTRIES}" "${PAGE_ENTRIES}" | jq -s 'add')
  fi

  # check if there are more pages by checking the length of the entries
  # if it's less than 100, we assume there are no more pages
  if [[ $(echo "${ALL_PAGE_ENTRIES}" | jq length) -lt 100 ]]; then
    break
  fi

  ((RECURSIVE_PAGE++))
done

# print length of cache entries
info "Found ${#CACHE_ENTRIES[@]} cache entries."

# if no cache entries found, exit
if [[ ${#CACHE_ENTRIES[@]} -eq 0 ]]; then
  info "No cache entries to purge."
  exit 0
fi

debug "Cache entries to purge:"
for ENTRY in "${CACHE_ENTRIES[@]}"; do
  # TODO(@luxass): print cache entry details
  debug "located cache entry: $(echo "${ENTRY}" | jq -r '.key')"
done

# loop through cache entries and purge them
for ENTRY in "${CACHE_ENTRIES[@]}"; do
  CACHE_ID=$(echo "${ENTRY}" | jq -r '.id')

  # TODO(@luxass): figure out error handling for gh cache delete
  debug "Purging cache entry with ID: ${CACHE_ID}"

  gh cache delete "${CACHE_ID}" \
    --repo "${GITHUB_REPOSITORY:-}"
done
