# Engine recon — Batch 2 of `calypsocode-ui-rebrand.md`

> Deliverable of calypsocode-ui-rebrand.md Batch 2.

Fork, build, and `@opentui` reconnaissance for the real CalypsoCode agent
fork. This is the deliverable for Batch 2 — Batch 3 (rebrand + animation)
should scope its effects against the findings below, not against
assumptions.

## Where the fork lives

- **GitHub:** https://github.com/MyrLeProgrammeur/calypsocode-agent
  (forked from `sst/opencode`, whose actual GitHub org is `anomalyco` —
  `gh repo view` reports the fork's parent as `anomalyco/opencode`; `sst/opencode`
  is the name used in prior planning docs and redirects/aliases to it).
  Default branch: `dev`.
- **Local clone:** `/home/matheo/dev/calypsocode-agent` — a sibling of this
  repo, **not** a subdirectory or submodule (Settled decision 12). It has
  its own `origin` (the fork) and `upstream` (`anomalyco/opencode`) remotes
  wired for future `git fetch upstream && git rebase`.
- Nothing in this repo (`CalypsoCode`) was touched except this file.

## Build commands (reproducible from a clean clone)

```bash
# 1. Fork (one-time, already done)
gh repo fork sst/opencode --fork-name calypsocode-agent --clone=false

# 2. Clone as a sibling directory
cd /home/matheo/dev
git clone https://github.com/MyrLeProgrammeur/calypsocode-agent.git calypsocode-agent
cd calypsocode-agent
git remote add upstream https://github.com/anomalyco/opencode.git

# 3. Install (bun pinned at 1.3.14, already at ~/.bun/bin/bun — do not upgrade)
~/.bun/bin/bun install
```

**The real blocker was not `node-pty`.** The repo's root `postinstall`
already runs `packages/core/script/fix-node-pty.ts`, which `chmod`s the
`spawn-helper` binaries inside a bundled `node-pty`'s prebuilds — but this
fork has since moved to `@lydell/node-pty` (platform-specific prebuilt
packages, e.g. `@lydell/node-pty-linux-x64`, no compile needed) plus a
Bun-native `bun-pty` for the default Bun runtime path. That fix script's
target path (`node_modules/node-pty/prebuilds`) doesn't even match the
current dependency name, and it exits cleanly with nothing to do — it is
effectively a no-op on this checkout today.

The actual failure on a clean `bun install` was a **native compile step for
`tree-sitter-powershell`**, which has no prebuilt binary for this
platform/arch and shells out to `node-gyp rebuild` in its own postinstall.
`node-gyp` was not on `PATH` (`spawn node-gyp ENOENT`), even though the
underlying toolchain (`python3`, `make`, `gcc`, `g++`) was present. Fix:

```bash
# 4. Put node-gyp on PATH (bun's global bin dir, ~/.bun/bin, is already on
#    PATH, so this makes `node-gyp` resolvable without touching the pinned
#    bun binary itself)
~/.bun/bin/bun install -g node-gyp

# 5. Re-run install clean
rm -rf node_modules packages/*/node_modules
git checkout -- bun.lock
~/.bun/bin/bun install
```

Result: `4716 packages installed` in ~55s, no errors. Verified the native
binding actually compiled:
`node_modules/.bun/tree-sitter-powershell@0.25.10/node_modules/tree-sitter-powershell/build/Release/tree_sitter_powershell_binding.node`.

```bash
# 6. Confirm the build runs
bun run --cwd packages/opencode --conditions=browser src/index.ts --version
# -> "local"
```

## TUI start — confirmed

`bun run dev` (`bun run --cwd packages/opencode --conditions=browser
src/index.ts`) was launched under a pseudo-tty (`script -qec ... /path/to/log`,
no `tmux` available) with a timeout, since a real TUI needs a tty for raw
mode. Captured output is genuine full-screen rendering: a block-letter
"OpenCode" ASCII logo, the prompt box ("Ask anything..."), the agent/model
selector line ("Build · Big Pickle · OpenCode Zen"), key hints (`tab
agents`, `ctrl+p commands`), the tip line ("Run /connect to add an AI
provider and start coding"), and the cwd/version footer. The raw escape
sequences captured include direct 24-bit SGR codes, e.g.
`\x1b[38;2;255;255;255m` / `\x1b[48;2;10;10;10m` — truecolor in active use
by the existing UI, not just available in principle.

## Standalone session against a fake OpenAI-compatible provider

Wiring the fork into `bin/calypsocode`'s namespace/profile machinery is
Batch 6, not this batch, so this was done standalone: a throwaway Python
HTTP stub (modeled on the method in `docs/FINDINGS.md`'s F11 header test)
answered `/v1/chat/completions`, and an `OPENCODE_CONFIG` JSON file (the
same shape `bin/calypsocode`'s `compartment_prepare()` generates —
`@ai-sdk/openai-compatible` provider, `baseURL` + `{env:...}` apiKey) pointed
a non-interactive `opencode run "hi" --model <provider>/placeholder-model`
at it.

Result: session created, model assigned (`build · placeholder-model`),
title-generation call and main-turn call both reached the stub with the
expected headers (`Authorization: Bearer dummy`, `User-Agent:
opencode/local ai-sdk/provider-utils/4.0.23 runtime/bun/1.3.14`, `x-session-id`),
both got `200`, and the process exited `0`. This proves the fork's build is
functional end-to-end (config loading, provider wiring, session lifecycle,
non-interactive `run` mode) against a generic OpenAI-compatible endpoint.
(A follow-up attempt at getting the stub to speak proper SSE streaming so
the reply text itself prints hung on stub protocol details, not on
anything the fork did — not worth chasing further for a build-verification
step.)

## `@opentui` reconnaissance (`@opentui/core@0.4.5`, from `node_modules/.bun/@opentui+core@0.4.5+*/node_modules/@opentui/core`)

### 24-bit / truecolor — real, in active use

- `lib/RGBA.d.ts` defines `RGBA` as a first-class color type with
  `fromHex`, `fromInts`, `fromValues(r,g,b,a)` constructors and a
  `ColorIntent = "rgb" | "indexed" | "default"` — the library explicitly
  models full RGB as distinct from indexed/256-color, not as an
  approximation of it.
- `buffer.d.ts`'s cell/text APIs (`setCell`, `setCellWithAlphaBlending`,
  `drawText`, `drawChar`, `fillRect`) all take `fg`/`bg` as `RGBA`, i.e.
  arbitrary per-cell 24-bit color, not a fixed palette.
- `ansi.d.ts` exposes `setRgbBackground: (r, g, b) => string`, emitting raw
  24-bit ANSI SGR sequences directly.
- Confirmed at runtime, not just in types: the captured TUI startup output
  (above) contains literal `\x1b[38;2;r;g;bm` / `\x1b[48;2;r;g;bm` truecolor
  escape codes.

### Animated redraws on a timer/frame loop — real, not input-driven only

- `renderer.d.ts`'s `CliRenderer` has `targetFps`/`maxFps`/`currentFps`,
  a private `startRenderLoop`/`loop`, `setFrameCallback(callback:
  (deltaTime: number) => Promise<void>)`, and a `requestLive()` /
  `dropLive()` / `liveRequestCount` pair — a request-counted mechanism to
  keep the render loop actively ticking even with no user input.
- `animation/Timeline.d.ts`'s `TimelineEngine.attach(renderer: CliRenderer)`
  runs its own `defaults.frameRate`-driven update loop against a renderer,
  independent of key/mouse events.
- Concrete, already-shipping example in this exact fork:
  `node_modules/.../opentui-spinner/dist/src-*.mjs`'s `SpinnerRenderable`
  (used by `packages/tui/src/ui/spinner.ts` — OpenCode's own spinner
  system) runs a `setInterval`-based scheduler (bounded to
  16.67ms–1000ms, i.e. up to 60fps) that calls `this.requestRender()` on
  every tick, purely on a timer, with no input involved.

### Gradient text — the substrate is real; no single named "gradient" API

- No dedicated `Gradient`/`gradient()` class or helper exists in
  `@opentui/core` itself — a repo-wide `grep -ri gradient` across the
  `@opentui/*` packages only turns up one docstring
  (`post/effects.d.ts`'s `CRTRollingBarEffect`, "a smooth horizontal bar
  ... with a bell-curve gradient" — a lighting effect, not text).
- But the substrate that makes gradient text possible is real and already
  exercised in this codebase: `drawChar(char, x, y, fg: RGBA, bg: RGBA)`
  takes an independent color per character, and OpenCode's own
  `packages/tui/src/ui/spinner.ts` builds a genuine multi-color animated
  gradient trail on top of it — `deriveTrailColors()` (alpha-falloff
  gradient derived from one base color), `deriveInactiveColor()`, and a
  `ColorGenerator` callback type,
  `(frameIndex, charIndex, totalFrames, totalChars) => RGBA`, consumed
  per-character by `SpinnerRenderable.renderSelf()`. Gradient text is
  achievable and precedented here, but as manual per-character RGBA
  computation, not a one-line built-in.
- Also present, for reference: `post/effects.d.ts`'s
  `RainbowTextEffect` — applies animated HSV-cycled rainbow coloring to
  existing white-foreground cells across the whole buffer, on a
  `deltaTime`-driven `apply()` call. Not "gradient text" in the
  two-color-blend sense, but the same category of per-cell color-cycling
  effect, and it is a full pre-built class, not something to write from
  scratch.

### Built-in easing/transition primitives — real, a full set

- `animation/Timeline.d.ts` exports `Timeline`, `createTimeline()`, and a
  module-level `engine: TimelineEngine` singleton. `Timeline.add(target,
  properties: AnimationOptions, startTime)` tweens arbitrary numeric
  properties over a `duration`, with `loop` (boolean or count),
  `loopDelay`, `alternate`, `once`, and `onStart`/`onUpdate`/`onLoop`/
  `onComplete` callbacks — an anime.js-shaped API.
- `EasingFunctions` is a closed set of 16 named functions actually
  implemented (not stubs): `linear`, `inQuad`, `outQuad`, `inOutQuad`,
  `inExpo`, `outExpo`, `inOutSine`, `outBounce`, `inBounce`, `outElastic`,
  `inCirc`, `outCirc`, `inOutCirc`, `inBack`, `outBack`, `inOutBack`.

## Summary table

| Capability | Real? | Evidence |
|---|---|---|
| 24-bit truecolor | Yes | `lib/RGBA.d.ts` (`ColorIntent: "rgb"`), `buffer.d.ts` per-cell `RGBA` params, `ansi.d.ts#setRgbBackground`, confirmed live in captured TUI output |
| Animated redraws off a timer/frame loop | Yes | `renderer.d.ts#CliRenderer` (`targetFps`, `setFrameCallback`, `requestLive`/`dropLive`), `animation/Timeline.d.ts#TimelineEngine.attach`, `opentui-spinner`'s `setInterval` scheduler already shipping in `packages/tui/src/ui/spinner.ts` |
| Gradient text | Partial | No named `Gradient` API in `@opentui/core`; per-character `RGBA` control (`drawChar`) plus the `ColorGenerator` callback shape is real and already used for a gradient trail effect in `packages/tui/src/ui/spinner.ts` |
| Built-in easing/transition primitives | Yes | `animation/Timeline.d.ts` — `Timeline`/`createTimeline`, 16 named easing functions, loop/alternate/callbacks |

Batch 3 should scope its animation set against this: full timeline/easing
support and a live render loop are there to use directly; a "gradient
text" effect means writing a `ColorGenerator`-shaped function (there is
already one in-tree to crib from), not calling a built-in.
