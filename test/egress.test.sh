#!/usr/bin/env bash
# The egress check: proving, from inside the namespace, that traffic leaves via Tor.
#
# This suite did not exist until 2026-07-26, while `launch.test.sh` claimed in a
# comment that egress was "covered in egress.test.sh". `run.sh` globs
# `test/*.test.sh`, so a suite that does not exist is silently zero tests — no error,
# no warning, and the comment was the only thing in the repo asserting the coverage.
#
# A mutation pass over the launcher found eight of ten deliberate breakages surviving
# a green run, and the pattern was not random: every mutation to the egress check and
# to what the receipt claims about Tor survived. Each test below kills one of them,
# and each was confirmed by re-introducing that breakage.
#
# Everything is stubbed: no Tor, no network, no real agent.
# shellcheck source=test/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

launch() {
  TEST_KEY=k run_calypso --profile default --yes "$@"
}

test_a_tor_exit_is_accepted_and_named() {
  write_profile
  stub_namespace
  launch
  assert_status 0
  assert_contains "egress verified — Tor exit 185.220.101.1"
  assert_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# Mutation: accept a non-Tor exit. The check answering at all means traffic left the
# machine; that it left unprotected is the whole thing this refuses.
test_a_non_tor_exit_refuses_the_launch() {
  write_profile
  stub_namespace
  STUB_EGRESS_ANSWERS='{"IsTor":false,"IP":"88.120.4.9"}' launch
  assert_status 1
  assert_contains "egress is NOT Tor"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# A definite negative must not be retried. Retrying implies it might pass, and it
# cannot — the answer arrived and said no.
test_a_non_tor_exit_is_not_retried() {
  write_profile
  stub_namespace
  STUB_EGRESS_ANSWERS='{"IsTor":false,"IP":"88.120.4.9"}' launch
  assert_status 1
  assert_not_contains "attempt 2/3"
}

# Mutation: accept any answer mentioning IsTor, true or false. A substring match on
# the field name rather than the value passes a payload that says the opposite.
test_an_answer_naming_istor_without_asserting_it_is_refused() {
  write_profile
  stub_namespace
  STUB_EGRESS_ANSWERS='{"IsTor":"maybe","IP":"9.9.9.9"}' launch
  assert_status 1
  assert_not_contains "egress verified"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# An empty or unparseable answer is a dead circuit, not a pass.
test_an_unusable_answer_refuses_the_launch() {
  write_profile
  stub_namespace
  STUB_EGRESS_ANSWERS='' launch
  assert_status 1
  assert_contains "could not confirm Tor egress"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# Mutation: cut the retry from three attempts to one. Roughly one circuit in three
# was dead in testing (F4), so a single attempt turns a working stack into a coin
# flip. Two failures then success must still launch.
test_the_retry_survives_two_dead_circuits() {
  write_profile
  stub_namespace
  STUB_EGRESS_FAIL_N=2 STUB_EGRESS_COUNTER="$SANDBOX/egress-attempts" launch
  assert_status 0
  assert_contains "attempt 1/3"
  assert_contains "attempt 2/3"
  assert_contains "egress verified — Tor exit 185.220.101.1"
  assert_equals "$(cat "$SANDBOX/egress-attempts")" "3"
}

# Three failures is the limit, and the message points at F4 rather than blaming the
# user's setup.
test_three_dead_circuits_refuse_the_launch() {
  write_profile
  stub_namespace
  STUB_EGRESS_FAIL_N=9 STUB_EGRESS_COUNTER="$SANDBOX/egress-attempts" launch
  assert_status 1
  assert_contains "could not confirm Tor egress in 3 attempts"
  assert_equals "$(cat "$SANDBOX/egress-attempts")" "3"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# Mutation: never record the exit IP. The receipt could then name no exit, or worse,
# name one it never saw. The stub answers 185.220.101.1 for exactly this assertion,
# which no test made until now.
test_the_verified_exit_ip_reaches_the_receipt() {
  write_profile
  stub_namespace
  launch
  assert_status 0
  case "$(receipt_body)" in
    *"exit 185.220.101.1"*) ;;
    *) _fail "the receipt does not name the exit IP the check verified" "$(receipt_body)" ;;
  esac
}

# Mutation: have the receipt assert a Tor exit on a session where nothing was
# verified. This is the receipt lying about the single fact it exists to certify, and
# it passed all 63 tests before this suite existed.
test_a_none_mode_receipt_never_claims_a_tor_exit() {
  write_profile
  stub_calypsocode_agent
  CALYPSO_NETWORK=none TEST_KEY=k run_calypso --profile default --yes
  assert_status 0
  case "$(receipt_body)" in
    *"verified IsTor"*) _fail "a none-mode receipt claims an egress check ran" "$(receipt_body)" ;;
    *"exit "*) _fail "a none-mode receipt names a Tor exit" "$(receipt_body)" ;;
    *) ;;
  esac
}

# --no-verify skips the check. The receipt must say so rather than stay silent, which
# a reader would take as a pass.
test_no_verify_receipt_says_the_egress_was_not_verified() {
  write_profile
  stub_namespace
  launch --no-verify
  assert_status 0
  case "$(receipt_body)" in
    *"NOT verified"*) ;;
    *) _fail "the receipt should say the egress was not verified" "$(receipt_body)" ;;
  esac
}

# Mutation: stop refusing when curl is absent. curl is what performs both the leak
# test and the egress check, so without it the session runs with no evidence at all —
# and the receipt would have no way to know.
test_a_missing_curl_refuses_the_launch() {
  write_profile
  stub_calypsocode_agent
  stub_oniux
  stub_ip
  stub_ss
  rm -f "$SANDBOX/bin/curl"
  stub_no_curl
  launch
  assert_status 1
  assert_contains "curl not found"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# And it must refuse for the right reason. Without the host-side guard the message
# would be "no target answered" — true, and a diagnosis pointing at the network rather
# than at the missing binary that made every target look unreachable.
test_a_missing_curl_does_not_masquerade_as_an_unreachable_network() {
  write_profile
  stub_calypsocode_agent
  stub_oniux
  stub_ip
  stub_ss
  rm -f "$SANDBOX/bin/curl"
  stub_no_curl
  launch
  assert_status 1
  assert_not_contains "no target on the host answered"
}

run_tests
