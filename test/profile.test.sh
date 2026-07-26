#!/usr/bin/env bash
# Profile loading. A profile defines a compartment boundary, so a profile that
# parses wrongly is a compartment that leaks quietly — every one of these
# failures must be loud.
# shellcheck source=test/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

test_missing_profile_names_the_expected_path() {
  run_calypso profile --profile nope
  assert_status 1
  assert_contains "profile 'nope' not found"
  assert_contains "$CALYPSO_PROFILE_DIR/nope.env"
}

test_valid_profile_resolves() {
  write_profile
  run_calypso profile
  assert_status 0
  assert_contains "profile:      testbox"
  assert_contains "network:      tor"
  assert_contains "git identity: dev <dev@localhost>"
}

test_profile_name_defaults_to_filename() {
  write_profile mycompartment \
    "NETWORK=tor" "API_KEY_ENV=TEST_KEY" "API_BASE=https://x.invalid" \
    "MODEL=m" "GIT_NAME=n" "GIT_EMAIL=e@f"
  run_calypso profile --profile mycompartment
  assert_status 0
  assert_contains "profile:      mycompartment"
}

test_unknown_key_is_refused() {
  write_profile default \
    "NETWORK=tor" "API_KEY_ENV=TEST_KEY" "API_BASE=https://x.invalid" \
    "MODEL=m" "GIT_NAME=n" "GIT_EMAIL=e@f" "TYPOO=1"
  run_calypso profile
  assert_status 1
  assert_contains "unknown key 'TYPOO'"
}

test_missing_required_key_is_refused() {
  write_profile default \
    "NETWORK=tor" "API_KEY_ENV=TEST_KEY" "API_BASE=https://x.invalid" \
    "MODEL=m" "GIT_NAME=n"
  run_calypso profile
  assert_status 1
  assert_contains "missing required key 'GIT_EMAIL'"
}

# PROFILE names a directory under compartments/. Two profiles that both escape it
# resolve to the same directory and share config, data and state — F9, reachable by
# typing. And a session with an unwritable receipt path sends data and records nothing.
test_profile_name_that_escapes_the_compartment_dir_is_refused() {
  write_profile default \
    "PROFILE=../shared" "NETWORK=tor" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://x.invalid" "MODEL=m" "GIT_NAME=n" "GIT_EMAIL=e@f"
  run_calypso profile
  assert_status 1
  assert_contains "outside the others"
}

test_profile_name_with_a_slash_is_refused() {
  write_profile default \
    "PROFILE=client/acme" "NETWORK=tor" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://x.invalid" "MODEL=m" "GIT_NAME=n" "GIT_EMAIL=e@f"
  run_calypso profile
  assert_status 1
  assert_contains "PROFILE='client/acme'"
}

# Same class of accident as an unknown key, with a worse outcome: a second NETWORK=
# line silently drops a compartment boundary.
test_duplicate_key_is_refused() {
  write_profile default \
    "NETWORK=tor" "NETWORK=none" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://x.invalid" "MODEL=m" "GIT_NAME=n" "GIT_EMAIL=e@f"
  run_calypso profile
  assert_status 1
  assert_contains "set twice"
}

# The picker's design rests on there never being a second place a backend choice can
# hide. An inspection command showing the file's value while an override is in force
# is that same bug in miniature.
test_profile_reports_the_effective_network_not_the_file() {
  write_profile
  CALYPSO_NETWORK=none run_calypso profile
  assert_status 0
  assert_contains "network:      none"
  assert_contains "overridden for this run"
  assert_contains "the profile says tor"
}

test_profile_reports_the_file_when_there_is_no_override() {
  write_profile
  run_calypso profile
  assert_status 0
  assert_contains "network:      tor"
  assert_not_contains "overridden"
}

# `trim` strips whitespace at the edges only, so an interior tab reaches the generated
# config and, unescaped, produces JSON the agent cannot parse — an opaque agent error
# standing in for a profile typo.
test_a_tab_inside_a_value_still_produces_valid_json() {
  write_profile testbox \
    "PROFILE=testbox" "NETWORK=none" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://x.invalid" "MODEL=mo	del" "GIT_NAME=n" "GIT_EMAIL=e@f"
  stub_calypsocode_agent
  TEST_KEY=k run_calypso --profile testbox --yes
  assert_status 0
  local cfg="$CALYPSO_HOME/compartments/testbox/opencode.calypso.json"
  python3 -m json.tool "$cfg" > /dev/null || _fail "a tab in a profile value broke the config"
}

test_unsupported_network_is_refused() {
  write_profile default \
    "NETWORK=vpn" "API_KEY_ENV=TEST_KEY" "API_BASE=https://x.invalid" \
    "MODEL=m" "GIT_NAME=n" "GIT_EMAIL=e@f"
  run_calypso profile
  assert_status 1
  assert_contains "v1 accepts 'tor' or 'none'"
}

test_whitespace_and_quotes_are_tolerated() {
  write_profile default \
    "  # a comment" "" "  NETWORK = tor  " 'API_KEY_ENV="TEST_KEY"' \
    "API_BASE=https://x.invalid" "MODEL=m" "GIT_NAME=Some Name" "GIT_EMAIL=e@f"
  run_calypso profile
  assert_status 0
  assert_contains "network:      tor"
  assert_contains "git identity: Some Name <e@f>"
}

test_file_without_trailing_newline_is_read_fully() {
  printf 'NETWORK=tor\nAPI_KEY_ENV=TEST_KEY\nAPI_BASE=https://x.invalid\nMODEL=m\nGIT_NAME=n\nGIT_EMAIL=last@line' \
    > "$CALYPSO_PROFILE_DIR/default.env"
  run_calypso profile
  assert_status 0
  assert_contains "last@line"
}

# A profile is read, never sourced: a config file must not be able to run code.
# shellcheck disable=SC2016  # the literal $() is exactly what is being asserted
test_profile_is_not_executed_as_shell() {
  write_profile default \
    "NETWORK=tor" "API_KEY_ENV=TEST_KEY" 'API_BASE=$(touch '"$SANDBOX"'/pwned)' \
    "MODEL=m" "GIT_NAME=n" "GIT_EMAIL=e@f"
  run_calypso profile
  assert_no_file "$SANDBOX/pwned"
  assert_contains 'api_base:     $(touch'
}

test_key_presence_is_reported_without_printing_it() {
  write_profile
  TEST_KEY="super-secret-value" run_calypso profile
  assert_status 0
  assert_contains "TEST_KEY is set"
  assert_not_contains "super-secret-value"
}

run_tests
