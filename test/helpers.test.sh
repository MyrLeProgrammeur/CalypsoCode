#!/usr/bin/env bash
# Self-tests for the test harness itself (test/helpers.sh). run_tests() tracks
# one result per test FUNCTION rather than per assertion, and a test whose
# prerequisite is missing must show up as skipped rather than as a silent
# pass. Both properties are easy to get subtly wrong, so they get their own
# suite: each of the three scenarios (a pass, a failure with several failed
# assertions, and a skip) is run in an isolated sub-shell that defines its own
# throwaway test_* functions and calls run_tests(), and this suite asserts on
# that sub-shell's captured output and exit status.
# shellcheck source=test/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

_run_harness_scenario() {
  local body="$1"
  bash -c "
    source '$REPO_ROOT/test/helpers.sh'
    $body
    run_tests
  "
}

test_one_passing_test_is_counted_as_one_pass() {
  local out status
  out="$(_run_harness_scenario 'test_ok() { assert_equals 1 1; }')"
  status=$?
  assert_equals "$status" "0"
  case "$out" in
    *"1/1 passed"*) ;;
    *) _fail "expected a 1/1 pass summary" "$out" ;;
  esac
  case "$out" in *FAILED*) _fail "a passing test must not be reported as failed" "$out" ;; esac
  case "$out" in *skipped*) _fail "a passing test must not be reported as skipped" "$out" ;; esac
}

# Several failed assertions inside one test function must still count as ONE
# failed test, not several — otherwise passed+failed+skipped can exceed the
# number of test functions actually run.
test_one_failure_with_several_assertions_counts_once() {
  local out status
  out="$(_run_harness_scenario 'test_broken() { assert_equals 1 2; assert_equals 3 4; assert_equals 5 6; }')"
  status=$?
  assert_equals "$status" "1"
  case "$out" in
    *"0/1 passed, 1 FAILED"*) ;;
    *) _fail "one test function with three failed assertions must count as one failed test" "$out" ;;
  esac
  # All three assertion failures are still individually reported.
  local fail_lines
  fail_lines="$(printf '%s\n' "$out" | grep -c 'FAIL  test_broken')"
  assert_equals "$fail_lines" "3"
}

test_a_skip_is_counted_separately_from_pass_and_fail() {
  local out status
  out="$(_run_harness_scenario 'test_missing_prereq() { skip "prerequisite not installed"; return 0; }')"
  status=$?
  assert_equals "$status" "0"
  case "$out" in
    *"0/1 passed, 1 skipped"*) ;;
    *) _fail "expected a skip to be its own bucket, not a pass" "$out" ;;
  esac
  case "$out" in *FAILED*) _fail "a skipped test must not be reported as failed" "$out" ;; esac
}

# passed + failed + skipped must always equal the number of test functions run.
test_totals_always_add_up() {
  local out status
  out="$(_run_harness_scenario '
    test_a_ok() { assert_equals 1 1; }
    test_b_broken() { assert_equals 1 2; assert_equals 3 4; }
    test_c_skipped() { skip "no prereq"; return 0; }
    test_d_ok() { assert_equals 2 2; }
  ')"
  status=$?
  assert_equals "$status" "1"
  case "$out" in
    *"2/4 passed, 1 skipped, 1 FAILED"*) ;;
    *) _fail "expected 2 passed, 1 skipped, 1 failed out of 4 test functions" "$out" ;;
  esac
}

# Item 12: sandbox_setup must sanitize every launcher-facing, provider and
# identity variable before a test runs, not just the two names it used to
# unset. Proven end to end here: the same real suite (profile.test.sh — fast,
# and touches profile/network reporting) run once from a clean environment and
# once from a deliberately polluted one must produce an identical result. An
# inherited CALYPSO_NETWORK=none, for instance, used to silently change which
# branch of a suite ran.
test_a_polluted_environment_produces_the_same_result_as_a_clean_one() {
  local clean polluted
  clean="$(env -i PATH="$PATH" HOME="$HOME" bash "$REPO_ROOT/test/profile.test.sh" 2>&1)"
  polluted="$(
    CALYPSO_NETWORK=none \
    CALYPSO_HOME=/nonexistent/bogus-calypso-home \
    CALYPSO_PROFILE_DIR=/nonexistent/bogus-profiles \
    CALYPSO_STATE_DIR=/nonexistent/bogus-state \
    OPENCODE_DISABLE_AUTOUPDATE=0 \
    XDG_CONFIG_HOME=/nonexistent/bogus-xdg \
    http_proxy=http://bogus-proxy.invalid:9 \
    https_proxy=http://bogus-proxy.invalid:9 \
    GIT_AUTHOR_NAME="Polluted Dev" \
    GIT_AUTHOR_EMAIL="polluted@invalid" \
    TEST_KEY="developer-shell-leftover-key" \
    bash "$REPO_ROOT/test/profile.test.sh" 2>&1
  )"
  assert_equals "$polluted" "$clean"
}

run_tests
