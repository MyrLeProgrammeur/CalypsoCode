# Contributing to CalypsoCode

Thanks for the interest. This project is small and deliberately simple —
contributions are welcome, but let's keep that spirit.

> **Read [docs/ROADMAP.md](docs/ROADMAP.md) first.** The launcher runs, but the
> premise behind it is unmeasured: no real coding session has gone through it
> yet ([the gate](docs/ROADMAP.md#gate)). Anything that assumes Tor is usable
> for agentic work is assuming what this project has not yet shown.

## No CLA

No Contributor License Agreement is required. CalypsoCode is under
[AGPL-3.0](LICENSE) and will stay that way; there's no planned dual commercial
license that would require collecting rights over your contribution. Your code
stays AGPL-3.0, same as the rest of the project.

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

## Local checks before pushing

There's no test suite yet (the project is currently a bash script plus config).
Before pushing:

```bash
# Syntax and best practices for the main script
shellcheck bin/calypsocode

# Config files are valid YAML/JSON
yamllint config/*.yaml
python3 -m json.tool config/opencode.json.example > /dev/null
```

If `shellcheck` is not installed, `bash -n bin/calypsocode` catches syntax
errors but nothing else — CI (`.github/workflows/ci.yml`) runs the real
linters on every PR, so a green local check is not a green CI.

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
- Any hosted or pooled service shared between multiple users — ruled out on
  provider-ToS grounds.
- Rebuilding the coding agent itself. Wrap or fork OpenCode; the
  differentiation here is the privacy layer.
- Per-request key rotation. It is unsound on a shared circuit and not
  implementable in LiteLLM anyway.

PRs in these directions will be declined or redirected to a broader discussion
first — not because the ideas are bad, but because these aren't decisions to
make in the middle of a code PR.
