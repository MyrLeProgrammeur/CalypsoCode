# Threat model

This document honestly states what `cloakcode` protects and what it does not.
A privacy tool that oversells its guarantees is worse than useless — read this
before treating anything here as "total" anonymity.

## What it actually protects

- **Your IP address from the provider (Venice, Tinfoil, ...)**: `oniux` isolates
  the LiteLLM proxy at the kernel level (Linux namespaces) and forces all its
  outbound traffic through Tor. The provider only ever sees a Tor exit node,
  never your real IP or your ISP's.
- **The persistence of a single key over time**: with several keys in the
  rotation pool, no single request is easily tied back to "always the same
  key" — useful if a key leaks, or if you want to limit the behavioral
  profile that accumulates on one account.
- **Accidental network leaks**: unlike a simple `HTTPS_PROXY` export that some
  programs ignore, oniux's namespace isolation is leak-proof even if the
  wrapped program misbehaves.

## What it does NOT protect

- **Your account identity.** This project is self-hosted: every key in the
  pool is still YOUR key, on YOUR account. If that account is tied to your
  email or credit card (Tinfoil's default), the provider knows it's you using
  the service, even if it never sees your IP. Content confidentiality (the
  provider can't read your prompts, guaranteed by their TEE) and identity
  anonymity (the provider doesn't know who you are) are two different
  guarantees — this project only provides the second, and only at the
  network level.
- **Payment traceability.** Paying Venice in crypto is only anonymous if the
  purchase chain is too. A KYC purchase on an exchange followed by a direct
  transfer to a Venice wallet remains traceable through blockchain analysis,
  independent of the network layer.
- **A shared anonymity set.** Rotation does NOT mix your traffic with other
  users' (only a multi-user pooled service would do that — explicitly ruled
  out for this project, see README). Rotating across your own keys reduces
  correlation over time; it does not create an anonymous crowd.
- **The content of your prompts.** Your writing style, identifiable project
  details, or simply your name mentioned in a conversation remain the weakest
  link, no matter how careful the network layer is.
- **An absolute TEE guarantee.** Tinfoil's hardware confidentiality rests on
  security assumptions (Intel SGX, AMD SEV, ...) that have been broken before
  via side-channel attacks. Solid, not infallible.
- **Traffic correlation by a global adversary.** Tor remains theoretically
  vulnerable to timing analysis by an entity that observes both your entry
  point and the exit node — out of reach for a private actor, not necessarily
  for a state with broad access to network infrastructure.

## Beyond this, it's on you

- Don't reuse an already-known identity (work email, usual handle) to create
  the accounts behind the pool's keys if you want to limit correlation.
- If payment anonymity matters to you, source your crypto outside a direct
  KYC-exchange-to-wallet path.
- Stay mindful of what you actually write in your prompts.
