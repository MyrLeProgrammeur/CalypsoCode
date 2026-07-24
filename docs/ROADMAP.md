# Roadmap

Where the project stands, what was decided, and the order to build in.
Context: [FINDINGS.md](FINDINGS.md) for verified behaviour,
[DESIGN.md](DESIGN.md) for the target architecture.

---

## Current status

**`bin/calypsocode` was rewritten around the profile model.** It loads a
compartment profile, sets identity by environment, launches the agent inside a
single `oniux` namespace, verifies from inside that the egress is Tor before
anything is sent, and writes a receipt to `~/.local/state/calypsocode/`.

Steps 1–4 of the build order below are implemented. LiteLLM, the host-side
health-check loop, and the loopback hop are gone rather than patched — they
were the v0 defect that
[F1](FINDINGS.md#f1--a-host-process-cannot-reach-a-port-bound-inside-oniux)
proved unimplementable.

**What is not done is the gate.** No real coding session has ever run through
this. Everything below the network layer is still assumption.

## <a name="gate"></a>The gate

One test decides whether Tor stays the default or becomes one backend among
several:

> Install `opencode`, obtain a Venice key, and run **one real coding session
> end-to-end** under the compartment design, timing the round trips.

It answers both remaining premise risks at once:

1. Does authenticated `POST /chat/completions` survive over Tor, or do providers
   treat billable traffic differently from the public `/models` endpoint that
   [F4](FINDINGS.md#f4--venice-and-tinfoil-do-not-block-tor-exits) tested?
2. Is an agentic session — dozens of sequential round trips, each crossing three
   relays, with roughly 1 in 3 circuits dead in early sampling — usable at all?

Security correctness is irrelevant if the answer to (2) is no, because nobody
runs an unusable tool twice. **Measure before building further.**

The [network-backend design](DESIGN.md#network-backends) makes a bad result
survivable rather than fatal: `network: tor` becomes a niche profile and the
rest of the architecture is unaffected.

## Build order

Everything in v1 is environment configuration. There is no proxy, no traffic
inspection, and no content rewriting — see
[the boundary](DESIGN.md#why-this-boundary-and-not-a-wider-one).

1. **Profiles and compartments.** One launch = one namespace = one circuit =
   one key = one config. Independent of the gate, immediately useful.
2. **Identity configuration.** `LC_ALL`, `TZ`, hostname, git author/committer,
   per-compartment `XDG_CONFIG_HOME`. Each is one line and removes a signal at
   its source.
3. **Startup check.** Once, before anything is sent: is the git identity the
   compartment's? Does the project path contain the OS username? Report, then
   get out of the way.
4. **Session receipts.** Egress proof, negative leak test, compartment
   integrity, and an explicit list of what was *not* removed.
5. **Tor as one backend among several.** VPN-in-namespace, direct, custom SOCKS.

Rewriting `bin/calypsocode` is step 1. Drop the host-side health check, drop
LiteLLM from the default path, and keep the log outside the private `/tmp`. If
any loopback hop survives, set `NO_PROXY=127.0.0.1,localhost`
([F2](FINDINGS.md#f2--oniux-injects-all_proxy-which-breaks-same-namespace-loopback)).

## Decisions taken

- **The thesis: Calypso erases who is asking, not what is asked.** Content
  confidentiality is a property of the provider the user chooses.
- **No content rewriting.** Not prompts, not code, not tool calls. Two-way
  translation with per-session state, covering every encoding, whose failures
  are silent and whose bugs corrupt user source — rejected as more dangerous
  than the leak it prevents.
- **No filesystem mounts or path remapping.** Considered and dropped. It
  addressed only the username-in-path leak, at the cost of per-compartment mount
  scoping, dependency-reach limits, relative-path depth constraints, and risk to
  the user's project. Handled by user-side convention instead
  ([THREAT-MODEL.md](THREAT-MODEL.md#keep-your-username-out-of-your-paths)).
- **No verifying other people's guarantees.** Calypso does not attest enclaves
  or vouch for provider policy. Doing so would inherit a blast radius it does
  not control, for no benefit.
- **Per-request key rotation is dead.** Unsound on a shared circuit, and
  [not implementable in LiteLLM](FINDINGS.md#f5--litellm-cannot-bind-a-proxy-per-model).
  Replaced by per-compartment rotation plus optional time-based retirement.
- **LiteLLM is optional.** With content rewriting out of scope, nothing requires
  Calypso to sit in the request path.
- **Do not rebuild the coding agent.** Wrap or fork OpenCode.
- **No hosted or pooled multi-user service.** Provider ToS.
- **Tor is a backend, not the thesis.**

## Honest assessment

The security premise survived testing: kernel-enforced fail-closed isolation is
real, providers do not block Tor at the network layer, and the compartment
design is sound.

There is no moat. What remains is a few hundred lines of orchestration around
the Tor Project's tool. But that is the wrong yardstick — `torsocks` has no moat
either. The success condition is that **people use it and it does not lie to
them**, and the real asset is the verified configuration knowledge in
[FINDINGS.md](FINDINGS.md): that `ALL_PROXY` silently breaks loopback inside
oniux, and that Venice and Tinfoil accept Tor, are things nobody had written
down for this use case.

Narrowing the scope to "who, not what" made the project smaller and much more
buildable. v1 is a launcher plus environment configuration — days of work, every
part of it verifiable — rather than a request-rewriting engine that could
corrupt a user's repository. The two things it cannot do (account identity,
writing style) are stated in the receipt every session rather than hidden.

## Prior art

- **[oniux](https://gitlab.torproject.org/tpo/core/oniux)** (Tor Project) —
  does the network isolation as a one-liner; experimental per its own
  announcement. This project's contribution over `oniux opencode` is the
  compartment model, identity configuration, and receipts.
- **[LLM-Tor](https://github.com/prince776/LLM-Tor)** — tackles the account
  identity problem directly, using blind RSA signatures so the proxy cannot link
  prompts to purchasing accounts. A real shared anonymity set rather than a set
  of one. Early (≈14 stars) and requires a trusted third-party operator running
  a live service.
- **[Onion-Search-MCP](https://github.com/maximilianromer/Onion-Search-MCP)** —
  adjacent niche, agent tooling over Tor.
- **Venice** already markets anonymized proxy access to frontier models, which
  erodes part of the pitch from the provider side.
