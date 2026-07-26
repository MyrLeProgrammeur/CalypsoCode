#!/usr/bin/env bash
# Runs every test/*.test.sh. Each suite runs as its own process, so one
# suite's sandbox or stray environment cannot affect another's.
#
#   ./test/run.sh            # all suites
#   ./test/run.sh receipt    # suites matching a name
#
# Hermetic by default: no network, no Tor, no real agent, no real config.
# Suites that need Tor announce themselves and skip unless CALYPSO_TEST_NET=1.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

# The suites that must exist. A glob cannot tell "this suite passed" from "this
# suite is not there": `egress.test.sh` was referenced in a comment for weeks while
# never existing, so every egress mutation sailed through a green run. A missing
# suite now fails loudly instead of counting as zero tests.
EXPECTED_SUITES=(egress launch leak picker profile receipt)

filter="${1:-}"
failed=0
ran=0

if [ -z "$filter" ]; then
  for expected in "${EXPECTED_SUITES[@]}"; do
    if [ ! -e "test/$expected.test.sh" ]; then
      echo "test/run.sh: test/$expected.test.sh is missing." >&2
      echo "test/run.sh: a suite that does not exist is not a suite that passed." >&2
      exit 1
    fi
  done
fi

for suite in test/*.test.sh; do
  [ -e "$suite" ] || continue
  if [ -n "$filter" ]; then
    case "$suite" in *"$filter"*) ;; *) continue ;; esac
  fi
  ran=$((ran + 1))
  bash "$suite" || failed=$((failed + 1))
done

echo
if [ "$ran" = 0 ]; then
  echo "no suites matched '${filter}'"
  exit 1
fi
if [ "$failed" -gt 0 ]; then
  echo "$failed of $ran suite(s) FAILED"
  exit 1
fi
echo "all $ran suite(s) passed"
