# Plan — Fork OpenCode into CalypsoCode

> Executor: Sonnet or Opus + subagents. Apply the decisions, do not re-litigate
> them. Unresolved doubt → stop and ask.

## Goal & scope

Turn CalypsoCode from a launcher that wraps someone else's agent into a
rebranded fork of OpenCode: its own name on screen, its own config namespace,
and honest attribution of what it is built on.

**In scope:** the visible rename (Tier 1), the disclosure surface, and — if the
header test says it matters — removing client-identifying headers from outbound
requests (Tier 2).

**Explicitly NOT decided in this plan:** whether to become a full distribution
with its own release pipeline (Tier 3). See Open questions.

### Required reading before starting

- `docs/plans/fork-scope.md` — the measured scope. File paths, line numbers and
  counts in it were verified against `sst/opencode@dev` on 2026-07-24. **Do not
  re-derive them; do re-check them against the clone, since upstream moves.**
- `docs/DESIGN.md#every-signal-decided` — the signal table. Tier 2 exists to
  move one row of it.
- `docs/FINDINGS.md` F9 — why an agent's identity surface is more than one
  directory. Directly relevant to renaming the app namespace.

## Starting state

- Branch: work happens on a feature branch, not `main`.
- `bin/calypsocode` works and is committed (batches 1–6 of
  `docs/plans/v1-launcher.md`, all complete and measured).
- `bun` 1.3.14 is installed at `~/.bun/bin/bun` — the exact version
  `sst/opencode` pins in `packageManager`.
- OpenCode 1.18.4 is installed at `~/.opencode/bin/opencode`, from the upstream
  installer. Nothing has been forked yet.
- A shallow clone may still exist in the session scratchpad; treat it as
  disposable and re-clone if absent.

## Settled decisions

- **The fork happens, and it is branded CalypsoCode.** The name on screen is the
  point.
- **Licence position is clear.** OpenCode is MIT; modification and rebranding
  are permitted. The only obligation is that the copyright and permission notice
  travel with copies. There is no UI-attribution requirement.
- **Disclosure exceeds what the licence requires, deliberately.** A "fork of
  OpenCode" line on screen, the README stating the agent is OpenCode, and an
  `--about` carrying both licences. This is a project-values choice, not a legal
  one — the tool must not obscure what it is built on.
- **Never claim to be OpenCode.** MIT grants no trademark rights. Rebranding
  away from their mark is the correct direction; impersonating them is the only
  thing actually forbidden.
- **Do not rename the `@opencode-ai/*` internal package imports.** 4,056 of the
  11,946 "opencode" occurrences are that namespace. Nobody sees them, and
  renaming is pure churn against every future rebase.
- **Only four packages matter** for a CLI + TUI: `opencode`, `core`, `tui`,
  `cli`. The desktop, web, console, Slack and infra packages are not in scope.
- **The models.dev catalog fetch needs configuration, not a patch** — the
  `OPENCODE_MODELS_URL` flag already exists.

## Open questions

**These do not block Batches 1–4. Do not decide either on the user's behalf.**

1. **Does the generic `@ai-sdk/openai-compatible` path send identifying
   headers?** `HTTP-Referer: https://opencode.ai/`, `X-Title` and `X-Source` are
   attached by six named providers and at
   `packages/opencode/src/provider/provider.ts:461,472`. They appear scoped to
   named providers, not the generic path Venice uses — **unverified**.
   Batch 1 answers it. If the generic path is clean, Tier 2 is optional polish.
   If it is not, Tier 2 is the privacy justification for the whole fork.

2. **Tier 3 — become a full distribution?** Upstream ships to npm, GitHub
   Releases, Homebrew and an Arch `PKGBUILD` across `linux-x64`,
   `darwin-arm64` and Windows. Taking that on is permanent release-engineering
   ownership against a fast-moving upstream on pre-release dependencies. The
   stated ambition is an "AI distro", which is exactly this — but it has not
   been committed to, and Batches 2–6 do not require it.

3. **Migration for existing compartments.** Changing `const app = "opencode"`
   moves every XDG leaf directory. Existing compartments under
   `~/.config/calypsocode/compartments/<name>/data/opencode` become
   `.../data/calypsocode`, orphaning session history. With one test compartment
   (`gate`) this is currently free to ignore — but it is a real upgrade concern
   the moment anyone else uses it. Ask before writing a migration.

## Batches (independent)

### Batch 1 — The header test · **answers Open question 1**

- **Files:** none (measurement), then `docs/FINDINGS.md`
- **Actions:**
  - Stand up a local HTTP server that logs every request header and returns a
    minimal OpenAI-compatible `/chat/completions` response.
  - Point a throwaway profile's `API_BASE` at it, run
    `CALYPSO_NETWORK=none ./bin/calypsocode --profile <test> --yes run "hi"`.
    `none` mode is required: the namespace cannot reach host loopback (F1).
  - Record verbatim which headers OpenCode sends to a *generic*
    openai-compatible provider.
- **Constraints:** costs nothing and must stay that way — no real provider, no
  API key with credit. Do not infer the answer from reading the source; the
  point is to observe it.
- **Verify:** the server log contains the full header set of a real request.
- **Done when:** `docs/FINDINGS.md` records, as a measured finding, whether a
  generic provider receives a client-identifying header — and
  `docs/DESIGN.md`'s "Client & TLS fingerprint ⚠️ partial" row cites it.

### Batch 2 — Fork and reproducible build

- **Files:** new fork checkout; a note in `docs/` recording where it lives
- **Actions:**
  - Fork `sst/opencode`, clone it, and get a build that runs:
    `bun install` then the CLI entry (`bun run dev` runs
    `packages/opencode/src/index.ts`).
  - Confirm the built binary starts, shows the TUI, and can run a session
    against the `gate` profile's provider config.
  - Record the exact build commands that worked.
- **Constraints:** `bun@1.3.14` is pinned and already installed — do not upgrade
  it to make something work. `node-pty` has a `postinstall` fix step; if it
  fails, that is the problem to solve, not to work around.
- **Verify:** a locally built binary runs `--version` and starts a session.
- **Done when:** the build is reproducible from a clean clone with written-down
  commands.

### Batch 3 — Tier 1, the visible rename

- **Files:** in the fork —
  `packages/tui/src/logo.ts`, `packages/opencode/src/cli/ui.ts`,
  `packages/tui/src/util/presentation.ts`, `packages/core/src/global.ts`,
  and the relevant `package.json` files
- **Actions:**
  - Redraw the block-letter logo as CalypsoCode. `logo.ts` stores it as `left`
    and `right` halves — currently "open" and "code" — which maps onto
    "Calypso" + "Code". It is 11 glyphs against 8, so the art gets wider; check
    it still fits a narrow terminal.
  - Update the second logo copy in `cli/ui.ts` (around lines 7–9).
  - `packages/core/src/global.ts:10` — `const app = "opencode"` → `calypsocode`.
    This one line moves `data`, `cache`, `config`, `state` and `tmp`.
  - Rename the binary and user-facing package names.
- **Constraints:**
  - Do **not** touch `@opencode-ai/*` imports.
  - Re-verify the line numbers above against the clone before editing; they were
    measured on 2026-07-24 and upstream moves.
  - Keep the diff to strings and art. Any change to behaviour belongs in
    another batch.
- **Verify:** built binary shows the CalypsoCode logo; `debug paths` reports
  every path under a `calypsocode` directory.
- **Done when:** nothing user-visible says "opencode" except the deliberate
  attribution from Batch 4.

### Batch 4 — Disclosure

- **Files:** in the fork — an `--about` command and the startup line; in this
  repo — `README.md`
- **Actions:**
  - A visible "fork of OpenCode" line where a user will actually see it.
  - `--about` (or equivalent) carrying **both** licences: OpenCode's MIT notice
    and CalypsoCode's AGPL-3.0.
  - Ship OpenCode's `LICENSE` file in the distribution.
  - `README.md` states plainly that the agent is a fork of OpenCode.
- **Constraints:** this is the batch that keeps the project honest. It is not
  optional and it is not decoration — a privacy tool that hides its own
  provenance has undermined the argument it exists to make.
- **Verify:** `grep -ri "opencode" ` over user-visible strings returns only
  intentional attribution.
- **Done when:** a user who has never read the README can discover what the tool
  is built on, from the tool.

### Batch 5 — Tier 2, de-brand the wire · **conditional on Batch 1**

- **Files:** in the fork — `packages/opencode/src/provider/provider.ts`,
  `packages/core/src/plugin/provider/*.ts`
- **Actions (only if Batch 1 showed identifying headers reach a generic
  provider):**
  - Remove or neutralise `HTTP-Referer`, `X-Title`, `X-Source`.
  - Decide what replaces them: nothing at all is the privacy-correct answer;
    substituting a CalypsoCode identifier just swaps one fingerprint for
    another, rarer one. **Ask before choosing.**
  - Set `OPENCODE_MODELS_URL` (or its renamed equivalent) so the models.dev
    fetch is a deliberate, documented call rather than a silent one — or
    document why it stays.
- **Constraints:** do not widen this into general traffic rewriting. Calypso
  erases who is asking by *configuring*, never by rewriting requests
  (`docs/DESIGN.md#why-this-boundary-and-not-a-wider-one`). Removing a header
  the client itself adds is configuration of our own agent, not interception —
  keep the distinction visible in the commit message.
- **Verify:** re-run Batch 1's header test against the fork; the identifying
  headers are gone.
- **Done when:** `docs/FINDINGS.md` and the signal table both reflect the new
  state, measured.

### Batch 6 — Point the launcher at the fork

- **Files:** `bin/calypsocode`, `README.md`, `docs/plans/fork-scope.md`
- **Actions:**
  - `bin/calypsocode` currently looks for `opencode` on `PATH` and its error
    message points at `opencode.ai/install`. Both need to reference the
    CalypsoCode build.
  - Keep a clear failure message naming how to obtain or build it.
- **Constraints:** the launcher's guarantees must not regress — egress
  verification, the receipt, and the compartment env are all still required, and
  their tests still have to pass.
- **Verify:** `CALYPSO_NETWORK=none ./bin/calypsocode --profile gate --yes`
  starts the forked binary; the receipt is still written.
- **Done when:** a session runs end to end on the fork, with a receipt, and no
  reference to the upstream installer remains.

## Execution

- One subagent per batch; commit and `/clear` between batches.
- Batch 1 first — it is cheap and it decides Batch 5.
- Batches 2–4 are independent of the open questions.
- Batch 5 must not start until Batch 1 is answered.
- Do not start Tier 3 work (release pipeline, platform targets, package
  registries) under this plan. It is Open question 2.

## Known pitfalls

- **213 MB, 30+ packages, four that matter.** `opencode`, `core`, `tui`, `cli`.
  Ignore desktop, web, console, Slack, `sst.config.ts` and the infra packages
  entirely.
- **11,946 mentions of "opencode" is a misleading number.** 4,056 are internal
  `@opencode-ai/*` imports; roughly 467 quoted strings across the three main
  packages are the actual surface.
- **`global.ts:10` is load-bearing.** One line renames every XDG directory. That
  is the good news and the migration hazard — see Open question 3.
- **Line numbers rot.** Every path and line in `docs/plans/fork-scope.md` was
  measured on 2026-07-24 against `dev`. Re-check before editing.
- **Pre-release dependencies.** `effect@4.0.0-beta.83`, `@opentui/*@0.4.5`,
  `drizzle-orm@1.0.0-rc.2`. Expect breakage on upgrade, and do not upgrade
  casually to fix an unrelated problem.
- **`bun` is pinned at 1.3.14** and already installed at that exact version.
- **`node-pty` is a native dependency** with a `postinstall` fix step.
- **The MIT notice must survive** every refactor, rebase and repackage.
- **F1 still applies to the header test.** The namespace cannot reach host
  loopback, so the test must run in `CALYPSO_NETWORK=none` mode.
- **Rebase burden is the real cost of the fork**, not the rename. The branding
  strings are stable; everything around them is not.
