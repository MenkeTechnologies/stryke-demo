#!/usr/bin/env bash
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
ok=1

empty=0
while IFS= read -r f; do
    [[ -s "$f" ]] || { echo "FAIL  empty: $f"; empty=$((empty+1)); ok=0; }
done < <(find demos -maxdepth 1 -name "*.stk" -type f 2>/dev/null)
[[ $empty -eq 0 ]] && echo "PASS  every demos/*.stk non-empty ($(find demos -maxdepth 1 -name '*.stk' | wc -l | tr -d ' ') files)"

missing=""
while IFS= read -r f; do
    base="${f##*/}"
    base="${base%.stk}"
    base="${base#*_}"
    if ! grep -qE "^${base}:" Makefile; then
        missing="$missing $base"; ok=0
    fi
done < <(find demos -maxdepth 1 -name "*.stk" -type f 2>/dev/null)
if [[ -n "$missing" ]]; then
    echo "FAIL  Makefile missing targets:$missing"
else
    echo "PASS  Makefile has target for every demo"
fi

if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import yaml,sys;yaml.safe_load(open('docker-compose.yml'))" 2>/dev/null; then
        echo "PASS  docker-compose.yml parses as YAML"
    else
        echo "WARN  docker-compose.yml parse failed (PyYAML missing or invalid)"
    fi
fi

[[ $ok -eq 1 ]] && exit 0 || exit 1
