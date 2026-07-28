#!/usr/bin/env bash
# test/mutate.sh — a small, home-grown mutation runner for the launcher.
#
# Not a general mutation-testing framework: the launcher is one bash file, and
# a framework would be disproportionate to it. This does one thing: apply a
# short, fixed list of exact, hand-picked mutations to a *copy* of
# bin/calypsocode, run the focused test suite that should catch each one, and
# fail if it doesn't.
#
# Origin: docs/plans/done/review-remediation.md, batch 4. A manual mutation
# pass there found 8 of 10 deliberate breakages of the launcher surviving a
# green 63-test run — the pattern was structural, not random: every mutation
# to the egress check and to what the receipt claims about Tor survived. This
# script makes that pass repeatable instead of a one-off finding, covering the
# 8 mutants github.com issue #30 names.
#
# The working tree is never touched: every mutation is applied to a copy in a
# scratch directory, and CALYPSO_BIN is pointed at that copy for the duration
# of its one test.
#
# A mutant "survives" (bad) if the suite still passes against the mutated
# copy — the bug it introduces went unnoticed. It is "killed" (good) if the
# suite fails. This script exits non-zero if any mutant survives, naming which
# one and why.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ORIGINAL="$REPO_ROOT/bin/calypsocode"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

MUTANT_FILE="$WORK/mutant"

SURVIVED=()
TOTAL=0

# --- mutation primitive ------------------------------------------------------

# Does the substitution and the counting in one Perl process so both use the
# same notion of "matches this pattern" — a bash grep-then-sed pair can disagree
# on that, especially once regex metacharacters are involved, and a mutant
# whose self-check and whose actual edit can disagree is worse than none.
# \Q...\E on the search side means FROM is matched literally, whatever
# characters it contains; the /e flag on the replace side means TO is
# substituted as the literal content of a Perl variable, never re-interpreted
# — so both sides tolerate '$', '"', quotes and brackets in launcher source
# without escaping.
REGION_REPLACE_PL="$WORK/region_replace.pl"
cat > "$REGION_REPLACE_PL" <<'PERL_EOF'
my ($file, $from, $to, $s, $e) = @ARGV;
open my $fh, "<", $file or die "mutate.sh: cannot read $file: $!\n";
my @lines = <$fh>;
close $fh;
die "mutate.sh: line range $s..$e is out of bounds for $file (" . scalar(@lines) . " lines)\n"
  if $s < 1 || $e > @lines || $s > $e;
my $region = join("", @lines[$s - 1 .. $e - 1]);
my $count = () = $region =~ /\Q$from\E/g;
$region =~ s/\Q$from\E/$to/ge;
splice(@lines, $s - 1, $e - $s + 1, $region);
open my $out, ">", $file or die "mutate.sh: cannot write $file: $!\n";
print $out @lines;
print STDOUT "$count";
PERL_EOF

# Applies a mutation to $MUTANT_FILE and insists it changed exactly $expect
# occurrence(s) of $from, within lines $start..$end (default: the whole file).
# A count that doesn't match means the launcher's shape moved since this
# mutant was written — fail loudly rather than silently mutate zero, or more
# than the one region a mutant is supposed to be.
mutate() {
  local desc="$1" from="$2" to="$3" expect="$4" start="${5:-1}" end="${6:-}"
  [ -n "$end" ] || end="$(wc -l < "$MUTANT_FILE")"
  local got
  got="$(perl "$REGION_REPLACE_PL" "$MUTANT_FILE" "$from" "$to" "$start" "$end")"
  if [ "$got" != "$expect" ]; then
    echo "MUTATION SETUP FAILED — $desc" >&2
    echo "  expected $expect occurrence(s) of the anchor text between lines $start-$end, found $got." >&2
    echo "  anchor: $from" >&2
    echo "  bin/calypsocode has moved since this mutant was written — update test/mutate.sh." >&2
    exit 2
  fi
}

fresh_mutant() {
  cp "$ORIGINAL" "$MUTANT_FILE"
  chmod +x "$MUTANT_FILE"
}

# The two copies of probe_tcp are byte-identical on purpose (see the comment
# at its second definition in bin/calypsocode) so a plain whole-file mutate()
# would hit both. These bound a mutation to the INNER heredoc body — the copy
# that actually runs inside the namespace — leaving the host-side copy alone.
inner_range() {
  local s e
  s="$(grep -n "cat <<'INNER_EOF'" "$MUTANT_FILE" | head -1 | cut -d: -f1)"
  e="$(grep -nx 'INNER_EOF' "$MUTANT_FILE" | tail -1 | cut -d: -f1)"
  [ -n "$s" ] && [ -n "$e" ] && [ "$s" -lt "$e" ] \
    || { echo "MUTATION SETUP FAILED — could not find the INNER heredoc body" >&2; exit 2; }
  printf '%s %s\n' "$s" "$e"
}

# --- running a focused suite against the mutant ------------------------------

run_suite() {
  local suite="$1"
  CALYPSO_BIN="$MUTANT_FILE" bash "$REPO_ROOT/test/$suite" > "$WORK/out" 2>&1
}

# name, focused suite, whether it survived, and — on survival — why.
record() {
  local name="$1" status="$2"
  TOTAL=$((TOTAL + 1))
  if [ "$status" -eq 0 ]; then
    SURVIVED+=("$name")
    echo "  SURVIVED  $name — the suite below still passed against the mutated copy"
    sed 's/^/            /' "$WORK/out"
  else
    echo "  killed    $name"
  fi
}

# --- mutants ------------------------------------------------------------------
# Each one: a fresh copy, one self-verified transformation, then the suite
# that is supposed to notice.

echo "── mutation suite"

# 1. oniux bypass. Existing suites stub oniux as a transparent `exec "$@"`, so
# they cannot tell whether it was actually invoked or skipped — which is
# exactly how this mutation survived a green run before. Verified here with a
# dedicated oniux stub that marks its own invocation, rather than by reusing
# the transparent one.
echo
echo "1. oniux bypass"
fresh_mutant
# shellcheck disable=SC2016  # these are literal launcher-source anchors, not expressions to expand
mutate "oniux bypass" \
  'run_with_evidence_handshake oniux bash -c "$INNER"' \
  'run_with_evidence_handshake bash -c "$INNER"' \
  1
# shellcheck source=test/helpers.sh
source "$REPO_ROOT/test/helpers.sh"
sandbox_setup
write_profile
stub_calypsocode_agent
cat > "$SANDBOX/bin/oniux" <<'EOF'
#!/usr/bin/env bash
echo "STUB_ONIUX_INVOKED" >&2
exec "$@"
EOF
chmod +x "$SANDBOX/bin/oniux"
CALYPSO_BIN="$MUTANT_FILE" TEST_KEY=k run_calypso --profile default --yes --no-verify || true
{
  echo "STATUS=$STATUS"
  echo "$OUTPUT"
} > "$WORK/out"
sandbox_teardown
# Mirrors what a real test file's run_tests() returns: 0 only when every
# assertion held, non-zero the moment one didn't — here, the one assertion is
# "oniux actually ran". Its absence is the expected, deterministic outcome of
# this exact mutation, and that absence is what must count as a failing
# assertion (a killed mutant), the same as a failed assert_contains would.
case "$OUTPUT" in
  *STUB_ONIUX_INVOKED*) status=0 ;; # the assertion held: no bypass detected
  *) status=1 ;;                    # oniux never ran: the bypass was caught
esac
record "oniux bypass (oniux never invoked for NETWORK=tor)" "$status"

# 2. non-Tor acceptance. parse_tor_response()'s embedded Python only prints
# NOTTOR when `is_tor is False`; making that condition unreachable (`is None`,
# which a value already checked to be a bool can never be) lets a false
# answer fall through to the IP-validation branch and come back as a verified
# exit instead of a refusal.
echo
echo "2. non-Tor exit accepted as verified"
fresh_mutant
mutate 'non-Tor acceptance' 'if is_tor is False:' 'if is_tor is None:' 1
s=0; run_suite egress.test.sh || s=$?
record "non-Tor exit accepted as a verified Tor egress" "$s"

# 3. non-Tor retry. Dropping the `exit 1` in the IsTor:false branch turns a
# definite negative into a retried one. egress.test.sh's own retry assertion
# (test_a_non_tor_exit_is_not_retried) checks for the log line the *dead
# circuit* branch prints ("attempt N/3"), which the IsTor:false branch never
# prints even when this mutation makes it loop back into the retry — so the
# existing suite cannot see this one either. Verified here by counting how
# many times the egress URL is actually queried.
echo
echo "3. a non-Tor answer is retried instead of refused"
fresh_mutant
mutate 'non-Tor retry' \
  $'did not go through Tor. Retrying will not fix that." >&2\n          exit 1\n' \
  $'did not go through Tor. Retrying will not fix that." >&2\n' \
  1
sandbox_setup
write_profile
stub_calypsocode_agent
stub_oniux
stub_ip
stub_ss
cat > "$SANDBOX/bin/curl" <<'EOF'
#!/usr/bin/env bash
url=""
for arg in "$@"; do case "$arg" in http://*|https://*) url="$arg" ;; esac; done
case "$url" in
  *check.torproject.org*)
    n=0
    [ -f "$SANDBOX_EGRESS_COUNTER" ] && n="$(cat "$SANDBOX_EGRESS_COUNTER")"
    n=$((n + 1))
    echo "$n" > "$SANDBOX_EGRESS_COUNTER"
    echo '{"IsTor":false,"IP":"88.120.4.9"}'
    exit 0
    ;;
esac
# Leak probing, both sides (see stub_curl in helpers.sh): reachable from the
# host, refused from inside the namespace — a normal, sealed compartment, so
# the launch reaches the egress check at all instead of being refused earlier
# for an unrelated reason.
host="${url#http://}"; host="${host%%/*}"
if [ -z "${CALYPSO_LEAK_TARGETS:-}" ]; then exit 0; fi
exit 7
EOF
chmod +x "$SANDBOX/bin/curl"
export SANDBOX_EGRESS_COUNTER="$SANDBOX/egress-attempts"
echo 0 > "$SANDBOX_EGRESS_COUNTER"
CALYPSO_BIN="$MUTANT_FILE" TEST_KEY=k run_calypso --profile default --yes || true
{
  echo "STATUS=$STATUS"
  echo "egress queried $(cat "$SANDBOX_EGRESS_COUNTER") time(s)"
  echo "$OUTPUT"
} > "$WORK/out"
attempts="$(cat "$SANDBOX_EGRESS_COUNTER")"
unset SANDBOX_EGRESS_COUNTER
sandbox_teardown
# The assertion: a confirmed non-Tor answer must be queried exactly once, never
# retried. Same mirroring as mutants 1 and 5 — the assertion holding is status
# 0, its absence (querying more than once) is the failing assertion.
if [ "$attempts" = "1" ]; then status=0; else status=1; fi
record "a confirmed non-Tor exit is retried instead of refused immediately (queried $attempts time(s), want 1)" "$status"

# 4. shared XDG state. Reverting the compartment-scoped data/state directories
# to a shared location is the F9 regression this launcher was rewritten to
# fix: two profiles would then share session history and stored credentials.
echo
echo "4. XDG_DATA_HOME / XDG_STATE_HOME stop moving with the compartment"
fresh_mutant
mutate 'shared XDG state' \
  $'export XDG_DATA_HOME="$COMPARTMENT_DIR/data"\nexport XDG_STATE_HOME="$COMPARTMENT_DIR/state"\n' \
  $'export XDG_DATA_HOME="$CALYPSO_HOME/data"\nexport XDG_STATE_HOME="$CALYPSO_HOME/state"\n' \
  1
s=0; run_suite launch.test.sh || s=$?
record "XDG_DATA_HOME / XDG_STATE_HOME no longer scoped to the compartment (F9)" "$s"

# 5. proxy bypass removal (F10). Without both the env unset AND --noproxy,
# the leak probe travels through the same SOCKS proxy oniux sets up, and a
# private target refused there looks identical to one refused by the kernel —
# the exact confusion F10 documents. Existing stub curl ignores proxy env vars
# entirely, so it cannot tell the two apart; this uses a dedicated curl stub
# that specifically simulates that masking.
echo
echo "5. leak probe stops bypassing the proxy (F10)"
fresh_mutant
read -r inner_s inner_e < <(inner_range)
mutate 'proxy bypass removal (unset)' \
  $'    unset ALL_PROXY all_proxy HTTP_PROXY http_proxy HTTPS_PROXY https_proxy\n' \
  '' \
  1 "$inner_s" "$inner_e"
# The line count shifted by one after the removal above; recompute the range
# rather than reuse stale numbers for the second half of the same mutant.
read -r inner_s inner_e < <(inner_range)
mutate 'proxy bypass removal (--noproxy)' \
  " --noproxy '*'" \
  '' \
  1 "$inner_s" "$inner_e"
sandbox_setup
write_profile
stub_calypsocode_agent
stub_ip
stub_ss
# Simulates oniux actually setting up its SOCKS proxy inside the namespace —
# the real ALL_PROXY the ordinary passthrough stub never sets.
cat > "$SANDBOX/bin/oniux" <<'EOF'
#!/usr/bin/env bash
export ALL_PROXY=socks5h://127.0.0.1:9050
exec "$@"
EOF
chmod +x "$SANDBOX/bin/oniux"
cat > "$SANDBOX/bin/curl" <<'EOF'
#!/usr/bin/env bash
url=""
for arg in "$@"; do case "$arg" in http://*|https://*) url="$arg" ;; esac; done
case "$url" in *check.torproject.org*) echo '{"IsTor":true,"IP":"185.220.101.1"}'; exit 0 ;; esac
[ -z "${CALYPSO_LEAK_TARGETS:-}" ] && exit 0   # host-side confirmation: always answers
# The masking effect a bypassed proxy exists to prevent: a probe still routed
# through Tor's SOCKS layer gets refused there, indistinguishable from a
# genuine kernel refusal — even when the target below is a real, reachable
# leak. Bypassing the proxy is what tells the two apart.
if [ -n "${ALL_PROXY:-}${all_proxy:-}" ]; then exit 1; fi
host="${url#http://}"; host="${host%%/*}"
for reachable in ${STUB_CURL_REACHABLE:-}; do [ "$reachable" = "$host" ] && exit 0; done
exit 1
EOF
chmod +x "$SANDBOX/bin/curl"
STUB_CURL_REACHABLE=10.9.9.42:22000 CALYPSO_BIN="$MUTANT_FILE" TEST_KEY=k run_calypso --profile default --yes || true
{
  echo "STATUS=$STATUS"
  echo "$OUTPUT"
} > "$WORK/out"
sandbox_teardown
# Same mirroring as mutant 1: the assertion is "a real, reachable leak target
# is still reported as LEAK DETECTED". Its absence — the deterministic result
# of this exact mutation, given the proxy-aware curl stub above — is the
# failing assertion, i.e. the killed mutant.
case "$OUTPUT" in
  *"LEAK DETECTED"*) status=0 ;; # the assertion held: no masking detected
  *) status=1 ;;                 # masked by the proxy: the flaw was caught
esac
record "a real leak is masked by the un-bypassed proxy (F10)" "$status"

# 6. curl exit-56 misclassification. Dropping 56 (data received, no reply)
# from the "connection completed" case makes a handshake look refused —
# scoring a real leak as sealed.
echo
echo "6. curl exit 56 stops counting as a completed handshake"
fresh_mutant
read -r inner_s inner_e < <(inner_range)
mutate 'curl exit-56 misclassification' '0 | 52 | 56) return 0 ;;' '0 | 52) return 0 ;;' 1 "$inner_s" "$inner_e"
s=0; run_suite leak.test.sh || s=$?
record "a handshake without a reply (curl 56) is no longer scored as a leak" "$s"

# 7. missing receipt evidence. Dropping the write to CALYPSO_EGRESS_FILE means
# the parent's handshake in run_with_evidence_handshake() has nothing to read,
# so the receipt cannot name the exit it verified.
echo
echo "7. the verified exit IP never reaches the receipt"
fresh_mutant
# shellcheck disable=SC2016  # literal launcher-source anchor, not an expression to expand
mutate 'missing receipt evidence' \
  'printf '"'"'%s\n'"'"' "$CALYPSO_EXIT_IP" > "$CALYPSO_EGRESS_FILE"' \
  'true # mutated: exit IP no longer recorded' \
  1
s=0; run_suite egress.test.sh || s=$?
record "the verified Tor exit never reaches the receipt" "$s"

# 8. disabled third-party-fetch protections. Removing the two exports lets the
# agent's default outbound calls to models.dev and its own update endpoint
# through — traffic that never reaches the receipt because Calypso is not in
# the request path.
echo
echo "8. third-party-fetch protections disabled"
fresh_mutant
mutate 'disabled third-party-fetch protections' \
  $'export OPENCODE_DISABLE_AUTOUPDATE=1\nexport OPENCODE_DISABLE_MODELS_FETCH=1\n' \
  $'# export OPENCODE_DISABLE_AUTOUPDATE=1  # mutated: third-party fetch protections disabled\n# export OPENCODE_DISABLE_MODELS_FETCH=1\n' \
  1
s=0; run_suite launch.test.sh || s=$?
record "the agent's default third-party fetches are no longer disabled" "$s"

# --- verdict ------------------------------------------------------------------

echo
if [ "${#SURVIVED[@]}" -gt 0 ]; then
  echo "   ${#SURVIVED[@]}/$TOTAL mutant(s) SURVIVED:"
  for name in "${SURVIVED[@]}"; do
    echo "     - $name"
  done
  exit 1
fi
echo "   $TOTAL/$TOTAL mutants killed"
