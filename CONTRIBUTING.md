# Contributing to CalypsoCode

Thanks for the interest. This project is small and deliberately simple —
contributions are welcome, but let's keep that spirit.

> **Read [docs/ROADMAP.md](docs/ROADMAP.md) first.** The launcher runs and the
> gate has been passed — one real coding session over Tor, measured
> ([the gate](docs/ROADMAP.md#gate)). That is an existence proof, not a track
> record: how a provider reacts to Tor-origin traffic over weeks, and how the
> latency feels on a large repository, remain unmeasured
> ([still untested](docs/FINDINGS.md#still-untested)).

## No CLA

No Contributor License Agreement is required, and none will be. CalypsoCode is
under [AGPL-3.0](LICENSE) and stays that way — this tool's job is to verify
things on your behalf, and a verifier nobody can read is worth nothing. Your
code stays AGPL-3.0, same as the rest of the project.

## Before opening a PR

- **Bugs and small fixes**: open a PR directly, with a description of what was
  broken.
- **New features or behavior changes**: open an issue first. In particular,
  anything touching network isolation (`oniux`), compartment boundaries, or
  the threat model deserves discussion before code — a silent regression here
  has real consequences for users.
- **`docs/THREAT-MODEL.md`**: this document must stay honest, not promotional.
  If your contribution changes what the tool does or doesn't protect, update
  it in the same PR.
- **`docs/FINDINGS.md`**: only add claims you have **measured**. Every entry
  states its evidence, and untested things are marked untested. Do not add
  inferences to that file — they belong in `DESIGN.md`.

## Git conventions

**Branches.** `main` is protected: no direct pushes, CI green to merge. Work
happens on a branch named `type/short-description` in kebab-case — `feat/`,
`fix/`, `refactor/`, `chore/`, `docs/`, `test/`. Branches are short-lived; if
one lives longer than a few days it should have been split.

When a branch executes a plan from `docs/plans/`, name it after the plan's slug
so the two are obviously the same piece of work.

**Commits.** A conventional subject line, then prose:

```
feat(launcher): verify egress is Tor before the agent starts

The check runs inside the namespace, because that is the only place it can
run — the host cannot observe the namespace's egress (F1).

A dead circuit and a non-Tor egress are different failures and are treated
differently. [...]
```

The subject keeps the history scannable and leaves the door open to generated
changelogs. The body is where the value is: **why** the change is right, and
what was measured. A commit that explains only what it did has thrown away the
part a reader cannot reconstruct from the diff.

**Merges.** Merge commits, not squash. Each commit in this project is meant to
stand on its own as a record of a decision and its evidence; collapsing a
branch into one line deletes exactly the part worth keeping. Rebase your own
branch onto `main` before opening the PR, and use `--force-with-lease`, never
`--force`.

Delete branches after merge.

## Local checks before pushing

Before pushing:

```bash
# The test suite — hermetic, no network, no Tor, a few seconds
./test/run.sh
./test/run.sh receipt          # one suite

# Syntax and best practices
shellcheck bin/calypsocode
shellcheck -x test/run.sh test/helpers.sh test/*.test.sh

# Config files are valid YAML/JSON
yamllint config/*.yaml
python3 -m json.tool config/opencode.json.example > /dev/null

# No secrets, in the diff or anywhere in history
gitleaks detect --source . --redact
```

The tests stub the agent and the network, so they exercise the launcher's
logic rather than the machine's connectivity. **A test that passes against
broken code is worse than no test** — when you add one, break the code
deliberately and check that it fails.

If `shellcheck` is not installed, `bash -n bin/calypsocode` catches syntax
errors but nothing else. CI runs everything above on every branch and every
PR, so a green local check is not a green CI.

`./bin/calypsocode doctor` reports what it checked and what it could not; it
does not claim the stack works. Keep it that way. A `doctor` that concludes
"everything is ready" because three binaries exist is what the first version
did, and it was wrong the entire time the tool could not run at all.

## Style

- Bash: `set -euo pipefail`, no reliance on non-portable bashisms.
- Script comments, user-facing messages, and documentation in English.
- No new runtime dependency without prior discussion — the goal is a thin
  orchestration layer over oniux and an existing coding agent, not a large
  project to maintain.

## Scope

Explicitly **out of scope** (see [docs/ROADMAP.md](docs/ROADMAP.md#decisions-taken)):

- **Content rewriting of any kind** — prompts, code, or tool calls. Calypso
  erases who is asking, not what is asked. Two-way translation with per-session
  state fails silently and can corrupt a user's source.
- **Filesystem mounts and path remapping.** Considered and dropped; the leak it
  addressed is handled by user-side convention.
- **Verifying other providers' guarantees** (enclave attestation, no-logging
  policy). Provider choice belongs to the user.
- Any hosted or pooled service shared between multiple users. The launcher is a
  local tool; adding a service is a project-direction decision rather than
  something to settle in a code review.
- Rebuilding the coding agent itself. Wrap or fork OpenCode; the
  differentiation here is the privacy layer.
- Per-request key rotation. It is unsound on a shared circuit and not
  implementable in LiteLLM anyway.

PRs in these directions will be declined or redirected to a broader discussion
first — not because the ideas are bad, but because these aren't decisions to
make in the middle of a code PR.
