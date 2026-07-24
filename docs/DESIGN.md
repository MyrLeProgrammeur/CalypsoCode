# Design — erasing who is asking

> **Calypso erases who is asking. Not what is asked.**

That sentence is the scope. Everything below follows from it.

This is a design document, not a description of what the code currently does.
See [FINDINGS.md](FINDINGS.md) for what is verified and
[ROADMAP.md](ROADMAP.md) for build order.

---

## The boundary

Two different problems get confused constantly:

| | Problem | Whose job |
|---|---|---|
| **What** is sent | Can the provider read my code and my prompts? | **The provider's.** Pick a hardware enclave (Tinfoil) if you want this. It is a property of who you buy from, not of Calypso. |
| **Who** sent it | Can the provider tell it was me? | **Calypso's.** Nobody serves this well today. |

Calypso makes no claim about content. It does not read, rewrite, or scrub your
code or your prompts. If content confidentiality matters to you, that is a
provider choice, and it is yours to make.

### Why this boundary and not a wider one

An earlier version of this design had Calypso rewriting request bodies to strip
identifiers out of prompts and tool calls. That was dropped deliberately:

- It required two-way translation with per-session state — the model answers
  using the fake values, so every answer must be translated back.
- It had to cover file contents, tool-call arguments, tool-call results, and
  command output, in every encoding those can appear in.
- Getting it wrong corrupts the user's source code. For a privacy tool, that is
  worse than the leak it prevents.
- Its failures are silent. A missed pattern leaks with no error.

The scope above avoids all of it. Everything Calypso removes, it removes by
**configuring the environment before launch**, never by rewriting traffic.

---

## What "identity" means here

Identity is not your name. To a provider, it is the **set of signals that link
two requests to the same person**. You do not need to be named to be tracked —
you need to be linkable.

### Every signal, decided

| Signal | Who or what? | Calypso |
|---|---|---|
| IP address | who | ✅ Tor, via `oniux` |
| Locale, timezone, hostname | who | ✅ set in the namespace |
| Git author name and email | who | ✅ per-compartment identity |
| Agent config / memory files | who — a dossier about you | ✅ per-compartment config |
| OS / kernel / shell metadata | who | ✅ normalized where the agent allows |
| Client & TLS fingerprint | who | ⚠️ partial — see below |
| Working hours, session rhythm | who | ⚠️ reported, not removed |
| **OS username in file paths** | **who** | ❌ **not handled — user-side, see [THREAT-MODEL](THREAT-MODEL.md)** |
| **API key / account** | **who** | ❌ **cannot be removed** |
| Writing style | who, inseparable from what | ❌ cannot be removed |
| Your code | what | not touched |
| Your prompt text | what | not touched |

The ❌ rows are in scope by the thesis and out of reach in practice. They belong
in the receipt, stated plainly, every session.

### The rule for compartments

**Every signal must change at the same boundary.** A compartment is only as
isolated as its weakest shared signal. Rotate the key but share the circuit and
the circuit links them; rotate the circuit but share the key and the key links
them.

### Why per-request rotation was wrong

The original design shuffled several API keys across requests on a **single
shared circuit**. That rotates the credential while holding the network
constant, which does not merely fail to help — it creates the link. The provider
sees N distinct keys arriving from one exit IP, in one window, inside one
conversation. That is a correlation proof, not a defence.

Rotation as a *goal* is sound — it stops one account accumulating your entire
history. Only the unit was wrong. Rotation now happens at the **compartment**
boundary, where every signal changes together.

It is also not implementable otherwise:
[LiteLLM cannot bind a proxy per model](FINDINGS.md#f5--litellm-cannot-bind-a-proxy-per-model).

### Rotation over time

A compartment's key can retire after N sessions or N days, with a fresh one
taking over. This bounds accumulation inside a compartment, and it is nearly
free — a new namespace already draws a new circuit
([F3](FINDINGS.md#f3--distinct-socks-credentials-give-distinct-circuits)).

---

## The residual: your account

Tor hides your IP. Your API key then announces your name on arrival.

You authenticate as a paying customer with an email and a payment method. The
provider does not need your IP — you told them who you are in the header. Under
this thesis that stops being a footnote and becomes *the* limit, because "who
is asking" is the entire product.

What can be done:

- **Compartments** — separate accounts for separate work, limiting what any one
  account accumulates.
- **Retirement** — a compartment's key expires and is replaced.
- **Funding** — an anonymous purchase chain, with the caveats in
  [THREAT-MODEL.md](THREAT-MODEL.md).

What cannot: making the account itself anonymous. That needs blind signatures
and a service operator, which is
[out of scope](#scope-boundary).

So the honest form of the thesis:

> Calypso erases everything about who is asking, except the account you pay
> with — and gives you the tools to keep those accounts separate.

---

## How it works: configure, don't rewrite

Everything Calypso removes is removed **before the agent starts**, by
controlling the environment it runs in. No traffic is inspected or modified.

```
LC_ALL=C                  # no locale leak (French shell errors, etc.)
TZ=UTC                    # no timezone inference
hostname                  # set inside the namespace
GIT_AUTHOR_NAME=dev       # git stops printing your name
GIT_AUTHOR_EMAIL=dev@localhost
GIT_COMMITTER_NAME=dev
GIT_COMMITTER_EMAIL=dev@localhost
XDG_CONFIG_HOME=<compartment>   # agent loads this compartment's config only
```

Each line removes a signal at its source, so the bad value is never produced.
That is strictly more reliable than detecting and removing it afterwards, and it
cannot corrupt anything.

### Profile schema

One flat `KEY=value` file per compartment, at
`~/.config/calypsocode/profiles/<name>.env`:

```sh
PROFILE=client-acme
NETWORK=tor                        # v1 implements tor | none
API_KEY_ENV=VENICE_API_KEY_ACME    # names the variable, never holds the key
API_BASE=https://api.venice.ai/api/v1
MODEL=zai-org-glm-5-1              # model choice is the user's, uncensored or not
GIT_NAME=dev
GIT_EMAIL=dev@localhost
```

Flat text, not YAML: it needs no parser beyond a `read` loop and adds no
runtime dependency. The file is **read, never sourced** — a config file must not
be able to run code. Unknown keys are refused rather than ignored, so a typo
fails loudly instead of silently dropping a compartment boundary.

The key itself stays out of the file, which lives in a config directory that
tends to end up in backups and dotfile repos. The profile names the environment
variable; the user exports it from wherever they keep secrets.

Retirement (`retire: 30d`) and the `vpn` / `direct` / `socks` backends are
design, not v1 — see [network backends](#network-backends).

One launch = one namespace = one circuit = one key = one config. Nothing
crosses.

### Network backends

| Value | Mechanism |
|---|---|
| `tor` | `oniux` (verified working) |
| `vpn` | WireGuard inside the namespace |
| `direct` | plain namespace, no isolation |
| `socks` | user-supplied SOCKS endpoint |

Tor is one backend, not the thesis. Two reasons that matters:

- **The transport is not the identity model.** Compartments, identity
  environment, and receipts are unchanged by whichever backend carries them.
  Changing `network:` moves rows in the signal table above; it does not move the
  boundary.
- **Fail-closed generalizes.** Namespace isolation makes a VPN leak-proof too,
  which is better than most VPN kill switches. Someone who needs a network
  observer defeated but cannot pay three-hop latency still has a real option.

It also de-risks the project: if the latency gate
([ROADMAP.md](ROADMAP.md#gate)) shows Tor is unusable for agentic sessions,
`network: tor` becomes a niche profile and nothing else changes.

### Is LiteLLM required?

**No.** Its only job was per-request key rotation, which it cannot do per
circuit and which is the wrong unit anyway. OpenCode speaks to
OpenAI-compatible providers directly, so pointing it at a provider removes the
proxy layer, a large Python dependency with its own CVE history, the loopback
hop, and the [`ALL_PROXY` trap](FINDINGS.md#f2--oniux-injects-all_proxy-which-breaks-same-namespace-loopback).

With content rewriting out of scope, nothing requires Calypso to sit in the
request path at all. Keep a proxy only for cross-provider fallback or model
aliasing — conveniences, never anonymity.

---

## Proof, not claims

Privacy tools assert; almost none demonstrate. A `doctor` that checks three
binaries exist and prints `everything is ready` has verified nothing.

Properties worth proving:

1. **Egress proof.** From inside the namespace, confirm the exit is Tor and
   record which exit. Already demonstrated in
   [F4](FINDINGS.md#f4--venice-and-tinfoil-do-not-block-tor-exits).
2. **Negative leak test.** Deliberately attempt what *must* fail — reach a host
   interface, resolve DNS outside the namespace — and assert it fails. This is
   the only way to prove isolation rather than assume it.
3. **Identity check at startup.** Once, before anything is sent: is the git
   identity the compartment's or the user's real one? Does the project path
   contain the OS username? Report and let the user decide.
4. **Compartment integrity.** Log the key↔circuit binding per session and
   assert key_A never left via circuit_B.

### The receipt

On exit, state what left the machine and under what identity — including what
was **not** removed:

```
compartment:  client-acme
network:      tor, exit 94.16.116.81, verified IsTor
identity:     git dev@localhost, TZ=UTC, LC_ALL=C
config:       compartment-local only

NOT removed:  prompt content, source code, writing style
              session timing (14:02–15:31 CET, 47 requests)
              OS username present in file paths
              account: venice_acme — the provider knows this customer
```

The receipt is where the honesty lives. Because it states the limits every
session, the README does not need a paragraph of disclaimers — the tool says it
at the moment it matters.

A check at **session start** is different from the receipt and both are needed:
a log tells you after it left, a warning tells you before. One check at the
boundary, then silence, then the receipt.

---

## Scope boundary

- **No content rewriting.** Not prompts, not code, not tool calls. See
  [why](#why-this-boundary-and-not-a-wider-one).
- **No filesystem mounts or path remapping.** Considered and dropped: it solved
  only the username-in-path leak, at the cost of per-compartment mount scoping,
  dependency-reach problems, relative-path depth constraints, and the risk of
  breaking a user's project. The leak it addressed is handled by user-side
  convention instead ([THREAT-MODEL.md](THREAT-MODEL.md)).
- **Do not rebuild the agent.** The agentic loop, tool use, and context
  management are years of work and are why OpenCode exists. Wrap or fork one.
- **No hosted or pooled multi-user service.** Ruled out on provider-ToS grounds.
- **No verifying other people's guarantees.** Calypso does not attest enclaves
  or vouch for provider policy. Provider choice is the user's.
