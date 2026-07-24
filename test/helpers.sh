# shellcheck shell=bash
# Test helpers for calypsocode. No dependencies beyond bash and coreutils —
# the tool is a bash script, and a bash script is enough to test it.
#
# Every test runs hermetically: its own profile directory, compartment home,
# state directory, and a PATH containing only stubs. Nothing touches the
# network, the real config, or the real agent.

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_TEST=""
FAILURES=()

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CALYPSO_BIN="${CALYPSO_BIN:-$REPO_ROOT/bin/calypsocode}"
ORIGINAL_PATH="$PATH"

SANDBOX=""
OUTPUT=""
STATUS=0

# --- sandbox ---------------------------------------------------------------

sandbox_setup() {
  SANDBOX="$(mktemp -d)"
  mkdir -p "$SANDBOX"/{profiles,home,state,bin,project}
  export CALYPSO_PROFILE_DIR="$SANDBOX/profiles"
  export CALYPSO_HOME="$SANDBOX/home"
  export CALYPSO_STATE_DIR="$SANDBOX/state"
  export PATH="$SANDBOX/bin:$ORIGINAL_PATH"
  # Tests must never depend on the developer's real key.
  unset VENICE_API_KEY_ACME TEST_KEY 2>/dev/null || true
}

sandbox_teardown() {
  [ -n "$SANDBOX" ] && [ -d "$SANDBOX" ] && rm -rf "$SANDBOX"
  export PATH="$ORIGINAL_PATH"
}

# Writes a profile. Call with no args for a valid default one.
# shellcheck disable=SC2120  # the arguments are genuinely optional
write_profile() {
  local name="${1:-default}"
  shift || true
  if [ $# -gt 0 ]; then
    printf '%s\n' "$@" > "$CALYPSO_PROFILE_DIR/$name.env"
  else
    cat > "$CALYPSO_PROFILE_DIR/$name.env" <<'EOF'
PROFILE=testbox
NETWORK=tor
API_KEY_ENV=TEST_KEY
API_BASE=https://api.example.invalid/v1
MODEL=test-model
GIT_NAME=dev
GIT_EMAIL=dev@localhost
EOF
  fi
}

# A stub agent that records the environment it was launched with.
stub_opencode() {
  local exit_code="${1:-0}"
  cat > "$SANDBOX/bin/opencode" <<EOF
#!/usr/bin/env bash
echo "STUB_OPENCODE_RAN args=\$*"
for v in LC_ALL LANG TZ GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME \\
         GIT_COMMITTER_EMAIL XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME \\
         OPENCODE_CONFIG TEST_KEY; do
  echo "ENV \$v=\${!v:-<unset>}"
done
exit $exit_code
EOF
  chmod +x "$SANDBOX/bin/opencode"
}

# Removes the agent from PATH, simulating "not installed".
no_opencode() { rm -f "$SANDBOX/bin/opencode"; }

# --- running ---------------------------------------------------------------

# Runs the launcher, capturing combined output and status without aborting.
run_calypso() {
  OUTPUT="$("$CALYPSO_BIN" "$@" 2>&1)"
  STATUS=$?
  return 0
}

# --- assertions ------------------------------------------------------------

_fail() {
  TESTS_FAILED=$((TESTS_FAILED + 1))
  FAILURES+=("$CURRENT_TEST: $1")
  echo "  FAIL  $CURRENT_TEST"
  echo "        $1"
  if [ -n "${2:-}" ]; then
    echo "        ---- output ----"
    while IFS= read -r line; do echo "        $line"; done <<< "$2"
  fi
  return 1
}

assert_status() {
  local want="$1"
  [ "$STATUS" = "$want" ] || _fail "expected exit $want, got $STATUS" "$OUTPUT"
}

assert_contains() {
  case "$OUTPUT" in
    *"$1"*) return 0 ;;
    *) _fail "expected output to contain: $1" "$OUTPUT" ;;
  esac
}

assert_not_contains() {
  case "$OUTPUT" in
    *"$1"*) _fail "expected output NOT to contain: $1" "$OUTPUT" ;;
    *) return 0 ;;
  esac
}

assert_file_exists() {
  [ -e "$1" ] || _fail "expected file to exist: $1"
}

assert_no_file() {
  [ ! -e "$1" ] || _fail "expected file NOT to exist: $1"
}

assert_equals() {
  [ "$1" = "$2" ] || _fail "expected '$2', got '$1'"
}

# Counts receipts written in the sandbox state dir.
receipt_count() {
  find "$SANDBOX/state" -maxdepth 1 -name 'receipt-*.txt' 2>/dev/null | wc -l | tr -d ' '
}

receipt_body() {
  cat "$SANDBOX/state"/receipt-*.txt 2>/dev/null
}

# --- driver ----------------------------------------------------------------

run_tests() {
  local suite fn
  suite="$(basename "${BASH_SOURCE[1]}" .test.sh)"
  echo "── $suite"
  for fn in $(declare -F | awk '{print $3}' | grep '^test_' | sort); do
    CURRENT_TEST="$fn"
    TESTS_RUN=$((TESTS_RUN + 1))
    sandbox_setup
    "$fn" || true
    sandbox_teardown
  done

  if [ "$TESTS_FAILED" -gt 0 ]; then
    echo "   $((TESTS_RUN - TESTS_FAILED))/$TESTS_RUN passed, $TESTS_FAILED FAILED"
    return 1
  fi
  echo "   $TESTS_RUN/$TESTS_RUN passed"
  return 0
}
