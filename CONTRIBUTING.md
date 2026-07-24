# Contributing to cloakcode

Thanks for the interest. This project is small, niche, and deliberately
simple — contributions are welcome, but let's keep that spirit.

## No CLA

No Contributor License Agreement is required. cloakcode is under
[AGPL-3.0](LICENSE) and will stay that way; there's no planned dual
commercial license that would require collecting rights over your
contribution. Your code stays AGPL-3.0, same as the rest of the project.

## Before opening a PR

- **Bugs and small fixes**: open a PR directly, with a description of what
  was broken.
- **New features or behavior changes**: open an issue first to discuss it.
  In particular, anything touching network isolation (`oniux`) or the
  threat model deserves discussion before code — a silent regression here
  has real consequences for users.
- **`docs/THREAT-MODEL.md`**: this document must stay honest, not
  promotional. If your contribution changes what the tool does or doesn't
  protect, update this file in the same PR.

## Local checks before pushing

There's no test suite (the project is a bash script plus config, not an
application). Before pushing:

```bash
# Syntax and best practices for the main script
shellcheck bin/cloakcode

# The script doesn't crash, even without dependencies installed
./bin/cloakcode doctor

# Config files are valid YAML/JSON
yamllint config/*.yaml
python3 -m json.tool config/opencode.json.example > /dev/null
```

CI (`.github/workflows/ci.yml`) runs these same checks on every PR.

## Style

- Bash: `set -euo pipefail`, no reliance on non-portable bashisms beyond
  what's already used in `bin/cloakcode`.
- Script comments and user-facing messages in English (consistency with
  the existing code); documentation (README, this file) in English too.
- No new runtime dependency without prior discussion — the idea is to stay
  a thin wrapper around oniux, LiteLLM, and OpenCode, not to grow into a
  large project to maintain.

## Scope

Explicitly **out of scope** for now (see [Roadmap](README.md#roadmap) in
the README): any hosted/pooled service shared between multiple users, and
any smart fallback/routing logic between models. PRs in these directions
will likely be declined or redirected to a broader discussion first — not
because the idea is bad, but because these aren't decisions to make in the
middle of a code PR.
