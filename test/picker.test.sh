#!/usr/bin/env bash
# The first-run picker. Its job is to replace a cryptic "copy this file and edit
# it" with a choice the user actually understands — without ever making that
# choice for them, and without claiming a backend works before anything has run.
#
# Hermetic: no network, no Tor, no real agent. The interactive paths run through
# a pseudo-terminal, so `[ -t 0 ]` is satisfied without a human.
# shellcheck source=test/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Backend, API base, model, key variable, compartment, git name, git email.
ANSWERS_TOR='1
https://api.example.invalid/v1
test-model
TEST_KEY
testbox
dev
dev@localhost
'

profile_path() { echo "$CALYPSO_PROFILE_DIR/default.env"; }

test_picker_writes_a_profile_from_the_answers() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR"
  assert_file_exists "$(profile_path)"
  local body
  body="$(cat "$(profile_path)")"
  case "$body" in *"NETWORK=tor"*) ;; *) _fail "backend not written" "$body" ;; esac
  case "$body" in *"API_BASE=https://api.example.invalid/v1"*) ;; *) _fail "api base not written" "$body" ;; esac
  case "$body" in *"MODEL=test-model"*) ;; *) _fail "model not written" "$body" ;; esac
  case "$body" in *"PROFILE=testbox"*) ;; *) _fail "compartment not written" "$body" ;; esac
}

# The choice has exactly one home. A remembered default living anywhere else is
# how a profile that says `tor` ends up running something quieter.
test_the_choice_is_stored_only_in_the_profile() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR"
  assert_file_exists "$(profile_path)"
  local strays
  strays="$(find "$CALYPSO_HOME" "$CALYPSO_STATE_DIR" -type f \
    -exec grep -l 'NETWORK' {} + 2>/dev/null || true)"
  assert_equals "$strays" ""
}

# The profile names the variable; the secret stays in the environment.
test_the_key_value_is_never_written_to_the_profile() {
  have_pty || return 0
  stub_namespace
  TEST_KEY=super-secret-value run_calypso_tty "$ANSWERS_TOR"
  local body
  body="$(cat "$(profile_path)")"
  case "$body" in
    *super-secret-value*) _fail "the key value was written to the profile" "$body" ;;
  esac
  case "$body" in *"API_KEY_ENV=TEST_KEY"*) ;; *) _fail "the key variable name is missing" "$body" ;; esac
}

# Offering something that does not exist would be the picker lying in its very
# first sentence.
test_a_backend_that_is_not_built_is_refused_and_re_asked() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "3
2
https://api.example.invalid/v1
test-model
TEST_KEY
testbox
dev
dev@localhost
"
  assert_contains "Not built yet"
  local body
  body="$(cat "$(profile_path)")"
  case "$body" in *"NETWORK=none"*) ;; *) _fail "the second choice was not honoured" "$body" ;; esac
}

# A binary on disk is not a working stack. Claiming otherwise is what the first
# doctor did, and the picker must not reintroduce it in colour.
test_tor_is_offered_as_installed_but_unverified() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR"
  assert_contains "oniux installed, not yet verified"
  assert_not_contains "everything is ready"
}

test_tor_is_marked_unavailable_when_oniux_is_missing() {
  have_pty || return 0
  stub_calypsocode_agent
  stub_ip
  stub_curl
  run_calypso_tty "2
https://api.example.invalid/v1
test-model
TEST_KEY
testbox
dev
dev@localhost
"
  assert_contains "UNAVAILABLE — oniux is not installed"
}

test_socks_is_not_sold_as_a_faster_tor() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR"
  assert_contains "not \"Tor but faster\""
}

# Without someone to ask, the picker must refuse rather than choose. A silent
# default here would be a leak with a friendly face.
test_no_tty_refuses_instead_of_picking() {
  stub_namespace
  OUTPUT="$("$CALYPSO_BIN" < /dev/null 2>&1)"
  STATUS=$?
  assert_status 1
  assert_contains "not found"
  assert_no_file "$(profile_path)"
}

# --yes means "do not ask me", which cannot mean "choose a backend for me".
test_yes_refuses_instead_of_picking() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR" --yes
  assert_status 1
  assert_no_file "$(profile_path)"
}

# `doctor` reports; it does not create things behind the user's back.
test_doctor_does_not_trigger_the_picker() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR" doctor
  assert_no_file "$(profile_path)"
}

run_tests
