#!/usr/bin/env bash
# Launch path: identity environment, compartment isolation, and refusing to
# start when the compartment is not complete.
#
# These run with CALYPSO_NETWORK=none so they need neither Tor nor the network.
# What `none` skips is egress verification, which test/egress.test.sh covers — and
# did not, for as long as this comment claimed it while the file did not exist.
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

# "Export it from wherever you keep secrets" is only useful to someone who
# already has a wherever. The refusal has to carry the shape of the command,
# with this compartment's variable and profile already in it.
test_missing_key_shows_the_command_that_fixes_it() {
  write_profile
  stub_calypsocode_agent
  launch
  assert_contains "compartment 'testbox' has no key"
  assert_contains "set -Ux TEST_KEY"
  assert_contains "export TEST_KEY="
  assert_contains "calypsocode --profile default"
}

# An export lives and dies with one shell. Offering it as *the* fix, with a
# "then launch" line under it, is a message that stops being true the moment the
# terminal closes — so the durable form has to be the one named first, and the
# per-shell one has to say that it is per-shell.
test_the_fix_says_which_form_survives_a_new_terminal() {
  write_profile
  stub_calypsocode_agent
  launch
  assert_contains "kept across terminals"
  assert_contains "this terminal only"
}

# The launcher is not in the request path, so it never learns that a key was
# rejected. It must not word the refusal as though it knew.
test_the_refusal_does_not_claim_to_know_why_the_key_failed() {
  write_profile
  stub_calypsocode_agent
  launch
  assert_not_contains "revoked"
  assert_not_contains "expired"
  assert_not_contains "invalid key"
}

test_doctor_shows_the_same_command() {
  write_profile
  stub_calypsocode_agent
  run_calypso doctor --profile default
  assert_status 1
  assert_contains "\$TEST_KEY is not set in this shell"
  assert_contains "set -Ux TEST_KEY"
}

# leak_candidates() needs `ip` and `ss`, but doctor did not check for either —
# their absence used to surface later as a misleading "no target on the host
# answered", which reads as a network problem rather than a missing tool.
test_doctor_reports_missing_ip() {
  write_profile
  stub_calypsocode_agent
  stub_oniux
  stub_no_leak_tools
  TEST_KEY=k run_calypso doctor --profile default
  assert_status 1
  assert_contains "FAIL  ip not found"
}

test_doctor_reports_missing_ss() {
  write_profile
  stub_calypsocode_agent
  stub_oniux
  stub_no_leak_tools
  TEST_KEY=k run_calypso doctor --profile default
  assert_status 1
  assert_contains "FAIL  ss not found"
}

# NETWORK=none has no namespace to leak-test, so ip/ss must not be checked at
# all — matching how the oniux check is skipped for the same reason.
test_doctor_does_not_check_ip_or_ss_for_network_none() {
  write_profile default \
    "NETWORK=none" "API_KEY_ENV=TEST_KEY" "API_BASE=https://x.invalid" \
    "MODEL=m" "GIT_NAME=n" "GIT_EMAIL=e@f"
  stub_calypsocode_agent
  stub_no_leak_tools
  TEST_KEY=k run_calypso doctor --profile default
  assert_status 0
  assert_not_contains "ip not found"
  assert_not_contains "ss not found"
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
  TEST_KEY=k launch -- run "fix the bug"
  assert_status 0
  assert_contains "STUB_CALYPSOCODE_AGENT_RAN args=run fix the bug"
  assert_agent_argv run "fix the bug"
}

# Argv boundaries have to survive every layer between the launcher's own
# argument parsing and the agent's exec: an array the whole way, never a
# flattened string rebuilt with `eval` or word-splitting, which cannot tell
# "one argument with a space" from "two arguments" and would silently merge
# or split things a real caller never asked for.
test_an_empty_argument_survives_as_its_own_element() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch -- run "" done
  assert_status 0
  assert_agent_argv run "" done
}

test_an_argument_containing_only_whitespace_is_not_split() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch -- "run   this" "  leading and trailing  "
  assert_status 0
  assert_agent_argv "run   this" "  leading and trailing  "
}

test_a_multiline_argument_survives_intact() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch -- run "line one
line two
line three"
  assert_status 0
  assert_agent_argv run "line one
line two
line three"
}

test_a_unicode_argument_survives_intact() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch -- run "fïx thé bùg 日本語 🐛"
  assert_status 0
  assert_agent_argv run "fïx thé bùg 日本語 🐛"
}

# Glob and quote characters must reach the agent literally, not expanded or
# stripped by any intermediate shell layer.
test_glob_and_quote_characters_are_not_interpreted() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch -- '*.txt' 'a "quoted" word' "it's" '$HOME' '`cmd`'
  assert_status 0
  assert_agent_argv '*.txt' 'a "quoted" word' "it's" '$HOME' '`cmd`'
}

# An argument that starts with a dash must reach the agent as an argument,
# not be reinterpreted as an option by anything between the launcher's own
# parsing and the agent's exec.
test_a_leading_dash_argument_is_not_reinterpreted() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch -- --model some/model -x
  assert_status 0
  assert_agent_argv --model some/model -x
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

# The agent's two default outbound paths that are not the provider. Both are refused
# in two places, and both places are asserted: an env var upstream could rename, and a
# config key upstream has to honour.
test_third_party_fetches_are_refused() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch
  assert_status 0
  assert_contains "ENV OPENCODE_DISABLE_AUTOUPDATE=1"
  assert_contains "ENV OPENCODE_DISABLE_MODELS_FETCH=1"
  local cfg="$CALYPSO_HOME/compartments/testbox/opencode.calypso.json"
  python3 -m json.tool "$cfg" > /dev/null || _fail "generated config is not valid JSON"
  grep -q '"autoupdate": false' "$cfg" || _fail "autoupdate is not disabled in the config"
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

# NETWORK=none must never invoke oniux at all — there is no namespace to run
# checks inside of, and no isolation to claim.
test_none_mode_never_invokes_oniux() {
  write_profile
  stub_calypsocode_agent
  stub_oniux
  TEST_KEY=k launch
  assert_status 0
  assert_oniux_never_invoked
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

# oniux gives the namespace a private /tmp (docs/FINDINGS.md F6/F7): a project
# directory under the host's /tmp does not exist inside it at all, and the
# agent used to fail with an opaque, unrelated-looking error only once the
# namespace was already running. Caught before launch instead. Gated to
# NETWORK=tor specifically — NETWORK=none never creates a namespace, so there
# is no private /tmp to be hidden by.
test_working_directory_directly_under_tmp_is_refused() {
  write_profile
  stub_calypsocode_agent
  local dir back="$PWD"
  dir="$(mktemp -d)"
  cd "$dir" || _fail "could not enter the tmp test directory"
  TEST_KEY=k run_calypso --profile default --yes
  cd "$back" || true
  rmdir "$dir" 2>/dev/null || true
  assert_status 1
  assert_contains "under /tmp"
  assert_contains "private /tmp"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# A symlink whose own path is outside /tmp, but which resolves into it, must
# be caught the same way — it does not exist inside the namespace either.
test_symlink_resolving_into_tmp_is_refused() {
  write_profile
  stub_calypsocode_agent
  local target link back="$PWD"
  target="$(mktemp -d)"
  link="/var/tmp/calypso-test-link-$$"
  ln -s "$target" "$link" || _fail "could not create the test symlink"
  cd "$link" || _fail "could not enter the symlinked test directory"
  TEST_KEY=k run_calypso --profile default --yes
  cd "$back" || true
  rm -f "$link"
  rmdir "$target" 2>/dev/null || true
  assert_status 1
  assert_contains "under /tmp"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

test_a_normal_project_path_is_allowed() {
  write_profile
  stub_namespace
  local back="$PWD"
  cd "$REPO_ROOT" || _fail "could not enter the repo root"
  TEST_KEY=k run_calypso --profile default --yes
  cd "$back" || true
  assert_status 0
  assert_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# /var/tmp is not a subpath of /tmp, and must not be treated as one — the
# check is specifically about oniux's private /tmp, not anything named "tmp".
test_a_neutral_external_path_outside_tmp_is_allowed() {
  write_profile
  stub_namespace
  local dir back="$PWD"
  dir="$(mktemp -d -p /var/tmp calypso-test-XXXXXX)"
  cd "$dir" || _fail "could not enter the neutral test directory"
  TEST_KEY=k run_calypso --profile default --yes
  cd "$back" || true
  rmdir "$dir" 2>/dev/null || true
  assert_status 0
  assert_contains "STUB_CALYPSOCODE_AGENT_RAN"
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

# umask 077 is set once near the top of the script so everything it creates —
# regardless of the invoking shell's own umask — is private. Run explicitly
# under a permissive parent umask to prove that is not inherited.
test_compartment_and_config_are_private_under_a_permissive_parent_umask() {
  local old_umask; old_umask="$(umask)"
  umask 022
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch
  umask "$old_umask"
  assert_status 0
  assert_mode "$CALYPSO_HOME/compartments/testbox" 700
  assert_mode "$CALYPSO_HOME/compartments/testbox/opencode.calypso.json" 600
  assert_mode "$CALYPSO_HOME/compartments/testbox/data" 700
  assert_mode "$CALYPSO_HOME/compartments/testbox/state" 700
}

# `--` is the mandatory boundary for agent arguments. Before this, an
# unrecognized option silently forwarded to the agent — a typo'd
# `--proifle` quietly launched the *default* profile with the typo passed
# along, rather than reporting the typo. Every security-relevant option name
# is checked here: a typo in any of them must refuse, not launch.
test_typo_in_profile_option_never_launches_default() {
  write_profile
  stub_calypsocode_agent
  CALYPSO_NETWORK=none TEST_KEY=k run_calypso --proifle default --yes
  assert_status 1
  assert_contains "unknown option '--proifle'"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

test_typo_in_no_verify_option_never_launches() {
  write_profile
  stub_calypsocode_agent
  CALYPSO_NETWORK=none TEST_KEY=k run_calypso --profile default --yes --no-verifyy
  assert_status 1
  assert_contains "unknown option '--no-verifyy'"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

test_typo_in_force_unsafe_option_never_launches() {
  write_profile
  stub_calypsocode_agent
  CALYPSO_NETWORK=none TEST_KEY=k run_calypso --profile default --yes --force-unsaf
  assert_status 1
  assert_contains "unknown option '--force-unsaf'"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

test_typo_in_yes_option_never_launches() {
  write_profile
  stub_calypsocode_agent
  CALYPSO_NETWORK=none TEST_KEY=k run_calypso --profile default --yess
  assert_status 1
  assert_contains "unknown option '--yess'"
  assert_not_contains "STUB_CALYPSOCODE_AGENT_RAN"
}

# A valid agent option after `--` must reach the agent completely unparsed by
# the launcher, even though it looks like a launcher flag itself.
test_agent_option_after_separator_reaches_the_agent_unparsed() {
  write_profile
  stub_calypsocode_agent
  TEST_KEY=k launch -- --model some/model
  assert_status 0
  assert_contains "STUB_CALYPSOCODE_AGENT_RAN args=--model some/model"
}

run_tests
