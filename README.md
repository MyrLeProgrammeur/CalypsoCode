<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/calypsocode-logo-dark.svg">
  <img alt="CalypsoCode" src="docs/assets/calypsocode-logo-light.svg" width="464">
</picture>

[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0-8b4cff.svg)](LICENSE)

# CalypsoCode

CalypsoCode removes a defined set of identifiers — network address, git
identity, environment metadata, agent config — from what your coding agent
transmits, and reports per session what it removed and what it did not.

> **Status: it works, and the premise has been measured once.** A real coding
> session ran end-to-end through the launcher over Tor on the agent this project
> actually ships — 4 round trips, 3.6s mean, 0 failures
> ([F12](docs/FINDINGS.md#f12--the-compiled-calypsocode-agent-holds-a-real-session-over-tor)).
> That is an existence proof, not a track record: one task, one provider, one day.
> What a single session cannot show — how a provider reacts to Tor-origin traffic
> over weeks, how the latency feels on a large repository — is listed in
> [docs/FINDINGS.md](docs/FINDINGS.md#still-untested).

## The idea

**CalypsoCode hides your network identity from everyone except the provider you
pay.**

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

`calypsocode --new-profile NAME` writes one: it asks which network backend you
want, states plainly which are built and which are not, and never picks for you.
Without a terminal, or with `--yes`, it refuses rather than choosing a default —
a backend selected on your behalf is a leak with a friendly face. The answers go
into the profile and nowhere else, so there is never a second place a backend
choice could hide. Add `--from NAME` to copy the network and provider from a
profile you already have; the key variable and the git identity are always asked
for again, because two compartments sharing either are one customer to the
provider.

Creating never happens on the way to launching. `calypsocode --profile typo`
reports that no such profile exists and lists the ones that do, rather than
offering to build a compartment under the typo.

One launch = one namespace = one circuit. One compartment = one key = one
config = one identity, and it persists across launches. Nothing crosses between
compartments.

Your provider still knows which customer is paying. What an observer between you
and the provider learns is nothing — including which model you chose.

## Install

Linux only. Three pieces: the launcher, the agent it runs, and `oniux` for the
network namespace.

**1. The launcher.** It resolves everything from `$XDG_CONFIG_HOME` and uses no
paths relative to its own location, so a symlink is the whole install:

```sh
git clone https://github.com/MyrLeProgrammeur/CalypsoCode.git
cd CalypsoCode
ln -s "$PWD/bin/calypsocode" ~/.local/bin/calypsocode
```

**2. The agent.** `calypsocode-agent` has no published release yet, so it is built
from source. It is a fork of OpenCode (see [The agent](#the-agent)) and needs
`bun` — pinned at `1.3.14` — plus `node-gyp` on `PATH`, because one dependency has
no prebuilt binary for every platform and falls back to compiling:

```sh
bun install -g node-gyp
git clone https://github.com/MyrLeProgrammeur/calypsocode-agent.git
cd calypsocode-agent
bun install
bun run --cwd packages/opencode script/build.ts --single
ln -s "$PWD/packages/opencode/dist/"*"/bin/calypsocode-agent" ~/.local/bin/
```

`--single` builds for the current platform only. The result is a self-contained
binary — it needs no `bun` at runtime. Note the symlink points into the build
directory, which the next build erases and recreates.

**3. oniux**, from the Tor Project — experimental, per its own announcement:

```sh
cargo install --git https://gitlab.torproject.org/tpo/core/oniux --tag v0.11.0
```

**Check it.** `~/.local/bin` must be on your `PATH` first:

```sh
calypsocode doctor
```

`doctor` reports what it checked and what it could not, per profile: `oniux` and
the exact revision installed, `curl`, `calypsocode-agent`, and whether the
compartment's key is present. It does not
conclude that the stack works — that is what the receipt at the end of a real
session is for.

You will need a profile before `doctor` has anything to check; write one with
`calypsocode --new-profile NAME`. The subcommand comes first, so it is
`calypsocode doctor --profile NAME` — `calypsocode --profile NAME doctor` is read
as a launch.

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

- `oniux` isolation is fail-closed at the kernel routing level ✅ — and every
  session proves it against targets confirmed reachable from the host first,
  which it did not until 2026-07-26 ⚠️
- Venice and Tinfoil do **not** block Tor exits ✅
- Authenticated, billed inference over Tor works — HTTP 200 in 3.0s ✅
- A real coding session ran end-to-end on the shipped agent: 4 round trips,
  3.6s mean, 0 failures ✅
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

## The agent

CalypsoCode's own code is the launcher — profiles, compartments, egress
verification, the receipt. The coding agent it runs, `calypsocode-agent`, is a
rebranded fork of [OpenCode](https://github.com/anomalyco/opencode): the same
agentic loop and tool use, with CalypsoCode's palette and disclosure on top.
Run `calypsocode-agent --about` for the attribution. The fork is MIT, like the
original: the changes are a rebrand plus one header fix, and MIT keeps that fix
offerable upstream. This launcher is AGPL-3.0 — it is the part worth protecting,
because it holds the receipt, the leak test and the disclosure.

## Prior art

[oniux](https://gitlab.torproject.org/tpo/core/oniux) does the network
isolation as a one-liner; [LLM-Tor](https://github.com/prince776/LLM-Tor) tackles
account identity with blind signatures. Neither does per-compartment identity
for coding agents. See [docs/ROADMAP.md](docs/ROADMAP.md#prior-art).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) — no CLA.

## License

[AGPL-3.0](LICENSE).
