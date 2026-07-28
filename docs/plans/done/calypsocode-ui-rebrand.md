# Plan — CalypsoCode UI Rebrand

> Executed 2026-07-26, all 6 batches. Settled decision 8 amended: blue `#4C8DFF`
> was dropped from the palette in fork commit `8835df0`; shipped palette is
> violet `#8b4cff` ↔ pink `#ff2e97`.

> Executor: Sonnet or Opus + subagents. Apply the decisions, do not re-litigate
> them. Unresolved doubt → stop and ask.

## Goal & scope

Give CalypsoCode its own visual identity instead of inheriting OpenCode's UI
verbatim. This extends the existing fork plan
(`docs/plans/calypsocode-fork.md`) — it does not replace it. The fork happens
either way; this plan folds a real rebrand (palette + motion) into that
fork's Batch 3, and adds the launcher-side renaming this requires.

**In scope now (Phase 1, cosmetic):** palette and animation applied to
OpenCode's *existing* TUI structure and flow, inside a real fork.

**Explicitly out of scope (Phase 2, structural — future plan, not this one):**
reorganizing screens/flow to surface Calypso-specific concepts (the session
receipt, compartment identity, Tor egress proof) that don't exist in vanilla
OpenCode. Do not start this under the current plan.

### Required reading before starting

- `docs/plans/calypsocode-fork.md` — the 6-batch fork plan this work extends.
  Its settled decisions stand; this plan only adds the UI-rebrand content of
  Batch 3 and confirms sequencing/naming choices below.
- `docs/plans/fork-scope.md` — measured paths/line counts against
  `sst/opencode@dev` as of 2026-07-24. Re-check before editing; upstream
  moves.
- `docs/DESIGN.md` — the signal table; Batch 5 exists to move one row of it.
- Design reference:
  `<home>/Téléchargements/CloakCode logo round two_files/CalypsoCode Architecture.dc.html`
  — source of the color palette below. **This is a web mockup, not a TUI
  mockup.** Extract the hex values only; do not try to reproduce its
  gradients/blur/box-shadow pixel-for-pixel in a terminal. (Folder name says
  "CloakCode" — an earlier working name; the file content already says
  "CalypsoCode" throughout. No actual naming conflict, ignore the folder
  name.)

## Settled decisions

1. Scope = full UI: the launcher (`bin/calypsocode`) and the OpenCode agent it
   wraps, rebranded together as one CalypsoCode experience.
2. Phase 1 (this plan) = cosmetic only, on OpenCode's existing structure/flow.
   Phase 2 (structural, later, separate plan) = surface Calypso-specific
   concepts in the UI.
3. Sequencing: do not create the working branch until the `v1-launcher`
   branch is merged into `main` (currently blocked on `gh` re-auth per the
   last session's handoff — check `git log main` / `gh pr view` before
   starting Batch 0).
4. This executes as a **real fork** of OpenCode (not string edits on the
   installed binary) — i.e., all 6 batches of `calypsocode-fork.md` happen,
   with the UI rebrand folded into Batch 3.
5. Batch 1 (header test) runs **in parallel** with Batches 2–4, not
   sequentially before them. It only gates Batch 5.
6. Target interface: **TUI only**. No web or desktop UI in scope.
7. Execution model: hybrid delegation. Claude (main loop) owns architecture
   calls and the creative rebrand work; `sonnet`-tier subagents handle
   mechanical work (Batch 1 measurement, Batch 2 fork/build setup, string
   renaming sweeps). Reserve `opus` for a genuinely hard architectural call —
   none identified yet; don't default to it.
8. **Color palette** — extracted verbatim from the design reference above,
   **not** from the earlier verbal "violet/blue/yellow" description (the
   reference has no yellow):
   - Violet (dominant): `#7C5CFF`
   - Blue (accent): `#4C8DFF`
   - Pink/magenta (highlight): `#FF5C9D` / `#FF8DC0`
   - Background: near-black `rgb(9,8,15)` with soft violet/pink/blue radial
     gradients (adapt to terminal: gradients likely become dithered or flat
     accent bands, see Batch 2)
   - Primary text: `rgb(244,242,255)`; secondary/muted text:
     `rgb(126,122,152)` / `rgb(110,106,134)`
   - Success/verified state: green `rgb(127,229,176)` (kept from reference)
   - Fonts referenced in the mockup (Manrope / JetBrains Mono) are an
     aesthetic cue only — a TUI does not control the terminal's font, do not
     hardcode font families.
9. **Animation ambition**: transitions + micro-interactions + flashy motion
   touches — all three are wanted, but the concrete set is decided **after**
   Batch 2's engine reconnaissance, not fixed in advance.
10. Terminal engine feasibility gates animation scope: Batch 2 must include a
    reconnaissance step on what `@opentui/*` actually supports (truecolor,
    animated redraws, gradient text, transition primitives) before Batch 3
    commits to specific effects.
11. **Agent binary name: `calypsocode-agent`** — avoids a PATH collision with
    the existing launcher script `bin/calypsocode`, which today does
    `exec opencode "$@"` (bin/calypsocode:844) and will do
    `exec calypsocode-agent "$@"` after Batch 6.
12. **Fork location:** a real GitHub fork at
    `github.com/MyrLeProgrammeur/calypsocode-agent` (forked from
    `sst/opencode`), not a subdirectory or submodule of this repo. Keeps the
    upstream link for future `git fetch upstream && git rebase`.
13. **No compartment migration.** Only one test compartment (`gate`) exists
    today; its history loss when `global.ts`'s `const app = "opencode"`
    changes is accepted. Do not write a migration script.

## Open questions

None — every branch was resolved in the interview that produced this plan.
(Batch 5's necessity is not "open": it is mechanically decided by Batch 1's
measured result, per the existing fork plan.)

## Batches

### Batch 0 — Branch setup

- **Files:** none (git operations only).
- **Actions:**
  - Confirm the `v1-launcher` branch is merged into `main`
    (`git log main --oneline | grep -i v1-launcher`, or `gh pr view` on the
    PR). Do not proceed until it has.
  - `git checkout main && git pull`
  - `git checkout -b feat/calypsocode-ui-rebrand`
- **Constraints:** do not create the branch before the merge lands (Settled
  decision 3).
- **Verify:** `git branch --show-current` reports
  `feat/calypsocode-ui-rebrand`; `git log --oneline -3` shows the
  `v1-launcher` commits present in history.
- **Done when:** branch exists off an up-to-date `main`.

### Batch 1 — The header test (from `calypsocode-fork.md`, runs parallel to 2–4)

- **Files:** none (measurement), then `docs/FINDINGS.md`.
- **Actions:**
  - Stand up a local HTTP server that logs every request header and returns a
    minimal OpenAI-compatible `/chat/completions` response.
  - Point a throwaway profile's `API_BASE` at it, run
    `CALYPSO_NETWORK=none ./bin/calypsocode --profile <test> --yes run "hi"`
    (`none` mode required — the namespace cannot reach host loopback, see F1
    in Known pitfalls).
  - Record verbatim which headers OpenCode sends to a *generic*
    OpenAI-compatible provider.
- **Constraints:** no real provider, no API key with credit.
- **Verify:** the server log contains the full header set of a real request.
- **Done when:** `docs/FINDINGS.md` records, as a measured finding, whether a
  generic provider receives a client-identifying header, and
  `docs/DESIGN.md`'s "Client & TLS fingerprint ⚠️ partial" row cites it.

### Batch 2 — Fork, build, and engine reconnaissance

- **Files:** new fork checkout at
  `github.com/MyrLeProgrammeur/calypsocode-agent`; a note in `docs/` recording
  where it lives and what the reconnaissance found.
- **Actions:**
  - Fork `sst/opencode` on GitHub to `MyrLeProgrammeur/calypsocode-agent`;
    clone it locally.
  - `bun install`, confirm the build runs (`bun run dev` runs
    `packages/opencode/src/index.ts`), confirm the TUI starts and can run a
    session against the `gate` profile's provider config.
  - **Reconnaissance:** inspect `@opentui/*` (source and/or its own docs) for
    actual support of: 24-bit/truecolor, animated redraws, gradient text, any
    built-in easing/transition primitives. Write down what's real and what
    isn't — this is what Batch 3's animation set gets scoped against.
  - Record the exact build commands that worked.
- **Constraints:** `bun@1.3.14` is pinned and already installed at
  `~/.bun/bin/bun` — do not upgrade it. `node-pty`'s `postinstall` fix step is
  expected; solve it, don't route around it.
- **Verify:** the locally built binary runs `--version` and starts a session.
- **Done when:** the build is reproducible from a clean clone with
  written-down commands, **and** a short reconnaissance note states
  `@opentui`'s actual color/animation capabilities.

### Batch 3 — Tier 1 rename + UI rebrand (cosmetic phase)

- **Files:** in the fork — `packages/tui/src/logo.ts`,
  `packages/opencode/src/cli/ui.ts`,
  `packages/tui/src/util/presentation.ts`, `packages/core/src/global.ts`,
  wherever the TUI's existing theme/color tokens live (search for them once
  cloned — don't invent a parallel system), and the relevant `package.json`
  files.
- **Actions:**
  - Redraw the block-letter logo as CalypsoCode. `logo.ts` stores `left`/
    `right` halves (currently "open"/"code") → "Calypso"/"Code" — 11 glyphs
    vs 8, wider; check it still fits a narrow terminal.
  - Update the second logo copy in `cli/ui.ts` (around lines 7–9 as of
    2026-07-24 — re-verify).
  - `packages/core/src/global.ts:10` — `const app = "opencode"` →
    `"calypsocode-agent"` (re-verify line number against the clone).
  - Rename binary/package user-facing names to `calypsocode-agent` (Settled
    decision 11).
  - Apply the Settled-decision-8 palette to whatever theme/color token system
    OpenCode's TUI already has — replace values at the source, don't hand-
    patch individual render calls.
  - Implement the animation set decided from Batch 2's reconnaissance. This
    is a design call Claude makes directly in main loop, not delegated
    (Settled decision 7).
- **Constraints:**
  - Do **not** touch `@opencode-ai/*` imports.
  - Keep this batch's diff to strings, art, and theme/color values — no
    structural UI changes (that's Phase 2, explicitly out of scope, Settled
    decision 2).
  - Re-verify every line number above against the clone before editing.
- **Verify:** built binary shows the CalypsoCode logo in the new palette;
  the paths-debug command (or equivalent) reports every path under a
  `calypsocode-agent` directory.
- **Done when:** nothing user-visible says "opencode" except the deliberate
  attribution from Batch 4, and the TUI visibly uses the violet/blue/pink
  palette with the agreed animation set.

### Batch 4 — Disclosure (from `calypsocode-fork.md`, unchanged)

- **Files:** in the fork — an `--about` command and the startup line; in this
  repo — `README.md`.
- **Actions:**
  - A visible "fork of OpenCode" line where a user will actually see it.
  - `--about` (or equivalent) carrying **both** licences: OpenCode's MIT
    notice and CalypsoCode's AGPL-3.0.
  - Ship OpenCode's `LICENSE` file in the distribution.
  - `README.md` states plainly the agent is a fork of OpenCode.
- **Constraints:** not optional, not decoration — a privacy tool that hides
  its own provenance undermines the argument it exists to make.
- **Verify:** `grep -ri "opencode"` over user-visible strings returns only
  intentional attribution.
- **Done when:** a user who never read the README can discover what the tool
  is built on, from the tool itself.

### Batch 5 — Tier 2, de-brand the wire · conditional on Batch 1

- **Files:** in the fork — `packages/opencode/src/provider/provider.ts`,
  `packages/core/src/plugin/provider/*.ts`.
- **Actions (only if Batch 1 showed identifying headers reach a generic
  provider):**
  - Remove or neutralise `HTTP-Referer`, `X-Title`, `X-Source`.
  - Decide what replaces them — nothing at all is the privacy-correct
    default; substituting a CalypsoCode identifier just swaps one
    fingerprint for a rarer one. **Ask before choosing.**
- **Constraints:** do not widen this into general traffic rewriting
  (`docs/DESIGN.md#why-this-boundary-and-not-a-wider-one`). Removing a header
  the client itself adds is configuration of our own agent, not interception.
- **Verify:** re-run Batch 1's header test against the fork; the identifying
  headers are gone.
- **Done when:** `docs/FINDINGS.md` and the signal table both reflect the new
  state, measured.

### Batch 6 — Point the launcher at the fork

- **Files:** `bin/calypsocode`, `README.md`, `docs/plans/fork-scope.md` (in
  this repo).
- **Actions:**
  - `bin/calypsocode` currently checks `command -v opencode` (doctor check,
    ~line 559), tests `command -v opencode` again before exec (~line 833),
    and runs `exec opencode "$@"` (~line 844); its failure message points at
    `opencode.ai/install`. Update all of these to reference
    `calypsocode-agent` and how to obtain/build it. `grep -n opencode
    bin/calypsocode` to catch every reference, including comments describing
    XDG paths that shift with the rename (~lines 291–305, 694–695).
  - Keep a clear failure message naming how to obtain or build
    `calypsocode-agent`.
- **Constraints:** the launcher's guarantees must not regress — egress
  verification, the receipt, and the compartment env are all still required;
  `./test/run.sh` must stay green.
- **Verify:**
  `CALYPSO_NETWORK=none ./bin/calypsocode --profile gate --yes` starts the
  forked binary; the receipt is still written; `./test/run.sh` passes.
- **Done when:** a session runs end to end on the fork, with a receipt, and
  no reference to the upstream `opencode` installer remains.

## Execution

- One subagent per batch; commit and `/clear` between batches.
- Batch 0 first, gated on the `v1-launcher` merge — check before starting
  anything else.
- Batch 1 runs in parallel with Batch 2 (Settled decision 5).
- Batch 3 depends on Batch 2's reconnaissance output — do not start Batch 3's
  animation implementation until that note exists.
- Batch 5 must not start until Batch 1 is answered.
- Batches 2–4 are otherwise independent of each other.
- Phase 2 (structural UI changes for Calypso-specific concepts) is explicitly
  **not** part of this plan — write a fresh plan for it once Phase 1 ships.

## Known pitfalls

- 213 MB, 30+ packages in `sst/opencode`; only four matter: `opencode`,
  `core`, `tui`, `cli`. Ignore desktop, web, console, Slack, `sst.config.ts`,
  infra packages entirely.
- 11,946 mentions of "opencode" is misleading: 4,056 are internal
  `@opencode-ai/*` imports (do not touch); ~467 quoted strings across the
  three main packages are the real surface.
- `global.ts`'s `app` constant renames every XDG directory — that already
  factored into the no-migration call (Settled decision 13).
- Line numbers in `fork-scope.md` and `calypsocode-fork.md` were measured
  2026-07-24 against `sst/opencode@dev` — re-check before editing, upstream
  moves.
- Pre-release deps: `effect@4.0.0-beta.83`, `@opentui/*@0.4.5`,
  `drizzle-orm@1.0.0-rc.2` — expect breakage on upgrade, don't upgrade
  casually to fix something unrelated.
- `bun` pinned at `1.3.14`, already installed at `~/.bun/bin/bun`.
- `node-pty` is a native dependency with a `postinstall` fix step.
- The MIT notice must survive every refactor, rebase, repackage.
- F1 (the namespace can't reach host loopback) still applies to the header
  test — it must run in `CALYPSO_NETWORK=none` mode.
- Rebase burden against a fast-moving upstream is the real ongoing cost of
  this fork, not the rename itself.
