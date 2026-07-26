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

LiteLLM, the host-side health-check loop, and the loopback hop are gone rather
than patched — they were the v0 defect that
[F1](FINDINGS.md#f1--a-host-process-cannot-reach-a-port-bound-inside-oniux)
proved unimplementable.

Steps 1–4 are implemented and **the gate below has been run and passed**: a
real coding session completed through the launcher over Tor, in 35s across 8
round trips ([F8](FINDINGS.md#f8--a-real-agentic-session-works-over-tor-at-4s-per-round-trip)).

The agent ships too. `calypsocode-agent` — a rebranded fork of OpenCode — is what
the launcher execs, and it no longer names itself in the `User-Agent` sent to a
generic provider ([the plan](plans/done/calypsocode-ui-rebrand.md),
[F11](FINDINGS.md#f11--opencode-sends-a-client-identifying-user-agent-to-a-generic-openai-compatible-provider)
for the measurement that made it necessary).

What remains is step 5, and the things one session cannot establish — how a
provider responds to Tor-origin traffic over weeks, and how the latency feels
on a large repository rather than a toy task.

## <a name="gate"></a>The gate

**Passed. Tor stays the default.**

The test was: install the agent, obtain a Venice key, and run one real coding
session end-to-end under the compartment design, timing the round trips. It was
run, and [F8](FINDINGS.md#f8--a-real-agentic-session-works-over-tor-at-4s-per-round-trip)
records the numbers. The agent was upstream `opencode` at the time — the fork
that replaced it came later, and this gate says nothing about it.

Both premise risks are answered:

1. **Does authenticated `POST /chat/completions` survive over Tor?** Yes. HTTP
   200 in 3.0s, billed normally. Venice does not treat billable Tor traffic
   differently from the public `/models` endpoint that
   [F4](FINDINGS.md#f4--venice-and-tinfoil-do-not-block-tor-exits) tested.
2. **Is an agentic session usable at Tor latency?** Yes, for a small task:
   8 round trips, 3.8s mean, 35s wall clock, 0 failures, correct result.

What the gate did *not* license: F8 is one task on one provider on one day.
It shows the premise holds, not that a long session on a large repository is
comfortable, and it says nothing about how a provider's fraud heuristics
respond over weeks. Those are in
[still untested](FINDINGS.md#still-untested).

The [network-backend design](DESIGN.md#network-backends) was the hedge against
a bad result here. It is no longer load-bearing for that reason, and the other
backends can be judged on their own merits.

## Build order

Everything in v1 is environment configuration. There is no proxy, no traffic
inspection, and no content rewriting — see
[the boundary](DESIGN.md#why-this-boundary-and-not-a-wider-one).

1. **Profiles and compartments.** One launch = one namespace = one circuit. One
   compartment = one key = one config = one identity, persisting across
   launches. Independent of the gate, immediately useful.
2. **Identity configuration.** `LC_ALL`, `TZ`, hostname, git author/committer,
   per-compartment `XDG_CONFIG_HOME`. Each is one line and removes a signal at
   its source.
3. **Startup check.** Once, before anything is sent: is the git identity the
   compartment's? Does the project path contain the OS username? Report, then
   get out of the way.
4. **Session receipts.** Egress proof, negative leak test, compartment
   integrity, and an explicit list of what was *not* removed. The leak test
   attempts what must fail — reaching the host's own network from inside the
   namespace — and refuses to launch if it succeeds
   ([F10](FINDINGS.md#f10--how-the-namespace-refuses-and-why-a-dns-based-leak-test-proves-nothing)).
5. **Tor as one backend among several.** VPN-in-namespace, direct, custom SOCKS.
   The first-run picker that presents them is built; the backends themselves are
   not, and it says so rather than offering choices that would fail. When they
   land, `socks` runs inside a namespace whose only route is the supplied
   endpoint — otherwise it is the one row in the table where fail-closed does not
   hold, since a SOCKS proxy is honoured by applications rather than enforced by
   the kernel.

Rewriting `bin/calypsocode` is step 1. Drop the host-side health check, drop
LiteLLM from the default path, and keep the log outside the private `/tmp`. If
any loopback hop survives, set `NO_PROXY=127.0.0.1,localhost`
([F2](FINDINGS.md#f2--oniux-injects-all_proxy-which-breaks-same-namespace-loopback)).

### Two questions step 5 has to answer, with what is already measured

Neither is decided. Both were investigated on 2026-07-26 so that whoever reaches step 5
starts from evidence rather than from a blank page. Nothing built so far depends on
either.

**1. Should a compartment hold one Tor circuit, or let it rotate?**

Today it rotates, and that is not a choice anyone made — it is arti's default, unexamined.
Measured inside a single namespace: **three distinct exits in 27 minutes** (`80.67.172.162`
→ `45.84.107.172` at ~11 min → `185.220.101.43` at ~22 min). So a two-hour session presents
one account to the provider from roughly a dozen addresses.

That cuts both ways, which is why it is a question and not a bug. To a fraud system, one
account hopping between many exits in an afternoon is the classic stolen-credential
signature — the risk [F4](FINDINGS.md#f4--venice-and-tinfoil-do-not-block-tor-exits)
names. Holding one exit looks like an ordinary user, and concentrates every request of
that compartment onto one relay: whoever watches it sees all of the compartment's traffic
rather than a tenth, and two compartments landing on the same exit become linkable.

The lever is `oniux --arti-config` with `[circuit_timing] max_dirtiness`. **Do not trust
the config being accepted:** arti silently accepts keys that do not exist — verified by
feeding it an invented one, which it swallowed without complaint. One run with
`max_dirtiness = "24 hours"` held the same exit through 13 minutes, where the unconfigured
run had already rotated at 11; the confirming probe at 20 minutes was lost to a dead
circuit. **Suggestive, not established.** What would settle it is both configurations
running in parallel namespaces for 30–40 minutes, which removes the day and the network
load as explanations.

Per-compartment separation is a different and easier question, already answered:
[F3](FINDINGS.md#f3--distinct-socks-credentials-give-distinct-circuits) measured that
distinct SOCKS credentials give distinct circuits, 4 for 4.

The real answer probably differs per provider, and weeks of ordinary use is what would
inform it — the same measurement [Still untested](FINDINGS.md#still-untested) item 1 has
been waiting for since the beginning.

**2. Should the launcher support Tor bridges?**

Today `docs/THREAT-MODEL.md` says an observer between you and the provider learns nothing
except that you use Tor. A bridge removes that last line: with a pluggable transport the
traffic does not look like Tor at all. That is a capability change, not a refinement.

**arti supports it.** Verified in the installed `oniux` binary: the pluggable-transport
manager is compiled in (`BridgeConfig`, and the error string `PT binary failed to
initialise transports`). No transport is bundled — `obfs4`, `snowflake` and `webtunnel`
appear nowhere in it — because arti spawns an **external** PT binary over the standard
protocol. None is installed on this machine.

So the cost is one more runtime dependency (`lyrebird` for obfs4, or `snowflake-client`),
a bridge to obtain, and configuration. **`doctor` would have to check that binary**, or
this recreates exactly the hole closed on 2026-07-26 when it turned out `curl` — which
performs both verifications — was never checked.

Two things worth keeping straight if this is picked up. A bridge replaces your guard with
a relay nobody vetted: the trade against a VPN is real, but it is *contractual*
traceability you avoid, not the operator seeing your address — the bridge sees it, exactly
as a VPN would. And Snowflake is harder to block, not unblockable: censors fingerprint its
STUN/DTLS patterns rather than blocking WebRTC wholesale, and have degraded it in practice.

## Decisions taken

- **The thesis: CalypsoCode hides your network identity from everyone except the
  provider you pay.** Content confidentiality is a property of the provider the
  user chooses.
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
- **Do not rebuild the coding agent.** Wrap or fork OpenCode. **Done:** forked, as
  `calypsocode-agent`. The agentic loop and tool use stay upstream's; what the
  fork adds is the branding and the de-branded wire.
- **The launcher is a local tool.** It includes no hosted or pooled multi-user
  service. Whether one should exist is a project-direction decision, not a code
  change.
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
