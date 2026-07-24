#!/usr/bin/env bash
# The receipt. This is the document whose entire job is to be true, so its
# failure modes matter more than most: a receipt for a session that never
# happened is a lie, and a missing receipt after Ctrl-C is a silent one.
# shellcheck source=test/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# shellcheck disable=SC2120  # arguments are optional
launch() {
  CALYPSO_NETWORK=none run_calypso --profile default --yes "$@"
}

test_completed_session_leaves_a_receipt() {
  write_profile
  stub_opencode
  TEST_KEY=k launch
  assert_status 0
  assert_equals "$(receipt_count)" "1"
}

test_receipt_states_what_was_not_removed() {
  write_profile
  stub_opencode
  TEST_KEY=k launch
  local body; body="$(receipt_body)"
  case "$body" in *"NOT removed"*) ;; *) _fail "receipt omits the NOT-removed block" "$body" ;; esac
  case "$body" in *"prompt content, source code, writing style"*) ;; *) _fail "receipt omits content limits" "$body" ;; esac
  case "$body" in *"session timing"*) ;; *) _fail "receipt omits session timing" "$body" ;; esac
  case "$body" in *"the provider"*) ;; *) _fail "receipt omits the account residual" "$body" ;; esac
}

test_receipt_names_the_compartment_and_identity() {
  write_profile
  stub_opencode
  TEST_KEY=k launch
  local body; body="$(receipt_body)"
  case "$body" in *"compartment:  testbox"*) ;; *) _fail "receipt omits compartment" "$body" ;; esac
  case "$body" in *"git dev <dev@localhost>"*) ;; *) _fail "receipt omits git identity" "$body" ;; esac
}

test_receipt_never_contains_the_key_value() {
  write_profile
  stub_opencode
  TEST_KEY=super-secret-value launch
  case "$(receipt_body)" in
    *super-secret-value*) _fail "the API key value leaked into the receipt" ;;
    *) return 0 ;;
  esac
}

test_none_mode_receipt_admits_there_was_no_isolation() {
  write_profile
  stub_opencode
  TEST_KEY=k launch
  case "$(receipt_body)" in
    *"network:      none"*) return 0 ;;
    *) _fail "receipt does not state that isolation was off" "$(receipt_body)" ;;
  esac
}

# A refused launch is not a session. Claiming "NOT removed: prompt content"
# when nothing was ever sent would be a receipt for something that never
# happened.
test_no_receipt_when_the_agent_never_started() {
  write_profile
  no_opencode
  TEST_KEY=k launch
  assert_status 127
  assert_equals "$(receipt_count)" "0"
  assert_contains "the agent never started"
}

test_no_receipt_when_the_key_is_missing() {
  write_profile
  stub_opencode
  launch
  assert_status 1
  assert_equals "$(receipt_count)" "0"
}

test_no_receipt_for_profile_or_doctor() {
  write_profile
  stub_opencode
  TEST_KEY=k run_calypso profile
  TEST_KEY=k run_calypso doctor
  assert_equals "$(receipt_count)" "0"
}

test_marker_files_are_cleaned_up() {
  write_profile
  stub_opencode
  TEST_KEY=k launch
  local leftovers
  leftovers="$(find "$SANDBOX/state" -maxdepth 1 -name '.egress-*' -o -maxdepth 1 -name '.started-*' 2>/dev/null | wc -l | tr -d ' ')"
  assert_equals "$leftovers" "0"
}

# Ctrl-C is how an agent session normally ends, so the receipt has to survive
# it. Measured on bash 5.3: an EXIT trap *does* run on an untrapped SIGINT, so
# the receipt itself is not what the explicit INT/TERM traps buy. What they buy
# is a correct exit status — without them a signalled launcher can report 0,
# claiming success for an interrupted session. Both properties are asserted:
# the group test covers a real Ctrl-C, the direct test covers the status.
_signal_test() {
  local sig="$1" want_status="$2"
  write_profile
  cat > "$SANDBOX/bin/opencode" <<'EOF'
#!/usr/bin/env bash
echo "STUB_OPENCODE_RAN"
sleep 3
EOF
  chmod +x "$SANDBOX/bin/opencode"

  # Job control matters here. Without `set -m`, a background job started by a
  # non-interactive shell inherits SIGINT as ignored, so no trap can fire and
  # the test would pass or fail for the wrong reason. With it, the launcher
  # leads its own process group and we can signal that group — which is what
  # a terminal does on Ctrl-C, agent included.
  set -m
  CALYPSO_NETWORK=none TEST_KEY=k "$CALYPSO_BIN" --profile default --yes > "$SANDBOX/out" 2>&1 &
  local pid=$!
  set +m

  local waited=0
  while ! grep -q STUB_OPENCODE_RAN "$SANDBOX/out" 2>/dev/null; do
    sleep 0.2
    waited=$((waited + 1))
    [ "$waited" -gt 50 ] && break
  done

  kill -"$sig" -"$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  STATUS=$?
  OUTPUT="$(cat "$SANDBOX/out")"

  assert_status "$want_status"
  assert_equals "$(receipt_count)" "1"
}

test_sigint_still_writes_exactly_one_receipt() { _signal_test INT 130; }
test_sigterm_still_writes_exactly_one_receipt() { _signal_test TERM 143; }

# Signalling the launcher alone, rather than the process group. Without an
# explicit INT trap bash exits 0 here — reporting success for a session the
# user interrupted. This is the case that fails if the traps are removed.
_direct_signal_test() {
  local sig="$1" want_status="$2"
  write_profile
  cat > "$SANDBOX/bin/opencode" <<'EOF'
#!/usr/bin/env bash
echo "STUB_OPENCODE_RAN"
sleep 3
EOF
  chmod +x "$SANDBOX/bin/opencode"

  set -m
  CALYPSO_NETWORK=none TEST_KEY=k "$CALYPSO_BIN" --profile default --yes > "$SANDBOX/out" 2>&1 &
  local pid=$!
  set +m

  local waited=0
  while ! grep -q STUB_OPENCODE_RAN "$SANDBOX/out" 2>/dev/null; do
    sleep 0.2
    waited=$((waited + 1))
    [ "$waited" -gt 50 ] && break
  done

  kill -"$sig" "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  STATUS=$?
  OUTPUT="$(cat "$SANDBOX/out")"

  assert_status "$want_status"
}

test_interrupted_session_does_not_report_success() { _direct_signal_test INT 130; }
test_terminated_session_does_not_report_success() { _direct_signal_test TERM 143; }

run_tests
