#!/usr/bin/env bash
# Golden-file render test: re-renders each tests/<name>-values.yaml fixture and
# diffs it byte-for-byte against the checked-in tests/<name>-expected.yaml.
# Run from anywhere; paths are resolved relative to this script.
#
# To intentionally update a golden file after a deliberate chart change, run
# with UPDATE=1 to regenerate it instead of diffing:
#   UPDATE=1 ./render_test.sh
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chart_dir="$(dirname "$script_dir")"

status=0

for values_file in "$script_dir"/*-values.yaml; do
  name="$(basename "$values_file" -values.yaml)"
  expected_file="$script_dir/${name}-expected.yaml"
  release="${name}"
  namespace="${name}"

  actual="$(helm template "$release" "$chart_dir" --namespace "$namespace" -f "$values_file")"

  if [[ "${UPDATE:-}" == "1" ]]; then
    printf '%s\n' "$actual" > "$expected_file"
    echo "updated: $expected_file"
    continue
  fi

  if [[ ! -f "$expected_file" ]]; then
    echo "FAIL: $name -- missing $expected_file (run with UPDATE=1 to create it)"
    status=1
    continue
  fi

  if ! diff -u "$expected_file" <(printf '%s\n' "$actual"); then
    echo "FAIL: $name -- rendered output does not match $expected_file"
    status=1
    continue
  fi

  echo "PASS: $name"
done

exit "$status"
