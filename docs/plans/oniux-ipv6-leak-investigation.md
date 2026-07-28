# Handoff: oniux IPv6 leak — INVALIDATED, no leak found (see verdict below)

## Verdict (2026-07-28): false positive, closed

Re-tested on this machine with the exact repro below plus additional controls. **No IPv6
leak exists.** The original repro's methodology error: it treated "connection succeeded
and returned a real-looking global IPv6 address" as proof of a leak, without checking
*whose* address that was.

Decisive tests run:
1. Hit `https://ipv6.icanhazip.com/` (an echo-my-IP service) three times from inside
   `oniux`, unsetting `ALL_PROXY`/`http_proxy`/`https_proxy` first (matching the original
   repro exactly). Got three **different** IPv6 addresses across the three runs (expected —
   different Tor circuits each time): `2a01:270:9847::1`, `2a0d:bbc7::f816:3eff:fee6:ca14`,
   `2a0b:f4c2:2::62`.
2. Cross-checked every one of those addresses against Tor's own relay directory
   (`https://onionoo.torproject.org/summary?search=<ip>`). **All three matched real,
   Exit-flagged Tor relays** (`speakFreely`; the `r0cket04i*` family; `ForPrivacyNET`).
3. Confirmed none of them are this host's real IPv6 (`2a07:b944::2:2` / `fdeb:446c:912d:8da::/64`,
   the ProtonVPN-assigned addresses visible via `ip -6 addr show` outside the namespace).
4. Checked what a plain (non-Tor) DNS lookup of `icanhazip.com` gives on the host:
   `2606:4700::6810:b9f1` (Cloudflare, real). Checked what oniux's own resolver
   (`fe80::53`, per `/etc/resolv.conf` inside the namespace) gives for the same hostname:
   a synthetic `fec0:.../10` address, never `2606:4700::...`. This confirms oniux/onionmasq
   rewrites DNS answers to synthetic addresses and tunnels the real connection through
   arti — same mechanism as its IPv4 handling — rather than leaking the real resolver
   answer or a direct route.
5. Read `onion-tunnel`'s (onionmasq) packet-parsing and proxy code
   (`crates/onion-tunnel/src/parser.rs`, `proxy.rs`, `scaffolding/linux.rs`): IPv4 and IPv6
   are handled by fully symmetric code paths, both routed through
   `arti.connect_with_prefs()`. The one direct-connect ("leak") code path that exists in
   `proxy.rs:153-197` is gated by `scaffolding.should_protect()`, which
   `LinuxScaffolding` (the implementation oniux actually uses) hard-codes to `false`
   with the comment `"On normal Linux we will never leak."` — this path is inert on Linux.

Residual, unexplained-but-not-a-leak oddity: `curl -6 https://google.com/` inside oniux
returned `Connexion refusée` (exit code 7) rather than a successful response, using a
synthetic `fec0::/10` address that never got a live mapping. This looks like a Tor-side
circuit/exit availability or automap-timing hiccup, not a security issue — worth a look if
it's reproducible, but out of scope for the leak investigation this document was tracking.

**Action:** issue #38 should be re-scoped back down from "security-critical bypass" —
no defense-in-depth `ip6tables` mitigation is needed for this specific finding. The
original repro text below is kept for the record, annotated with what it got wrong.

---

## (Original handoff, kept for context — see verdict above for the correction)

# Handoff: oniux IPv6 leak — needs deeper investigation

Status: **open, not yet reported anywhere, not yet fixed.** Surfaced during triage of
issue #38 ("Verify and document IPv6 isolation coverage"). Handed off here so it can be
investigated independently while the rest of the #38-adjacent triage/fix work continues
in parallel.

## The finding

Inside the oniux network namespace, a direct (non-proxied) IPv6 connection reaches the
real internet, bypassing Tor entirely. This is a live deanonymization vector, not just a
test-coverage gap.

### Repro

```sh
# 1. namespace only has loopback + link-local IPv6 + an on-link default route,
#    no global address — looks safe at first glance:
oniux bash -c 'ip -6 addr show; echo ---; ip -6 route show'
# -> lo: ::1/128
#    onion0: fe80::.../64 (link-local only)
#    route: default dev onion0 (on-link, no gateway)

# 2. but a direct outbound IPv6 connection (bypassing the SOCKS proxy env vars)
#    succeeds end-to-end:
oniux bash -c 'unset ALL_PROXY http_proxy https_proxy; curl -6 -sv --max-time 5 https://google.com/ -o /dev/null'
# -> resolves google.com to a real global IPv6 address, completes TLS handshake,
#    gets a real HTTP/2 301 response. curl exit 0.
```

Environment this was reproduced on: oniux v0.11.0 (commit `f98d8f5c270a11a3aa530513f8d30d49075b128f`,
installed via `cargo install --git ... --tag v0.11.0`, checkout at
`~/.cargo/git/checkouts/oniux-a37b67fa6132af61/f98d8f5`). Host has a real routable global
IPv6 (via ProtonVPN's `proton0` interface) outside the namespace — that's likely a
precondition for the leak to be externally reachable at all.

## What we know from oniux's own source

`~/.cargo/git/checkouts/oniux-a37b67fa6132af61/f98d8f5/src/main.rs`:
- Line 118-124: assigns both an IPv4 (`169.254.42.1/24`) and an IPv6
  (`fe80::1/64`-ish link-local) address to the `onion0` tun device.
- Line 125-126: sets a default gateway for **both** `AddressFamily::Inet` and
  `AddressFamily::Inet6` on the tun. So IPv6 capture is intentional, not an oversight at
  the routing-table level.

Per public docs (Arti's "oniux" page, the Tor Project blog announcement, and the oniux
forum thread), the architecture is: `onionmasq` reads raw packets off the tun, reconstructs
TCP streams in userspace, and forwards them through the embedded `arti` Tor client — for
both IPv4 and IPv6, per the announcement ("oniux supports IPv6 of course!", with an example
`oniux curl -6 https://ipv6.icanhazip.com`).

So the intent, per upstream's own routing setup and public claims, is that IPv6 should be
fully tunneled. The repro above shows it is not, at least in this environment/version —
somewhere between "packet hits the tun" and "connection completes", IPv6 traffic is not
going through arti/Tor the way IPv4 traffic does.

## What's NOT yet known (this is the work for the next agent)

1. **Root cause inside oniux/onionmasq.** Is this a bug in `onionmasq`'s IPv6 packet
   handling (e.g. falls through to some direct-forward path), a misconfiguration specific
   to this host (ProtonVPN's `proton0` global IPv6 present outside the namespace — does
   the leak reproduce without it?), or something specific to v0.11.0 that's fixed in a
   newer/older revision?
2. **Whether this is already known/fixed upstream.** Web search (GitHub, Tor Project forum,
   generic search engines) turned up nothing describing this exact behavior. Note:
   `gitlab.torproject.org` (the actual upstream tracker, `tpo/core/oniux`) returned HTTP 403
   to the WebFetch tool used during this session — **the GitLab issue tracker itself was
   never actually searched**, only indirectly via search-engine indexing. That's the most
   important gap to close first: read `https://gitlab.torproject.org/tpo/core/oniux/-/issues`
   directly (browser or an authenticated method) before assuming this is unreported.
3. **Reproducibility without a secondary IPv6 uplink.** Test on a host with no other global
   IPv6 route at all, to see if the leak still occurs or if it's specific to routing-table
   interaction with another interface (e.g. `proton0` here).
4. **Whether arti/Tor's SOCKS layer even supports IPv6 exit circuits reliably** — there's a
   long-standing tor-core ticket (`#31542`, "Cannot connect to IPv6 addresses using Tor
   SOCKS") that's about classic Tor SOCKS, not oniux/arti specifically, but may be related
   context on IPv6 exit support maturity.

## Recommended handling once root-caused

- **Do not open a public issue first** — this is a live deanonymization bug in a
  Tor-Project-maintained, security-positioned tool. Report privately to the Tor Project
  first (coordinated disclosure), matching the spirit of CalypsoCode's own issue #23
  (vulnerability disclosure policy) which was triaged in the same session.
- Independently of upstream's timeline, CalypsoCode issue #38 was re-scoped during triage
  from "enhancement: document IPv6 coverage" to a security-critical `bug`: the launcher
  should add its own defense-in-depth mitigation (e.g. an explicit `ip6tables`/`nft` DROP
  rule for all outbound IPv6 on `onion0`, applied inside the namespace before `exec`-ing
  the agent) rather than relying solely on oniux's own routing intent. That mitigation work
  is tracked separately and continuing in the main session — this document is only about
  the upstream root-cause investigation.

## Context on how this was found

Found while triaging GitHub issue #38 for MyrLeProgrammeur/CalypsoCode ("Verify and
document IPv6 isolation coverage"), one of 27 issues bulk-filed by `constantin-jais`
on 2026-07-28 (likely an automated security-review dump). During a `/grill-me` session
resolving `ready-for-human` issues, we measured actual IPv6 behavior instead of just
reading code, and found the live leak described above.
