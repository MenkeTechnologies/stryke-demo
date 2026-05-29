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

# Pin the documented "14 demos / 14 connector siblings" claim used across
# stryke-demo/docs/*.html and the broader stryke ecosystem narrative. The
# run_all.stk aggregator is intentionally excluded so the count reflects
# *unique* connectors only, not the orchestration script.
demo_count=$(find demos -maxdepth 1 -name "*.stk" -type f ! -name "run_all.stk" | wc -l | tr -d ' ')
if [[ $demo_count -eq 14 ]]; then
    echo "PASS  exactly 14 unique demos (matches docs/*.html '14 demos' claim)"
else
    echo "FAIL  expected 14 unique demos, got $demo_count — docs/*.html numeric claim drifted"
    ok=0
fi

# Demos are numbered 01..14; pin the strict sequence so a missing file
# or a duplicated number (e.g. two 05_*) is caught immediately.
expected_nums=$(seq -f "%02g" 1 14 | sort)
actual_nums=$(find demos -maxdepth 1 -name "*.stk" -type f ! -name "run_all.stk" \
    -exec basename {} \; | sed 's/_.*//' | sort)
if [[ "$expected_nums" == "$actual_nums" ]]; then
    echo "PASS  demo numbering 01..14 contiguous, no duplicates"
else
    echo "FAIL  demo numbering drifted (expected 01..14 strict)"
    ok=0
fi

# Every Makefile demo target must appear under .PHONY too, otherwise a
# `make arrow` that collides with a real file in cwd would silently skip.
phony_line=$(grep -E "^\.PHONY:" Makefile | head -1)
phony_missing=""
for target in install up down all arrow mysql postgres spark aws gcp kafka grpc parquet duckdb redis mongo k8s docker; do
    grep -qE "\\b${target}\\b" <<<"$phony_line" || phony_missing="$phony_missing $target"
done
if [[ -z "$phony_missing" ]]; then
    echo "PASS  all 18 Makefile targets declared .PHONY (file-collision safe)"
else
    echo "FAIL  .PHONY missing:$phony_missing"
    ok=0
fi

[[ $ok -eq 1 ]] && exit 0 || exit 1
