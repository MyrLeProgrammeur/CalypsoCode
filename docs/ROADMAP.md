# Roadmap

Where the project stands, what was decided, and the order to build in.
Context: [FINDINGS.md](FINDINGS.md) for verified behaviour,
[DESIGN.md](DESIGN.md) for the target architecture.

---

## Current status

**`bin/calypsocode` does not work.** It implements the pre-testing
architecture, which
[F1](FINDINGS.md#f1--a-host-process-cannot-reach-a-port-bound-inside-oniux)
proved is not implementable: a host-side OpenCode cannot reach a LiteLLM proxy
bound inside the oniux namespace. In `tor` mode the script always exhausts its
health-check loop and dies with `LiteLLM proxy did not start in time`, and
[F6](FINDINGS.md#f6--oniux-uses-a-private-tmp-by-default) means the log it
points at does not exist on the host.

This is a design defect, not an unfinished implementation. It is fixed by
rewriting around the profile model, not by adding code to the current script.

## <a name="gate"></a>The gate

One test decides whether Tor stays the default or becomes one backend among
several:

> Install `opencode`, obtain a Venice key, and run **one real coding session
> end-to-end** under the compartment design, timing the round trips.

It answers both remaining premise risks at once:

1. Does authenticated `POST /chat/completions` survive over Tor, or do the
   providers treat billable traffic differently from the public `/models`
   endpoint that
   [F4](FINDINGS.md#f4--venice-and-tinfoil-do-not-block-tor-exits) tested?
2. Is an agentic session — dozens of sequential round trips, each crossing
   three relays, with roughly 1 in 3 circuits dead in early sampling — usable
   at all?

Security correctness is irrelevant if the answer to (2) is no, because nobody
runs an unusable tool twice. **Measure before building further.**

Note that the [network-backend design](DESIGN.md#network-backends) makes a bad
result survivable rather than fatal: `network: tor` becomes a niche profile and
the rest of the architecture is unaffected.

## Build order

1. **Profiles and compartments.** One launch = one namespace = one circuit =
   one key = one context. Works with any backend, immediately useful, and does
   not depend on the gate.
2. **Content scrubbing.** The [biggest real leak](DESIGN.md#the-leak-that-actually-matters)
   and the strongest differentiator. Home paths, git identity, project names.
3. **Session receipts.** Egress proof, negative leak tests, compartment
   integrity, content scan results, TEE attestation.
4. **Tor as one backend among several.** VPN-in-namespace, direct, custom SOCKS.

Rewriting `bin/calypsocode` is step 1. Drop the host-side health check, drop
LiteLLM from the default path, set `NO_PROXY=127.0.0.1,localhost` if any
loopback hop remains ([F2](FINDINGS.md#f2--oniux-injects-all_proxy-which-breaks-same-namespace-loopback)),
and keep the log outside the private `/tmp`.

## Decisions taken

- **Per-request key rotation is dead.** Unsound on a shared circuit, and
  [not implementable in LiteLLM](FINDINGS.md#f5--litellm-cannot-bind-a-proxy-per-model)
  regardless. Replaced by per-compartment rotation plus optional time-based
  key retirement.
- **LiteLLM is optional, not required.** Justified only by cross-provider
  fallback, model aliasing, or content scrubbing — never by anonymity.
- **Do not rebuild the coding agent.** Wrap or fork OpenCode.
- **No hosted or pooled multi-user service.** Provider ToS.
- **Tor is a backend, not the thesis.**

## Honest assessment

The security premise survived testing: kernel-enforced fail-closed isolation is
real, providers do not block Tor at the network layer, and the compartment
design is sound.

There is no moat. What remains is a few hundred lines of orchestration around
the Tor Project's tool. But that is the wrong yardstick — `torsocks` has no
moat either. For a tool like this the success condition is that **people use
it and it does not lie to them**, and the real asset is the verified
configuration knowledge in [FINDINGS.md](FINDINGS.md): that `ALL_PROXY`
silently breaks loopback inside oniux, and that Venice and Tinfoil accept Tor,
are things nobody had written down for this use case.

The reframe in [DESIGN.md](DESIGN.md) is what makes it more than a script.
Compartmentalization serves a much larger audience than Tor does, content
scrubbing addresses a leak no competitor touches, and receipts turn assertions
into evidence.

## Prior art

- **[oniux](https://gitlab.torproject.org/tpo/core/oniux)** (Tor Project) —
  does the isolation half as a one-liner. Experimental status, per its own
  announcement. This project's contribution over `oniux opencode` is the
  compartment model, scrubbing, and verification, not the isolation itself.
- **[LLM-Tor](https://github.com/prince776/LLM-Tor)** — solves the harder
  identity half properly, using blind RSA signatures to separate payment
  identity from usage so the proxy cannot link prompts to accounts. A real
  shared anonymity set rather than a set of one. Early (≈14 stars) and requires
  a trusted third-party operator running a live service.
- **[Onion-Search-MCP](https://github.com/maximilianromer/Onion-Search-MCP)** —
  adjacent niche, agent tooling over Tor.
- **Venice** already markets anonymized proxy access to frontier models, which
  erodes part of the pitch from the provider side.
