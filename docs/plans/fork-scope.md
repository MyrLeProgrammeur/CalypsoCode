# Scope — forking OpenCode into CalypsoCode

> Measured against `sst/opencode` at `dev`, cloned 2026-07-24. Numbers are
> counted, not estimated. Nothing here is a recommendation to proceed; it is
> what proceeding costs.

## The short version

The **rename is cheap**. The **distribution is not**. Everything expensive in
this document is expensive because it is what being a distribution means, not
because OpenCode is hard to modify.

## Licence position

MIT. Modification and redistribution are permitted; the only obligation is that
the copyright and permission notice travel with copies. There is **no
UI-attribution requirement** — nothing forces the name "OpenCode" to stay on
screen.

MIT grants no trademark rights, which points the same way as the plan: brand the
fork as CalypsoCode, do not present it as OpenCode. Stating "fork of OpenCode"
on screen and in the README is more disclosure than the licence asks for.

MIT → AGPL-3.0 is one-way compatible, so the code can live in this repo. Keep
their `LICENSE` in the distribution and in an `--about`.

## What the codebase actually is

Not a TUI app — a monorepo of 30+ packages, 213 MB, including a desktop app, a
web app, a console, Slack integration, and cloud infrastructure (`sst.config.ts`).

The part a CLI + TUI distribution needs is a small fraction:

| Package | Size | Role |
|---|---|---|
| `packages/opencode` | 19 MB | CLI entry, session, provider wiring |
| `packages/core` | 3.7 MB | paths, config, models catalog |
| `packages/tui` | 1.8 MB | the terminal UI |
| `packages/cli` | 112 KB | preview CLI |

Toolchain: `bun@1.3.14`, already installed on this machine at the exact pinned
version. Native dependency on `node-pty` via a `postinstall` fix.

### Scale of the name, honestly

| Count | What |
|---|---|
| 11,946 | occurrences of "opencode" in `*.ts`/`*.tsx` |
| 4,056 | of those are `@opencode-ai/*` internal package imports |
| 467 | quoted strings in `tui` + `opencode` + `core` — the real surface |

The 4,056 imports are an internal namespace. Renaming them is pure churn and can
be skipped entirely — nobody sees them.

## Tier 1 — the visible rename (hours)

| File | Lines | What |
|---|---|---|
| `packages/tui/src/logo.ts` | 11 | The TUI logo. Stored as `left` / `right` halves — "open" and "code" — which maps exactly onto "Calypso" + "Code". Redrawing is the only real work; "CalypsoCode" is 11 glyphs vs 8, so the art gets wider. |
| `packages/opencode/src/cli/ui.ts` | 7–9 | A second copy of the logo for non-TUI output. |
| `packages/tui/src/util/presentation.ts` | — | Logo usage. |
| `packages/core/src/global.ts` | **10** | `const app = "opencode"` — **one line** that derives `data`, `cache`, `config`, `state` and `tmp` from XDG. Changing it moves the whole identity namespace to `calypsocode`. |
| `package.json` (several) | — | Binary and package names. |

That single line in `global.ts` is the most valuable finding here. It means
CalypsoCode gets its own config and state namespace for one character-level
change, and stops sharing directories with a user's existing OpenCode install —
which matters for compartments.

Add to this tier: the on-screen "fork of OpenCode" notice and an `--about`
carrying both licences.

## Tier 2 — de-branding what goes on the wire (about a day)

This is the tier that is **privacy work, not cosmetics**, and the reason the
fork may be justified beyond aesthetics.

**Identifying headers.** `packages/opencode/src/provider/provider.ts:461,472`
and six plugin providers (`openrouter`, `llmgateway`, `zenmux`, `vercel`,
`kilo`, `nvidia`) attach:

```
HTTP-Referer: https://opencode.ai/
X-Title:      opencode
X-Source:     opencode
```

These announce the client to the provider — the "Client & TLS fingerprint ⚠️
partial" row of the signal table, made concrete. They appear to be scoped to
**named providers only**, not to the generic `@ai-sdk/openai-compatible` path
that Venice uses.

> **Untested, and it decides this tier.** Point `API_BASE` at a local
> header-logging server, run in `CALYPSO_NETWORK=none` mode, and read exactly
> what OpenCode sends to a generic provider. Costs nothing. If Venice already
> receives no identifying header, Tier 2 is optional; if it does, Tier 2 is the
> whole reason to fork.

**Third-party catalog fetch.** `packages/core/src/models-dev.ts:154,170` fetches
`https://models.dev/api.json` at startup. Already overridable via the
`OPENCODE_MODELS_URL` flag, so this needs **configuration, not a patch** — but
it is a network call to a party that is not your provider, and it should be
named in the threat model either way.

**Upsell URLs.** `packages/opencode/src/session/retry.ts:11,109` point at
`opencode.ai/go`. Cosmetic.

**Clean:** no Sentry or telemetry in the `opencode`, `core`, or `tui` paths.

## Tier 3 — becoming a distribution (weeks, then forever)

This is the real cost, and it is ongoing rather than one-off.

- **Release pipeline.** Upstream publishes to npm, GitHub Releases, a Homebrew
  formula and an Arch `PKGBUILD`, across `linux-x64`, `darwin-arm64` and
  Windows (`script/publish.ts`). You inherit all of it, under your own npm scope
  and your own release infrastructure.
- **`bin/calypsocode` stops being a launcher.** It currently assumes
  `opencode.ai/install`. It would need to find your build instead. This is the
  point where CalypsoCode stops wrapping someone else's tool and starts being a
  distribution — which is the stated goal, but it is a different project with a
  different maintenance profile.
- **Dependency churn.** The pinned catalog leans on pre-release versions:
  `effect@4.0.0-beta.83`, `@opentui/*@0.4.5`, `drizzle-orm@1.0.0-rc.2`. Betas
  move fast and break.
- **Rebase burden.** Every upstream release is a merge against a codebase you
  did not write. The 467 branding strings are stable; the surrounding code is
  not.

## The honest trade

Tier 1 is a weekend and buys the thing that was actually asked for: the name on
screen, and a separate config namespace.

Tier 2 is a day and buys a real privacy improvement — *if* the header test says
it does.

Tier 3 is the AI-distro ambition, and its cost is not the code. It is owning a
release pipeline across three platforms, forever, against a fast-moving upstream.
That is precisely what a distribution is, so the cost is not a surprise — but it
should be chosen deliberately, not arrived at by having already done Tiers 1
and 2.

**Nothing here forces the tiers to be taken together.** Tier 1 alone is a
legitimate, licence-clean, honestly-attributed rebrand.

## Next concrete step

Run the header test described in Tier 2. It costs nothing, it is the only
unknown that changes the shape of this decision, and until it is answered the
fork's privacy justification is a guess.

---

Source clone kept at
`/tmp/claude-1000/-home-matheo-dev-cloakcode/…/scratchpad/opencode-src`
(213 MB, shallow). It is in a scratch directory and will not survive
indefinitely — re-clone with
`git clone --depth 1 https://github.com/sst/opencode.git` if it is gone.
