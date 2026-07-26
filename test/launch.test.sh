#!/usr/bin/env bash
# Launch path: identity environment, compartment isolation, and refusing to
# start when the compartment is not complete.
#
# These run with CALYPSO_NETWORK=none so they need neither Tor nor the network.
# What `none` skips is egress verification — covered in egress.test.sh.
# shellcheck source=test/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

launch() {
  CALYPSO_NETWORK=none run_calypso --profile default --yes "$@"
}

test_missing_key_refuses_to_launch() {
  write_profile
  stub_calypsocode_agent
  launch
  assert_status 1
  assert_contains "TEST_KEY is empty or unset"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

test_identity_environment_reaches_the_agent() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch
  assert_status 0
  assert_contains "ENV LC_ALL=C"
  assert_contains "ENV LANG=C"
  assert_contains "ENV TZ=UTC"
  assert_contains "ENV GIT_AUTHOR_NAME=dev"
  assert_contains "ENV GIT_AUTHOR_EMAIL=dev@localhost"
  assert_contains "ENV GIT_COMMITTER_NAME=dev"
  assert_contains "ENV GIT_COMMITTER_EMAIL=dev@localhost"
  assert_contains "ENV TEST_KEY=k"
}

# F9: config alone is not the compartment. Data and state must move too, or
# session history and stored credentials cross between compartments.
test_all_compartment_paths_move_together() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch
  assert_status 0
  assert_contains "ENV XDG_CONFIG_HOME=$CALYPSO_HOME/compartments/testbox"
  assert_contains "ENV XDG_DATA_HOME=$CALYPSO_HOME/compartments/testbox/data"
  assert_contains "ENV XDG_STATE_HOME=$CALYPSO_HOME/compartments/testbox/state"
}

test_agent_arguments_are_passed_through() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch run "fix the bug"
  assert_status 0
  assert_contains "STUB_CALYPSOCODE_AGENT_RAN args=run fix the bug"
}

test_generated_agent_config_matches_the_profile() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch
  local cfg="$CALYPSO_HOME/compartments/testbox/opencode.calypso.json"
  assert_file_exists "$cfg"
  python3 -m json.tool "$cfg" > /dev/null || _fail "generated config is not valid JSON"
  grep -q '"baseURL": "https://api.example.invalid/v1"' "$cfg" || _fail "baseURL not from profile"
  grep -q '"apiKey": "{env:TEST_KEY}"' "$cfg" || _fail "apiKey should reference the env var by name"
  grep -q '"model": "calypsocode/test-model"' "$cfg" || _fail "model not from profile"
}

# The path leak Calypso does not fix, so the least it can do is say so. Uses the
# real username rather than a fixture, because that is what the check reads and a
# fixture would pass while the real thing broke.
#
# The mirror case — a username that IS the documented neutral convention, where
# the warning must NOT appear — is not covered here: the suite cannot change what
# `id -un` returns, and giving the launcher an env var to override its own idea of
# your username would put a switch in a privacy tool that can hide a real leak.
test_username_in_the_project_path_is_reported() {
  write_profile
  stub_calypsocode_agent
  local dir
  dir="$CALYPSO_HOME/$(id -un)-project"
  mkdir -p "$dir"
  local back="$PWD"
  cd "$dir" || _fail "could not enter the test project directory"
  TEST_KEY=k launch
  cd "$back" || true
  assert_status 0
  assert_contains "contains your OS username"
}

# MODELS exists so the agent's own picker has something to pick from: the
# generated config used to list exactly one model, which made that picker
# useless inside a compartment.
test_extra_models_reach_the_generated_config() {
  write_profile testbox \
    "PROFILE=testbox" "NETWORK=none" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://api.example.invalid/v1" "MODEL=test-model" \
    "MODELS=second-model, third-model" "GIT_NAME=dev" "GIT_EMAIL=dev@localhost"
  stub_calypsocode_agent
  TEST_KEY=k launch --profile testbox
  local cfg="$CALYPSO_HOME/compartments/testbox/opencode.calypso.json"
  assert_file_exists "$cfg"
  python3 -m json.tool "$cfg" > /dev/null || _fail "generated config is not valid JSON"
  grep -q '"second-model": {}' "$cfg" || _fail "MODELS entry missing from the config"
  grep -q '"third-model": {}' "$cfg" || _fail "comma-separated MODELS entry missing"
  # MODEL stays what the session opens on, however many others are offered.
  grep -q '"model": "calypsocode/test-model"' "$cfg" || _fail "MODEL is no longer the default"
}

# A model named twice must not produce duplicate JSON keys.
test_model_repeated_in_models_is_not_duplicated() {
  write_profile testbox \
    "PROFILE=testbox" "NETWORK=none" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://api.example.invalid/v1" "MODEL=test-model" \
    "MODELS=test-model,other-model" "GIT_NAME=dev" "GIT_EMAIL=dev@localhost"
  stub_calypsocode_agent
  TEST_KEY=k launch --profile testbox
  local cfg="$CALYPSO_HOME/compartments/testbox/opencode.calypso.json"
  python3 -m json.tool "$cfg" > /dev/null || _fail "generated config is not valid JSON"
  local n
  n="$(grep -c '"test-model": {}' "$cfg")"
  [ "$n" = 1 ] || _fail "test-model listed $n times, expected once"
}

# The key must never be written into a config file that lives on disk.
test_generated_config_never_contains_the_key_value() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=super-secret-value launch
  local cfg="$CALYPSO_HOME/compartments/testbox/opencode.calypso.json"
  grep -q "super-secret-value" "$cfg" && _fail "the API key value was written to disk"
  return 0
}

test_none_mode_warns_that_there_is_no_isolation() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch
  assert_contains "WARNING"
  assert_contains "No isolation"
}

test_missing_agent_fails_clearly() {
  write_profile
  no_calypsocode_agent
  TEST_KEY=k launch
  assert_status 127
  assert_contains "calypsocode-agent not found"
}

test_agent_exit_status_is_propagated() {
  write_profile
  stub_calypsocode_agent 42
  TEST_KEY=k launch
  assert_status 42
}

test_startup_check_reports_what_will_be_used() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch
  assert_contains "compartment 'testbox'"
  assert_contains "git identity   dev <dev@localhost>"
  assert_contains "account        \$TEST_KEY"
}

# Without a terminal the confirmation cannot be given, so it must refuse
# rather than hang or silently proceed.
test_no_tty_without_yes_refuses() {
  write_profile
  stub_calypsocode_agent
  OUTPUT="$(CALYPSO_NETWORK=none TEST_KEY=k "$CALYPSO_BIN" --profile default < /dev/null 2>&1)"
  STATUS=$?
  assert_status 1
  assert_contains "not a terminal"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

test_invalid_network_override_is_refused() {
  write_profile
  stub_calypsocode_agent
  CALYPSO_NETWORK=carrier-pigeon TEST_KEY=k run_calypso --profile default --yes
  assert_status 1
  assert_contains "accepted values: tor, none"
}

test_help_and_doctor_do_not_launch() {
  write_profile
  stub_calypsocode_agent
  run_calypso --help
  assert_status 0
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"

  TEST_KEY=k run_calypso doctor
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# The original doctor printed "everything is ready" because three binaries
# existed, while the tool could not run at all. It must never assert again.
test_doctor_does_not_claim_readiness() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k run_calypso doctor
  assert_not_contains "everything is ready"
  assert_contains "not checked:"
}

run_tests
