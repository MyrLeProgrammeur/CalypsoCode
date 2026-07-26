#!/usr/bin/env bash
# `--new-profile`. Its job is to replace a cryptic "copy this file and edit it"
# with a choice the user actually understands — without ever making that choice
# for them, and without claiming a backend works before anything has run.
#
# It is deliberately not reachable from the launch path: naming a profile that
# does not exist has to report that, not build a compartment under the typo.
#
# Hermetic: no network, no Tor, no real agent. The interactive paths run through
# a pseudo-terminal, so `[ -t 0 ]` is satisfied without a human.
# shellcheck source=test/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

# Backend, API base, model, extra models (blank), key variable, compartment,
# git name, git email.
ANSWERS_TOR='1
https://api.example.invalid/v1
test-model

TEST_KEY
testbox
dev
dev@localhost
'

profile_path() { echo "$CALYPSO_PROFILE_DIR/default.env"; }

# Writes a compartment worth cloning: `none` so the copy needs no oniux.
write_source_profile() {
  write_profile source \
    "PROFILE=source" \
    "NETWORK=none" \
    "API_KEY_ENV=SOURCE_KEY" \
    "API_BASE=https://api.example.invalid/v1" \
    "MODEL=test-model" \
    "MODELS=alt-a, alt-b" \
    "GIT_NAME=dev" \
    "GIT_EMAIL=dev@localhost"
}

test_new_profile_writes_a_profile_from_the_answers() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR" --new-profile default
  assert_file_exists "$(profile_path)"
  local body
  body="$(cat "$(profile_path)")"
  case "$body" in *"NETWORK=tor"*) ;; *) _fail "backend not written" "$body" ;; esac
  case "$body" in *"API_BASE=https://api.example.invalid/v1"*) ;; *) _fail "api base not written" "$body" ;; esac
  case "$body" in *"MODEL=test-model"*) ;; *) _fail "model not written" "$body" ;; esac
  case "$body" in *"PROFILE=testbox"*) ;; *) _fail "compartment not written" "$body" ;; esac
}

# Creating and entering a compartment are separate acts. Merging them is what
# turned a mistyped --profile into a new compartment.
test_new_profile_does_not_launch() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR" --new-profile default
  assert_file_exists "$(profile_path)"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# MODELS is what the in-session picker offers. The wizard used to drop it
# silently, so a profile it wrote could never offer a second model.
test_extra_models_are_written_when_given() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty '1
https://api.example.invalid/v1
test-model
alt-a, alt-b
TEST_KEY
testbox
dev
dev@localhost
' --new-profile default
  local body
  body="$(cat "$(profile_path)")"
  case "$body" in *"MODELS=alt-a, alt-b"*) ;; *) _fail "extra models not written" "$body" ;; esac
}

test_no_extra_models_writes_no_models_line() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR" --new-profile default
  local body
  body="$(cat "$(profile_path)")"
  case "$body" in *MODELS=*) _fail "an empty answer still wrote a MODELS line" "$body" ;; esac
}

# --- a mistyped --profile ---------------------------------------------------

# The whole reason creation moved out of the launch path.
test_a_missing_profile_is_an_error_not_an_invitation() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR" --profile gaet
  assert_status 1
  assert_contains "profile 'gaet' not found"
  assert_contains "--new-profile gaet"
  assert_not_contains "Backend [1]"
  assert_no_file "$CALYPSO_PROFILE_DIR/gaet.env"
}

# Seeing the real names beside the typo is what identifies it as one.
test_a_missing_profile_names_the_profiles_that_exist() {
  write_source_profile
  run_calypso --profile gaet
  assert_status 1
  assert_contains "existing:"
  assert_contains "source"
}

test_a_missing_profile_says_so_when_there_are_none() {
  run_calypso --profile gaet
  assert_status 1
  assert_contains "none yet"
}

# --- --from -----------------------------------------------------------------

# What describes the provider carries over; what identifies you does not.
test_from_copies_the_network_and_the_provider() {
  have_pty || return 0
  stub_namespace
  write_source_profile
  run_calypso_tty 'NEW_KEY
perso
dev
dev@localhost
' --new-profile perso --from source
  local body
  body="$(cat "$CALYPSO_PROFILE_DIR/perso.env")"
  case "$body" in *"NETWORK=none"*) ;; *) _fail "network not copied" "$body" ;; esac
  case "$body" in *"MODEL=test-model"*) ;; *) _fail "model not copied" "$body" ;; esac
  case "$body" in *"MODELS=alt-a, alt-b"*) ;; *) _fail "extra models not copied" "$body" ;; esac
  assert_not_contains "Backend [1]"
}

# Two compartments sharing a key are one customer to the provider, so the key
# variable is asked for again rather than copied.
test_from_does_not_copy_the_key_variable() {
  have_pty || return 0
  stub_namespace
  write_source_profile
  run_calypso_tty 'NEW_KEY
perso
dev
dev@localhost
' --new-profile perso --from source
  local body
  body="$(cat "$CALYPSO_PROFILE_DIR/perso.env")"
  case "$body" in *"API_KEY_ENV=NEW_KEY"*) ;; *) _fail "the new key variable was not used" "$body" ;; esac
  case "$body" in *SOURCE_KEY*) _fail "the source's key variable was copied" "$body" ;; esac
}

test_from_without_new_profile_is_refused() {
  run_calypso --from source
  assert_status 1
  assert_contains "--from only means something together with --new-profile"
}

# --- refusals ---------------------------------------------------------------

test_an_existing_profile_is_never_overwritten() {
  write_source_profile
  run_calypso --new-profile source
  assert_status 1
  assert_contains "already exists"
}

# The name becomes a path, so it is validated before anything is written.
test_a_name_that_climbs_out_of_the_profile_directory_is_refused() {
  run_calypso --new-profile ../evil
  assert_status 1
  assert_contains "letters, digits, dot, dash and underscore only"
  assert_no_file "$SANDBOX/evil.env"
}

test_a_name_that_hides_from_a_listing_is_refused() {
  run_calypso --new-profile .hidden
  assert_status 1
  assert_no_file "$CALYPSO_PROFILE_DIR/.hidden.env"
}

# --yes means "do not ask me", which cannot mean "choose a backend for me".
test_yes_cannot_answer_the_questions() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR" --new-profile default --yes
  assert_status 1
  assert_no_file "$(profile_path)"
}

# Naming a profile to write and one to launch in the same command is a mistake,
# not a preference to resolve silently.
test_new_profile_and_profile_together_are_refused() {
  run_calypso --new-profile perso --profile source
  assert_status 1
  assert_contains "Pass one of them"
  assert_no_file "$CALYPSO_PROFILE_DIR/perso.env"
}

# Without someone to ask, refuse rather than choose. A silent default here
# would be a leak with a friendly face.
test_no_tty_refuses_instead_of_picking() {
  stub_namespace
  OUTPUT="$("$CALYPSO_BIN" --new-profile default < /dev/null 2>&1)"
  STATUS=$?
  assert_status 1
  assert_contains "not a terminal"
  assert_no_file "$(profile_path)"
}

# --- what the picker says ---------------------------------------------------

# A binary on disk is not a working stack. Claiming otherwise is what the first
# doctor did, and the picker must not reintroduce it in colour.
test_tor_is_offered_as_installed_but_unverified() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR" --new-profile default
  assert_contains "oniux installed, not yet verified"
  assert_not_contains "everything is ready"
}

test_tor_is_marked_unavailable_when_oniux_is_missing() {
  have_pty || return 0
  stub_calypsocode_agent
  stub_ip
  stub_curl
  run_calypso_tty '2
https://api.example.invalid/v1
test-model

TEST_KEY
testbox
dev
dev@localhost
' --new-profile default
  assert_contains "UNAVAILABLE — oniux is not installed"
}

# Offering something that does not exist would be the picker lying in its very
# first sentence.
test_a_backend_that_is_not_built_is_refused_and_re_asked() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty '3
2
https://api.example.invalid/v1
test-model

TEST_KEY
testbox
dev
dev@localhost
' --new-profile default
  assert_contains "Not built yet"
  local body
  body="$(cat "$(profile_path)")"
  case "$body" in *"NETWORK=none"*) ;; *) _fail "the second choice was not honoured" "$body" ;; esac
}

test_socks_is_not_sold_as_a_faster_tor() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR" --new-profile default
  assert_contains "not \"Tor but faster\""
}

# The choice has exactly one home. A remembered default living anywhere else is
# how a profile that says `tor` ends up running something quieter.
test_the_choice_is_stored_only_in_the_profile() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR" --new-profile default
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
  TEST_KEY=super-secret-value run_calypso_tty "$ANSWERS_TOR" --new-profile default
  local body
  body="$(cat "$(profile_path)")"
  case "$body" in
    *super-secret-value*) _fail "the key value was written to the profile" "$body" ;;
  esac
  case "$body" in *"API_KEY_ENV=TEST_KEY"*) ;; *) _fail "the key variable name is missing" "$body" ;; esac
}

# `doctor` reports; it does not create things behind the user's back.
test_doctor_does_not_create_a_profile() {
  have_pty || return 0
  stub_namespace
  run_calypso_tty "$ANSWERS_TOR" doctor
  assert_no_file "$(profile_path)"
}

run_tests
