# Security

CalypsoCode isolates network identity for a coding agent. Its threat model is
stated in [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md) — read that first to
know what a report against this project can and cannot claim.

## Supported versions

There are no tagged releases. Only the latest `main` is supported; if you find
a vulnerability, check it still reproduces on current `main` before reporting.

## Reporting a vulnerability

**Do not open a public issue for a vulnerability that includes exploit
details.** Use GitHub's private vulnerability reporting instead:

- [Open a private advisory](https://github.com/MyrLeProgrammeur/CalypsoCode/security/advisories/new)
- or the repo's **Security** tab → **Report a vulnerability**

This requires the maintainer to have private vulnerability reporting enabled
on the repository. If it appears unavailable, open a regular issue asking for
a private contact — without exploit details — and one will be provided.

A public issue is fine for a vulnerability *class* discussed in the abstract
(e.g. "does the leak test cover X") with no working exploit attached. Anything
that would let a reader reproduce an attack against another user's compartment
goes through the private channel.

### What to include

- A minimal, redacted reproduction: the smallest profile/config and steps that
  show the issue.
- No production secrets, no real API keys, no real local usernames or paths.
  Use placeholder values (`client-acme`, `dev@localhost`, `/home/user/...`) the
  same way the rest of this project's docs do.
- Which guarantee in the threat model you believe is broken, and how.

## What happens next

1. **Acknowledgment.** Expect a response within a few days.
2. **Fix.** We work on a fix on `main`, coordinating with you on scope and
   timeline as needed.
3. **Disclosure timing.** We agree with you on when details become public —
   normally once a fix lands, not before.
4. **Advisory.** Once fixed, we publish a GitHub Security Advisory describing
   the issue and crediting the reporter, unless you prefer to stay anonymous.

## Scope

This covers `bin/calypsocode` (the launcher) in this repository. Issues in the
forked agent (`calypsocode-agent`) or in `oniux` belong to their own
repositories — see [README.md](README.md#the-agent) for the relationship
between the two.
