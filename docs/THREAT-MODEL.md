# Threat model

This document states what `CalypsoCode` protects and what it does not. A
privacy tool that oversells its guarantees is worse than useless — read this
before treating anything here as "total" anonymity.

The scope in one line: **Calypso erases who is asking, not what is asked.**
Content confidentiality is a property of the provider you choose, not of this
tool. See [DESIGN.md](DESIGN.md#the-boundary).

> **Current status.** `bin/calypsocode` does not run; the architecture it
> implements was disproven by testing
> ([FINDINGS.md](FINDINGS.md#f1--a-host-process-cannot-reach-a-port-bound-inside-oniux)).
> This document describes what the [redesign](DESIGN.md) targets. Nothing here
> is currently delivered by working code.

## What it protects

- **Your IP address from the provider.** `oniux` isolates the process at the
  kernel level and forces all outbound traffic through Tor. Verified: the
  namespace has exactly one route (`default dev onion0`), and egress reports
  `IsTor:true`.
- **What your ISP, employer, or state can see.** TLS hides content, but SNI
  leaks the destination hostname — a network observer otherwise learns you use
  `api.venice.ai`. Tor removes that. Where AI tooling is monitored or
  restricted, this is the primary benefit.
- **Accidental network leaks.** Unlike an `HTTPS_PROXY` export that programs can
  ignore, namespace isolation is fail-closed at the kernel routing level even if
  the wrapped program misbehaves. This is the strongest property in the stack.
- **Machine and account metadata.** Locale, timezone, hostname, git author
  identity, and your agent's global config are set or replaced per compartment
  before launch, so the identifying values are never produced.
- **Cross-project linkage.** Compartments bind one key to one circuit to one
  config, so a breach of one does not expose the others.

## What it does NOT protect

- **Your account identity — the main limit.** Every key is still YOUR key, on
  YOUR account. Tor hides your IP; the API key then announces your name on
  arrival. If the account is tied to your email or card, the provider knows it
  is you. Compartments limit what any one account accumulates; nothing here
  makes an account anonymous. That would require blind signatures and a service
  operator, which is [out of scope](DESIGN.md#scope-boundary).
- **The content of your prompts and your code.** Calypso does not read,
  rewrite, or scrub what you send — deliberately
  ([why](DESIGN.md#why-this-boundary-and-not-a-wider-one)). If you need the
  provider to be unable to read your code, that is a provider choice: a hardware
  enclave (Tinfoil) gives a verifiable guarantee, a no-logging policy (Venice)
  gives a promise. Different things.
- **Your OS username, which appears in file paths.** A coding agent transmits
  absolute paths constantly:

  ```
  /home/<user>/dev/client-acme/src/billing.ts
  ```

  Calypso does not rewrite these — path remapping was considered and dropped
  ([scope boundary](DESIGN.md#scope-boundary)). This is handled by convention
  instead; see below.
- **Your writing style.** Authorship attribution works on a few thousand words:
  vocabulary, sentence structure, typo patterns, first-language interference.
  This is identity, it is inseparable from content, and it cannot be removed
  without a local paraphrasing layer that would degrade the agent.
- **Session timing.** When you work, how long, and in what rhythm. Reported in
  the receipt; not removed, because jitter would make an interactive session
  unusable.
- **Payment traceability.** Paying in crypto is only anonymous if the purchase
  chain is. A KYC exchange purchase followed by a direct transfer stays
  traceable through chain analysis, independent of the network layer.
- **A shared anonymity set.** Compartmentalization does not mix your traffic
  with other users' — only a multi-user pooled service would, and that is ruled
  out. Separating your own identities limits linkage between them. Your
  anonymity set is still one.
- **Fraud-system reactions.** Providers may flag accounts whose API traffic
  arrives from Tor exits — a classic credential-theft signal. ToS permission and
  fraud heuristics are different things, and neither is tested
  ([F4](FINDINGS.md#f4--venice-and-tinfoil-do-not-block-tor-exits)).
- **Traffic correlation by a global adversary.** Tor remains vulnerable to
  timing analysis by an entity observing both your entry point and the exit
  node — out of reach for a private actor, not necessarily for a state.

## Beyond this, it's on you

### Keep your username out of your paths

Calypso does not rewrite paths, so this one is yours. Cheapest first:

```bash
# 1. Projects outside home — no username in the path at all
sudo mkdir /srv/dev && sudo chown "$USER" /srv/dev

# 2. A neutral account — also separates ssh keys, git config, shell history
sudo useradd -m user && sudo su - user     # → /home/user/dev

# 3. Do nothing — the receipt will state that your username is in every path
```

**Prefer the documented convention (`/home/user/` or `/srv/dev/`) over a
neutral name of your own invention.** If every user picks something different —
`/home/dev`, `/home/coder`, `/home/user1` — each choice is mildly distinctive.
A shared default makes everyone look alike, which is the point.

### Everything else

- Do not reuse an already-known identity (work email, usual handle) for the
  accounts behind a compartment's keys.
- If payment anonymity matters, source funds outside a direct
  KYC-exchange-to-wallet path.
- Keep compartments genuinely separate. Opening client A's repo inside client
  B's profile defeats the design — the content links them even when the key and
  circuit do not.
- Name your project folders with the knowledge that those names are
  transmitted. `client-acme` will be sent; that is your choice to make.
- Stay mindful of what you write in your prompts. Calypso does not touch them.
