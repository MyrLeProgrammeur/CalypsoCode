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

# Preflight: a missing prerequisite used to surface mid-suite as a generic,
# unexplained failure (a JSON-parsing test failing for no visible reason
# because python3 was absent, say). Checked once, up front, with a diagnostic
# that names exactly what is missing and the package that provides it.
#
# Package names, per distro:
#   Debian/Ubuntu   apt install python3 util-linux iproute2 curl coreutils
#   Fedora/RHEL     dnf install python3 util-linux iproute curl coreutils
#   Arch            pacman -S python util-linux iproute2 curl coreutils
#   macOS (brew)    brew install python3 coreutils curl
#                   (`script` and `ip`/`ss` are not available on macOS; the
#                   PTY-dependent and leak-candidate tests skip there.)
preflight() {
  local failed=0

  if [ -z "${BASH_VERSINFO:-}" ]; then
    echo "test/run.sh: not running under bash." >&2
    return 1
  fi
  if [ "${BASH_VERSINFO[0]}" -lt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -lt 4 ]; }; then
    echo "test/run.sh: bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]} found, 4.4+ required" >&2
    echo "test/run.sh: (test/helpers.sh uses \`mapfile -d ''\`, added in bash 4.4)." >&2
    failed=1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "test/run.sh: python3 not found — required by the profile/config JSON-validation" >&2
    echo "test/run.sh: tests, and by the launcher's own egress-response parser." >&2
    failed=1
  fi

  local cmd
  for cmd in curl mkfifo ip ss stat mkdir rm cat tr sed awk cut sort head grep timeout date; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "test/run.sh: '$cmd' not found — required by the test harness or its stubs." >&2
      failed=1
    fi
  done

  if ! command -v script >/dev/null 2>&1; then
    echo "test/run.sh: 'script' not found — PTY-dependent tests (--new-profile's" >&2
    echo "test/run.sh: interactive wizard) will report as SKIPPED, not run." >&2
  fi

  [ "$failed" = 0 ]
}

preflight || { echo "test/run.sh: fix the above before running the suite." >&2; exit 1; }

# The suites that must exist. A glob cannot tell "this suite passed" from "this
# suite is not there": `egress.test.sh` was referenced in a comment for weeks while
# never existing, so every egress mutation sailed through a green run. A missing
# suite now fails loudly instead of counting as zero tests.
EXPECTED_SUITES=(egress helpers launch leak picker profile receipt)

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
