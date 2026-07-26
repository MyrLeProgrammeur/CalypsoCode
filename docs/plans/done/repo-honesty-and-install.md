# Plan — Repo honesty pass, cleanup, and install

> Executed 2026-07-26, all 8 batches. Batch 1 merged as PR #5, Batch 2 as fork
> commit `d4cda2e`, Batches 3–8 as PR #6. Two deviations, both recorded in PR #6:
> `ROADMAP.md:33` keeps `opencode` because it describes the gate as it was run,
> before the fork existed; `publish.ts` was not renamed because it publishes
> upstream's AUR package from upstream's own releases.

> Executor: Sonnet or Opus + subagents. Apply the decisions, do not re-litigate
> them. Unresolved doubt → stop and ask.

## Goal & scope

Close out the UI-rebrand work and make the repo tell the truth about itself,
then make it installable.

Three things are wrong today and this plan fixes all three:

1. **Nothing is pushed.** The rebrand fork has 6 commits that exist only on one
   disk; this repo's `feat/calypsocode-ui-rebrand` branch has 1 commit and no
   remote; 5 doc files are uncommitted. A power failure loses two days of work.
2. **The tagline contradicts the product.** `README.md:19` claims *"Calypso
   erases who is asking"* while the receipt the tool prints on every session
   says *"the provider knows which paying customer this was"*. Two adversarial
   reviews flagged this. The repo is public.
3. **Nobody can install it.** There is no `calypsocode` on `PATH` (you must run
   `./bin/calypsocode` from the repo), no Install section in the README, and
   the agent is a `bun run` shim with `/home/matheo/dev/calypsocode-agent`
   hardcoded in it.

**In scope:** the `CalypsoCode` repo, plus two narrowly-scoped touches on the
`calypsocode-agent` fork (push the existing commits; rename the compiled
binary's output name).

**Out of scope:** Phase 2 of the UI rebrand (structural TUI changes surfacing
Calypso concepts — a separate plan, not yet written). Multi-platform
distribution of the agent binary. Any change to `config/litellm.config.example.yaml`
or to existing `docs/FINDINGS.md` F-entries — see Known pitfalls.

### Required reading before starting

- `CONTRIBUTING.md` — commit conventions, the PR checklist, and the rule that
  merges into `main` use a merge commit (batch commits are kept, not squashed).
- `docs/plans/calypsocode-ui-rebrand.md` — the plan this one closes out. All
  6 of its batches are done; it is archived by Batch 4 below.
- `docs/FINDINGS.md` F1 (namespace cannot reach host loopback), F4 (~1 dead
  circuit in 3), F11 (the User-Agent leak) — all three constrain how the
  verification steps below can be run.

## Settled decisions

1. **The tagline stays a one-line headline, but says what the tool does.** New
   text, verbatim: *"CalypsoCode hides your network identity from everyone
   except the provider you pay."* No two-beat antithesis, no em-dash slogan.
2. Scope of the tagline change: 7 files, ~8 lines. No document is restructured.
3. **Install = a documented symlink.** No `install.sh`, no `Makefile`. `doctor`
   already checks `oniux`, `calypsocode-agent` and the key; an installer would
   only duplicate it.
4. **The agent binary gets compiled for real.** `build.ts`'s outfile is renamed
   from `opencode` to `calypsocode-agent`; the `bun run` dev shim is retired.
5. **Done, for the compiled binary, means a real Tor session** against a real
   provider with a receipt — not a `none`-mode startup. Times recorded in
   `docs/FINDINGS.md` as F12.
6. **Executed plans are archived, not deleted**, to `docs/plans/done/`, each
   with a one-line status header. `docs/engine-recon.md` moves there too — it
   is a batch deliverable, not reference documentation.
7. **`docs/DESIGN.md` and `docs/ROADMAP.md` get resynchronised** to the shipped
   state. `docs/FINDINGS.md` does not — see Known pitfalls.
8. **`config/opencode.json.example` → `config/agent.json.example`.**
9. **Two PRs, not one.** PR 1 closes the rebrand; PR 2 is the honesty pass,
   cleanup and install. The tagline change is an editorial decision and is
   reviewed on its own rather than buried inside a rebrand diff.
10. **The fork's palette deviation is accepted as intentional.** Commit
    `8835df0` dropped blue `#4C8DFF`, contradicting settled decision 8 of the
    rebrand plan. Shipped state (violet `#8b4cff` ↔ pink `#ff2e97`, mix 0.62,
    period 2400ms) stands; the archived plan gets an amendment note. No code
    changes.
11. No `CONTEXT.md` or repo-level `CLAUDE.md` is written by this plan.

## Open questions

None.

## Batches

Batches 1 and 2 are sequential (2 depends on 1's merge). Batches 3–6 all run
on the branch created in Batch 3 and are ordered by dependency: 4 and 5 are
independent of each other; 6 depends on 5.

### Batch 1 — Stop losing work, and close out the rebrand (PR 1)

- **Files:** `README.md`, `docs/DESIGN.md`, `docs/FINDINGS.md` (all three
  modified but uncommitted), `docs/engine-recon.md` and
  `docs/plans/calypsocode-ui-rebrand.md` (both untracked). Plus the
  `calypsocode-agent` fork, push only.
- **Actions:**
  - In the fork (`/home/matheo/dev/calypsocode-agent`, branch `dev`, 6 commits
    ahead of `origin/dev`): `git push origin dev`. Do this **first** — it is
    the single highest-value action in this plan and depends on nothing.
  - In this repo, on the existing `feat/calypsocode-ui-rebrand` branch, commit
    the five files as four commits, in this order:
    - `docs(findings): record the User-Agent a generic provider receives` —
      `docs/FINDINGS.md` (the F11 entry and its "Still untested" item 5)
    - `docs(recon): what @opentui can actually do` — `docs/engine-recon.md`
    - `docs(design): cite the measured client fingerprint` —
      `docs/DESIGN.md` (the "Client & TLS fingerprint, in detail" paragraph)
    - `docs: state that the agent is a fork, and the plan it came from` —
      `README.md` ("The agent" section) and
      `docs/plans/calypsocode-ui-rebrand.md`
  - `git push -u origin feat/calypsocode-ui-rebrand`
  - Open the PR against `main`. Body: the 6 batches, what each shipped, and a
    pointer to F11 as the measured justification for Batch 5.
  - **Merge with a merge commit**, keeping the batch commits (`CONTRIBUTING.md`).
- **Constraints:**
  - Do **not** fix the tagline here. That is Batch 4, deliberately in the other
    PR (settled decision 9).
  - Do **not** move anything into `docs/plans/done/` here. That is Batch 4.
  - `main` is protected: no direct push, PR required, applies to admins.
  - `gh` returned 401 in a past session. If it does again, re-auth
    (`gh auth status`, then `gh auth login`) rather than working around it.
- **Verify:** `git status --short` is empty in both repos; `git status -sb`
  reports no "devant"/"ahead" in either; the PR shows green CI (shellcheck,
  tests, secret scan).
- **Done when:** `main` contains the rebrand, and nothing of the last two days
  exists only locally.

### Batch 2 — Compile a real agent binary

- **Files:** in the fork — `packages/opencode/script/build.ts` (line 178 as of
  2026-07-26, re-verify), and whichever `package.json` `bin` entry names the
  binary. In this repo — nothing yet.
- **Actions:**
  - `packages/opencode/script/build.ts`: `outfile: \`dist/${name}/bin/opencode\``
    → `outfile: \`dist/${name}/bin/calypsocode-agent\``. Check whether
    `build-node.ts` and `publish.ts` hardcode the same name; rename there too
    if so.
  - Build for this host only: `bun run script/build.ts --target linux-x64`
    (confirm the exact flag against the script's own arg parsing at ~line 116
    before running).
  - `./dist/*/bin/calypsocode-agent --about` → prints both licences.
  - Replace the dev shim: `rm ~/.local/bin/calypsocode-agent`, then symlink the
    compiled binary there instead.
  - Commit the rename in the fork and push.
- **Constraints:**
  - `bun` is pinned at `1.3.14` at `~/.bun/bin/bun`. Do not upgrade it.
  - `node-gyp` must be on `PATH` for a clean install (`~/.bun/bin/bun install -g
    node-gyp`) — see `docs/engine-recon.md`.
  - `bun build --compile` has never been run on this checkout. Native deps
    (`@lydell/node-pty`, `tree-sitter-*`) and `@opentui` are the likely failure
    points.
  - **If the compile cannot be made to work in reasonable time: stop, restore
    the dev shim, and report.** Do not let this batch block Batches 3–6 — they
    are independent of it, and the fallback (documenting the from-source shim
    in the README) is a known-good outcome. Say so explicitly rather than
    quietly shipping the shim as if it were the plan.
- **Verify:** `calypsocode-agent --about` works from a shell with no `bun` on
  `PATH` and from a cwd outside both repos.
- **Done when:** a self-contained binary exists and `~/.local/bin/calypsocode-agent`
  points at it rather than at a `bun run` wrapper — or the fallback above is
  reported.

### Batch 3 — Branch for the honesty pass

- **Files:** none (git only).
- **Actions:** `git checkout main && git pull` (must contain Batch 1's merge),
  then `git checkout -b chore/repo-honesty-and-install`.
- **Constraints:** do not start before Batch 1's PR is merged.
- **Verify:** `git log --oneline -5` shows the rebrand merge commit.
- **Done when:** the branch exists off an up-to-date `main`.

### Batch 4 — The tagline, and the archive

- **Files:**
  - Tagline: `README.md:19`, `docs/DESIGN.md:1`, `docs/DESIGN.md:3`,
    `docs/DESIGN.md:139`, `docs/THREAT-MODEL.md:7`, `docs/ROADMAP.md:92`,
    `CONTRIBUTING.md:118`, `bin/calypsocode:4`.
  - Archive: `docs/plans/v1-launcher.md`, `docs/plans/calypsocode-fork.md`,
    `docs/plans/fork-scope.md`, `docs/plans/calypsocode-ui-rebrand.md`,
    `docs/engine-recon.md`.
- **Actions:**
  - Replace the tagline wherever it appears with, verbatim:
    *"CalypsoCode hides your network identity from everyone except the provider
    you pay."* Adapt grammatically to each site (a heading, a blockquote and a
    shell comment cannot all take the same sentence shape) but do **not**
    reintroduce a two-beat slogan.
    - `docs/DESIGN.md:1` — the H1 `# Design — erasing who is asking` becomes
      `# Design`.
    - `docs/DESIGN.md:139` — this one is already accurate ("except the account
      you pay"); align its wording, don't invent a new claim.
    - `bin/calypsocode:4` — a comment, so plain prose: the sentence plus the
      existing "Nothing here inspects or modifies traffic" line that follows.
  - `mkdir -p docs/plans/done`, then `git mv` the five files listed above into
    it. Add one status line at the top of each:
    - `v1-launcher.md` — `> Executed. Merged into main via PR #1.`
    - `calypsocode-fork.md` — `> Executed, as part of calypsocode-ui-rebrand.md.`
    - `fork-scope.md` — `> Superseded by engine-recon.md (measured against the actual clone).`
    - `calypsocode-ui-rebrand.md` — `> Executed 2026-07-26, all 6 batches. Settled decision 8 amended: blue #4C8DFF was dropped from the palette in fork commit 8835df0; shipped palette is violet #8b4cff ↔ pink #ff2e97.`
    - `engine-recon.md` — `> Deliverable of calypsocode-ui-rebrand.md Batch 2.`
  - Fix inbound links to the moved files (`grep -rn "engine-recon\|plans/v1-launcher\|plans/calypsocode-fork\|plans/fork-scope\|plans/calypsocode-ui-rebrand" --include=*.md .`).
- **Constraints:**
  - Line numbers above were measured 2026-07-26 **before** Batch 1's commits.
    Batch 1 does not touch any of these lines, but re-verify with
    `grep -n "who is asking"` before editing rather than trusting them.
  - The new sentence must not contradict the receipt, which prints *"the
    provider knows which paying customer this was"* (`bin/calypsocode:524-527`).
  - Do not touch `docs/private/north-star.md` — it is local-only, excluded via
    `.git/info/exclude`, and not backed up.
- **Verify:** `grep -rn "erases who is asking" --include=*.md --include=calypsocode .`
  returns only hits under `docs/plans/done/` and `docs/private/`;
  `./test/run.sh` passes (it asserts on launcher output).
- **Done when:** no non-archived document makes a claim the tool's own receipt
  contradicts, and `docs/plans/` contains only active plans.

### Batch 5 — Resynchronise DESIGN and ROADMAP

- **Files:** `docs/DESIGN.md`, `docs/ROADMAP.md`, `CONTRIBUTING.md`,
  `config/opencode.json.example`.
- **Actions:**
  - `docs/DESIGN.md` — the "Client & TLS fingerprint, in detail" paragraph
    (added by Batch 1, ~line 70) is written in the future tense: *"the fork's
    Batch 5 ... removes or neutralises"*. It shipped. Rewrite in the past
    tense, cite fork commit `dbffbc7`, and state the measured post-fix
    User-Agent: `ai-sdk/openai-compatible/2.0.41 ai-sdk/provider-utils/4.0.23
    runtime/bun/1.3.14` — no product token. Decide whether the signal-table row
    moves from ⚠️ partial to ✅; the TLS/JA3 dimension is still untested, so
    ⚠️ with a narrower reason is the likely honest answer.
  - `docs/ROADMAP.md:25` — "What remains is step 5" predates the fork. State
    the real position: the launcher and the agent fork both ship; step 5 (other
    backends) is what remains.
  - `docs/ROADMAP.md:33` — "install `opencode`" → `calypsocode-agent`.
  - `docs/ROADMAP.md:111` and `CONTRIBUTING.md:127` — "Wrap or fork OpenCode"
    is a past decision that has now been acted on. Mark it as done rather than
    pending.
  - `git mv config/opencode.json.example config/agent.json.example`, and update
    `CONTRIBUTING.md:85` which hardcodes the old name.
- **Constraints:**
  - **Do not rewrite `docs/FINDINGS.md` F-entries.** They are dated records of
    what was measured at a point in time. F1–F11 stay exactly as they are, even
    where they describe behaviour that has since changed (e.g. `FINDINGS.md:158`
    describing a LiteLLM log path the launcher no longer writes). New facts get
    new F-entries; old ones are never edited into agreement with the present.
  - Do not touch `config/litellm.config.example.yaml`. LiteLLM is out of the
    default path but `docs/FINDINGS.md:81` references that file as a known
    casualty; deleting it would orphan the reference.
  - CI globs `config/*.json.example` (`.github/workflows/ci.yml:47`), so the
    rename needs no CI change — confirm, don't assume.
- **Verify:** `./test/run.sh` passes; CI's JSON step still finds and validates
  the renamed file; `grep -rn "opencode" --include=*.md . | grep -v plans/done`
  returns only deliberate attribution to upstream.
- **Done when:** DESIGN and ROADMAP describe the shipped system, and no
  document says a shipped thing is pending.

### Batch 6 — Install section

- **Files:** `README.md`.
- **Actions:**
  - Add an `## Install` section, placed after "The idea" and before "How it
    works". Content:
    - clone this repo, `ln -s "$PWD/bin/calypsocode" ~/.local/bin/calypsocode`
    - the agent: install `calypsocode-agent` (point at whatever Batch 2 actually
      produced — the compiled binary, or the from-source build if Batch 2 hit
      its fallback)
    - `cargo install --git https://gitlab.torproject.org/tpo/core/oniux`
    - `calypsocode doctor` as the check
    - a note that `~/.local/bin` must be on `PATH`
  - Verify by hand that the symlinked launcher works from a cwd outside the
    repo: `cd /tmp && calypsocode doctor`, then `cd /tmp && calypsocode profile
    --profile gate`.
- **Constraints:**
  - Write what Batch 2 actually delivered, not what it was supposed to. If the
    compile failed, the README documents the from-source path and says so
    plainly.
  - `bin/calypsocode` resolves everything from `$XDG_CONFIG_HOME` and uses no
    `$0`-relative paths (verified 2026-07-26 by reading the file) — so a symlink
    needs no code change. Confirm by running it, don't take this on faith.
- **Verify:** in a fresh shell, from `/tmp`: `calypsocode doctor` runs and
  reports on `oniux`, `calypsocode-agent` and the key.
- **Done when:** someone who has never seen the repo can get to a working
  `calypsocode doctor` by following the README alone.

### Batch 7 — The gate: a real session on the compiled binary

- **Files:** `docs/FINDINGS.md` (a new F12 entry, appended).
- **Actions:**
  - Export the real Venice key for the `gate` profile.
  - `calypsocode --profile gate` (invoked by name, from outside the repo — this
    exercises Batch 6's symlink at the same time). Full path: leak test, Tor
    egress verification, then a real coding task with several round trips.
  - Record in a new **F12**: the date, the agent binary (compiled vs shim), the
    Tor exit, round-trip count and timings, and whether the receipt was written
    correctly. Follow the shape of F8, which recorded the v1 gate.
- **Constraints:**
  - This costs real API usage. It is the point: settled decision 5.
  - Roughly 1 circuit in 3 was dead in testing (F4). A failed egress check is
    not a failure of this batch — re-run.
  - Append F12; do not edit F8 (Known pitfalls, and Batch 5's constraint).
- **Verify:** a receipt file exists under `~/.local/state/calypsocode/` with a
  Tor exit IP, `leak test passed`, and a non-zero session duration.
- **Done when:** the compiled agent has held a real session over Tor, and
  `docs/FINDINGS.md` records the numbers.

### Batch 8 — PR 2

- **Files:** none (git only).
- **Actions:** push `chore/repo-honesty-and-install`, open the PR against
  `main`, merge with a merge commit.
- **Constraints:** CI must be green before merge. `main` is protected.
- **Verify:** `main` contains every batch above; both repos are clean and
  pushed.
- **Done when:** `git status -sb` in both repos shows no local-only commits.

## Execution

- One subagent per batch; commit and `/clear` between batches.
- **Batch 1 first, and its `git push origin dev` step before anything else** —
  it is the only step that removes an existing risk of data loss.
- Batch 2 is independent of Batches 3–8 and may run in parallel with them, but
  Batch 6's README text and Batch 7's gate both depend on knowing its outcome.
- Batch 3 gates 4–8. Batches 4 and 5 are independent of each other.
- Batch 7 needs Batch 6 (it invokes `calypsocode` by name) and Batch 2's
  outcome.

Model tiers: mechanical work (Batch 1's commits, Batch 3, Batch 4's archive
moves, Batch 8) → `haiku`. Batch 2 (build debugging), Batch 5 (doc rewriting),
Batch 6 → `sonnet`. Batch 4's tagline rewrite and Batch 7's findings write-up
→ whoever is in main loop; the wording was decided above and must not be
re-invented by a subagent.

## Known pitfalls

- **`docs/FINDINGS.md` is append-only in spirit.** F-entries are dated
  measurements. Never edit one to match the present state — add a new entry.
  This is the single most likely way an executor damages this repo.
- The tagline appears in `bin/calypsocode:4`, not just in Markdown. A
  `--include=*.md` grep will miss it.
- `docs/private/north-star.md` is local-only via `.git/info/exclude`, this
  clone only, not backed up. It contains the phrase too. Leave it alone.
- `main` is protected: PR required, applies to admins, no direct push.
- CI pins shellcheck to `0.11.0` — the apt version behaves differently. Test
  against the pinned one.
- `gh` returned 401 in a past session; re-auth rather than routing around it.
- `bun` is pinned at `1.3.14`. `node-gyp` must be on `PATH` for a clean install
  in the fork.
- The fork tracks a fast-moving upstream. Every commit added to it raises the
  future rebase cost — Batch 2's rename is one line for that reason.
- Line numbers throughout were measured 2026-07-26. Re-verify with `grep -n`
  before editing.

---

✅ Plan written to `docs/plans/repo-honesty-and-install.md`.
Lowest-cost execution: **1.** `/clear` **2.** `/model sonnet or opus` **3.** "Execute `docs/plans/repo-honesty-and-install.md`, batch by batch."
