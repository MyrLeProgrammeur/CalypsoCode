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
  run_calypso profile --network none
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
# Control characters in profile values used to be escaped on the way into the
# agent's config and passed through raw everywhere else — the same byte meaning
# three different things depending on which consumer read it. They are refused
# at the boundary now, so there is one rule instead of one per destination.
# Refused *before* launch: a value the launcher will not accept must stop the
# session, not reach the agent and fail later.
test_a_tab_inside_a_value_is_refused_before_launch() {
  write_profile testbox \
    "PROFILE=testbox" "NETWORK=none" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://x.invalid" "MODEL=mo	del" "GIT_NAME=n" "GIT_EMAIL=e@f"
  stub_calypsocode_agent
  TEST_KEY=k run_calypso --profile testbox --network none --yes
  assert_status 1
  assert_contains "MODEL contains a tab (0x09)"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

test_an_escape_character_in_a_value_is_refused() {
  write_profile testbox \
    "PROFILE=testbox" "NETWORK=none" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://x.invalid" "MODEL=m" \
    "$(printf 'GIT_NAME=de\033[31mv')" "GIT_EMAIL=e@f"
  stub_calypsocode_agent
  TEST_KEY=k run_calypso --profile testbox --network none --yes
  assert_status 1
  assert_contains "GIT_NAME contains an escape (0x1B)"
}

test_a_carriage_return_inside_a_value_is_refused() {
  write_profile testbox \
    "PROFILE=testbox" "NETWORK=none" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://x.invalid" "MODEL=m" \
    "$(printf 'GIT_NAME=one\rtwo')" "GIT_EMAIL=e@f"
  stub_calypsocode_agent
  TEST_KEY=k run_calypso --profile testbox --network none --yes
  assert_status 1
  assert_contains "GIT_NAME contains a carriage return (0x0D)"
}

test_a_backspace_inside_a_value_is_refused() {
  write_profile testbox \
    "PROFILE=testbox" "NETWORK=none" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://x.invalid" "MODEL=m" \
    "$(printf 'GIT_NAME=ab\bc')" "GIT_EMAIL=e@f"
  stub_calypsocode_agent
  TEST_KEY=k run_calypso --profile testbox --network none --yes
  assert_status 1
  assert_contains "GIT_NAME contains a backspace (0x08)"
}

test_a_form_feed_inside_a_value_is_refused() {
  write_profile testbox \
    "PROFILE=testbox" "NETWORK=none" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://x.invalid" "MODEL=m" \
    "$(printf 'GIT_NAME=a\fb')" "GIT_EMAIL=e@f"
  stub_calypsocode_agent
  TEST_KEY=k run_calypso --profile testbox --network none --yes
  assert_status 1
  assert_contains "GIT_NAME contains a form feed (0x0C)"
}

test_a_delete_character_inside_a_value_is_refused() {
  write_profile testbox \
    "PROFILE=testbox" "NETWORK=none" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://x.invalid" "MODEL=m" \
    "$(printf 'GIT_NAME=a\177b')" "GIT_EMAIL=e@f"
  stub_calypsocode_agent
  TEST_KEY=k run_calypso --profile testbox --network none --yes
  assert_status 1
  assert_contains "GIT_NAME contains a delete (0x7F)"
}

# The rule is "printable", not "ASCII". A compartment for someone whose name
# has an accent, or is written in a non-Latin script, is a normal profile.
test_printable_unicode_in_a_value_is_accepted_and_reaches_the_config() {
  write_profile testbox \
    "PROFILE=testbox" "NETWORK=none" "API_KEY_ENV=TEST_KEY" \
    "API_BASE=https://x.invalid" "MODEL=modèle-日本語" \
    "GIT_NAME=Zoé Ünicode" "GIT_EMAIL=e@f"
  stub_calypsocode_agent
  TEST_KEY=k run_calypso --profile testbox --network none --yes
  assert_status 0
  local cfg="$CALYPSO_HOME/compartments/testbox/opencode.calypso.json"
  python3 -m json.tool "$cfg" > /dev/null \
    || _fail "unicode in a profile value broke the config" "$(cat "$cfg")"
  case "$(cat "$cfg")" in
    *"modèle-日本語"*) ;;
    *) _fail "the model name should reach the config intact" "$(cat "$cfg")" ;;
  esac
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
    "NETWORK=tor" "API_KEY_ENV=TEST_KEY" 'API_BASE=https://x.invalid/$(touch '"$SANDBOX"'/pwned)' \
    "MODEL=m" "GIT_NAME=n" "GIT_EMAIL=e@f"
  run_calypso profile
  assert_no_file "$SANDBOX/pwned"
  assert_contains 'api_base:     https://x.invalid/$(touch'
}

test_key_presence_is_reported_without_printing_it() {
  write_profile
  TEST_KEY="super-secret-value" run_calypso profile
  assert_status 0
  assert_contains "TEST_KEY is set"
  assert_not_contains "super-secret-value"
}

# API_KEY_ENV is used in bash indirect expansion, so an array-like value is not
# merely a bad name — it can execute during the expansion itself.
test_array_like_api_key_env_is_refused_without_side_effect() {
  # shellcheck disable=SC2016 # the $(...) must reach the profile unexpanded —
  # expanding it here would run the payload in the test instead of the launcher.
  write_profile default \
    'NETWORK=tor' 'API_KEY_ENV=a[$(touch '"$SANDBOX"'/pwned)]' \
    'API_BASE=https://x.invalid' 'MODEL=m' 'GIT_NAME=n' 'GIT_EMAIL=e@f'
  run_calypso profile
  assert_status 1
  assert_no_file "$SANDBOX/pwned"
}

test_valid_api_key_env_names_still_work() {
  write_profile default \
    'NETWORK=tor' 'API_KEY_ENV=MY_KEY_2' \
    'API_BASE=https://x.invalid' 'MODEL=m' 'GIT_NAME=n' 'GIT_EMAIL=e@f'
  run_calypso profile
  assert_status 0
  assert_contains 'MY_KEY_2 is NOT set'
}

test_api_key_env_starting_with_a_digit_is_refused() {
  write_profile default \
    'NETWORK=tor' 'API_KEY_ENV=9KEY' \
    'API_BASE=https://x.invalid' 'MODEL=m' 'GIT_NAME=n' 'GIT_EMAIL=e@f'
  run_calypso profile
  assert_status 1
  assert_contains "API_KEY_ENV='9KEY'"
}

# API_BASE validation: Tor only protects traffic up to the exit relay, so a
# remote http:// endpoint hands the key and every prompt to whoever is
# downstream in the clear. https:// is required for anything remote;
# 127.0.0.1/localhost are the one accepted local exception.
_write_api_base_profile() {
  write_profile default \
    "NETWORK=tor" "API_KEY_ENV=TEST_KEY" "API_BASE=$1" \
    "MODEL=m" "GIT_NAME=n" "GIT_EMAIL=e@f"
}

test_https_api_base_is_accepted() {
  _write_api_base_profile "https://api.example.invalid/v1"
  run_calypso profile
  assert_status 0
}

test_remote_http_api_base_is_rejected() {
  _write_api_base_profile "http://api.example.invalid/v1"
  run_calypso profile
  assert_status 1
  assert_contains "only accepted for 127.0.0.1 or localhost"
}

test_loopback_http_api_base_is_accepted() {
  _write_api_base_profile "http://127.0.0.1:8080/v1"
  run_calypso profile
  assert_status 0
}

test_localhost_http_api_base_is_accepted() {
  _write_api_base_profile "http://localhost:8080/v1"
  run_calypso profile
  assert_status 0
}

test_unsupported_scheme_api_base_is_rejected() {
  _write_api_base_profile "ftp://api.example.invalid/v1"
  run_calypso profile
  assert_status 1
  assert_contains "unsupported scheme 'ftp://'"
}

test_malformed_api_base_without_scheme_is_rejected() {
  _write_api_base_profile "api.example.invalid/v1"
  run_calypso profile
  assert_status 1
  assert_contains "explicit scheme"
}

test_api_base_with_userinfo_is_rejected() {
  _write_api_base_profile "https://user:pass@api.example.invalid/v1"
  run_calypso profile
  assert_status 1
  assert_contains "embedded credentials"
}

test_api_base_with_fragment_is_rejected() {
  _write_api_base_profile "https://api.example.invalid/v1#frag"
  run_calypso profile
  assert_status 1
  assert_contains "fragment"
}

test_api_base_with_empty_host_is_rejected() {
  _write_api_base_profile "https:///v1"
  run_calypso profile
  assert_status 1
  assert_contains "missing host"
}

# profile_load() builds a path directly from the --profile name, same as
# profile_create() does when writing one. A name that climbs out of
# PROFILE_DIR must never be opened, whichever direction it is used in.
test_profile_load_rejects_path_traversal() {
  mkdir -p "$SANDBOX/outside"
  cat > "$SANDBOX/outside/passwd.env" <<'EOF'
NETWORK=tor
API_KEY_ENV=TEST_KEY
API_BASE=https://x.invalid
MODEL=m
GIT_NAME=n
GIT_EMAIL=e@f
EOF
  run_calypso profile --profile "../outside/passwd"
  assert_status 1
  assert_contains "letters, digits, dot, dash and underscore only"
  assert_not_contains "profile:      testbox"
}

test_profile_load_rejects_absolute_path() {
  run_calypso profile --profile "/etc/passwd"
  assert_status 1
  assert_contains "letters, digits, dot, dash and underscore only"
}

test_profile_load_rejects_nested_path() {
  run_calypso profile --profile "a/b"
  assert_status 1
  assert_contains "letters, digits, dot, dash and underscore only"
}

test_profile_load_rejects_hidden_name() {
  run_calypso profile --profile ".hidden"
  assert_status 1
  assert_contains "letters, digits, dot, dash and underscore only"
}

test_profile_load_accepts_valid_punctuation() {
  write_profile "a.b-c_d" \
    "NETWORK=tor" "API_KEY_ENV=TEST_KEY" "API_BASE=https://x.invalid" \
    "MODEL=m" "GIT_NAME=n" "GIT_EMAIL=e@f"
  run_calypso profile --profile "a.b-c_d"
  assert_status 0
}

# --from goes through profile_load() too — same guard applies to the name it
# copies from.
test_from_rejects_path_traversal() {
  have_pty || { skip "script (pty) not installed"; return 0; }
  run_calypso_tty "" --new-profile x --from "../outside/passwd"
  assert_status 1
  assert_contains "letters, digits, dot, dash and underscore only"
}

run_tests
