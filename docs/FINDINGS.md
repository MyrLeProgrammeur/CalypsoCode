# Findings — verified behaviour of the stack

Empirical results from testing `oniux`, the provider endpoints, and LiteLLM.
Everything here was **measured**, not assumed. Where something is untested, it
says so.

Test date: 2026-07-24 · Linux 7.0.0-27-generic · oniux installed via
`cargo install --git https://gitlab.torproject.org/tpo/core/oniux --tag v0.11.0`.

**The oniux revision matters and is recorded here for that reason.** Every isolation
finding below — F1, F2, F6, F7, F10, F14 — was measured against
**oniux 0.11.0, commit `f98d8f5c270a`**. oniux is experimental by its own
announcement and has no `--version` flag; without pinning, none of these findings is
reproducible, including by their author after the next `cargo install`. If the
installed revision differs from this one, treat them as expired rather than as facts.
`calypsocode doctor` prints what is actually installed.

**Corrections.** When a finding turns out to have been stated wrong, it is
corrected in place and labelled `**Correction, <date>.**`, not deleted — see
the example under [F7](#f7--home-is-shared-with-the-host-only-tmp-is-private)
and the caveat under [F12](#f12--the-compiled-calypsocode-agent-holds-a-real-session-over-tor).
Replacing a real local username or home path with a placeholder (`<user>`,
`<home>`, `<project>`) is the same category of edit: a privacy redaction, not
a retraction. It does not change what was measured or what the finding
concludes — only which literal string stands in for a path that was never
part of the technical result.

---

## F1 — A host process cannot reach a port bound inside oniux

**Status: confirmed. This invalidated the original architecture.**

`oniux` places the child in its own network namespace, which has its own
loopback stack. The host's `127.0.0.1` and the namespace's `127.0.0.1` are
different network stacks.

```
host netns:   lo 127.0.0.1/8   wlp1s0 10.243.121.206   proton0 10.2.0.2
oniux netns:  lo 127.0.0.1/8   onion0 169.254.42.1
```

Binding a listener on port 4000 inside oniux and connecting from the host:

```
curl 127.0.0.1:4000  →  exit 7 (connection refused)
ss -ltnp | grep 4000 →  nothing listening on host port 4000
```

`oniux --help` confirms there is no escape hatch — no `--publish`, no
`--expose`. The only port option is `--socks-port`, which starts a SOCKS
server *inside* the namespace.

**Consequence.** The original design — `opencode` on the host talking to
`oniux litellm` over `127.0.0.1:4000` — is not implementable. Any component
that must talk to another over loopback has to live in the **same** namespace.

## F2 — oniux injects `ALL_PROXY`, which breaks same-namespace loopback

**Status: confirmed. This is the subtlest trap in the stack.**

Co-locating both processes in one namespace looked broken at first. It is not.
`lo` is up and the listener binds correctly:

```
LISTEN 0 5   127.0.0.1:4000   users:(("python3",pid=5,fd=3))
```

The failure comes from the environment oniux hands the child:

```
ALL_PROXY=socks5h://localhost:9050
```

Every proxy-aware client — curl, httpx, and therefore **LiteLLM and
OpenCode** — dutifully sends even `127.0.0.1` traffic to Tor's SOCKS server,
which refuses to proxy to localhost:

```
* Uses proxy env variable ALL_PROXY == 'socks5h://localhost:9050'
* cannot complete SOCKS5 connection to 127.0.0.1. (1)
```

**Fix.** Set `NO_PROXY=127.0.0.1,localhost` (and lowercase `no_proxy`) for the
client side, or unset `ALL_PROXY`. Verified working.

**This does not weaken isolation.** Re-running the egress check with `NO_PROXY`
set still returns `{"IsTor":true,"IP":"45.84.107.55"}`, because the namespace
has exactly one route:

```
default dev onion0 proto static
169.254.42.0/24 dev onion0 proto kernel scope link src 169.254.42.1
```

Isolation is enforced by the kernel routing table, not by the env var. The
variable is belt-and-braces; removing it for loopback is safe.

**Known casualty.** The Tinfoil block in `config/litellm.config.example.yaml`
points LiteLLM at `http://127.0.0.1:3301/v1`. That path is broken as written
for exactly this reason.

## F3 — Distinct SOCKS credentials give distinct circuits

**Status: confirmed, 4/4 distinct exits.**

oniux runs an internal SOCKS server (default port 9050). Arti applies stream
isolation per SOCKS credential pair, so different credentials get different
circuits:

| SOCKS user | Exit IP |
|---|---|
| `k1` | 192.42.116.118 |
| `k2` | 45.84.107.198 |
| `k3` | 45.84.107.17 |
| `k4` | 185.100.87.192 |

Separate `oniux` invocations also draw separate circuits — exits observed
across runs in this session: `37.187.74.97`, `45.84.107.55`, `94.16.116.81`,
`45.84.107.33`.

**Consequence.** Binding one identity to one circuit is achievable two ways:
per-SOCKS-credential within a namespace, or one namespace per identity. The
latter is simpler and needs no SOCKS configuration at all, since the namespace
default route already is that identity's circuit.

## F4 — Venice and Tinfoil do not block Tor exits

**Status: confirmed at the network layer. Not confirmed for authenticated traffic.**

Both providers expose `/models` publicly — clearnet baseline returns HTTP 200
with no key at all, so any difference over Tor is purely network-level
blocking.

| Circuit | Exit IP | Venice `/api/v1/models` | Tinfoil `/v1/models` |
|---|---|---|---|
| c1 | 94.16.116.81 | **200** | **200** |
| c2 | 45.84.107.33 | **200** | **200** |
| c3 | *(circuit dead)* | ERR | ERR |

c3 also failed against `check.torproject.org`, so it was a dead circuit, not
provider blocking.

**Caveats, stated plainly:**

- This is an **unauthenticated GET to a public endpoint**. It does not prove
  that authenticated, billable `POST /chat/completions` traffic survives.
  Anti-abuse rules are routinely per-route.
- A key presenting from rotating Tor exits is a classic credential-theft
  signal to a fraud system. ToS permission and fraud heuristics are different
  things, and neither is tested here.
- 1 of 3 circuits was simply dead. Small sample, but the launcher needs
  retry-on-circuit-failure, not a fixed health-check loop that gives up.

## F5 — LiteLLM cannot bind a proxy per model

**Status: confirmed via upstream issue. Open, unimplemented.**

[BerriAI/litellm#25563](https://github.com/BerriAI/litellm/issues/25563) is an
open feature request for per-model SOCKS5/outbound proxy in `model_list`.
LiteLLM today honours only process-level `HTTP_PROXY` / `HTTPS_PROXY` /
`ALL_PROXY`. The acknowledged workaround is to run multiple LiteLLM instances
with different env proxy settings.

**Consequence.** Binding key₁→circuit₁ and key₂→circuit₂ inside a single
LiteLLM instance is **not possible today**. This kills per-request key rotation
on technical grounds, independently of the security argument in
[DESIGN.md](DESIGN.md#why-per-request-rotation-was-wrong).

## F6 — oniux uses a private `/tmp` by default

**Status: confirmed.**

`--no-private-tmp` disables it, so by default the child gets its own `/tmp`
mount. Anything the wrapped process writes to `/tmp` is invisible from the
host. `bin/calypsocode` writes its LiteLLM log to `/tmp/calypsocode-litellm.log`
and then tells the user to read it on failure — pointing at a file that does
not exist outside the namespace.

## F7 — `$HOME` is shared with the host; only `/tmp` is private

**Status: confirmed.**

The private mount from [F6](#f6--oniux-uses-a-private-tmp-by-default) covers
`/tmp` and not `$HOME`. A file written by the wrapped process appears on the
host immediately:

```
inside:  echo "written from inside the namespace" > ~/.local/state/calypsocode/probe
host:    cat ~/.local/state/calypsocode/probe
         written from inside the namespace
```

The same run corroborates F6 from the other direction: an executable placed in
a `/tmp` subdirectory and added to `PATH` was **not found** inside the
namespace, because that path does not exist there.

**Consequence.** Results that are only knowable inside the namespace — the Tor exit
IP, the leak-test verdict, whether the agent started — are written from inside to
`~/.local/state/calypsocode/` and read on the host. No host-side file handle has to be
passed in, and nothing may be written to `/tmp`.

> **Correction, 2026-07-26.** This paragraph said "the session receipt is written from
> inside the namespace". It is not, and never was: `receipt_write` runs on the host,
> from the `EXIT`/`INT`/`TERM` traps, outside `oniux`. Only the small marker files
> above cross the boundary. The finding's conclusion — that `$HOME` is the way back
> out and `/tmp` cannot be used — is unaffected and is what the measurement showed;
> the sentence describing which file takes that path was wrong when written.

## F8 — A real agentic session works over Tor, at ~4s per round trip

**Status: confirmed. This is [the gate](ROADMAP.md#gate).**

OpenCode 1.18.4 through `bin/calypsocode`, Venice `zai-org-glm-5-1`, one task:
write `fizzbuzz.py`, run it with `python3` to check it, write a README. The
agent completed it correctly and the script produces correct output.

| | |
|---|---|
| Wall clock | 35s, including egress verification |
| Assistant round trips | 8 |
| Round trip min / mean / max | 2.1s / 3.8s / 9.0s |
| Failed requests during the session | 0 |
| Tokens | 15.4K in, 637 out, 104K cache read |
| Exit | 185.220.101.16, verified `IsTor` before launch |

**Authenticated inference was tested separately first**, because it is the risk
[F4](#f4--venice-and-tinfoil-do-not-block-tor-exits) explicitly did not cover:
`POST /chat/completions` with a real key over Tor returned **HTTP 200 in 3.0s**
(exit 185.220.101.23), billed normally — the response carried
`"cost":{"usd":0.001586266}`. Venice does not treat billable Tor-origin traffic
differently from the public `/models` endpoint.

**Caveats, stated plainly:**

- One task, one provider, one session, one day. This is an existence proof that
  the premise holds, not a latency distribution.
- The first round trip is the slow one (9.0s). The rest sat between 2.1s and
  4.2s.
- One circuit was dead immediately before this run and needed a retry, matching
  F4's roughly-1-in-3 rate. The launcher's retry handled it.
- Nothing here says anything about a long session, a large repo, or how a
  provider's fraud heuristics respond over weeks.

**Consequence.** Tor stays the default. ~4s per round trip is materially slower
than clearnet and it is not the thing that makes an agentic session unusable.

## F9 — `XDG_CONFIG_HOME` alone does not compartment OpenCode

**Status: confirmed. It changed the launcher.**

Good news first: a marker provider planted in the host's global
`~/.config/opencode/opencode.json` did **not** appear in `opencode debug config`
inside a compartment. OpenCode honours `XDG_CONFIG_HOME`, so config isolation
works — that was an open question and it is now answered.

But config is not the compartment. With only `XDG_CONFIG_HOME` set,
`opencode debug paths` reported:

```
config     …/compartments/gate/opencode      ← moved
data       <home>/.local/share/opencode ← SHARED
state      <home>/.local/state/opencode ← SHARED
```

`data` is where session history and stored provider credentials live. Two
compartments would have shared both, which is precisely the failure the
[compartment rule](DESIGN.md#the-rule-for-compartments) forbids: rotate the key
and the config, keep one history, and the history links them.

**Fix.** `bin/calypsocode` also sets `XDG_DATA_HOME` and `XDG_STATE_HOME`, after
which config, data, state and log all resolve inside the compartment.
`XDG_CACHE_HOME` is deliberately left shared: it holds downloaded packages and
binaries, carries no identity, and moving it would re-download them through Tor
for every compartment.

**The general lesson.** An agent's identity surface is not one directory. Any
new agent wrapped by Calypso needs this enumerated, not assumed — `debug paths`
or its equivalent, checked, before claiming the compartment holds.

## F10 — How the namespace refuses, and why a DNS-based leak test proves nothing

**Status: confirmed. Measured 2026-07-25, Linux 7.0.0-28-generic.**

Three measurements taken to design the negative leak test — the test that
deliberately attempts what must fail. They rule out the obvious design and
point at the one that works.

### DNS answers everything, including names that do not exist

Inside the namespace, `/etc/resolv.conf` points at Tor's own resolver, so
nothing reaches the host's:

```
nameserver 169.254.42.53
nameserver fe80::53
```

But Tor's automap hands out a synthetic address for *any* name it is asked
about, without checking that the name resolves at all:

```
probe-2-06b54b09.example.com  →  fec0:70bd:8ac5:2708:3578:4b:cf1a:2099   rc=0
wikipedia.org                 →  fec0:103e:64dd:ff54:e587:5406:6383:ae76  rc=0
```

Both are in `fec0::/10`, the deprecated site-local range Tor uses for virtual
addresses; the real destination is resolved at connection time, over the
circuit.

**Consequence.** A negative test shaped as *"resolving a name outside Tor must
fail"* **passes against working and broken code alike** — Tor answers
everything either way. It measures nothing. That is precisely the test
[CONTRIBUTING](../CONTRIBUTING.md) forbids: one that passes against broken code
is worse than no test.

### The reliable signal is a connection attempt to a private address

With every proxy variable unset and `curl --noproxy '*'`:

```
192.168.1.1    rc=7   2711 ms    (LAN gateway; first packet builds the circuit)
192.168.1.43   rc=7    246 ms    (the host's own LAN address)
172.17.0.1     rc=7    252 ms    (docker bridge)
1.1.1.1        rc=0    594 ms    (public: succeeds, carried over Tor via onion0)
```

Private destinations fail fast and deterministically; public ones succeed
through the tunnel. That asymmetry is the signal. Budget for the first attempt
being ~2.7s while the circuit is built, and ~250ms after.

### The test must bypass the proxy, or it proves the wrong thing

The same targets, with oniux's `ALL_PROXY=socks5h://localhost:9050` left in
place, return `rc=97` — `CURLE_PROXY`, meaning Tor's SOCKS server declined to
proxy to a private address.

That is a **weaker** result than it looks: it proves the environment variable is
set, not that the transport is constrained. The claim in
[THREAT-MODEL](THREAT-MODEL.md) is about kernel-level routing, and
[F2](#f2--oniux-injects-all_proxy-which-breaks-same-namespace-loopback) already
established that isolation comes from the routing table rather than the
variable. Only by unsetting the proxy and passing `--noproxy '*'` does a failure
become evidence about the route.

**Consequence for the implementation.** Test connections, not resolution; target
private addresses discovered on the host and passed in (they are invisible from
inside); bypass the proxy; and do not test `169.254.42.0/24` — that is onion0's
own subnet and is legitimately reachable.

## F11 — OpenCode sends a client-identifying `User-Agent` to a generic OpenAI-compatible provider

**Status: confirmed. Measured 2026-07-26, `bin/calypsocode` unmodified, OpenCode 1.18.5.**

This is Batch 1 of `docs/plans/calypsocode-ui-rebrand.md`: does a generic
OpenAI-compatible provider receive any header that identifies the client?
Answer, plainly: **yes.**

**Method.** A throwaway local HTTP server (Python `http.server`, not part of
this repo) logged every request's method, path, and full header set verbatim,
and answered `/v1/chat/completions` with a minimal valid completion so the
client would not error out. A throwaway profile pointed a real launch at it:

```
PROFILE=header-test
NETWORK=none                          # required — see F1, the namespace can't reach host loopback
API_KEY_ENV=FAKE_HEADER_TEST_KEY      # exported with a dummy value, no real key
API_BASE=http://127.0.0.1:8765/v1
MODEL=placeholder-model
GIT_NAME=dev
GIT_EMAIL=dev@localhost
```

```
export FAKE_HEADER_TEST_KEY=dummy
CALYPSO_NETWORK=none ./bin/calypsocode --profile header-test --yes run "hi"
```

`NETWORK=none` is the only way to run this test — it is not a statement about
production config.

**Result.** Two `POST /v1/chat/completions` requests reached the server (an
automatic title-generation call, then the main turn), both carrying identical
headers:

```
Authorization: Bearer dummy
Content-Type: application/json
User-Agent: opencode/1.18.5 ai-sdk/provider-utils/4.0.23 runtime/bun/1.3.14
x-session-affinity: ses_06437557cffeJnbh5OQ7cGl91r
x-session-id: ses_06437557cffeJnbh5OQ7cGl91r
Connection: keep-alive
Accept: */*
Host: 127.0.0.1:8765
Accept-Encoding: gzip, deflate, br, zstd
Content-Length: <n>
```

`User-Agent: opencode/1.18.5 ai-sdk/provider-utils/4.0.23 runtime/bun/1.3.14`
is a client-identifying header, sent verbatim, on every request: it names the
tool, its exact version, the AI SDK version, and the JS runtime version. A
generic OpenAI-compatible provider — no OpenRouter-style conventions
involved — receives this on every turn of every session.

`x-session-id` / `x-session-affinity` is a second, weaker signal: a
random ID, constant across every request of one CLI invocation, that lets
the provider link that session's requests together server-side. It is
presumed to change between launches (not verified across multiple launches
in this test).

**What did not appear.** No `X-Title`, `HTTP-Referer`, or `X-Source` header —
the specific names named in the plan as things to check for. Those are
OpenRouter-specific conventions; the generic `@ai-sdk/openai-compatible`
provider path this profile exercises does not send them. Their absence does
not make the row safe: the `User-Agent` above is the concrete identifying
header this test was designed to catch, and it is present.

**Also observed.** OpenCode never called `GET /models` in this run — the
compartment's generated config supplies the model explicitly
(`compartment_prepare` in `bin/calypsocode`), so no separate models-list
request happens.

**Consequence.** Batch 5 of `docs/plans/calypsocode-ui-rebrand.md`
(de-brand the wire) is necessary, not speculative: the `User-Agent` string is
a measured, concrete client fingerprint reaching every generic
OpenAI-compatible provider CalypsoCode talks to.

## F12 — The compiled `calypsocode-agent` holds a real session over Tor

**Status: confirmed. Measured 2026-07-26.** This is the gate for the fork, the way
[F8](#f8--a-real-agentic-session-works-over-tor-at-4s-per-round-trip) was the gate
for the launcher. F8 ran upstream OpenCode 1.18.4; nothing until now had shown the
fork works against a real provider, only against a local stub.

The agent was the **compiled binary** — `bun build --compile`, version
`0.0.0-dev-202607261100`, 180MB, self-contained, invoked through
`~/.local/bin/calypsocode-agent`. The launcher was invoked by name from outside
both repositories, so this also exercises the symlink install.

Same task as F8, deliberately, so the numbers compare: write `fizzbuzz.py`, run it
with `python3` to check it, write a `README.md`. The agent completed it correctly
and the script produces correct output.

| | |
|---|---|
| Wall clock | 19s, including egress verification |
| Assistant round trips | 4 (plus 1 title-generation call) |
| Round trip min / mean / max | 1.7s / 3.6s / 7.9s |
| Failed requests during the session | 0 |
| Tokens | 14.9K in, 268 out, 43.6K cache read |
| Exit | 185.220.100.249, verified `IsTor` before launch |
| Receipt | written, with Tor exit, `leak test passed — 3 private target(s)`, and a non-zero duration |

Round trips were counted from the agent's own log: each `message=stream` line is
one request, and each is bounded by the next `message=loop step=N`. The last one is
bounded by the session's `time_updated`. F8 reported 8 round trips for this task
and this run took 4 — same task, different model behaviour on the day, not a
measured improvement in anything.

**Three failures preceded it, and the cause was the test, not the tool.** The first
three attempts ran with the project directory under `/tmp`. All three failed
identically: leak test passed, egress verified, then `UnknownError / "Unexpected
server error"` from the agent's own server before any inference completed. The
agent's log named it — `Failed to init file picker: Invalid path
/tmp/calypso-gate-f12`. oniux gives the namespace a private `/tmp`
([F6](#f6--oniux-uses-a-private-tmp-by-default),
[F7](#f7--home-is-shared-with-the-host-only-tmp-is-private)), so a project
directory under `/tmp` does not exist inside the namespace and the agent
bootstraps into nothing. Moving the project to `$HOME` fixed it with no code
change. **A cwd under `/tmp` cannot work by design, and the failure gives no hint
of why** — the error surfaces as an opaque server error with a ref.

**The provider was ruled out before the agent was blamed**, because the error
message pointed nowhere. Over the same Tor path: `GET /models` returned HTTP 200 in
2.0s with `zai-org-glm-5-1` still present among 106 models, and a minimal
authenticated `POST /chat/completions` returned HTTP 200 in 11.1s, billed
(`"cost":{"usd":0.001554366}`). The from-source build failed identically to the
compiled one, which is what ruled out the compile as the cause.

**Caveats, stated plainly:**

- One task, one provider, one session, one day — an existence proof for the fork,
  not a latency distribution. Same limit F8 stated.
- `cost` came back `0.0` in the agent's own session record even though Venice
  returned a cost field on the direct request above. The fork's generic provider
  path does not appear to parse it. Unexplained, not investigated.
- **The `3 private target(s)` in the receipt above was not three pieces of evidence.**
  At most one of the three could have failed. Measured and replaced —
  [F14](#f14--the-leak-test-could-not-fail-and-what-it-takes-to-make-it-able-to). The
  number here is left as printed, because it is what the tool said.
- The receipt correctly flagged `OS username '<user>' is in your project path` —
  the session ran under `$HOME` because the three attempts before it had been run
  under `/tmp`. **Correction:** an earlier version of this entry said the
  documented mitigation for that leak was unavailable inside the namespace, and
  that the two mitigations conflicted. That was wrong and is withdrawn.
  [THREAT-MODEL](THREAT-MODEL.md#keep-your-username-out-of-your-paths) recommends
  a directory outside home (`/srv/dev`) or a neutral account, never `/tmp`, and
  both work inside the namespace — only `/tmp` is private (F6, F7). There is no
  conflict.
- This says nothing about the `User-Agent` the compiled binary puts on the wire.
  No logging endpoint was involved in this run, so the compiled-binary question
  raised in `DESIGN.md` remains open.

**Consequence.** The fork is usable, not just buildable. The launcher's install
path, the compiled binary, the leak test, the egress check and the receipt all
work together in one real session.

## F13 — Of 106 Venice models, 3 are usable by an agent, strongly private, and cached

**Status: confirmed. Measured 2026-07-26** against `GET /models` over Tor, and by
running the F12 task on three of them.

The question was which model a compartment should name. Privacy level alone does
not answer it, and picking on privacy alone produces a profile that cannot work.

**The counts.** Venice advertises privacy per model, in `model_spec`. Of 106:

| Filter | Count |
|---|---|
| `supportsE2EE` **and** `supportsTeeAttestation` | 16 (the same 16) |
| `supportsFunctionCalling` | 94 |
| Both of the above | **6** |
| ...of which priced for cached input | **3** |

The three: `e2ee-deepseek-v4-flash`, `e2ee-qwen3-6-27b`, `e2ee-qwen3-6-35b-a3b`.
They are not a tier ladder — two labs, and no price/capability gradient. The
cheapest output of the three also has the largest context.

**Tool use is the filter that matters first.** `e2ee-glm-5-1` has both privacy
capabilities and reads as an ideal choice. It rejects a coding agent outright:

```
{"issues":[{"message":"tool_choice is not supported by this model"},
           {"message":"tools is not supported by this model"}]}
```

The session fails before any inference, after the leak test and egress check have
already passed — so the failure looks like a Calypso problem and is not one.

**Cached input, not privacy, drives the bill.** Same F12 task, same launcher,
costs computed from published pricing (not from billing — see the caveat):

| Model | TEE/E2EE | Fresh in | Cached in | Out | Est. cost | Wall |
|---|---|---|---|---|---|---|
| `zai-org-glm-5-1` | no | 14,850 | 43,636 | 268 | $0.037 | 19s |
| `e2ee-glm-5-2-p` | yes | 58,355 | 192 | 285 | $0.104 | 27s |
| `e2ee-deepseek-v4-flash` | yes | 30,793 | 29,952 | 444 | $0.0069 | 34s |
| `e2ee-deepseek-v4-flash` (2nd run) | yes | 16,118 | 44,544 | 635 | $0.0049 | 35s |

The strongly-private `deepseek-v4-flash` is **~7× cheaper** than the
non-private model it replaced, and ~21× cheaper than `e2ee-glm-5-2-p`. Strong
privacy did not cost more here; choosing the one model of the six with no cached
tier did.

`e2ee-glm-5-2-p` has no `cache_input` price and read 192 cached tokens across a
whole session, which is two independent signals that it does not cache. Caching
works *within* one session, not only across sessions: every turn resends the
conversation, so turns 2+ read what turn 1 cached. That is why a missing cache
tier is expensive rather than merely suboptimal.

**E2EE is not obtained by naming an E2EE model.** A plain OpenAI-compatible
`POST /chat/completions` with a plaintext body to `e2ee-glm-5-1` returned HTTP
200, billed, with `"enable_e2ee": true` echoed in `venice_parameters`. The
plaintext was sent and accepted. `enable_e2ee` in a response is a parameter echo,
not evidence of encryption. What a generic client gets from these models is the
attested enclave; the client-side encryption half needs a client that encrypts,
which this agent is not.

**Caveats:**

- Costs are computed from `model_spec.pricing`, not read from an invoice. The
  agent records `cost = 0.0` in its own session row even though Venice returns a
  cost field on a direct request — the fork's generic provider path does not parse
  it. Actual spend was not verified.
- One task, one day. Token counts on a real task will differ; the ratio between
  a cached and an uncached model is the transferable part, not the absolute
  numbers.
- `betaModel: true` on all three. Availability may change.
- No model in the intersection supports vision. Strong privacy, tool use, caching
  and image input do not currently co-exist at this provider.
- Whether the attestation evidence these models offer is *valid* was not checked.
  Verifying a third party's guarantees is out of scope
  ([ROADMAP](ROADMAP.md#decisions-taken)); this entry records that the evidence is
  advertised, nothing more.

## F14 — The leak test could not fail, and what it takes to make it able to

**Status: confirmed. Measured 2026-07-26.** This is the correction to what
[F12](#f12--the-compiled-calypsocode-agent-holds-a-real-session-over-tor) reported as
`leak test passed — 3 private target(s)`. F12's number is what the tool printed and is
not edited here; what this entry establishes is that the number was not evidence.

**The old check asked the wrong question.** It probed `http://<target>/` and treated
**curl exit 0 as a leak and every other exit code as sealed.** Exit 7 means "nothing is
listening on that port", not "unreachable". Run from the host — no namespace, no
isolation of any kind — with the identical command:

| Target | curl exit | Old verdict |
|---|---|---|
| `192.168.1.43` — the host's own address | 7 | sealed ❌ |
| `172.17.0.1` — docker | 7 | sealed ❌ |
| `192.168.1.1` — the gateway | 0 | leak ✅ |
| `192.168.1.43:22000` — a port that **does** listen | **56** | sealed ❌ |

`ss -ltn` confirms nothing on this host listens on port 80. Two of the three targets
therefore returned the same verdict whether the namespace was sealed or wide open. The
fourth row is the sharpest: **exit 56 means the TCP handshake completed** and it was
scored as sealed. So was exit 28, because `--max-time 5` made a timeout indistinguishable
from a refusal — a leak to a slow host read as isolation.

**On this machine the check was not entirely vacuous**, because this gateway happens to
serve HTTP on port 80. That is the whole problem: its ability to fail depended on the
router model. On a LAN whose gateway serves HTTPS only, it would have reported
`3 private target(s) unreachable` with isolation completely broken.

F10 is where this slipped through. It measured `192.168.1.1` and `192.168.1.43` at
rc=7 *inside* the namespace and concluded that private destinations fail fast while
public ones succeed. True, and the wrong asymmetry: private-versus-public rather than
sealed-versus-unsealed. The host-side control was never taken. F10 also measured the
signal that would have caught it — 246ms and 252ms — where an unisolated connection to a
closed local port returns RST in well under a millisecond.

**What replaced it.** Targets are now `address:port` pairs **confirmed from the host to
accept a TCP connection** before being passed into the namespace; a target the host
cannot reach is not evidence and is dropped. Ports come from `ss -ltn`, restricted to
listeners bound to every interface — a loopback-only listener is unreachable from another
namespace even with no isolation, so it could not fail either. Three outcomes are now
distinguished: handshake completed is a leak, refused is a pass, timed out is
inconclusive and refuses to launch.

**Measured after the change, one real session over Tor:**

```
leak test passed — 6 target(s) that answer from the host refused the connection
refusal times: 172.17.0.1:1716=3630ms  172.17.0.1:22000=141ms
               192.168.1.1:443=103ms   192.168.1.1:80=97ms
               192.168.1.43:1716=139ms 192.168.1.43:22000=165ms
```

Six pieces of evidence where there had been one. The times are the corroboration and are
now in the receipt: 97ms to 3630ms, all orders of magnitude above the sub-millisecond
refusal a local closed port produces, which is what distinguishes "refused by arti after
leaving through onion0" from "refused by the kernel because nothing was there".

**Caveats:**

- The target set is discovered per host, so the count varies by machine. Six here; a
  machine with no all-interface listener and an HTTPS-only gateway may find none, and
  then the launcher refuses rather than reporting a pass over zero evidence.
- `curl` is still the probe rather than a bare TCP connect. Deliberate: the test suite can
  stub a command and cannot stub bash's `/dev/tcp` builtin, and a check that cannot be
  tested is how this one broke. Correctness does not depend on HTTP — 52 and 56 both mean
  the connection was made.
- This says nothing about leaks by a path the probe does not take: a protocol other than
  TCP, an interface that appeared after discovery, an address the host does not have. Same
  limit F10 stated, and still true.

## F15 — The compiled binary sends no product token

**Status: confirmed. Measured 2026-07-26.** This closes the open half of what
`DESIGN.md` claims about fork commit `dbffbc7`, and "Still untested" item 6.

The concern was concrete. `packages/opencode/script/build.ts` passes
`--user-agent=opencode/${Script.version}` to Bun when compiling, so the compiled
binary carries a product-and-version token as its default `User-Agent` for every
`fetch`. [F11](#f11--opencode-sends-a-client-identifying-user-agent-to-a-generic-openai-compatible-provider)
measured the from-source build and `dbffbc7` fixed that path; nobody had ever observed
the artifact users actually execute.

**Method**, reusing F11's: a throwaway local HTTP server logging every request's method,
path and full header set verbatim, answering `/v1/chat/completions` with a minimal valid
completion. A throwaway profile with `NETWORK=none` — required, because the namespace
cannot reach host loopback ([F1](#f1--a-host-process-cannot-reach-a-port-bound-inside-oniux))
— and a dummy key. Run through `bin/calypsocode` against the **compiled** binary,
version `0.0.0-dev-202607261100`.

**Result.** Two `POST /v1/chat/completions`, both carrying:

```
Authorization: Bearer dummy
Content-Type: application/json
User-Agent: ai-sdk/openai-compatible/2.0.41 ai-sdk/provider-utils/4.0.23 runtime/bun/1.3.14
x-session-affinity: ses_060cc1a6bffeLC7vh1ZYgkhB4p
x-session-id: ses_060cc1a6bffeLC7vh1ZYgkhB4p
```

**No product token.** The baked-in `--user-agent` does not reach the wire, because the
SDK sets the header explicitly on every request and an explicit header beats Bun's
default. What was suspected to leak does not, and it is now measured rather than
reasoned about.

`x-session-id` / `x-session-affinity` are unchanged from F11 and remain what that entry
called them: a random ID constant across one invocation, letting a provider link that
session's requests together. Still not verified to rotate between launches. No
`GET /models` was made, matching F11.

**Caveats:**

- **This does not verify that `models.dev` and the update check are suppressed.** Those
  requests go to other hosts, which a local server cannot see, and `NETWORK=none` means
  there is no namespace to confine them. The launcher setting
  `OPENCODE_DISABLE_MODELS_FETCH`, `OPENCODE_DISABLE_AUTOUPDATE` and
  `"autoupdate": false` is asserted by the test suite; that those settings actually
  stop the traffic is not measured here. Watching connections during a session, or a
  DNS log, would settle it.
- One binary, one build. A future build with a different SDK version could differ —
  the property depends on the SDK setting the header, not on anything this project
  controls.

---

## Still untested

The premise risks are answered ([F8](#f8--a-real-agentic-session-works-over-tor-at-4s-per-round-trip),
[F9](#f9--xdg_config_home-alone-does-not-compartment-opencode)). What is left is
what one session cannot show.

1. **Provider ToS / fraud response** to Tor-origin API traffic over time. One
   session proves the request is accepted, not that an account survives weeks of
   rotating exits. Unchanged, and still the risk that would hurt a real user
   most.
2. **Latency on real work.** F8 measured a small, self-contained task. A large
   repository, long context, and a session of hundreds of round trips are not
   the same thing — at 3.8s each, the cost is linear and adds up.
3. **Whether a compartment holds over time.** F9 enumerated OpenCode's paths
   once, on one version. An agent that later writes somewhere new — a plugin
   cache, an MCP server's own state — reopens the question silently. Nothing
   currently re-checks it.
4. **What the leak test does not cover.** It is now built: every session proves
   the host's private addresses are unreachable before the agent starts, so
   isolation is no longer trusted on F1's routing table alone. What it does not
   prove is the absence of a leak by some path it does not probe — a protocol
   other than TCP, an interface that appeared after discovery, an address the
   host does not have. It shows the obvious ways out are shut, not that none
   exists.
5. **Whether the `User-Agent` fingerprint ([F11](#f11--opencode-sends-a-client-identifying-user-agent-to-a-generic-openai-compatible-provider))
   is stable, and whether it can be removed pre-fork.** One run, one OpenCode
   version. Not tested: whether the string changes across OpenCode versions or
   configured providers, whether `x-session-id` actually rotates between
   launches, and whether it is overridable through OpenCode's own config
   (`opencode.json` / plugin) without forking at all — Batch 5 assumes a fork
   is required, but that has not been checked against upstream's config
   surface.
6. ~~What the compiled binary actually sends as its `User-Agent`.~~ **Closed
   2026-07-26 by [F15](#f15--the-compiled-binary-sends-no-product-token):** measured
   against the compiled artifact, and it sends no product token — the baked-in
   `--user-agent` never reaches the wire because the SDK sets the header explicitly.
   What replaces it is narrower: the launcher now sets `OPENCODE_DISABLE_MODELS_FETCH`,
   `OPENCODE_DISABLE_AUTOUPDATE` and `"autoupdate": false`, and the suite asserts it
   sets them — but **that those settings actually stop the traffic is not measured.**
   Watching connections during a session, or a DNS log, would settle it.
