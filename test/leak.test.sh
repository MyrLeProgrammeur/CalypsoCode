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
  assert_contains "2 private target(s) unreachable"
  assert_contains "STUB_OPENCODE_RAN"
}

# The whole point of the test: a reachable private address means the namespace
# is not sealed, and every claim the receipt would make about isolation is false.
test_a_reachable_private_address_refuses_the_launch() {
  write_profile
  stub_namespace
  STUB_CURL_REACHABLE=10.9.9.42 launch
  assert_status 1
  assert_contains "LEAK DETECTED"
  assert_contains "10.9.9.42"
  assert_not_contains "STUB_OPENCODE_RAN"
}

# A refused launch sent nothing, so it is not a session and owes no receipt.
test_a_detected_leak_writes_no_receipt() {
  write_profile
  stub_namespace
  STUB_CURL_REACHABLE=10.9.9.1 launch
  assert_status 1
  assert_equals "$(receipt_count)" "0"
}

test_force_unsafe_launches_anyway() {
  write_profile
  stub_namespace
  STUB_CURL_REACHABLE=10.9.9.42 launch --force-unsafe
  assert_status 0
  assert_contains "LEAK DETECTED"
  assert_contains "--force-unsafe given"
  assert_contains "STUB_OPENCODE_RAN"
}

# Forcing past a leak must be visible afterwards, not only in the terminal
# scrollback of the moment.
test_force_unsafe_is_recorded_in_the_receipt() {
  write_profile
  stub_namespace
  STUB_CURL_REACHABLE=10.9.9.42 launch --force-unsafe
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
  CALYPSO_FORCE_UNSAFE=1 STUB_CURL_REACHABLE=10.9.9.42 launch
  assert_status 1
  assert_contains "LEAK DETECTED"
  assert_not_contains "STUB_OPENCODE_RAN"
}

# A test that could not run is not a test that passed — the mistake the first
# doctor made, and the reason it must never be repeated here.
test_no_discoverable_target_refuses_the_launch() {
  write_profile
  stub_opencode
  stub_oniux
  stub_ip_empty
  stub_curl
  launch
  assert_status 1
  assert_contains "no private addresses were found"
  assert_not_contains "STUB_OPENCODE_RAN"
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
