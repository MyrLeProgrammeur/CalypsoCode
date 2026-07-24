# Findings — verified behaviour of the stack

Empirical results from testing `oniux`, the provider endpoints, and LiteLLM.
Everything here was **measured**, not assumed. Where something is untested, it
says so.

Test date: 2026-07-24 · Linux 7.0.0-27-generic · oniux installed via
`cargo install --git https://gitlab.torproject.org/tpo/core/oniux`.

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

**Consequence.** The session receipt is written from inside the namespace to
`~/.local/state/calypsocode/` and read on the host. No host-side file handle has
to be passed in, and nothing may be written to `/tmp`.

---

## Still untested

These gate the project and none of them are answered yet.

1. **Authenticated inference over Tor.** Needs a real Venice key and a
   `POST /chat/completions`. The single most likely remaining premise risk.
2. **Provider ToS / fraud response** to Tor-origin API traffic over time.
3. **Latency of a real agentic session.** Dozens of sequential round trips,
   each crossing three relays. Unmeasured, and the likeliest reason a user
   would not run the tool twice. See [ROADMAP.md](ROADMAP.md#gate).
4. **Whether the user's global agent config leaks into a compartment.**
   OpenCode merges its config sources rather than replacing them, and its
   documentation lists a global `~/.config/opencode/opencode.json` without
   confirming that `XDG_CONFIG_HOME` moves it. `bin/calypsocode` sets both
   `XDG_CONFIG_HOME` and `OPENCODE_CONFIG` at the compartment, but if the
   global file loads anyway, the user's real agent config — instructions,
   MCP servers, memory — enters every compartment. That is the
   "dossier about you" row of the signal table, unverified. Measure it in the
   gate session by running with a marker in the host-side global config and
   checking whether the agent sees it.
