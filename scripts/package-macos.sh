#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Compatibility entry point for local callers. Release automation uses
# build-app.sh and package-release.sh so every released archive is reproducible.
exec bash scripts/build-app.sh "$@"
