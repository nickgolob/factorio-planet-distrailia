#!/usr/bin/env bash
# Distrailia test runner (macOS / Linux). On Windows use tools/run-tests.ps1 instead.
#
#   bash tools/run-tests.sh                luacheck + unit tests (no Factorio)
#   bash tools/run-tests.sh --integration  also the in-game FactorioTest suite (see TESTING.md)
#
# Prereqs:
#   macOS:  brew install lua luarocks node && luarocks install luacheck busted
#   Linux:  sudo apt install lua5.4 luarocks nodejs && luarocks install luacheck busted
# (No Windows-style npx patch is needed here -- npx resolves fine on Unix.)

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

integration=0
if [ "${1:-}" = "--integration" ] || [ "${1:-}" = "-i" ]; then integration=1; fi

failed=0

echo "== luacheck =="
if command -v luacheck >/dev/null 2>&1; then
  luacheck control.lua data.lua prototypes lib spec tests tools || failed=1
else
  echo "WARN: luacheck not found (luarocks install luacheck). Skipping static analysis." >&2
fi

echo
echo "== unit tests =="
if command -v busted >/dev/null 2>&1; then
  busted || failed=1
elif command -v lua >/dev/null 2>&1; then
  echo "(busted not found; falling back to tools/run_specs.lua)"
  # shellcheck disable=SC2046
  lua tools/run_specs.lua $(ls spec/*_spec.lua) || failed=1
else
  echo "ERROR: need 'busted' or 'lua' (brew install lua luarocks && luarocks install busted luacheck)." >&2
  failed=1
fi

if [ "$integration" -eq 1 ]; then
  echo
  echo "== integration tests (FactorioTest, headless) =="
  if [ ! -f factorio-test.json ]; then
    echo "WARN: factorio-test.json missing - copy factorio-test.example.json and set factorioPath (see TESTING.md). Skipping." >&2
    failed=1
  elif ls .factorio-test-data/mods/factorio-test_*.zip >/dev/null 2>&1; then
    npx --no-install factorio-test run --output-timeout 120 || failed=1
  else
    echo "WARN: factorio-test mod not staged in .factorio-test-data/mods/ (see TESTING.md). Skipping integration." >&2
    failed=1
  fi
fi

echo
if [ "$failed" -ne 0 ]; then
  echo "TESTS FAILED"
  exit 1
fi
echo "ALL TESTS PASSED"
