# Plan — CalypsoCode v1 launcher

> Executed. Merged into main via PR #1.

> Executor: Sonnet or Opus + subagents. Apply the decisions, do not re-litigate them. Unresolved doubt → stop and ask.

## Goal & scope

Build v1 of CalypsoCode: a launcher that runs OpenCode over Tor with
per-compartment identity, verifies the traffic really left via Tor, and prints a
receipt stating what was hidden and what was not.

**The thesis (do not re-open):** *Calypso erases who is asking, not what is
asked.* Content confidentiality is a property of the provider the user chooses.
Calypso never reads, rewrites, or scrubs prompts, code, or tool calls.

**In v1:** profile/compartment config, single-`oniux` launcher, identity
environment variables, egress verification, startup check, receipt.

**Explicitly NOT in v1:** LiteLLM, filesystem mounts or path remapping, any
content handling, key retirement, `vpn`/`direct`/`socks` backends.

### Required reading before starting

All three are already written and current. Read them; they contain the measured
facts and the reasoning behind every decision below.

- `docs/FINDINGS.md` — verified stack behaviour (F1–F6). **Non-negotiable
  constraints.**
- `docs/DESIGN.md` — the thesis, the who/what boundary, the signal table,
  profile schema, receipt format.
- `docs/ROADMAP.md` — build order, decisions taken, the gate test.

## Starting state

- Branch `main`, HEAD `f6d33b1`.
- **Six doc files have uncommitted modifications** (`README.md`,
  `CONTRIBUTING.md`, `docs/DESIGN.md`, `docs/ROADMAP.md`,
  `docs/THREAT-MODEL.md`, `config/litellm.config.example.yaml`). They are
  correct and current — commit them before or with Batch 1, do not revert.
- `bin/calypsocode` exists, is marked LEGACY in its header, and **does not
  work**. It is to be rewritten, not patched.
- Installed on the dev machine: `oniux`, `tor`, `python3`. **Not installed:**
  `litellm`, `opencode`, `shellcheck`, `yamllint`.

## Settled decisions

- Everything runs inside **one** `oniux` invocation — the host cannot reach into
  the namespace (F1).
- LiteLLM is removed from the default path; OpenCode talks to the provider
  directly.
- The host-side health-check loop is deleted (it is what F1 proved impossible).
- Identity is set by environment variables, never by rewriting traffic:
  `LC_ALL=C`, `TZ=UTC`, `GIT_AUTHOR_NAME/EMAIL`, `GIT_COMMITTER_NAME/EMAIL`,
  per-compartment `XDG_CONFIG_HOME`.
- Egress is verified from inside the namespace before the agent launches, with a
  `--no-verify` flag to skip (verification costs several seconds over Tor).
- One check at session start, then silence, then a receipt on exit.
- The receipt states what was **not** removed: account, prompt content, source
  code, writing style, session timing, OS username in paths.
- No mounts. The username-in-path leak is handled by user-side convention,
  documented in `docs/THREAT-MODEL.md#keep-your-username-out-of-your-paths`.
- The consultant / multi-client audience claim is **false** and must be removed:
  that user needs `git config user.email` and an env file, not namespace
  isolation.
- "Uncensored" is demoted from headline to capability — kept as an argument, not
  the main one.

## Open questions

**These block Batch 5 only. Batches 1–4 and 6 proceed regardless. Do not decide
either on the user's behalf — ask.**

1. **What does "log everything that went outside" mean?** Two answers with very
   different architectures:
   - *(a) Facts about the session* — exit IP, identity used, duration, request
     count. Cheap, needs no proxy, consistent with the settled design.
   - *(b) Actual request contents* — requires Calypso in the request path, which
     reintroduces the proxy that was deliberately removed.

   The plan below assumes **(a)**. If the answer is (b), stop: it is an
   architecture change, not a batch.

2. **Profile config file format.** The batches specify YAML at
   `~/.config/calypsocode/profiles/<name>.yaml` as an implementation choice. If
   the user prefers a flat `.env`-style file (simpler, no YAML parser needed in
   bash), that is a smaller dependency — worth confirming.

3. **Whether `CALYPSO_REQUIRE_VPN` stays as-is.** It currently exists and works
   (interface-pattern match). VPN-as-a-backend is out of v1 scope, but this
   pre-flight check may stay. Assume keep unless told otherwise.

## Batches (independent)

### Batch 1 — Doc corrections

- **Files:** `README.md`, `docs/DESIGN.md`
- **Actions:**
  - Remove the consultant / multi-client audience claim. In `README.md` it is
    the paragraph beginning "That serves more people than a Tor wrapper does";
    in `docs/DESIGN.md` it appears under the network-backends rationale. Replace
    with the audience that survives scrutiny: people whose **network is
    observed** while their account is not the threat — developers in censoring
    jurisdictions, people under employer/ISP monitoring, people in places where
    certain questions are dangerous.
  - Demote "uncensored" from headline framing to a capability mentioned
    alongside model choice. Lead with the network-observer threat instead.
- **Constraints:** Do not weaken `docs/THREAT-MODEL.md`; it is deliberately
  honest and its standard governs the other docs. Keep the existing voice —
  short sentences, no promotional padding.
- **Verify:** `grep -rn "consultant\|multiple clients" --include="*.md" .`
  returns nothing.
- **Done when:** No doc claims an audience that does not need namespace
  isolation, and no doc leads with "uncensored".

### Batch 2 — Profile config

- **Files:** new `config/profile.example.yaml`; new loader logic in
  `bin/calypsocode` (or a sourced helper).
- **Actions:** Define and load a compartment profile:

  ```yaml
  profile: client-acme
    network: tor            # v1 accepts only "tor" and "none"
    api_key_env: VENICE_API_KEY_ACME
    api_base: https://api.venice.ai/api/v1
    model: zai-org-glm-5-1
    git_name: dev
    git_email: dev@localhost
  ```

  Resolve from `~/.config/calypsocode/profiles/<name>.yaml`, selected by
  `--profile NAME` (default `default`).
- **Constraints:** Bash only, `set -euo pipefail`, no new runtime dependency
  without discussion (see `CONTRIBUTING.md`). If YAML parsing in bash is
  awkward, raise Open question 2 rather than adding a Python dependency.
- **Verify:** `python3 -c "import yaml; yaml.safe_load(open('config/profile.example.yaml'))"`
- **Done when:** A profile file is located, parsed, and its values are available
  as shell variables; a missing profile fails with a clear message naming the
  expected path.

### Batch 3 — Rewrite `bin/calypsocode`

- **Files:** `bin/calypsocode`
- **Actions:**
  - Delete the LiteLLM launch, the host-side `curl` health-check loop, and the
    LEGACY header block.
  - Structure as a single `oniux` invocation wrapping an inner script:

    ```
    oniux bash -c '<inner>' -- "$@"
    ```

    where `<inner>` sets the identity environment and then `exec opencode "$@"`.
  - Set inside the namespace: `LC_ALL=C`, `TZ=UTC`, `GIT_AUTHOR_NAME`,
    `GIT_AUTHOR_EMAIL`, `GIT_COMMITTER_NAME`, `GIT_COMMITTER_EMAIL`,
    `XDG_CONFIG_HOME=<compartment config dir>`, and the provider API key from
    the profile.
  - Keep `doctor`, but it must stop printing `everything is ready` on the basis
    of binaries existing. It should report what it actually checked.
  - Keep `CALYPSO_NETWORK=none` as an explicitly-warned escape hatch.
- **Constraints:**
  - **Never** add a check that reaches from the host into the namespace (F1).
  - No loopback hop exists in v1, so `ALL_PROXY` is not a problem — but if one
    is ever reintroduced, `NO_PROXY=127.0.0.1,localhost` is mandatory (F2).
  - Note the existing bug being removed: the current script sets
    `trap cleanup EXIT` and then calls `exec opencode`, which replaces the
    process — the trap never fires. Do not reproduce that pattern.
- **Verify:** `bash -n bin/calypsocode`, then `./bin/calypsocode doctor`
  (expect a non-zero exit while `opencode` is absent, with a clear message).
- **Done when:** `CALYPSO_NETWORK=none ./bin/calypsocode --profile default`
  reaches the point of trying to exec `opencode` and fails only because
  `opencode` is not installed.

### Batch 4 — Egress verification

- **Files:** `bin/calypsocode`
- **Actions:**
  - Inside the namespace, before `exec opencode`, confirm egress is Tor and
    capture the exit IP:
    `curl -s --max-time 60 https://check.torproject.org/api/ip`
    → expect `{"IsTor":true,"IP":"..."}`.
  - Abort with a clear error if `IsTor` is not true.
  - Retry on failure: roughly 1 in 3 circuits was dead in testing (see
    `docs/FINDINGS.md` F4). Retry a small number of times before giving up, and
    say which attempt failed.
  - Add `--no-verify` to skip the check; state in `--help` that skipping means
    the session is unverified.
- **Constraints:** Do not make this a fixed sleep loop. Tor is slow; give the
  check a real timeout and retry rather than a tight poll.
- **Verify:** `timeout 300 oniux --no-private-tmp bash -c 'curl -s --max-time 60 https://check.torproject.org/api/ip'`
  returns `IsTor:true` — this is exactly how F4 was measured and it works.
- **Done when:** The launcher refuses to start the agent when egress is not Tor,
  and records the exit IP when it is.

### Batch 5 — Startup check + receipt · **blocked on Open question 1**

- **Files:** `bin/calypsocode`
- **Actions (assuming answer (a) — session facts only):**
  - **Startup check, once, before launch:** report the git identity that will be
    used, whether the project path contains the OS username, and which account
    the profile will authenticate as. Proceed on confirmation, or immediately
    with `--yes`.
  - **Receipt on exit**, in the format already specified in
    `docs/DESIGN.md#the-receipt`. It must include the "NOT removed" block:
    prompt content, source code, writing style, session timing, OS username in
    paths, and the account name.
  - Write the receipt to `~/.local/state/calypsocode/`, **not** `/tmp` — oniux
    gives the child a private `/tmp` and anything written there is invisible
    from the host (F6).
- **Constraints:** No per-request warnings. One check at the boundary, then
  silence, then the receipt.
- **Verify:** First confirm the receipt path is actually visible from outside
  the namespace:
  `oniux bash -c 'echo test > ~/.local/state/calypsocode/probe'` then read it
  from the host. If `$HOME` turns out to be inside the private mount too, fall
  back to passing a host-side path in and writing through it, and record the
  finding in `docs/FINDINGS.md` as F7.
- **Done when:** A completed session leaves a readable receipt on the host
  stating both what was hidden and what was not.

### Batch 6 — The gate: one real session

- **Files:** none (measurement), then `docs/FINDINGS.md`
- **Actions:**
  - Install `opencode` (`curl -fsSL https://opencode.ai/install | bash`) and
    configure a Venice key.
  - Run one **real** coding session end-to-end through the launcher. Time the
    round trips and count failures.
  - Answer both open premise risks: (1) does authenticated
    `POST /chat/completions` survive over Tor — F4 only tested unauthenticated
    `/models`; (2) is an agentic session usable at Tor latency.
  - Record the result in `docs/FINDINGS.md` as a new finding, measured, with the
    same discipline as F1–F6: evidence or nothing.
- **Constraints:** This requires the user's API key and their decision to spend
  it. Do not fabricate or estimate numbers — if the session cannot be run,
  report that instead.
- **Verify:** The session completes a non-trivial task, and the timings are
  recorded.
- **Done when:** `docs/FINDINGS.md` contains a measured answer, and
  `docs/ROADMAP.md#gate` is updated to reflect whether Tor stays the default.

## Execution

- One subagent per batch; commit and `/clear` between batches.
- Batches 1–4 are independent of the open questions and can run immediately.
- Batch 5 must not start until Open question 1 is answered.
- Batch 6 requires `opencode` installed and a funded Venice key.

## Known pitfalls

- **F1 — the host cannot reach into the oniux namespace.** There is no
  `--publish`. Any design where a host process talks to a namespaced process
  over `127.0.0.1` is impossible. This killed v0.
- **F2 — oniux injects `ALL_PROXY=socks5h://localhost:9050`.** Proxy-aware
  clients will tunnel even loopback through Tor, where it is refused. Only
  relevant if a loopback hop is reintroduced; then `NO_PROXY` is mandatory.
- **F6 — oniux uses a private `/tmp`.** Files written to `/tmp` inside the
  namespace do not exist on the host. Never point a user at a `/tmp` path for
  logs.
- **`exec` destroys traps.** The old script's `trap cleanup EXIT` never ran
  because `exec opencode` replaced the process. Do not rely on EXIT traps after
  an `exec`.
- **Circuits die.** Roughly 1 in 3 in testing. Anything touching the network
  needs retry, not a single attempt.
- **Tor is slow.** Verification takes seconds; a full agentic session may be
  much worse. That is what Batch 6 measures.
- **`shellcheck` and `yamllint` are not installed on the dev machine.** Use
  `bash -n` and a `python3 -c "import yaml"` parse locally; CI
  (`.github/workflows/ci.yml`) runs the real linters on push. A green local
  check is not a green CI.
- **`doctor` currently lies.** It prints `everything is ready` when three
  binaries exist, while the tool cannot run. Any version that keeps asserting
  instead of verifying reproduces the original sin.
- **Do not widen the scope.** Content rewriting, mounts, and provider
  attestation were each considered and rejected with reasons recorded in
  `docs/ROADMAP.md#decisions-taken`. If a batch seems to need one of them,
  stop and ask.
