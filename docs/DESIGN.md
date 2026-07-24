# Design — identity compartmentalization for coding agents

The direction CalypsoCode is moving toward. This is a design document, not a
description of what the code currently does. See
[FINDINGS.md](FINDINGS.md) for what is verified and
[ROADMAP.md](ROADMAP.md) for build order.

---

## The reframe

The first version treated Tor as the thesis: a wrapper that runs a coding agent
over Tor with a pool of rotating API keys. Testing killed both halves of that
(see [F1](FINDINGS.md#f1--a-host-process-cannot-reach-a-port-bound-inside-oniux)
and [F5](FINDINGS.md#f5--litellm-cannot-bind-a-proxy-per-model)), and the
security argument killed the rotation independently.

What survives is a bigger idea. Tor is one **network backend**. The actual
primitive is:

```
profile = { API key, network path, model, memory/history boundary }
```

**Identity compartmentalization for coding agents.** The audience is no longer
"people who want Tor" — it is anyone who does not want project A's agent
traffic, keys, and context bleeding into project B's: consultants with multiple
clients, people under NDA boundaries, people whose employer bans AI tooling on
some repos but not others. Same machinery, much larger audience, and the Tor
users lose nothing.

---

## What "identity" means here

Identity is not your name. To a provider, your identity is the **set of signals
that let them link two requests to the same person**. You do not need to be
named to be tracked — you need to be linkable.

Compartmentalization means splitting activity into boxes where no signal ever
crosses between boxes.

Without compartments, one key and no isolation, over two years:

```
key K + home IP + client-A code + personal projects + your working hours
→ one profile, everything joined
```

One breach, one subpoena, one bad employee, and all of it is exposed
retroactively.

With compartments:

```
box "client-A":  key K_A  circuit C_A  only client A's code
box "personal":  key K_P  circuit C_P  only personal projects
→ two accounts that do not look related
```

### The rule that makes it work

**Every signal must change at the same boundary.** A compartment is only as
isolated as its weakest shared signal.

Rotate the key but share the circuit, and the circuit links them. Rotate the
circuit but share the key, and the key links them.

### The signals a coding agent emits

| Signal | Leaks via |
|---|---|
| Network | exit IP, circuit |
| Credential | API key, account |
| Payment | card or wallet that funded the account |
| **Content** | code, file paths, project names, writing style |
| Temporal | working hours, session rhythm |
| Client | user-agent, model choice, request shape |

All of them have to be compartmented. Most tools address only the first.

### Why per-request rotation was wrong

The original design shuffled several API keys across requests on a **single
shared circuit**. That rotates one signal (credential) while holding another
constant (network), which does not merely fail to help — it actively creates
the link. The provider observes N distinct keys arriving from one exit IP in
one time window inside one continuous conversation, which is a correlation
proof that those accounts are the same person.

Rotation as a *goal* is sound: it prevents one account accumulating your entire
history, so a future compromise cannot expose everything retroactively. The
unit was wrong. The fix is to rotate at the **compartment** boundary, where
every signal changes together.

Within a session, per-request rotation buys nothing anyway — the prompt
*content* links every request regardless of which key sent it.

### The third axis: rotation over time

A compartment's key can retire after N sessions or N days, with a fresh key
taking over. This bounds accumulation even inside a compartment, and it is
nearly free: a new namespace already draws a new circuit
([F3](FINDINGS.md#f3--distinct-socks-credentials-give-distinct-circuits)).

---

## The leak that actually matters

Network isolation is the part everyone thinks of and the part that is already
solved. The unsolved leak is **content**.

A coding agent sends file paths constantly. It sends diffs, which carry git
authorship. It sends stack traces with absolute paths. So the provider
receives, inside the prompt body:

```
/home/<user>/dev/client-acme/src/billing.ts
Author: <Real Name> <real.email@example.com>
```

**Tor does nothing about this.** Neither does a VPN, key rotation, or a TEE.
Kernel-level network isolation is in place and the username walks out in the
payload on request one.

This is the gap, and it is why a coding-agent-specific privacy tool is a
different product from "use Tor". The agent controls what gets sent, so the
agent can scrub it:

- home and project paths → stable per-compartment placeholders (`/work/...`)
- git author name and email → stripped
- client and project names → consistent per-compartment pseudonyms, so the
  model still reasons coherently across a session
- machine hostname, OS username, absolute paths in traces

This is also where a local proxy layer earns its place — **not** for key
rotation, but as an **egress filter** rewriting payloads before they leave.

---

## Profile schema (sketch)

```yaml
profile: client-acme
  network: tor          # tor | vpn | direct | socks
  key:     venice_acme  # one key, bound to this compartment only
  model:   uncensored
  scrub:   strict       # off | basic | strict
  retire:  30d          # rotate this compartment's key after N days
```

One launch = one namespace = one circuit = one key = one context. Nothing
crosses.

### Network backends

The launcher builds the namespace to match the `network` field:

| Value | Mechanism |
|---|---|
| `tor` | `oniux` (verified working) |
| `vpn` | WireGuard inside the namespace |
| `direct` | plain namespace, no isolation |
| `socks` | user-supplied SOCKS endpoint |

The compartment machinery, key binding, scrubbing, and receipts are identical
across backends. Two reasons this matters beyond flexibility:

- **Most of the audience does not need Tor.** A consultant separating client A
  from client B needs separate keys and contexts; Tor's three-hop latency buys
  them nothing. Today they cannot be served at all.
- **The fail-closed property generalizes.** Namespace isolation makes a VPN
  leak-proof too, which is better than most VPN kill switches (userspace and
  racy).

It also de-risks the project: if the latency test
([ROADMAP.md](ROADMAP.md#gate)) shows Tor is unusable for agentic sessions,
`network: tor` becomes a niche profile and everything else survives unchanged.

### Is LiteLLM required?

**No.** Its only job was per-request key rotation, which it cannot do per
circuit ([F5](FINDINGS.md#f5--litellm-cannot-bind-a-proxy-per-model)) and which
is the wrong unit anyway. OpenCode speaks to OpenAI-compatible providers
directly, so pointing it at Venice removes the proxy layer, a large Python
dependency with its own CVE history, the loopback hop, and the `ALL_PROXY`
trap.

Bring a proxy layer back only for: cross-provider fallback, a single model alias
spanning providers, or — the good reason — **content scrubbing**. Those are
features, not security primitives, and they should not sit in the trust path by
default.

---

## Proof, not claims

Every privacy tool asserts. Almost none demonstrate. The current `doctor`
checks that three binaries exist and prints `everything is ready` — it has
never verified a single property.

Five properties it could actually prove, in rough order of difficulty:

1. **Egress proof.** From inside the namespace, confirm the exit is Tor and
   record which exit. Already demonstrated in
   [F4](FINDINGS.md#f4--venice-and-tinfoil-do-not-block-tor-exits).
2. **Negative leak test.** Deliberately attempt what *must* fail — reach a host
   interface, resolve DNS outside the namespace — and assert it fails. Nobody
   does negative testing, and it is the only way to prove isolation rather than
   assume it.
3. **Compartment integrity.** Log the key↔circuit binding per session and
   assert key_A never left via circuit_B. This is the invariant the whole
   design rests on, and it is machine-checkable.
4. **Content scan.** Before each request, scan the payload for known identity
   tokens — OS username, git email, home path, client names. Block or warn.
   Milliseconds, and it covers the leak that matters most.
5. **TEE attestation.** Tinfoil publishes enclave attestation. Verify it per
   session and surface the result instead of trusting the marketing.

Package the output as a **session receipt**: on exit, state exactly what left
the machine, under which identity, through which exit, with which scrubs
applied and which attestation verified.

That receipt is the trust artifact — the thing that makes someone recommend
this to a colleague whose safety depends on it, and the standard
[THREAT-MODEL.md](THREAT-MODEL.md) already sets.

---

## Scope boundary

**Do not rebuild the agent.** The agentic loop, tool use, file editing, and
context management are years of work and are why OpenCode exists. The
differentiation here is the privacy layer. Wrap or fork an existing agent.

**No hosted or pooled multi-user service.** Ruled out on provider-ToS grounds
and unchanged by any of the above.
