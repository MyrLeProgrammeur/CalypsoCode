# shellcheck shell=bash
# Test helpers for calypsocode. No dependencies beyond bash and coreutils —
# the tool is a bash script, and a bash script is enough to test it.
#
# Every test runs hermetically: its own profile directory, compartment home,
# state directory, and a PATH holding only the stubs and the system utilities.
# Nothing touches the network, the real config, or the real agent.

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
# Informational only: how many individual assertions failed in total. Several
# failed assertions inside one test function still count as ONE failed test
# above — TESTS_FAILED tracks test functions, this tracks assertions.
ASSERTIONS_FAILED=0
CURRENT_TEST=""
CURRENT_TEST_FAILED=0
CURRENT_TEST_SKIPPED=0
FAILURES=()

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CALYPSO_BIN="${CALYPSO_BIN:-$REPO_ROOT/bin/calypsocode}"
ORIGINAL_PATH="$PATH"

SANDBOX=""
OUTPUT=""
STATUS=0

# --- sandbox ---------------------------------------------------------------

# Strips every launcher-facing, provider and identity variable the developer's
# own shell might happen to have set, before a single test runs. An inherited
# CALYPSO_NETWORK=none, for instance, silently changes which branch of the
# egress suite actually runs — and it did, once, before this existed. Each
# test then sets only what it actually needs on top of this.
_sanitize_env() {
  local v
  # CALYPSO_/OPENCODE_-prefixed: whatever the developer's own shell (or a
  # previous, unrelated launch) happens to have exported. CALYPSO_BIN is the
  # harness's own handle on the binary under test, not a launcher-facing
  # variable, so it is deliberately spared.
  for v in $(compgen -v | grep -E '^(CALYPSO_|OPENCODE_)' | grep -v '^CALYPSO_BIN$'); do
    unset "$v"
  done
  # XDG_CONFIG_HOME in particular feeds CALYPSO_HOME's own default, so an
  # inherited one would change where a test believes its sandbox lives before
  # sandbox_setup ever assigns CALYPSO_HOME below.
  unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME
  # A leak/egress test that unintentionally inherited one of these would be
  # probing a different network than the one it thinks it is probing.
  unset ALL_PROXY all_proxy HTTP_PROXY http_proxy HTTPS_PROXY https_proxy NO_PROXY no_proxy
  # Identity the launcher sets per-compartment; leaking the developer's own
  # here would mask a launcher bug that fails to override it.
  unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL \
        GIT_CONFIG_GLOBAL GIT_CONFIG_SYSTEM GIT_SSH GIT_SSH_COMMAND \
        SSH_AUTH_SOCK GNUPGHOME EMAIL
  # Provider secrets a test profile's API_KEY_ENV might happen to name.
  unset VENICE_API_KEY_ACME TEST_KEY TEST_KEY_2 SOURCE_KEY NEW_KEY
}

sandbox_setup() {
  _sanitize_env 2>/dev/null || true
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
#
# Argv is recorded two ways: `args=$*` for the simple cases that only care
# about a flattened string, and a NUL-delimited stream in $SANDBOX/agent-argv
# for anything that needs to prove argv *boundaries* survived — `$*` cannot
# tell "one arg with a space" from "two args", and no NUL byte can ever occur
# inside a real argv element, so it is an unambiguous separator.
stub_calypsocode_agent() {
  local exit_code="${1:-0}"
  cat > "$SANDBOX/bin/calypsocode-agent" <<EOF
#!/usr/bin/env bash
echo "STUB_CALYPSOCODE_AGENT_RAN args=\$*"
printf '%s\0' "\$@" > "$SANDBOX/agent-argv"
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

# Reads the stub agent's recorded argv into the array named by $1, using the
# NUL-delimited stream — never a flattened string, and never `eval` or a
# reconstructed command line.
read_agent_argv() {
  local -n _out="$1"
  mapfile -d '' -t _out < "$SANDBOX/agent-argv"
}

# Compares the stub agent's recorded argv, element for element, against the
# arguments given here.
assert_agent_argv() {
  # Named apart from the scalar `want`/`got` in assert_status and assert_mode.
  # A name carries one type per file for the linter, so reusing them here would
  # make those scalar reads look like an array expanded without an index.
  local -a want_argv=("$@") got_argv=()
  read_agent_argv got_argv
  if [ "${#got_argv[@]}" != "${#want_argv[@]}" ]; then
    _fail "expected ${#want_argv[@]} argv element(s), got ${#got_argv[@]}" "$(printf '%q\n' "${got_argv[@]}")"
    return
  fi
  local i
  for i in "${!want_argv[@]}"; do
    if [ "${got_argv[$i]}" != "${want_argv[$i]}" ]; then
      _fail "argv[$i]: expected $(printf '%q' "${want_argv[$i]}"), got $(printf '%q' "${got_argv[$i]:-}")"
      return
    fi
  done
}

# Removes the agent from PATH, simulating "not installed".
no_calypsocode_agent() { rm -f "$SANDBOX/bin/calypsocode-agent"; }

# Runs the command it is given, in this namespace. Enough to exercise the whole
# inner script without Tor: what oniux adds is isolation, and isolation is what
# the curl stub below simulates.
#
# Also records that it was called, and with exactly what: a mutant swapping
# `oniux bash -c ...` for plain `bash -c ...` would still pass every
# egress/leak test if nothing ever confirmed oniux itself ran. One counter
# line per call, and the argv of the most recent call, NUL-delimited so an
# empty or oddly-quoted argument cannot be confused with a field boundary.
stub_oniux() {
  cat > "$SANDBOX/bin/oniux" <<EOF
#!/usr/bin/env bash
echo 1 >> "$SANDBOX/oniux-invocations.count"
printf '%s\0' "\$@" > "$SANDBOX/oniux-invocations.argv"
exec "\$@"
EOF
  chmod +x "$SANDBOX/bin/oniux"
}

oniux_invocation_count() {
  if [ -f "$SANDBOX/oniux-invocations.count" ]; then
    wc -l < "$SANDBOX/oniux-invocations.count" | tr -d ' '
  else
    echo 0
  fi
}

# Exactly one oniux invocation, running `bash -c <inner> calypsocode ...` —
# the shape the launcher is documented to use, not just "oniux ran".
assert_oniux_invoked_once_with_inner_command() {
  local count; count="$(oniux_invocation_count)"
  [ "$count" = "1" ] || { _fail "expected exactly one oniux invocation, got $count"; return; }
  [ -f "$SANDBOX/oniux-invocations.argv" ] || { _fail "no oniux invocation was recorded"; return; }
  local -a argv
  mapfile -d '' -t argv < "$SANDBOX/oniux-invocations.argv"
  [ "${argv[0]:-}" = "bash" ] || _fail "expected oniux to invoke bash, got '${argv[0]:-}'"
  [ "${argv[1]:-}" = "-c" ] || _fail "expected -c as bash's second argument, got '${argv[1]:-}'"
  [ "${argv[3]:-}" = "calypsocode" ] || _fail "expected \$0 of the inner script to be 'calypsocode', got '${argv[3]:-}'"
}

assert_oniux_never_invoked() {
  [ "$(oniux_invocation_count)" = "0" ] || _fail "expected NETWORK=none never to invoke oniux, but it was invoked $(oniux_invocation_count) time(s)"
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

# Simulates two networks with one binary, because the launcher probes the same
# targets from both sides: from the host, to confirm a target answers at all, and
# from inside the namespace, where it must not. Only a target that answers on the
# host and refuses inside is evidence of isolation.
#
# The two sides are told apart by $CALYPSO_LEAK_TARGETS, which the launcher exports
# only after the host-side confirmation has already run. Unset means host side.
#
#   STUB_CURL_REACHABLE   hosts that answer from *inside* — a broken compartment
#   STUB_CURL_TIMEOUT     hosts that time out inside — an inconclusive test
#   STUB_CURL_HOST_DEAF   hosts that do not answer on the host either, so they are
#                         not evidence and must be dropped before the namespace
stub_curl() {
  cat > "$SANDBOX/bin/curl" <<'EOF'
#!/usr/bin/env bash
url=""
for arg in "$@"; do
  case "$arg" in http://*|https://*) url="$arg" ;; esac
done
case "$url" in
  *check.torproject.org*)
    # The egress check, driven by:
    #   STUB_EGRESS_ANSWERS   what to echo, verbatim. Default: a Tor exit.
    #   STUB_EGRESS_FAIL_N    fail this many attempts before answering, so the
    #                         retry loop can be exercised.
    #   STUB_EGRESS_COUNTER   counts every attempt, regardless of outcome —
    #                         set whenever a test needs to assert exactly how
    #                         many requests were made, not just infer it from
    #                         output text. Counted in a file because each
    #                         attempt is a fresh process.
    if [ -n "${STUB_EGRESS_COUNTER:-}" ]; then
      n=0
      [ -f "$STUB_EGRESS_COUNTER" ] && n="$(cat "$STUB_EGRESS_COUNTER")"
      n=$((n + 1))
      echo "$n" > "$STUB_EGRESS_COUNTER"
    fi
    if [ -n "${STUB_EGRESS_FAIL_N:-}" ] && [ "${n:-0}" -le "$STUB_EGRESS_FAIL_N" ]; then
      exit 7
    fi
    printf '%s\n' "${STUB_EGRESS_ANSWERS-{\"IsTor\":true,\"IP\":\"185.220.101.1\"\}}"
    exit 0
    ;;
esac
host="${url#http://}"
host="${host%%/*}"

if [ -z "${CALYPSO_LEAK_TARGETS:-}" ]; then
  # Host side: everything answers unless deliberately made deaf.
  for deaf in ${STUB_CURL_HOST_DEAF:-}; do
    [ "$deaf" = "$host" ] && exit 7
  done
  exit 0
fi

# Inside the namespace.
for t in ${STUB_CURL_TIMEOUT:-}; do
  [ "$t" = "$host" ] && exit 28
done
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
  stub_ss
  stub_curl
}

# A PATH with no curl on it at all.
#
# Deleting $SANDBOX/bin/curl is not enough: the sandbox PATH ends in /usr/bin:/bin, so
# the lookup falls through to the real one. That is why the "curl is missing" branch
# was untestable, and why a mutation removing its refusal survived a green suite.
#
# The list is the external commands the launcher needs *before* the curl guard fires.
# It is short because the guard is early and fatal. If a test using this starts failing
# with "command not found", the guard moved later — which is itself worth knowing.
stub_no_curl() {
  mkdir -p "$SANDBOX/nocurl"
  local c
  for c in bash env id date mkdir rm cat tr sed awk cut sort head grep timeout uname sleep printf mkfifo; do
    [ -x "/usr/bin/$c" ] && ln -sf "/usr/bin/$c" "$SANDBOX/nocurl/$c"
    [ -x "/bin/$c" ] && ln -sf "/bin/$c" "$SANDBOX/nocurl/$c"
  done
  export PATH="$SANDBOX/bin:$SANDBOX/nocurl"
}

# A PATH with everything `doctor` needs except `ip` and `ss` — so their
# absence can be asserted in isolation, without curl or oniux also appearing
# to be missing. Call after stub_oniux/stub_calypsocode_agent, which write
# into $SANDBOX/bin and stay reachable since that stays first in PATH.
stub_no_leak_tools() {
  mkdir -p "$SANDBOX/noleaktools"
  local c
  for c in bash env id date mkdir rm cat tr sed awk cut sort head grep timeout uname sleep printf curl python3; do
    [ -x "/usr/bin/$c" ] && ln -sf "/usr/bin/$c" "$SANDBOX/noleaktools/$c"
    [ -x "/bin/$c" ] && ln -sf "/bin/$c" "$SANDBOX/noleaktools/$c"
  done
  export PATH="$SANDBOX/bin:$SANDBOX/noleaktools"
}

# Listening ports, as `ss -ltn` prints them. Stubbed so the suite never reads the
# developer's real open ports — which would make the leak test's target list differ
# per machine, and the assertions below meaningless.
#
# One listener on every interface (:22000) and one on loopback only (:631). The
# loopback one must never become a target: it is unreachable from another namespace
# even with no isolation at all, so it could not fail the test.
stub_ss() {
  cat > "$SANDBOX/bin/ss" <<'EOF'
#!/usr/bin/env bash
echo "State  Recv-Q Send-Q Local Address:Port  Peer Address:Port Process"
echo "LISTEN 0      4096   *:22000             *:*"
echo "LISTEN 0      4096   127.0.0.1:631       0.0.0.0:*"
EOF
  chmod +x "$SANDBOX/bin/ss"
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

# Explicit skip, with a reason — for a test whose prerequisite (a PTY via
# `script`, typically) is missing in this environment. Distinct from a pass:
# a test that could not run is not a test that passed, so it must show up as
# its own bucket rather than silently inflating the pass count. Call and then
# `return 0` from the test.
skip() {
  CURRENT_TEST_SKIPPED=1
  echo "  SKIP  $CURRENT_TEST — $1"
}

# --- assertions ------------------------------------------------------------

# Counts assertions, not test functions: several failed assertions inside one
# test still make that test count as ONE failure, tallied once in run_tests
# after the function returns.
_fail() {
  ASSERTIONS_FAILED=$((ASSERTIONS_FAILED + 1))
  CURRENT_TEST_FAILED=1
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

# Octal permission bits only, portable between GNU and BSD stat.
file_mode() {
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null
}

assert_mode() {
  local path="$1" want="$2" got
  got="$(file_mode "$path")"
  [ "$got" = "$want" ] || _fail "expected mode $want on $path, got $got"
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
    CURRENT_TEST_FAILED=0
    CURRENT_TEST_SKIPPED=0
    TESTS_RUN=$((TESTS_RUN + 1))
    sandbox_setup
    "$fn" || true
    sandbox_teardown

    # One bucket per test function, not per assertion — see _fail(). Skip
    # takes precedence: a test that skips and also happens to trip a stray
    # assertion first is still a skip, not a failure, since it never ran its
    # real body.
    if [ "$CURRENT_TEST_SKIPPED" = "1" ]; then
      TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    elif [ "$CURRENT_TEST_FAILED" = "1" ]; then
      TESTS_FAILED=$((TESTS_FAILED + 1))
    else
      TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
  done

  local summary="   $TESTS_PASSED/$TESTS_RUN passed"
  [ "$TESTS_SKIPPED" -gt 0 ] && summary="$summary, $TESTS_SKIPPED skipped"
  if [ "$TESTS_FAILED" -gt 0 ]; then
    echo "$summary, $TESTS_FAILED FAILED ($ASSERTIONS_FAILED assertion(s))"
    return 1
  fi
  echo "$summary"
  return 0
}
