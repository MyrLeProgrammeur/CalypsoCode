# Archived configuration examples — none of these are supported

**Nothing in this directory is a config template. Do not copy any of it.**

These files match architectures the project moved away from. They are kept
because the findings in [`../FINDINGS.md`](../FINDINGS.md) cite them, and a
finding that references a deleted file cannot be checked. That is their only
purpose.

The supported example is [`../../config/profile.example.env`](../../config/profile.example.env),
and `calypsocode --new-profile <name>` writes one for you.

## `agent.json.example`

An agent provider block pointing at `http://127.0.0.1:4000` — the local LiteLLM
proxy of the original design. Two things make it unusable:

- **The launcher writes this file itself.** `compartment_prepare()` generates
  `opencode.calypso.json` per compartment from the profile, so a hand-written
  provider block has nothing to attach to.
- **The address is unreachable from where the agent runs.** oniux gives the
  child its own network namespace with its own loopback stack, so the host's
  `127.0.0.1:4000` does not exist inside it — see F1.

It also names a model `uncensored`, which is audience positioning the project
does not do.

## `litellm.config.example.yaml`

The LiteLLM router config of the original design, already annotated with what
is wrong with it: per-request key rotation over one shared circuit (which
proves to the provider that the accounts are one person), and a loopback
`api_base` that oniux tunnels through Tor — see F2 and F5. LiteLLM is not part
of the current design at all; the agent speaks to OpenAI-compatible providers
directly.
