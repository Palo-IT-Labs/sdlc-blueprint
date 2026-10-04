#!/usr/bin/env bash
# Contrôle de conformité d'un ou plusieurs repos (lecture seule).
# Usage : ./scripts/check.sh <owner>/<repo> [<owner>/<repo> ...]
# Options du collecteur (ex. --out reports) : voir python3 collector/sdlc_check.py --help
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ $# -ge 1 ] || { echo "Usage : $0 <owner>/<repo> [...]"; exit 2; }
repos=(); extra=()
for a in "$@"; do case "$a" in --*) extra+=("$a") ;; *) [ ${#extra[@]} -gt 0 ] && extra+=("$a") || repos+=("$a") ;; esac; done
exec python3 "$ROOT/collector/sdlc_check.py" --repo "${repos[@]}" ${extra[@]+"${extra[@]}"}
