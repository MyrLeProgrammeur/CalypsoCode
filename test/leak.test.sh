#!/usr/bin/env bash
# The negative leak test: the check that deliberately attempts what must fail.
#
# These run with NETWORK=tor and a stubbed namespace — oniux runs the command,
# curl decides what is reachable. No Tor, no network, no real agent. What is
# under test is the launcher's reaction to a compartment that is not sealed,
# which cannot be produced on demand with a real namespace.
# shellcheck source=test/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

launch() {
  TEST_KEY=k run_calypso --profile default --yes "$@"
}

test_passes_when_the_lan_is_unreachable() {
  write_profile
  stub_namespace
  launch
  assert_status 0
  assert_contains "leak test passed"
  # The gateway on 80 and 443, plus the host address on the port stub_ss reports as
  # listening on every interface. The loopback-only listener is deliberately absent.
  assert_contains "3 target(s) that answer from the"
  assert_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# The whole point of the test: a reachable private address means the namespace
# is not sealed, and every claim the receipt would make about isolation is false.
test_a_reachable_private_address_refuses_the_launch() {
  write_profile
  stub_namespace
  STUB_CURL_REACHABLE=10.9.9.42:22000 launch
  assert_status 1
  assert_contains "LEAK DETECTED"
  assert_contains "10.9.9.42:22000"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# A refused launch sent nothing, so it is not a session and owes no receipt.
test_a_detected_leak_writes_no_receipt() {
  write_profile
  stub_namespace
  STUB_CURL_REACHABLE=10.9.9.1:80 launch
  assert_status 1
  assert_equals "$(receipt_count)" "0"
}

test_force_unsafe_launches_anyway() {
  write_profile
  stub_namespace
  STUB_CURL_REACHABLE=10.9.9.42:22000 launch --force-unsafe
  assert_status 0
  assert_contains "LEAK DETECTED"
  assert_contains "--force-unsafe given"
  assert_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# Forcing past a leak must be visible afterwards, not only in the terminal
# scrollback of the moment.
test_force_unsafe_is_recorded_in_the_receipt() {
  write_profile
  stub_namespace
  STUB_CURL_REACHABLE=10.9.9.42:22000 launch --force-unsafe
  assert_status 0
  case "$(receipt_body)" in
    *"NOT isolated from your own network"*) ;;
    *) _fail "the receipt does not record that the session was forced past a leak" \
             "$(receipt_body)" ;;
  esac
}

# The flag is read from argv and exported unconditionally, so an environment
# variable of the same name is overwritten rather than obeyed. Otherwise one
# line in a shell profile would silently disable the check forever.
test_force_unsafe_cannot_come_from_the_environment() {
  write_profile
  stub_namespace
  CALYPSO_FORCE_UNSAFE=1 STUB_CURL_REACHABLE=10.9.9.42:22000 launch
  assert_status 1
  assert_contains "LEAK DETECTED"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# A test that could not run is not a test that passed — the mistake the first
# doctor made, and the reason it must never be repeated here.
test_no_discoverable_target_refuses_the_launch() {
  write_profile
  stub_calypsocode_agent
  stub_oniux
  stub_ip_empty
  stub_curl
  launch
  assert_status 1
  assert_contains "no target on the host answered"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# The defect this rewrite exists to fix. A target with nothing listening returns the
# same "did not answer" whether the namespace is sealed or wide open, so it cannot fail
# the test and must never be counted as evidence. Made deaf on the host here; it should
# be dropped before the namespace ever sees it.
test_a_target_the_host_cannot_reach_is_not_counted_as_evidence() {
  write_profile
  stub_namespace
  STUB_CURL_HOST_DEAF="10.9.9.1:80 10.9.9.1:443" launch
  assert_status 0
  assert_contains "1 target(s) that answer from the"
  assert_not_contains "3 target(s)"
}

# If every candidate is deaf on the host, there is nothing to prove and the launcher
# must refuse rather than report a pass over zero evidence.
test_all_targets_deaf_on_the_host_refuses_the_launch() {
  write_profile
  stub_namespace
  STUB_CURL_HOST_DEAF="10.9.9.1:80 10.9.9.1:443 10.9.9.42:22000" launch
  assert_status 1
  assert_contains "no target on the host answered"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# A timeout is not a refusal. The old check counted every non-zero curl exit as
# unreachable, so a slow host swallowing the connect read as sealed — the one bias a
# check like this must never have.
test_a_timing_out_target_is_inconclusive_and_refuses_the_launch() {
  write_profile
  stub_namespace
  STUB_CURL_TIMEOUT=10.9.9.42:22000 launch
  assert_status 1
  assert_contains "leak test inconclusive"
  assert_not_contains "leak test passed"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# A completed handshake is a leak even when nothing useful came back. curl 52 and 56
# both mean the connection was made, and both used to be scored as sealed.
test_a_handshake_without_a_reply_is_still_a_leak() {
  write_profile
  stub_namespace
  cat > "$SANDBOX/bin/curl" <<'EOF'
#!/usr/bin/env bash
url=""
for arg in "$@"; do case "$arg" in http://*|https://*) url="$arg" ;; esac; done
case "$url" in *check.torproject.org*) echo '{"IsTor":true,"IP":"185.220.101.1"}'; exit 0 ;; esac
[ -z "${CALYPSO_LEAK_TARGETS:-}" ] && exit 0
host="${url#http://}"; host="${host%%/*}"
[ "$host" = "10.9.9.42:22000" ] && exit 56
exit 7
EOF
  chmod +x "$SANDBOX/bin/curl"
  launch
  assert_status 1
  assert_contains "LEAK DETECTED"
  assert_contains "10.9.9.42:22000"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

test_receipt_records_a_passed_leak_test() {
  write_profile
  stub_namespace
  launch
  assert_status 0
  case "$(receipt_body)" in
    *"leak test passed"*) ;;
    *) _fail "the receipt does not record the leak test result" "$(receipt_body)" ;;
  esac
}

# --no-verify skips the check. The receipt must not imply it passed.
test_no_verify_receipt_says_the_test_did_not_run() {
  write_profile
  stub_namespace
  launch --no-verify
  assert_status 0
  case "$(receipt_body)" in
    *"leak test NOT RUN"*) ;;
    *) _fail "the receipt should say the leak test did not run" "$(receipt_body)" ;;
  esac
}

run_tests
