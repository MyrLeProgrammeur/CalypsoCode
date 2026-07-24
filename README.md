[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![CI](https://github.com/MyrLeProgrammeur/cloakcode/actions/workflows/ci.yml/badge.svg)](https://github.com/MyrLeProgrammeur/cloakcode/actions/workflows/ci.yml)

# cloakcode

OpenCode, isolated under Tor, with key rotation to uncensored models.

Deliberately niche: privacy/security-minded devs who want to decouple their
coding agent usage from their network identity. Self-hosted, everyone with
their own keys — no shared account, no intermediary.

```bash
./bin/cloakcode doctor   # checks dependencies, no API key or network needed
./bin/cloakcode          # runs OpenCode behind the tunnel
```

## How it works

[oniux](https://gitlab.torproject.org/tpo/core/oniux) (official Tor Project
tool, Linux namespaces) isolates a LiteLLM proxy in its own network space and
forces all its outbound traffic through Tor — leak-proof even if the proxy is
misconfigured, unlike a simple `HTTPS_PROXY` that some programs ignore. This
proxy runs several of your API keys (Venice, Tinfoil) in the same pool:
`routing_strategy: simple-shuffle` picks a different one on each request,
limiting the profile persistence on a single account. OpenCode only talks to
this proxy, over loopback — it's the only piece you use directly.

```
OpenCode → 127.0.0.1 (LiteLLM, key pool) → oniux (Tor) → Venice / Tinfoil
```

The Tor circuit is built once at `cloakcode`'s startup, not on every message —
the cost is at launch, not in the conversation.

## Installation

```bash
cargo install --git https://gitlab.torproject.org/tpo/core/oniux oniux
pip install 'litellm[proxy]'
curl -fsSL https://opencode.ai/install | bash
```

## Configuration

```bash
mkdir -p ~/.config/cloakcode
cp config/litellm.config.example.yaml ~/.config/cloakcode/litellm.config.yaml
cp config/opencode.json.example ./opencode.json
```

Fill in your own keys (Venice, Tinfoil) in `litellm.config.yaml`. OpenCode's
custom provider format changes fast — verified against
[opencode.ai/docs](https://opencode.ai/docs) at the time of writing, worth
rechecking if `opencode.json.example` stops working.

### Tor-over-VPN

Connect your VPN before launching `cloakcode` — oniux routes on top of the
existing default route, no extra setup needed.

## Environment variables

| Variable | Default | Effect |
|---|---|---|
| `CLOAKCODE_NETWORK` | `tor` | `tor` or `none` (no isolation, not recommended) |
| `CLOAKCODE_REQUIRE_VPN` | `0` | `1` = fail if no VPN interface is active |
| `CLOAKCODE_PROXY_PORT` | `4000` | Local port of the LiteLLM proxy |
| `CLOAKCODE_CONFIG_DIR` | `~/.config/cloakcode` | Config directory |
| `CLOAKCODE_LITELLM_CONFIG` | `$CLOAKCODE_CONFIG_DIR/litellm.config.yaml` | LiteLLM config path |
| `CLOAKCODE_LOG_FILE` | `/tmp/cloakcode-litellm.log` | Proxy log file |

## Limits

[docs/THREAT-MODEL.md](docs/THREAT-MODEL.md) — what this hides (your network
IP) and what it doesn't (your account, your payment, the content of your
prompts). Read it before trusting this tool for anything beyond what it
actually does.

## Why not a hosted service

A key pool shared across multiple users would anonymize better, but Venice's
terms (responsible for a third-party product's "End Users") and Tinfoil's (no
key/account sharing) make that risky. Self-hosting avoids it entirely:
everyone stays a direct customer of the provider, under their own terms.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) — no CLA. Ideas under discussion but
not built: smart fallback between a standard and an uncensored model on
refusal detection, multi-provider pooling beyond Venice/Tinfoil. Open an
issue before touching either.

## License

[AGPL-3.0](LICENSE).
