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
for target in install up down all clean arrow mysql postgres spark aws gcp kafka grpc parquet duckdb redis mongo k8s docker; do
    grep -qE "\\b${target}\\b" <<<"$phony_line" || phony_missing="$phony_missing $target"
done
if [[ -z "$phony_missing" ]]; then
    echo "PASS  all 19 Makefile targets declared .PHONY (file-collision safe)"
else
    echo "FAIL  .PHONY missing:$phony_missing"
    ok=0
fi

# Every demo's first non-comment, non-blank line must be a `use ` directive.
# stryke files load packages via `use Foo` (Perl-sigil-inheritance style); a
# demo that opens with `sub`, `my`, or a function call is mis-structured —
# the connector packages won't be in scope when the demo runs.
non_use=0
non_use_examples=()
while IFS= read -r f; do
    # First line that isn't blank, isn't a comment, and isn't a shebang.
    first=$(awk 'NF && $1 !~ /^#/ {print; exit}' "$f")
    if [[ -z "$first" ]]; then
        echo "FAIL  $f has no executable lines"
        non_use=$((non_use + 1))
        ok=0
    elif [[ "$first" != use\ * ]]; then
        non_use=$((non_use + 1))
        [[ "${#non_use_examples[@]}" -lt 3 ]] && non_use_examples+=("${f##*/}: '${first}'")
        ok=0
    fi
done < <(find demos -maxdepth 1 -name "*.stk" -type f ! -name "run_all.stk" 2>/dev/null)
if [[ $non_use -eq 0 ]]; then
    echo "PASS  every demo opens with a 'use ' directive (excl. run_all.stk)"
else
    echo "FAIL  $non_use demo(s) don't open with 'use ' (e.g. ${non_use_examples[*]})"
fi

# The Makefile `clean` target must mention the generated-artifact paths
# from .gitignore (target/, tmp/, stryke.lock). A `clean` that says
# `rm -rf *` would explode demos/; a `clean` that doesn't touch the
# ignored paths leaves stale bytecode that breaks the next build.
clean_recipe=$(awk '/^clean:/,/^$/' Makefile | grep -v "^clean:")
clean_missing=""
for path in target tmp stryke.lock; do
    grep -qE "\\b${path}\\b" <<<"$clean_recipe" || clean_missing="$clean_missing $path"
done
if grep -q "^clean:" Makefile; then
    if [[ -z "$clean_missing" ]]; then
        echo "PASS  Makefile clean target removes target/, tmp/, stryke.lock"
    else
        echo "FAIL  Makefile clean missing paths:$clean_missing"
        ok=0
    fi
else
    echo "FAIL  Makefile has no clean target"
    ok=0
fi

# Every demos/NN_<name>.stk filename must have a matching [deps].<name>
# entry in stryke.toml. Drift means a new demo was added without wiring
# its sibling-stryke-* dep, or a dep was renamed and the demo filename
# went stale — `s install` would either silently skip or fail at run.
missing_dep=""
while IFS= read -r f; do
    base="${f##*/}"
    base="${base%.stk}"
    name="${base#*_}"
    if ! grep -qE "^${name}[[:space:]]*=" stryke.toml; then
        missing_dep="$missing_dep $name"; ok=0
    fi
done < <(find demos -maxdepth 1 -name "*.stk" -type f ! -name "run_all.stk" 2>/dev/null)
if [[ -z "$missing_dep" ]]; then
    echo "PASS  every demo filename has a matching [deps] entry in stryke.toml"
else
    echo "FAIL  [deps] missing entries for demos:$missing_dep"
fi

# Every [deps].<name> entry must point at the sibling stryke-<name> repo
# under MenkeTechnologies. Pin the URL prefix so a typo or a fork that
# routes one dep to a non-MenkeTech org doesn't sneak past review.
bad_url=""
while IFS= read -r line; do
    name="${line%%=*}"
    name="${name%%[[:space:]]*}"
    expected="https://github.com/MenkeTechnologies/stryke-${name}"
    if ! grep -qE "^${name}[[:space:]]*=.*${expected}" stryke.toml; then
        bad_url="$bad_url $name"; ok=0
    fi
done < <(awk '/^\[deps\]/{f=1;next} /^\[/{f=0} f' stryke.toml | grep -E "^[a-z][a-z0-9]*[[:space:]]*=")
if [[ -z "$bad_url" ]]; then
    echo "PASS  every [deps] entry points at MenkeTechnologies/stryke-<name>"
else
    echo "FAIL  [deps] entries with wrong / missing sibling URL:$bad_url"
fi

# [deps] keys and demo filenames must be EXACTLY 1:1 — no orphan deps
# (declared but no demo) and no orphan demos (no dep wired). This is
# stricter than "every demo has a dep": it also catches the reverse.
deps_list=$(awk '/^\[deps\]/{f=1;next} /^\[/{f=0} f' stryke.toml \
    | grep -E "^[a-z][a-z0-9]*[[:space:]]*=" \
    | awk '{print $1}' | sort)
demo_list=$(find demos -maxdepth 1 -name "*.stk" -type f ! -name "run_all.stk" \
    -exec basename {} \; | sed 's/^[0-9]*_//;s/\.stk$//' | sort)
if [[ "$deps_list" == "$demo_list" ]]; then
    echo "PASS  [deps] keys and demo filenames are a 1:1 match (no orphans)"
else
    echo "FAIL  [deps] keys differ from demo filenames (orphan dep or orphan demo)"
    diff <(echo "$deps_list") <(echo "$demo_list") | sed 's/^/      /'
    ok=0
fi

# run_all.stk is the aggregator. Pin: it must load enough of the
# connector surface that `make all` exercises a meaningful smoke set —
# at least 12 of the 14 connectors (gcp/grpc are documented to require
# explicit args, so the aggregator may legitimately skip them with an
# inline note rather than a `use` directive). Drift to a low number
# would silently degrade the smoke test.
run_all="demos/run_all.stk"
if [[ -f "$run_all" ]]; then
    # Count any line that starts with `use ` followed by a capital letter
    # (excludes comments, blanks). Each `use Foo` or `use Foo::Bar` is
    # one loaded module — sub-modules of the same root still count as
    # "loaded the root" but we only count distinct roots.
    loaded_roots=$(grep -E "^use [A-Z]" "$run_all" | sed -E 's/^use ([A-Za-z0-9]+).*/\1/' | sort -u | wc -l | tr -d ' ')
    if (( loaded_roots >= 12 )); then
        echo "PASS  run_all.stk loads ${loaded_roots}/14 connector roots (smoke threshold ≥12)"
    else
        echo "FAIL  run_all.stk loads only ${loaded_roots}/14 connector roots (need ≥12)"
        ok=0
    fi
else
    echo "FAIL  demos/run_all.stk not present"
    ok=0
fi

# Makefile `all` target invocation must point at run_all.stk (the
# aggregator), not at any individual demo. Drift would make `make all`
# only exercise one connector — silent regression of the full-surface
# smoke test.
all_recipe=$(awk '/^all:[[:space:]]*$/{getline; print; exit}' Makefile)
if [[ "$all_recipe" == *"s demos/run_all.stk"* ]]; then
    echo "PASS  Makefile 'all' target invokes demos/run_all.stk"
else
    echo "FAIL  Makefile 'all' target recipe is '$all_recipe' (expected 's demos/run_all.stk')"
    ok=0
fi

[[ $ok -eq 1 ]] && exit 0 || exit 1
