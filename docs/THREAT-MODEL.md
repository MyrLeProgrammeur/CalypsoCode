# Threat model

This document honestly states what `CalypsoCode` protects and what it does not.
A privacy tool that oversells its guarantees is worse than useless — read this
before treating anything here as "total" anonymity.

> **Current status.** `bin/calypsocode` does not run; the architecture it
> implements was disproven by testing
> ([FINDINGS.md](FINDINGS.md#f1--a-host-process-cannot-reach-a-port-bound-inside-oniux)).
> This document describes the properties the [redesign](DESIGN.md) targets.
> Nothing here is currently delivered by working code.

## What it actually protects

- **Your IP address from the provider (Venice, Tinfoil, ...)**: `oniux` isolates
  the process at the kernel level (Linux namespaces) and forces all outbound
  traffic through Tor. The provider only ever sees a Tor exit node, never your
  real IP or your ISP's. Verified: the namespace has exactly one route
  (`default dev onion0`), and egress reports `IsTor:true`.
- **What your ISP, employer, or state can see.** TLS hides content but SNI
  leaks the destination hostname, so a network observer otherwise learns that
  you use `api.venice.ai`. Tor removes that. In a jurisdiction where AI-tool
  usage is monitored or restricted, this is the primary benefit — arguably more
  useful than hiding your IP from a provider you authenticate to by name.
- **Accidental network leaks.** Unlike an `HTTPS_PROXY` export that programs
  can ignore, namespace isolation is fail-closed at the kernel routing level
  even if the wrapped program misbehaves. This is the strongest property in the
  stack.
- **Cross-project linkage (planned).** Compartments bind one key to one circuit
  to one context, so a breach of one compartment does not expose the others.
  See [DESIGN.md](DESIGN.md#what-identity-means-here).

## What it does NOT protect

- **Your account identity.** This project is self-hosted: every key is still
  YOUR key, on YOUR account. If that account is tied to your email or credit
  card (Tinfoil's default), the provider knows it is you, even if it never sees
  your IP. Content confidentiality (the provider cannot read your prompts,
  guaranteed by their TEE) and identity anonymity (the provider does not know
  who you are) are different guarantees — this project addresses only the
  second, and only at the network level.
- **The content of your prompts — and this is the biggest hole.** A coding
  agent transmits file paths, diffs, and stack traces on nearly every request:

  ```
  /home/<user>/dev/client-acme/src/billing.ts
  Author: <Real Name> <real.email@example.com>
  ```

  Your OS username, your git identity, and your clients' names walk out in the
  payload regardless of how the network layer is configured. Tor does nothing
  about this. Neither does a VPN, key rotation, or a TEE. Scrubbing is
  [planned](DESIGN.md#the-leak-that-actually-matters) and **not implemented** —
  until it is, assume the provider can identify you from prompt content alone.
- **Payment traceability.** Paying Venice in crypto is only anonymous if the
  purchase chain is too. A KYC purchase on an exchange followed by a direct
  transfer to a Venice wallet remains traceable through blockchain analysis,
  independent of the network layer.
- **A shared anonymity set.** Compartmentalization does not mix your traffic
  with other users' — only a multi-user pooled service would, and that is
  explicitly ruled out. Separating your own identities limits linkage between
  them; it does not create an anonymous crowd. Your anonymity set is still one.
- **Fraud-system reactions.** Providers may flag or suspend accounts whose API
  traffic arrives from Tor exits — a classic credential-theft signal. ToS
  permission and fraud heuristics are different things, and neither has been
  tested here ([FINDINGS.md](FINDINGS.md#f4--venice-and-tinfoil-do-not-block-tor-exits)).
- **An absolute TEE guarantee.** Tinfoil's hardware confidentiality rests on
  assumptions (Intel SGX, AMD SEV, ...) that have been broken before via
  side-channel attacks. Solid, not infallible. Attestation is verifiable and
  [should be verified](DESIGN.md#proof-not-claims) rather than trusted.
- **Traffic correlation by a global adversary.** Tor remains theoretically
  vulnerable to timing analysis by an entity observing both your entry point
  and the exit node — out of reach for a private actor, not necessarily for a
  state with broad access to network infrastructure.

## Beyond this, it's on you

- Do not reuse an already-known identity (work email, usual handle) to create
  the accounts behind a compartment's keys.
- If payment anonymity matters, source your crypto outside a direct
  KYC-exchange-to-wallet path.
- Keep compartments genuinely separate. Opening client A's repo inside client
  B's profile defeats the entire design — the content links them even when the
  key and circuit do not.
- Stay mindful of what you actually write in your prompts. Until scrubbing
  exists, this is the weakest link by a wide margin.
