# Threat model

This document states what `CalypsoCode` protects and what it does not. A
privacy tool that oversells its guarantees is worse than useless — read this
before treating anything here as "total" anonymity.

The scope in one line: **CalypsoCode hides your network identity from everyone
except the provider you pay.**
Content confidentiality is a property of the provider you choose, not of this
tool. See [DESIGN.md](DESIGN.md#the-boundary).

> **Current status.** `bin/calypsocode` runs. It was rewritten around the
> compartment model after testing disproved the original architecture
> ([F1](FINDINGS.md#f1--a-host-process-cannot-reach-a-port-bound-inside-oniux)),
> and a real coding session has since completed through it over Tor
> ([F8](FINDINGS.md#f8--a-real-agentic-session-works-over-tor-at-4s-per-round-trip)).
> What follows under "does NOT protect" is not a to-do list: those are limits of
> the design itself, and they stay true however much of the roadmap gets built.

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
- **Machine and account metadata.** Locale, timezone, git author identity, and your
  agent's global config are set or replaced per compartment before launch, so the
  identifying values are never produced. **Not the hostname** — this document listed
  it here until 2026-07-26 and the launcher has never set it
  ([why](DESIGN.md#every-signal-decided)).
- **Cross-project linkage.** Compartments bind one key to one circuit to one
  config, so a breach of one does not expose the others.

## What it does NOT protect

- **Your account identity — the main limit.** Every key is still YOUR key, on
  YOUR account. Tor hides your IP; the API key then announces your name on
  arrival. If the account is tied to your email or card, the provider knows it
  is you. Compartments limit what any one account accumulates; nothing here
  makes an account anonymous. That would require blind signatures and a service
  operator; the launcher is a local tool and is neither
  ([scope](DESIGN.md#scope-boundary)).
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
  with other users' — only a multi-user pooled service would, and the launcher
  is not one. Separating your own identities limits linkage between them. Your
  anonymity set is still one.
- **Fraud-system reactions.** Providers may flag accounts whose API traffic
  arrives from Tor exits — a classic credential-theft signal. ToS permission and
  fraud heuristics are different things, and neither is tested
  ([F4](FINDINGS.md#f4--venice-and-tinfoil-do-not-block-tor-exits)).
- **Traffic correlation by a global adversary.** Tor remains vulnerable to
  timing analysis by an entity observing both your entry point and the exit
  node — out of reach for a private actor, not necessarily for a state.

## <a name="reading-a-providers-privacy-claims"></a>Reading a provider's privacy claims

Two entries above end the same way: what the provider can read is the provider's
property, not Calypso's. That is not a dismissal — it is a choice you make when
you write `MODEL=` in a profile, and it is worth making deliberately. This
section is how to read the claim. It is not a recommendation, and Calypso
verifies none of it.

Providers advertise privacy **per model**, not per account. The same key can
reach a model that logs and a model that cannot be read at all. Four levels
recur, and the gap between the second and the third is the one that matters:

| Level | What it means | Promise or proof |
|---|---|---|
| Anonymized | The provider forwards your request to an upstream model host without passing your identity along. The provider still knows it is you. | promise |
| Private | The provider processes your prompt and does not retain it. Usually described as contract-enforced zero retention. | promise |
| TEE | The model runs inside a hardware enclave, and the enclave can produce attestation evidence — a signed statement of which code is running inside it. Provider staff cannot read the prompt. | **proof** |
| E2EE | Your client encrypts before sending; only the attested enclave holds the key. The provider carries ciphertext it cannot open. | **proof** |

**The first two are audit questions, the last two are cryptography.** A
zero-retention promise can be true, can be broken by a subpoena, and cannot be
checked from outside. Attestation can be checked. Calypso does not check it
([why](ROADMAP.md#decisions-taken)) — but the evidence exists and is yours to
verify, which is a different situation from having only a policy page.

Three things measured while choosing a model for the gate
([F12](FINDINGS.md#f12--the-compiled-calypsocode-agent-holds-a-real-session-over-tor)),
each of which will bite anyone doing the same:

- **A privacy level says nothing about whether an agent can use the model.** A
  coding agent needs tool use — the mechanism by which the model asks for a file
  to be written or a command run. Plenty of strongly-private models do not
  support it, and they fail on the first turn with a message about `tools`, not
  about privacy. Check both.
- **Strong privacy does not have to cost more.** Assuming it does is how you end
  up on an expensive model for no gain. Prices vary by more than an order of
  magnitude *within* the same privacy level.
- **Prompt caching is the real cost variable, and it is not universal.** Every
  turn resends the whole conversation, so on a long session the provider's cached
  input price dominates the bill. Some models offer no cached tier at all. A
  model with no cache can cost several times one with it, at the same privacy
  level and the same nominal input price.

**E2EE through an OpenAI-compatible client is not what it sounds like.** True
end-to-end means *your* side encrypts. A generic OpenAI-compatible agent sends
plaintext, and an E2EE-capable endpoint will still answer it — so what you
actually get is the enclave, not the sealed envelope. The stronger half needs a
client that encrypts, which this agent does not do.

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
- **Do not run two sessions of the same compartment at once.** They share one
  compartment directory and therefore one agent state tree, and the session counter
  in the receipt will lose one of the two. This is documented rather than locked
  deliberately: a lock file would fix the counter and not the shared state, at the
  cost of three new ways to fail. Different compartments in parallel are fine — that
  is what compartments are.
- Name your project folders with the knowledge that those names are
  transmitted. `client-acme` will be sent; that is your choice to make.
- Stay mindful of what you write in your prompts. Calypso does not touch them.
