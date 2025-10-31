#!/usr/bin/env bash
# SPDX-License-Identifier: MIT

set -CeEuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"

# check for requirements
ensure_requirements

# Verify that `mode` is valid
MODE="${INPUT_MODE:-normal}"

ensure_options

case "${MODE}" in
  "normal")
    purge_by_age
    ;;
  "all")
    purge_all
    ;;
  *)
    bail "Unsupported mode: ${MODE}"
    ;;
esac
