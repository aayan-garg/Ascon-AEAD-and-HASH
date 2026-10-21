#!/usr/bin/env bash
# Automated Regression Test Runner (Bash)
# Usage: ./scripts/run_regression.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Triggering Ascon RTL Project Regression..."
python3 "${ROOT_DIR}/scripts/run_regression.py" "$@"
