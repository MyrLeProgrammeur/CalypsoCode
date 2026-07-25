[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)

# CalypsoCode

CalypsoCode removes a defined set of identifiers — network address, git
identity, environment metadata, agent config — from what your coding agent
transmits, and reports per session what it removed and what it did not.

> **Status: it works, and the premise has been measured once.** A real coding
> session ran end-to-end through the launcher over Tor — 8 round trips, 3.8s
> mean, 0 failures ([the gate](docs/ROADMAP.md#gate)). That is an existence
> proof, not a track record: one task, one provider, one day. What a single
> session cannot show — how a provider reacts to Tor-origin traffic over weeks,
> how the latency feels on a large repository — is listed in
> [docs/FINDINGS.md](docs/FINDINGS.md#still-untested).

## The idea

**Calypso erases who is asking. Not what is asked.**

Whether a provider can *read* your code and prompts is a property of the
provider you buy from — pick a hardware enclave like Tinfoil if that matters to
you. Whether they can tell it was *you* asking is a different problem, and
nobody serves it well. That's this project.

The unit is a **profile** — one file per compartment, in
`~/.config/calypsocode/profiles/`:

```sh
PROFILE=client-acme
NETWORK=tor                        # tor | none
API_KEY_ENV=VENICE_API_KEY_ACME    # names the variable, never holds the key
API_BASE=https://api.venice.ai/api/v1
MODEL=zai-org-glm-5-1
GIT_NAME=dev
GIT_EMAIL=dev@localhost
```

Run `calypsocode` with no profile yet and it offers to write one: it asks which
network backend you want, states plainly which are built and which are not, and
never picks for you. Without a terminal, or with `--yes`, it refuses rather than
choosing a default — a backend selected on your behalf is a leak with a friendly
face. The answers go into the profile and nowhere else, so there is never a
second place a backend choice could hide.

One launch = one namespace = one circuit. One compartment = one key = one
config = one identity, and it persists across launches. Nothing crosses between
compartments.

This is for people whose **network is observed** while their account is not the
threat: developers in censoring jurisdictions, people whose employer or ISP
monitors what they connect to, people where certain questions are dangerous to
be seen asking. Your provider still knows which customer is paying. What the
observer between you and the provider learns is nothing — including which model
you chose, uncensored or otherwise.

## How it works: configure, don't rewrite

Calypso never inspects or modifies your traffic. Every identifier it removes is
removed **before the agent starts**, by controlling the environment it runs in:

```
oniux                     # IP address → Tor, fail-closed at the kernel
LC_ALL=C                  # no locale leak
TZ=UTC                    # no timezone inference
GIT_AUTHOR_NAME=dev       # git stops printing your name
XDG_CONFIG_HOME=<compartment>   # your global agent config never loads
```

Each line removes a signal at its source, so the identifying value is never
produced. That's more reliable than scrubbing it afterwards, and it can't
corrupt your code.

## Why compartments, not key rotation

Identity isn't your name — it's the set of signals that link two requests to
the same person. A compartment is only as isolated as its weakest shared
signal, so every signal has to change at the same boundary.

The original design rotated API keys per request over one shared Tor circuit,
which rotates the credential while holding the network constant — handing the
provider a proof that those accounts are the same person.
[Full reasoning](docs/DESIGN.md#why-per-request-rotation-was-wrong).

## Proof, not claims

Privacy tools assert; almost none demonstrate. The goal is a **session
receipt**: on exit, state exactly what left the machine, under which identity,
through which exit — and what was *not* removed, including your account, your
prompt content, and your session timing.
[Details](docs/DESIGN.md#proof-not-claims).

## What is verified

Everything in [docs/FINDINGS.md](docs/FINDINGS.md) was measured, not assumed:

- `oniux` isolation is fail-closed at the kernel routing level ✅
- Venice and Tinfoil do **not** block Tor exits ✅
- Authenticated, billed inference over Tor works — HTTP 200 in 3.0s ✅
- A real coding session ran end-to-end: 8 round trips, 3.8s mean, 0 failures ✅
- Distinct SOCKS credentials yield distinct circuits ✅
- `oniux` injects `ALL_PROXY`, which silently breaks same-namespace loopback ⚠️
- `XDG_CONFIG_HOME` alone does **not** compartment an agent — data and state
  move separately, and did not until this was measured ⚠️
- LiteLLM cannot bind a proxy per model ❌
- Provider response to Tor traffic **over weeks**, and latency on a large
  repository — **untested**

## Limits

This is orthogonal to content confidentiality and to whichever provider you
choose. [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md) states what is and isn't
covered, including the two things that cannot be removed: your account, and
your writing style. Read it before trusting this tool for anything.

## Prior art

[oniux](https://gitlab.torproject.org/tpo/core/oniux) does the network
isolation as a one-liner; [LLM-Tor](https://github.com/prince776/LLM-Tor) tackles
account identity with blind signatures. Neither does per-compartment identity
for coding agents. See [docs/ROADMAP.md](docs/ROADMAP.md#prior-art).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) — no CLA.

## License

[AGPL-3.0](LICENSE).
