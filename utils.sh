#!/bin/bash

check_jq() {
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed. Please install jq to run this script."
        exit 1
    fi
}

check_gh() {
    if ! command -v gh &> /dev/null; then
        echo "Error: GitHub CLI (gh) is not installed. Please install gh to run this script."
        exit 1
    fi
}

bail() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    printf '::error::%s\n' "$*"
  else
    printf >&2 'error: %s\n' "$*"
  fi
  exit 1
}

warn() {
  if [[ -n "${GITHUB_ACTIONS:-}" ]]; then
    printf '::warning::%s\n' "$*"
  else
    printf >&2 'warning: %s\n' "$*"
  fi
}

info() {
  printf >&2 'info: %s\n' "$*"
}

debug() {
  if [[ -n "${INPUT_DEBUG:-}" && "${INPUT_DEBUG}" == "true" ]]; then
    printf >&2 'debug: %s\n' "$*"
  fi
}

ensure_requirements() {
  check_jq
  check_gh
}

ensure_options() {
  if [[ -z "${GITHUB_REPOSITORY:-}" ]]; then
    bail "GITHUB_REPOSITORY is not set. This action must be run in a GitHub Actions environment."
  fi

  # If mode is `ref`, ensure INPUT_REF is set
  if [[ "${MODE}" == "ref" ]]; then
    if [[ -z "${INPUT_REF:-}" ]]; then
      bail "INPUT_REF must be set when mode is 'ref'."
    fi
  fi



  # If mode is `age`
  if [[ "${MODE}" == "age" ]]; then
    # Ensure that INPUT_MAX_AGE is a valid number
    if ! [[ "${INPUT_MAX_AGE:-604800}" =~ ^[0-9]+$ ]]; then
      bail "Invalid INPUT_MAX_AGE value: '${INPUT_MAX_AGE:-604800}'. Please provide a valid number of seconds."
    fi

    # Ensure that INPUT_FILTER_KEY is valid
    if ! [[ "${INPUT_FILTER_KEY:-}" =~ ^(created_at|last_accessed_at)$ ]]; then
      bail "Invalid filter key option: ${INPUT_FILTER_KEY:-}. Valid options are: created_at, last_accessed_at."
    fi
  fi
}

purge_by_age() {
  local max_age="${INPUT_MAX_AGE:-604800}"
  local filter_key="${INPUT_FILTER_KEY:-last_accessed_at}"
  local ref="${1:-${GITHUB_REF:-}}"

  local max_date=$(( $(date +%s) - max_age ))

  info "Purging caches older than ${max_age} seconds (max date: ${max_date})."

  local all_cache_entries=$(gh cache list \
      --repo "${GITHUB_REPOSITORY:-}" \
      --ref "${ref}" \
      --limit "100" \
      --json='createdAt,id,key,lastAccessedAt,ref,sizeInBytes,version')

  # Filter based on the filter key option
  local jq_filter
  case "${filter_key}" in
    "created_at")
      jq_filter='.[] | select((.createdAt | .[0:19] +"Z" | fromdateiso8601) < '${max_date}')'
      ;;
    "last_accessed_at")
      jq_filter='.[] | select((.lastAccessedAt | .[0:19] +"Z" | fromdateiso8601) < '${max_date}')'
      ;;
  esac

  info "Filtering cache entries older than ${max_age} seconds using filter key: ${filter_key}"

  local cache_entries=$(echo "${all_cache_entries}" | jq "${jq_filter} | {
    id: .id,
    key: .key,
    created_at: .createdAt,
    last_accessed_at: .lastAccessedAt,
    size_in_bytes: .sizeInBytes,
    ref: .ref,
    version: .version
  }")

  # print length of cache entries
  local all_cache_count=$(echo "${all_cache_entries}" | jq -s '.[] | length')
  local cache_count=$(echo "${cache_entries}" | jq -s length)
  info "Found ${all_cache_count} total cache entries, ${cache_count} of which are older than ${max_age} seconds."

  # if no cache entries found, exit
  if [[ ${cache_count} -eq 0 ]]; then
    info "No cache entries to purge."
    return 0
  fi

  debug "Cache entries to purge:"
  echo "${cache_entries}" | jq -c '.' | while IFS= read -r ENTRY; do
    debug "cache entry: $(echo "${ENTRY}" | jq -r '"key=\(.key), id=\(.id), size=\(.size_in_bytes) bytes, created=\(.created_at), last_accessed=\(.last_accessed_at)"')"
  done

  # loop through cache entries and purge them
  echo "${cache_entries}" | jq -c '.' | while IFS= read -r ENTRY; do
    local cache_key=$(echo "${ENTRY}" | jq -r '.key')

    debug "purging cache entry key=(${cache_key}), id=($(echo "${ENTRY}" | jq -r '.id'))"

    if ! gh cache delete "${cache_key}" --repo "${GITHUB_REPOSITORY:-}" --ref "${ref}"; then
      bail "Failed to purge cache entry with key: ${cache_key}"
    fi
  done
}

purge_all() {
  info "Purging all caches using 'gh cache delete --all'."

  if ! gh cache delete --all --repo "${GITHUB_REPOSITORY:-}"; then
    bail "Failed to purge all cache entries"
  fi

  info "Successfully purged all cache entries."
}
