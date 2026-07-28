# Plan — Close the evidence chain and stop the phone-homes

> Executed 2026-07-26, all 9 batches, merged as PR #9 with the fork's half as
> `6e1da0e`. Its one remaining open question — circuit pinning versus rotation —
> moved to `docs/ROADMAP.md` under the network backend, where the decision belongs.

> Executor: Sonnet or Opus + subagents. Apply the decisions, do not re-litigate
> them. Unresolved doubt → stop and ask.

## Goal & scope

Two independent Opus reviews audited this repo on 2026-07-26. They converged, without
seeing each other's work, on the same two findings — and each added findings the other
missed. Every claim reproduced below was **verified in the main session** after the
reviews landed, not taken on the reviewers' word; where verification changed the
finding, the corrected version is what appears here.

The verdict both reached: the engineering discipline is real and better than most
privacy tooling ships, and the gap is between the honesty of the *voice* and the
honesty of the *evidence*. This plan closes that gap.

**In scope:** `bin/calypsocode`, `test/`, and the docs that overstate. Two exports and
a config key in the launcher to stop the agent contacting third parties.

**Out of scope, and deliberately:** the operator half and its three gate tests, every new
feature, and the user's own machine configuration. A grilling pass on 2026-07-26 walked
every open question in this plan; eight of nine are now decided and recorded in **Settled
decisions**, with a summary table in **Grilling pass — decisions log** at the end. **One
genuinely remains open (5, circuit pinning versus rotation)** and no batch depends on it.

### Required reading before starting

- `CONTRIBUTING.md` — commit conventions, merge-commit rule, and the house rule that
  when you add a test you break the code deliberately and confirm it fails.
- `docs/FINDINGS.md` F10 (what the negative test does and does not prove), F12 (the
  gate on the compiled fork), F13 (the model-capability measurements).
- `~/Desktop/calypsocode-handoff-2026-07-26.md` — session handoff with operational
  gotchas. Not in the repo; it is a personal note.

## Settled decisions

These were settled earlier in the project or in the session that produced this plan.
Do not revisit them.

1. **`docs/FINDINGS.md` F-entries are dated measurements.** Never edit one so it agrees
   with the present — a new fact gets a new entry. **Exception, with precedent:** a
   claim that was *false when written* is corrected in place and explicitly labelled a
   withdrawal. F12 was corrected this way; follow that shape.
2. **Measured facts go in FINDINGS, inference goes in DESIGN** (`CONTRIBUTING.md`).
3. `main` is protected — PR required, applies to admins. A direct push is refused with
   `GH006`. Verified.
4. Merge commits, not squash.
5. **No env var may override the launcher's own idea of the OS username.** This was
   considered as a way to test the neutral-username branch and rejected: it puts a
   switch in a privacy tool capable of hiding a real leak.
6. The neutral usernames the docs bless are exactly `user` and `dev`, not "anything
   generic" — a shared convention only works if it is shared.
7. Tor stays the only built backend for now; `socks`/`vpn` remain unbuilt (ROADMAP
   step 5). Nothing in this plan builds them — and decision 16 below settles why.

Added 2026-07-26 during a grilling pass over this plan:

8. **The fork stays, with the full UI.** The logo, the entrance animation, the renamed
   strings and `--about` are code and cannot be had from config; only the palette and
   the `User-Agent` could. Keeping them is a product decision, taken deliberately — not
   a technical necessity, because it is not one.
9. **Upstream is tracked on demand, not continuously.** Rebase when upstream ships
   something wanted, not on a schedule. Conflict cost scales with where the fork's lines
   sit, not with elapsed time, so a monthly or yearly rebase costs about the same.
10. **Batch 3 is done now, not deferred, and no stopgap is taken.** The alternative was
    a two-minute softening of the receipt's wording while the real fix waited. Rejected
    because the fix is imminent; if it slips by more than a week, revisit — a public repo
    asserting a proof it does not have is the exact contradiction PR #6 spent a day
    removing elsewhere.
11. **The operator half is out of scope, deferred indefinitely.** See resolved Open
    question 1.
12. **Two repositories, two licences.** `CalypsoCode` (the launcher) stays **AGPL-3.0** —
    it is original work, and it is where the receipt, the leak test and the disclosure
    live, so it is what a hostile reskin would target. `calypsocode-agent` (the fork)
    stays **MIT** — it is upstream's MIT tree with 24 mostly-cosmetic lines added, and MIT
    keeps the 3-line `request.ts` fix offerable upstream, which is the move that could
    eventually retire the fork. Only `about.ts` in the fork needs changing: it currently
    claims AGPL-3.0 for CalypsoCode's changes while every file in that repo says MIT.
    Rejected: AGPL-ing the fork, which would require the AGPL text, a `NOTICE`, both
    `package.json` files and per-file GPL §5a change markers — five files, in a tree that
    gets rebased, one of which upstream touches constantly.
13. **How a wrong F-entry is corrected — three branches.** Write this into
    `CONTRIBUTING.md`; it belongs there, not in a plan that gets archived. The dividing
    line: **correct errors, never edit measurements.**
    - **The world changed** (F6's LiteLLM log) → **leave it.** The entry is a dated
      snapshot and is accurate for its date. If the staleness genuinely confuses, a new
      entry says what changed.
    - **The sentence was false when written** (F7 claiming the receipt is written inside
      the namespace) → **correct in place, marked `Correction:`**, quoting what the
      original said. The reader sees the error *and* the correction. This is the
      precedent F12 already set.
    - **The measurement is right but the entry over-reads it** (F12's "3 private
      target(s)") → **a new entry**, measuring what the old one did not, with a pointer
      from the old. Do not touch the numbers — the receipt really did print that.

14. **Nothing new is built until there is real usage.** See resolved Open question 6.
15. **The documentation states capabilities, never audiences.** No document says who the
    tool is for, and none takes a position on who the adversary is. Two reasons, the second
    being the stronger: an audience claim is a marketing assertion the project cannot
    measure, and — in a privacy tool specifically — **naming your users publishes a profile
    of who uses it.** The distinction to hold: describing a *position on the network path*
    ("an observer between you and the provider") is a fact about topology and stays;
    describing a *person* ("developers in censoring jurisdictions") is profiling and goes.
    Applies to new documentation as well, not just the cleanup in Batch 5.
16. **`socks` and `vpn` stay unbuilt.** Review 1 argued they serve the users who actually
    exist while Tor serves the ones one would like to exist, and that the ordering is
    backwards. Possibly true, and it is still a feature — decision 14 applies. The signal
    that decides it is whether Tor's latency and its roughly-one-dead-circuit-in-three
    make real daily work unpleasant, which weeks of use will answer and guesswork will not.
17. **`dbffbc7`'s hunks in `provider.ts` and `nvidia.ts` are reverted; the `request.ts`
    hunk stays.** The reverted lines strip OpenRouter-style headers from four
    provider-specific blocks a CalypsoCode profile never reaches, and they sit in
    upstream's hottest file — they carry the fork's entire rebase liability and protect
    nothing in the actual workflow. Rejected as a reason to keep them: defence in depth for
    someone using the fork as a generic agent, a case that does not exist, and which a
    `headers` entry in the config would cover anyway. Batch 8.
18. **`session_tally` is documented, not locked.** A bash lock means a lock file, cleanup
    on signal, and a stale-lock case — three new failure modes to fix a counter. The
    counter is not the real problem: two sessions of one compartment sharing the agent's
    state tree is, and a lock does not fix that either. Batch 9.

## Open questions

**None of these may be decided by the executor. If the work runs into one, stop and ask.**

1. ~~Should the three gate tests in `docs/private/north-star.md:225-241` run first?~~
   **RESOLVED 2026-07-26: out of scope, deferred indefinitely.** They gate the *operator*
   half — `north-star.md:227` says "do not build **the token gateway** until all three are
   green" — and not the launcher, which that document already marks Built. Review 1
   overstated by implying all code should stop. Nothing in this plan is blocked by them.
   `docs/private/north-star.md` is local-only, gitignored and not backed up: read it if
   this reopens, never modify or commit it.
2. ~~Does `options.headers` in the compartment config retire the fork?~~
   **RESOLVED 2026-07-26: it could have, and the fork stays anyway.** See settled
   decisions 8 and 9, and "What the grilling pass established" below. The privacy fix was
   achievable from config; the UI is not, and the UI is wanted.
   **Still open, low urgency:** whether to revert `dbffbc7`'s 26-line hunk in
   `provider.ts`. It removes OpenRouter-style headers from four provider blocks that a
   CalypsoCode profile never reaches, and it is the fork's entire rebase liability. See
   below.
3. ~~AGPL or MIT.~~ **RESOLVED 2026-07-26: launcher AGPL, fork MIT.** See settled
   decision 12. Adds one small piece of work: `packages/opencode/src/cli/about.ts:19-20`
   in the fork must stop claiming AGPL-3.0 and state MIT, matching every file in that
   repository. That is a fork commit, so it rides the same push as anything else there.
4. ~~The project path.~~ **REMOVED FROM THIS PLAN 2026-07-26.** Still undecided, but it is
   an operation on the user's machine with no dependency on any batch here, and keeping it
   in a code plan confuses the two. It lives in `~/Desktop/calypsocode-handoff-2026-07-26.md`
   with the comparison table and the symlink ruled out by measurement. One technical
   blocker was lifted meanwhile: the neutral-username false positive is fixed and merged,
   so renaming to `user` no longer produces a spurious receipt warning every session.
5. **Circuit pinning versus rotation.** A single account arriving from many Tor exits is
   the credential-theft signal F4 warns about; pinning one exit per compartment looks
   like a normal user but concentrates correlation. Nobody has asked which is safer, and
   the answer likely differs by provider.
6. ~~Which creative extensions, if any.~~ **RESOLVED 2026-07-26: none until there is real
   usage, then `calypsocode audit` first.** Nothing is added by this plan. After the fixes
   land, use the tool on real work for weeks; that is what both reviews called the actual
   next step.
   `calypsocode audit` is the one to build after that, and the reason is that it makes the
   tool *more honest* rather than bigger: it adds no data collection, reads back receipts
   that already exist, and would surface four things currently invisible — the same
   `API_KEY_ENV` named by two profiles (a config error that silently destroys the
   compartment boundary), a Tor exit reused across compartments, overlapping session
   windows, and the key↔circuit assertion `DESIGN.md:267` already specifies and nobody
   built. **It needs a stock of receipts to be worth anything** — there are six today, all
   one compartment, all one day. Building it now means an analysis tool over four lines of
   data.
   `calypsocode exec -- <anything>` is deliberately parked despite a good cost/reach
   ratio: it widens the audience before the core is proven, and Review 1 already flagged
   the target population as thinner than the README claims. Widening before verifying is
   the wrong order.
7. **Does the receipt's `exit <IP>` describe the session, or only the verification?**
   **Partly measured 2026-07-26, and it needs one more measurement before it can be
   worded.** Three requests in a single `oniux` namespace, over 11 minutes:

   ```
   t+0min   → 80.67.172.162
   t+5min   → 80.67.172.162
   t+11min  → 45.84.107.172
   ```

   The exit rotated inside one namespace, consistent with Tor's ~10-minute circuit
   rotation. So *"one launch = one namespace = one circuit"* — asserted at `README.md:47`,
   `bin/calypsocode:75` and `DESIGN.md:208` — does not hold past roughly ten minutes.

   **The limit of that measurement, which decides the wording:** each probe used a fresh
   `curl`, therefore a fresh connection, and it is a *new* connection that draws a new
   circuit. A connection already open stays on its circuit. The agent talks to the provider
   over HTTP keep-alive and probably holds one connection for a whole session — F12's four
   round trips in 19 seconds almost certainly shared one, so its receipt was accurate.

   What is established is therefore **the mechanism, not the failure**: whether the agent
   reconnects during a long session is untested, and over 90 minutes with idle gaps a
   reconnect is likely. **Do not reword the receipt on this alone.** Measure it first —
   run a long session and compare the exit at the start with the exit at the end, or watch
   whether the agent opens more than one connection. Then either narrow the receipt to
   "verification exit" or keep it and add an F-entry establishing that one session means
   one circuit in practice. Either way the three assertions above need to stop being
   unqualified.

## What the grilling pass established

Verified 2026-07-26 while interrogating this plan. Three facts that were not in either
review, and one correction to both of them.

**The fork's de-branding is two changes, not one, and they have opposite economics.**
`dbffbc7` touches three files:

| File | Lines | Upstream activity | Useful to a CalypsoCode profile? |
|---|---|---|---|
| `session/llm/request.ts` | 3 | 11 commits, 3 in 30d | **yes** — the `User-Agent` F11 measured |
| `provider/provider.ts` | 30 (−26) | **382 commits, 10 in 30d** | **no** — see below |
| `core/src/plugin/provider/nvidia.ts` | 6 (−5) | — | no |

The 26 deleted lines in `provider.ts` remove `HTTP-Referer`, `X-Title`, `X-Source` and
`X-BILLING-INVOKE-ORIGIN` from four **provider-specific** option blocks. The launcher
always generates a provider named `calypsocode` on the generic
`@ai-sdk/openai-compatible` path (`bin/calypsocode:339`), so those blocks are never
reached. They carry the fork's whole rebase liability, in its hottest file, and buy
nothing for the actual workflow. Reverting that hunk is the open sub-question above.

**The `User-Agent` F11 measured comes from a local constant, and `dbffbc7` removed
exactly it.** `session/llm/request.ts:18` defines its own
``const USER_AGENT = `opencode/${InstallationVersion}` `` — two parts, matching F11's
`opencode/1.18.5` exactly. This is *not* `installation/index.ts:45`'s
`opencode/<channel>/<version>/<client>`. The two were confused mid-session and the
confusion is recorded here so nobody re-derives it: **DESIGN's claim about `dbffbc7`
holds.**

**A config-only override was available.** `models-dev.ts:102` declares
`headers: Schema.optional(Schema.Record(Schema.String, Schema.String))` on a model, and
`request.ts:203` spreads `...input.model.headers` **after** the branch that sets the
`User-Agent` — so a `headers` block in the generated compartment config would have
overridden it, without forking. Verified by schema and code path; **not verified on the
wire.** Batch 6 is where that would be settled. Note the difference in outcome: config
*overrides* with a value you choose, the fork *removes* and inherits whatever the SDK
sends. The former is arguably better.

## Batches

Batches 1 and 2 are independent of everything and of each other. Batch 3 and Batch 4
are independent of each other but both touch `test/`. Batch 6 verifies Batch 1. Batch 5
is documentation only.

### Batch 1 — Stop the agent contacting third parties

**The single highest-value change in this plan, and the only one that stops data
leaving.** Both reviews found it independently.

- **Files:** `bin/calypsocode` — the export block around line 730, and
  `compartment_prepare` (~line 305-345).
- **Evidence, verified:**
  - `packages/core/src/models-dev.ts:171` sends the OpenCode `USER_AGENT` to
    `https://models.dev/api.json` at startup **and every 60 minutes**. The opt-out
    `OPENCODE_DISABLE_MODELS_FETCH` exists (`packages/core/src/flag/flag.ts:29`) and is
    opt-out, so the fetch is the default.
  - `autoupdate` has **no default in the schema** (`packages/core/src/config.ts:42` —
    a bare `Schema.Union`), so it is `undefined` on a fresh install, which does not
    early-return. The default state is an unattended upgrade attempt.
  - `installation/index.ts` treats a binary under `~/.local/bin` as install method
    `curl`, which is the path `README.md` prescribes; `upgradeCurl` pipes
    `https://opencode.ai/install` into a shell. **If it ever fires it replaces the
    de-branded fork with vanilla OpenCode, silently.**
  - `grep -c "OPENCODE_DISABLE\|autoupdate" bin/calypsocode` → **0**.
- **Actions:**
  - Export `OPENCODE_DISABLE_AUTOUPDATE=1` and `OPENCODE_DISABLE_MODELS_FETCH=1`
    alongside the existing agent-facing exports. Comment them with *why* — these are
    non-provider destinations on the same circuit as provider traffic, and the receipt
    cannot see them.
  - Add `"autoupdate": false` to the generated compartment config, so the setting holds
    even if a flag name changes upstream. Belt and braces is correct here: one is an env
    var upstream could rename, the other is config upstream must honour.
- **Constraints:** the generated config is regenerated on every launch and must stay
  valid JSON — CI validates `config/*.json.example` but not the generated file, so
  assert it in a test.
- **Verify:** `./test/run.sh`; a new test asserting `autoupdate` is `false` in the
  generated config and that both variables reach the agent (`test/launch.test.sh`
  already asserts on stub-visible env — follow `test_identity_environment_reaches_the_agent`).
  Break both deliberately and confirm failure.
- **Done when:** both variables are set at launch, the generated config carries
  `"autoupdate": false`, and a test would catch the removal of either.

### Batch 2 — Refuse a malformed profile name and duplicate keys

- **Files:** `bin/calypsocode` (`profile_load`, ~line 226-263), `test/profile.test.sh`.
- **Evidence, reproduced in the main session:** `COMPARTMENT_DIR` is built at
  `bin/calypsocode:316` as `"$CALYPSO_HOME/compartments/$P_PROFILE"`. With
  `PROFILE=../shared` in two *different* profiles, both resolved to the same directory
  **outside** `compartments/`:

  ```
  AGENT XDG=/dev/shm/ptest/compartments/../shared    ← clientA
  AGENT XDG=/dev/shm/ptest/compartments/../shared    ← clientB
  line 478: .../receipt-...-../shared.txt: No such file or directory
  ```

  The agent ran — so data would have reached a provider — no receipt was written, and
  two compartments shared one config/data/state tree. That is the F9 failure the
  launcher was rewritten to prevent, reachable by typing a profile name. A plain `/`
  (`PROFILE=client/acme`) also runs the agent and writes no receipt.

  Separately: a profile with `NETWORK=tor` then `NETWORK=none` silently reports `none`.
  `profile_load` already refuses *unknown* keys so that "a typo fails loudly instead of
  silently dropping a compartment boundary" — a duplicated `NETWORK` is the same class
  of accident with a worse outcome.
- **Actions:**
  - Validate `P_PROFILE` against `^[A-Za-z0-9._-]+$` and `die` with a message naming the
    offending value. Place it next to the existing `NETWORK` validation so all profile
    invariants sit together.
  - Track keys seen while parsing; `die` on the second occurrence, naming the key and
    the line.
- **Constraints:** `PROFILE` defaults to the filename (`: "${P_PROFILE:=$name}"`), so
  validate **after** that default is applied — a filename can also contain a slash if
  someone passes `--profile a/b`.
- **Verify:** `./test/run.sh`; new tests for `PROFILE=../escape`, `PROFILE=a/b`, and a
  duplicated key. Break each deliberately.
- **Done when:** no profile value can place the compartment outside
  `$CALYPSO_HOME/compartments/`, and a duplicated key refuses instead of resolving.

### Batch 3 — Make the leak test able to fail

**This is the finding that should change the most.** It is the mechanism the project
points at when it claims to prove rather than assert (`docs/DESIGN.md:262-264`).

**Committed to now, not deferred** (settled decision 10). The receipt prints
`leak test passed — 3 private target(s)` to the user every session and `docs/FINDINGS.md`
F12 quotes it in a public repository; at most one of those three was a test. No stopgap
wording was applied, on the basis that this batch lands within days. **If it slips past a
week, stop and soften the receipt's wording first** — a public claim of proof that does
not exist is worse than a slightly clumsy commit history.

- **Files:** `bin/calypsocode` — `leak_targets` (~380-385) and the inner probe
  (~795-830); `test/leak.test.sh`; `docs/FINDINGS.md` (new entry).
- **Evidence, reproduced in the main session.** The probe is
  `curl -s --noproxy '*' -o /dev/null --max-time 5 "http://$leak_target/"` and the
  verdict treats **exit 0 as a leak and every other exit code as pass**. Run from the
  host, with no isolation whatsoever:

  | Target | curl exit | Scored as |
  |---|---|---|
  | `192.168.1.43` (the host's own address) | 7 | sealed ❌ |
  | `172.17.0.1` (docker) | 7 | sealed ❌ |
  | `192.168.1.1` (gateway) | 0 | leak ✅ |
  | `192.168.1.43:22000` (a port that **does** listen) | **56** | sealed ❌ |

  Exit 7 means "nothing listening on port 80", not "unreachable" — `ss -ltn` confirms
  nothing on this host listens on 80. So two of three targets return the same verdict
  sealed or not. **Exit 56 is the sharpest case: the TCP handshake completed and it is
  scored as sealed.** `--max-time 5` means a timeout (28) also passes, so a leak to a
  slow host reads as sealed. The check has **no false-FAIL mode at all** — every error
  path resolves to reassurance, which is exactly what `CONTRIBUTING.md:92-94` forbids.

  On this machine the gateway does answer on port 80, so the test is not entirely
  vacuous *here* — but its ability to fail depends on the user's router model. On a LAN
  with no gateway web UI it would report `3 private target(s) unreachable` with
  isolation completely broken.

  F10 measured `192.168.1.43` at 246ms and `172.17.0.1` at 252ms. **An unisolated
  connection to a closed local port returns RST in well under a millisecond.** That
  250ms is the evidence of isolation, and the shipped test discards it.
- **Actions:**
  - **Invert the predicate.** Only curl exit 7 (`couldn't connect`) is a pass. Exit 0,
    52 and 56 are leaks — all three prove the handshake completed. Exit 28 is
    inconclusive and must **refuse**, not pass.
  - **Add a positive control.** Before launching, on the host, find `(address, port)`
    pairs that actually answer: parse `ss -ltn` for listeners bound to `*` or `0.0.0.0`
    and pair them with the host's global-scope addresses; also probe the gateway on 80
    and 443. Confirm from the host that each candidate answers, and pass only confirmed
    ones into the namespace. Then the namespace's inability to reach them is evidence.
  - **Reuse the existing empty-list refusal** (~788-793) when no candidate answers —
    "a test that did not run is not a test that passed" is already the right sentence and
    needs to fire in one more case.
  - Consider a bare TCP connect (`/dev/tcp/$host/$port`; bash is already the inner
    interpreter) instead of an HTTP GET — it drops the port-80 assumption entirely and
    makes non-HTTP ports usable.
  - **Record the round-trip time in the receipt.** It is what distinguishes "refused by
    arti" from "refused by a closed port".
  - **Add a new F-entry** recording the host-side control measurement, and stating
    plainly that F12's `leak test passed — 3 private target(s)` overstated what was
    measured. **A new entry, not an edit** — settled decision 13, third branch: F12's
    numbers are true (the receipt really printed that), the over-reading is what the new
    entry corrects. Add a pointer from F12 to it.
- **Constraints:**
  - `leak_targets` wraps every stage in `|| true` on purpose: under `pipefail` a filter
    matching nothing would abort the launcher before it reached the namespace. Preserve
    that, and keep the "found nothing" decision inward where it can refuse usefully.
  - `169.254.42.0/24` is excluded deliberately — onion0's own subnet and Tor's resolver
    are legitimately reachable (F10). Do not re-add them.
  - The inner script runs inside `oniux` and cannot see the host's interfaces, which is
    why candidates are computed outside and passed in.
- **Verify:** `./test/run.sh`; extend `test/leak.test.sh`. The decisive test: with a
  stubbed probe returning 56, the launcher must refuse. Break the predicate deliberately
  and confirm failure.
- **Done when:** the leak test fails when isolation fails, refuses when it cannot tell,
  and the receipt states how many targets were *confirmed answerable from the host*
  rather than how many were probed.

### Batch 4 — Write `test/egress.test.sh`

- **Files:** new `test/egress.test.sh`; `test/helpers.sh` (parameterise `stub_curl`);
  `test/launch.test.sh:6` (the comment that lies).
- **Evidence, verified.** `test/launch.test.sh:6` says *"egress verification — covered in
  `egress.test.sh`"*. `ls test/*.test.sh` returns launch, leak, picker, profile, receipt.
  **`egress.test.sh` has never existed**, and `run.sh` globs `test/*.test.sh`, so a
  missing suite is silently zero tests — no error, no warning. That comment is the only
  thing in the repo asserting the coverage.

  Review 2 mutated the launcher ten times and ran the full suite against each. **Eight
  of ten survived a green 63-test run**, and the pattern is structural: every mutation to
  the egress verification and to what the receipt claims about Tor survived.

  | Deliberate breakage | Result |
  |---|---|
  | Drop the F9 fix — `XDG_DATA_HOME` stops moving | caught |
  | Reintroduce the timezone leak | caught |
  | Egress check accepts a **non-Tor** exit | **survived** |
  | Accepts any answer mentioning `IsTor`, true or false | **survived** |
  | Missing `curl` no longer refuses → silent unverified session | **survived** |
  | Dead-circuit retry cut from 3 attempts to 1 | **survived** |
  | Exit IP never recorded → receipt cannot name the exit | **survived** |
  | Leak test stops bypassing the proxy (the exact F10 error) | **survived** |
  | Receipt stops disclosing the username-in-path leak | **survived** |
  | **Receipt asserts a Tor exit that was never verified** | **survived** |

  The last one is the one to sit with: a receipt claiming
  `network: tor, exit 9.9.9.9, verified IsTor before launch` on a `NETWORK=none` run —
  lying about the single fact it exists to certify — passed all 63 tests. No test asserts
  the exit IP reaches the receipt, despite `test/helpers.sh:124` stubbing `185.220.101.1`
  for exactly that purpose.
- **Actions:**
  - Parameterise `stub_curl` over the `IsTor` value, the response shape, and a
    fail-then-succeed sequence so the retry can be exercised.
  - Cover, at minimum: a non-Tor exit must refuse; `IsTor: false` must refuse; a
    malformed answer must refuse; missing `curl` must refuse; the retry must attempt 3
    times; the verified exit IP must reach the receipt; and a `NETWORK=none` run must
    never produce a receipt claiming a Tor exit.
  - **Fix `launch.test.sh:6` either way** — once the suite exists the comment becomes
    true, but say which file covers what rather than leaving a bare promise.
  - Consider making `run.sh` fail loudly if a suite named in a comment is absent, or
    simply asserting the expected suite count. A silently-zero suite is the root cause
    and it will recur.
- **Constraints:** the suite must stay hermetic — no network, no Tor, no real agent.
  Follow `test/helpers.sh` conventions and the existing stub labelling.
- **Verify:** `./test/run.sh` shows 6 suites. Then re-run at least mutations 2, 3, 6, 7,
  8 and 10 from the table and confirm each now fails.
- **Done when:** six of the eight surviving mutations are caught, demonstrated by
  breaking the code deliberately rather than asserted.

### Batch 5 — Documentation honesty pass

Every item verified. This batch touches no code.

- **Files:** `docs/DESIGN.md`, `docs/THREAT-MODEL.md`, `docs/FINDINGS.md`, `README.md`,
  `bin/calypsocode` (one message, item 5).
- **Actions:**
  1. **`hostname` is claimed and not implemented.** `docs/DESIGN.md:56` marks
     "Locale, timezone, hostname" as `✅ set in the namespace`; `DESIGN.md:169` lists
     `hostname   # set inside the namespace`; `THREAT-MODEL.md:33` says machine metadata
     including hostname is "set or replaced per compartment before launch, so the
     identifying values are never produced". `grep -c hostname bin/calypsocode` → **0**,
     and `oniux` offers no UTS namespace or hostname option, so the child shares the
     host's. `README.md:117-123` is already honest and omits it. **Document rather than
     implement:** split the row, mark hostname ❌ or ⚠️ with the reason. Fix THREAT-MODEL
     first — overselling is the one thing that document exists not to do.
  2. **`DESIGN.md:262`** still specifies the negative test as including "resolve DNS
     outside the namespace". F10 proved the DNS half measures nothing and it was
     correctly never built. Stale against the project's own finding.
  3. **F6 says the launcher writes a LiteLLM log to `/tmp/calypsocode-litellm.log`.**
     There is no LiteLLM in the launcher any more. F6's *measurement* about the private
     `/tmp` stands and must not be touched; only the sentence describing what the
     launcher writes is stale. Prefer a new entry or a labelled note over editing the
     measurement.
  4. **F7 says "the session receipt is written from inside the namespace."** It is not —
     `receipt_write` runs on the host, called from the traps outside `oniux`; only the
     egress/leak/started markers cross the boundary. F7's *conclusion* is right, its
     mechanism description is wrong. Same treatment as item 3.
  5. **The startup check asserts an accomplished fact that has not happened.**
     `bin/calypsocode:444` prints `network tor, verified from inside the namespace before
     launch`, then asks for confirmation, and the actual verification runs later
     (~line 905). In a tool whose thesis is not overstating, the confirmation prompt
     overstates. Reword to future tense.
  6. **`README.md:11` leads with F8's numbers** — 8 round trips, 3.8s mean — measured on
     *upstream* OpenCode 1.18.4. `ROADMAP.md:42-43` already says that gate "says nothing
     about" the fork. F12 is the fork's gate and is better evidence. Lead with the number
     from the binary users will actually run.
  7. **Delete the audience positioning at `README.md:51-56`** (settled decision 15). The
     paragraph currently names who the tool is for — censoring jurisdictions, monitoring
     employers, questions dangerous to be seen asking. All of it goes. Keep the factual
     remainder, which is the part that was doing the work:

     > Your provider still knows which customer is paying. What an observer between you
     > and the provider learns is nothing — including which model you chose.

     Also drop the trailing "uncensored or otherwise" — it implies a use case, which is
     positioning in disguise, and "which model you chose" already covers it.
     **Keep `docs/THREAT-MODEL.md:26`** ("what your ISP, employer, or state can see").
     That names *positions on the network path* in order to say who can technically
     observe what — not who the user is. A threat model forbidden from saying who is on
     the path says nothing at all.
- **Constraints:** settled decision 13 decides items 3 and 4 without further judgement.
  **F6 (LiteLLM log) → leave it**, first branch: the world changed and the entry is
  accurate for its date. **F7 (receipt written inside the namespace) → correct in place,
  marked `Correction:`**, second branch: that sentence was false when written. Also write
  the three-branch rule itself into `CONTRIBUTING.md`, next to the existing "only add
  claims you have measured" paragraph.
- **Verify:** `grep -c hostname bin/calypsocode` still `0` while no document claims it is
  set; `./test/run.sh` (the suite asserts on launcher output, so item 5 may touch it).
- **Done when:** no document claims a behaviour the code does not implement, and no
  F-entry describes a mechanism that is not the mechanism.

### Batch 6 — Measure what the compiled binary actually sends

Closes `docs/FINDINGS.md` "Still untested" item 6, the open half of what DESIGN claims
about fork commit `dbffbc7`, **and** verifies Batch 1 landed.

- **Files:** `docs/FINDINGS.md` (new entry).
- **Actions:**
  - Reuse F11's method verbatim — it is written up in that entry: a throwaway local HTTP
    server logging every request's method, path and full header set, answering
    `/v1/chat/completions` with a minimal valid completion; a throwaway profile with
    `NETWORK=none` (**required** — the namespace cannot reach host loopback, F1).
  - Run it against the **compiled binary**, which is what users execute and what has
    never been measured. Record the `User-Agent` verbatim.
  - Confirm no request reaches `models.dev` or `api.github.com` during the session —
    this is Batch 1's proof.
  - Record as a new F-entry: date, binary, the exact header set, and whether the
    baked-in `--user-agent=opencode/<version>` from
    `packages/opencode/script/build.ts` surfaces on the wire.
- **Constraints:** `NETWORK=none` is a property of the test, not a recommended config —
  say so in the entry, as F11 does. Use a dummy key, never the real one.
- **Verify:** the entry states a measured header set, not an inference.
- **Done when:** DESIGN's scoped claim about the compiled path is either confirmed or
  corrected by measurement, and "Still untested" item 6 is struck.

### Batch 7 — Pin `oniux`, and check `curl` in `doctor`

- **Files:** `bin/calypsocode` (`doctor`, ~583-620), `README.md:93`, `docs/FINDINGS.md:8`.
- **Evidence:** `README.md` and `FINDINGS.md` both say `cargo install --git <url>` with
  no rev or tag, and `oniux --version` does not exist. `doctor_bin` reports presence via
  `command -v` only. So the isolation guarantee rests on an unknowable revision of a tool
  the Tor Project itself calls experimental, and **F1, F2, F6, F7 and F10 are not
  reproducible by anyone** — including their author, after the next `cargo install`.

  Separately, `doctor` does not check `curl`, which is what both the leak test and the
  egress check depend on. Its absence is discovered inside the namespace, after the user
  has confirmed a launch. The namespace shares the host filesystem, so a host-side check
  is valid.
- **Actions:**
  - Pin a specific rev in the documented install command; record that rev in FINDINGS
    next to the findings that depend on it.
  - Surface the installed revision in `doctor` if it can be determined; if it cannot,
    have `doctor` say so rather than imply the version is known.
  - Add `curl` to `doctor`'s checks. Consider skipping the `oniux` check for a
    `NETWORK=none` profile, which currently runs unconditionally.
- **Verify:** `./test/run.sh`; `./bin/calypsocode doctor --profile <name>` reports on
  `curl`. Note the subcommand must come first — `calypsocode --profile X doctor` is
  parsed as a launch.
- **Done when:** the isolation findings name the revision they were measured against.

### Batch 8 — The fork: revert the latent hunk, fix the licence claim

Two small changes in `<project-siblings>/calypsocode-agent`, one commit each, one push.

- **Files:** `packages/opencode/src/provider/provider.ts`,
  `packages/core/src/plugin/provider/nvidia.ts`,
  `packages/opencode/src/cli/about.ts`.
- **Actions:**
  - **Revert `dbffbc7`'s hunks in `provider.ts` and `nvidia.ts`** (settled decision 17).
    They strip `HTTP-Referer`, `X-Title`, `X-Source` and `X-BILLING-INVOKE-ORIGIN` from
    four provider-specific option blocks that a CalypsoCode profile never reaches, and
    they sit in upstream's hottest file. **Keep the 3-line `request.ts` hunk** — that one
    is the fix F11 justified and it is in a quiet file. Say in the commit body that the
    reverted headers are reachable only on provider paths the launcher does not use, and
    that a `headers` entry in the generated config would handle them if that ever changed.
  - **`about.ts:19-20` must stop claiming AGPL-3.0** for CalypsoCode's changes and state
    MIT, matching `LICENSE` and both `package.json` files (settled decision 12). Keep the
    "this is a fork of OpenCode" attribution — that part is correct and is the reason the
    command exists.
- **Constraints:**
  - Push with `TURBO_CONCURRENCY=1 git push origin dev` — the `pre-push` hook runs
    `turbo typecheck`, which OOMs on this machine at default concurrency and reads like a
    type failure. Never `--no-verify`.
  - Do not rebuild the binary as part of this. If a rebuild is wanted, the cwd must be
    inside the fork (see Known pitfalls).
- **Verify:** `TURBO_CONCURRENCY=1 bun typecheck` at the fork root → 30/30;
  `./bin/calypsocode --profile <name> --yes run "hi"` against a stub still works;
  `calypsocode-agent --about` prints MIT for both halves.
- **Done when:** no fork line remains in a file upstream touches often, and the licence
  the tool prints matches the licence the repository carries.

### Batch 9 — Small hardening batch

Lowest priority; each item is small and independently verified.

- **Files:** `bin/calypsocode`.
- **Actions:**
  - **Atomic receipt write.** A second Ctrl-C while `receipt_write` is mid-redirect
    leaves a truncated receipt with nothing marking it truncated. Write to a temp file
    and `mv` into place — appropriate for the one document whose job is to be true.
  - **`calypsocode profile` does not reflect an active `CALYPSO_NETWORK`.** Verified:
    `CALYPSO_NETWORK=none calypsocode profile` prints `network: tor`. The override is
    resolved after the subcommand dispatch. For a tool built around "there is never a
    second place a backend choice could hide", the inspection command showing the file's
    value rather than the effective one is the same bug in miniature.
  - **`json_escape` handles `\` and `"` only.** An interior tab in a profile value
    produces invalid JSON and an opaque agent error. Escape control characters.
  - **`session_tally` is an unlocked read-modify-write**, so two simultaneous launches of
    one compartment lose a count and share one agent state tree. **Decided: document it,
    do not lock it** (settled decision 18). A bash lock means a lock file, cleanup on
    signal, and a stale-lock case — three new ways to fail in order to fix a counter. And
    the counter is not the real problem: two sessions of one compartment sharing the
    agent's state tree is, and a lock does not fix that either. Say so in
    `docs/THREAT-MODEL.md` next to the compartment-separation advice.
- **Verify:** `./test/run.sh`; a test for the tab case; break each deliberately.
- **Done when:** the receipt cannot be truncated without saying so, and `profile` reports
  the effective configuration.

## Execution

- One subagent per batch; commit and `/clear` between batches.
- **Batch 1 first.** It is five minutes, it is the only batch that stops data leaving,
  and both reviews independently put it first.
- Batch 2 next — twenty minutes, and it closes a silent compartment merge.
- Batches 3 and 4 are the real work (~1 day and ~½ day). They are independent of each
  other; 4 has the better ratio of correctness recovered to effort, 3 fixes the claim the
  project is built on.
- Batch 5 can run any time and needs no code. Batch 6 needs Batch 1 to be meaningful.
- `main` is protected. Each batch, or a coherent group, goes through a PR with green CI
  (shellcheck pinned at `0.11.0`, the test suite, and gitleaks over full history).
- **This plan file is untracked.** Commit it on the first branch so it does not exist only
  on one disk.

Model tiers: Batches 1, 2, 7, 8 and 9 are mechanical → `haiku` or `sonnet`. Batch 3 and 4 are
real reasoning about what a test proves → `sonnet` at least, `opus` for Batch 3's
predicate and positive control. Batch 5's wording decisions and Batch 6's findings
write-up → whoever is in main loop; the honesty judgements there must not be delegated to
a weaker model.

## Known pitfalls

- **`docs/FINDINGS.md` is the single most likely thing to damage.** Settled decision 1.
  Two batches touch it; both must distinguish "this measurement is stale" (leave it, add
  a new entry) from "this sentence was false when written" (withdraw in place, labelled).
- **The fork's `pre-push` hook fails by OOM, not by type errors.** Turbo launches ~9
  `tsgo` processes on a 7.2 GiB machine and the kernel kills them; turbo then segfaults,
  and the output reads like a type failure. Use `TURBO_CONCURRENCY=1 git push origin dev`
  — same check, serial, 30/30 green. Never `--no-verify`.
- **Build the agent with the cwd inside the fork:**
  `bun run --cwd <project-siblings>/calypsocode-agent/packages/opencode script/build.ts --single`.
  ESM imports are hoisted above the script's own `chdir`, so invoking it from elsewhere
  stamps the binary with the *other* repo's branch and version. The flag is `--single`.
- **oniux gives the namespace a private `/tmp`** (F6, F7). A project directory under
  `/tmp` does not exist inside the namespace and the agent dies with an opaque
  `UnknownError`. This also swallows `curl -o /tmp/...` output while debugging through
  `oniux`. There is no guard for it — adding one was discussed and is not in this plan.
- **Roughly one Tor circuit in three is dead** (F4). A failed egress check is a retry.
- **`docs/private/north-star.md` is local-only**, excluded via `.git/info/exclude`, this
  clone only, not backed up. Read it if Open question 1 comes up. Never modify or commit
  it.
- **CI pins shellcheck to `0.11.0`** — the apt version behaves differently. The pinned
  one is already on this machine.
- **Line numbers throughout were measured 2026-07-26**, against `main` at `ffba1d1`.
  Re-verify with `grep -n` before editing rather than trusting them.
- **Do not take a review's word for a finding.** Every claim above was re-verified in the
  main session, and one was corrected in the process: the gateway *does* answer on port
  80 on this machine, so the leak test is not entirely vacuous here — it fails to be
  evidence on two of three targets, and its ability to fail at all depends on the user's
  router. Hold the same standard.

---

## Grilling pass — decisions log

Every open question above was walked through on 2026-07-26. Recorded here so the
resolutions are findable in one place rather than scattered through the sections.

| # | Question | Resolution |
|---|---|---|
| 1 | Gate tests before more code? | Out of scope, deferred indefinitely — they gate the operator, not the launcher |
| 2 | Does config retire the fork? | It could have; fork stays anyway for the UI, rebased on demand |
| 3 | AGPL or MIT? | Launcher AGPL, fork MIT, `about.ts` corrected |
| 4 | Project path | Removed from this plan — lives in the Desktop handoff |
| 5 | Circuit pinning vs rotation | Still open; rotation now measured, see question 7 |
| 6 | Which extensions? | None until weeks of real use, then `calypsocode audit` |
| 7 | Receipt's `exit <IP>` | Mechanism measured, failure not established — one more measurement needed |
| 8 | Revert `provider.ts`'s 26 lines? | Yes — Batch 9 |
| 9 | Lock `session_tally`? | No — document it |
| — | How to correct a wrong F-entry | Three-branch rule, into `CONTRIBUTING.md` |
| — | Audience positioning | Deleted everywhere; capabilities only |

Two things the grilling produced that neither review had, both verified in the main
session and both already folded into the sections above: the split economics of
`dbffbc7`'s three hunks, and the measured Tor exit rotation inside a single namespace.

One open question genuinely remains — **5, circuit pinning versus rotation** — and it is
now better posed than before: rotation is measured, so the question is whether pinning one
exit per compartment is safer than drawing many. A single account arriving from many exits
is the credential-theft signal F4 warns about; pinning looks like a normal user but
concentrates correlation. `oniux --arti-config` plus per-compartment SOCKS credentials
makes both implementable. The answer probably differs by provider, and weeks of real use is
what would inform it.
