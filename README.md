[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)

# CalypsoCode

Your coding agent, compartmented — separate keys, separate network paths,
separate contexts per project, with a receipt proving what left your machine.

> **Status: redesign in progress. `bin/calypsocode` does not currently run.**
> The original architecture was proven unimplementable by testing (see
> [docs/FINDINGS.md](docs/FINDINGS.md) — a host process cannot reach a port
> bound inside an `oniux` namespace). The replacement design is in
> [docs/DESIGN.md](docs/DESIGN.md); build order in
> [docs/ROADMAP.md](docs/ROADMAP.md). Do not treat this repo as a working
> privacy tool yet.

## The idea

Run a coding agent against privacy-focused providers (Venice, Tinfoil —
censored or uncensored models) in a way that keeps the person writing the code
as untraceable as the stack allows.

The unit is a **profile**:

```yaml
profile: client-acme
  network: tor          # tor | vpn | direct | socks
  key:     venice_acme  # bound to this compartment only
  model:   uncensored
  scrub:   strict
  retire:  30d
```

One launch = one namespace = one circuit = one key = one context. Nothing
crosses between compartments.

This serves more people than a Tor wrapper does. Anyone who does not want
project A's agent traffic, keys, and context bleeding into project B's —
consultants with multiple clients, people under NDA boundaries, people whose
employer bans AI tooling on some repos — wants the same machinery, with
`network:` set to something other than `tor`.

## Why compartments, not key rotation

Identity is not your name. To a provider it is the set of signals that link two
requests to the same person: exit IP, API key, payment, **content**, timing,
client fingerprint.

A compartment is only as isolated as its weakest shared signal, so every signal
must change at the same boundary. The original design rotated API keys per
request over one shared Tor circuit — which rotates the credential while
holding the network constant, and so hands the provider a proof that those
accounts are the same person. [Full reasoning](docs/DESIGN.md#why-per-request-rotation-was-wrong).

## The leak nobody fixes

A coding agent sends file paths, diffs, and stack traces constantly:

```
/home/<user>/dev/client-acme/src/billing.ts
Author: <Real Name> <real.email@example.com>
```

Tor does nothing about that. Neither does a VPN, key rotation, or a TEE. You
can have kernel-level network isolation and still leak your username in the
payload on request one. Scrubbing that is the part a coding-agent-specific tool
can do and a general-purpose proxy cannot.

## Proof, not claims

Privacy tools assert; almost none demonstrate. The goal is a **session
receipt**: on exit, state exactly what left the machine, under which identity,
through which exit, with which scrubs applied and which enclave attestation
verified. Egress proof and negative leak tests included —
[details](docs/DESIGN.md#proof-not-claims).

## What is verified

Everything in [docs/FINDINGS.md](docs/FINDINGS.md) was measured, not assumed:

- `oniux` isolation is fail-closed at the kernel routing level ✅
- Venice and Tinfoil do **not** block Tor exits (unauthenticated endpoints) ✅
- Distinct SOCKS credentials yield distinct circuits ✅
- `oniux` injects `ALL_PROXY`, which silently breaks same-namespace loopback ⚠️
- LiteLLM cannot bind a proxy per model ❌
- Authenticated inference over Tor, and real session latency — **untested**

## Limits

[docs/THREAT-MODEL.md](docs/THREAT-MODEL.md) states what this hides and what it
does not. Read it before trusting this tool for anything. A privacy tool that
oversells its guarantees is worse than useless.

## Prior art

[oniux](https://gitlab.torproject.org/tpo/core/oniux) does the isolation half
as a one-liner; [LLM-Tor](https://github.com/prince776/LLM-Tor) does the
identity half properly with blind signatures. Neither addresses
compartmentalization or content scrubbing for coding agents. See
[docs/ROADMAP.md](docs/ROADMAP.md#prior-art).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) — no CLA.

## License

[AGPL-3.0](LICENSE).
