# shellcheck shell=bash
# Test helpers for calypsocode. No dependencies beyond bash and coreutils —
# the tool is a bash script, and a bash script is enough to test it.
#
# Every test runs hermetically: its own profile directory, compartment home,
# state directory, and a PATH holding only the stubs and the system utilities.
# Nothing touches the network, the real config, or the real agent.

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
  # The stub dir plus system utilities, and deliberately NOT $ORIGINAL_PATH: a
  # developer machine has the real calypsocode-agent and oniux installed, so no_calypsocode_agent()
  # would fall through to the real agent, which waits on its TUI forever. CI
  # never caught it because CI has neither binary.
  export PATH="$SANDBOX/bin:/usr/bin:/bin"
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
stub_calypsocode_agent() {
  local exit_code="${1:-0}"
  cat > "$SANDBOX/bin/calypsocode-agent" <<EOF
#!/usr/bin/env bash
echo "STUB_CALYPSOCODE_AGENT_RAN args=\$*"
for v in LC_ALL LANG TZ GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME \\
         GIT_COMMITTER_EMAIL XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME \\
         OPENCODE_CONFIG OPENCODE_DISABLE_AUTOUPDATE OPENCODE_DISABLE_MODELS_FETCH \\
         TEST_KEY; do
  echo "ENV \$v=\${!v:-<unset>}"
done
exit $exit_code
EOF
  chmod +x "$SANDBOX/bin/calypsocode-agent"
}

# Removes the agent from PATH, simulating "not installed".
no_calypsocode_agent() { rm -f "$SANDBOX/bin/calypsocode-agent"; }

# Runs the command it is given, in this namespace. Enough to exercise the whole
# inner script without Tor: what oniux adds is isolation, and isolation is what
# the curl stub below simulates.
stub_oniux() {
  cat > "$SANDBOX/bin/oniux" <<'EOF'
#!/usr/bin/env bash
exec "$@"
EOF
  chmod +x "$SANDBOX/bin/oniux"
}

# Makes leak-target discovery deterministic. Without it the tests would probe
# whatever addresses the developer's machine happens to have.
stub_ip() {
  cat > "$SANDBOX/bin/ip" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  route*)        echo "default via 10.9.9.1 dev eth0 proto dhcp src 10.9.9.42 metric 600" ;;
  *"addr show"*) echo "2: eth0    inet 10.9.9.42/24 brd 10.9.9.255 scope global eth0" ;;
esac
EOF
  chmod +x "$SANDBOX/bin/ip"
}

# An `ip` that reports nothing, so no private target can be discovered.
stub_ip_empty() {
  printf '#!/usr/bin/env bash\nexit 0\n' > "$SANDBOX/bin/ip"
  chmod +x "$SANDBOX/bin/ip"
}

# Simulates the namespace's network. Private targets are unreachable and the
# egress check reports Tor, unless STUB_CURL_REACHABLE names a host that should
# answer — which is what a broken compartment looks like.
stub_curl() {
  cat > "$SANDBOX/bin/curl" <<'EOF'
#!/usr/bin/env bash
url=""
for arg in "$@"; do
  case "$arg" in http://*|https://*) url="$arg" ;; esac
done
case "$url" in
  *check.torproject.org*) echo '{"IsTor":true,"IP":"185.220.101.1"}'; exit 0 ;;
esac
host="${url#http://}"
host="${host%%/*}"
for reachable in ${STUB_CURL_REACHABLE:-}; do
  [ "$reachable" = "$host" ] && exit 0
done
exit 7
EOF
  chmod +x "$SANDBOX/bin/curl"
}

# The full set for an isolated-namespace launch: agent, oniux, ip, curl.
stub_namespace() {
  stub_calypsocode_agent
  stub_oniux
  stub_ip
  stub_curl
}

# --- running ---------------------------------------------------------------

# Runs the launcher, capturing combined output and status without aborting.
run_calypso() {
  OUTPUT="$("$CALYPSO_BIN" "$@" 2>&1)"
  STATUS=$?
  return 0
}

# Same, but through a pseudo-terminal, so paths guarded by `[ -t 0 ]` can be
# exercised instead of only their refusal branch. The first argument is what to
# type; the pty's carriage returns are stripped so assertions match normally.
run_calypso_tty() {
  local input="$1"
  shift
  local raw
  raw="$(printf '%s' "$input" | script -qec "$CALYPSO_BIN $*" /dev/null 2>&1)"
  STATUS=$?
  OUTPUT="$(printf '%s' "$raw" | tr -d '\r')"
  return 0
}

have_pty() { command -v script >/dev/null 2>&1; }

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
