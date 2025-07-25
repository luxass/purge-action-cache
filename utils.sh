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
