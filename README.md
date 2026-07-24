[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![CI](https://github.com/MyrLeProgrammeur/cloakcode/actions/workflows/ci.yml/badge.svg)](https://github.com/MyrLeProgrammeur/cloakcode/actions/workflows/ci.yml)

# cloakcode

OpenCode, isolé sous Tor, avec rotation de clés vers des modèles non censurés.

Niche assumée : devs vie privée/sécu qui veulent découpler leur agent de code de
leur identité réseau. Auto-hébergé, chacun avec ses propres clés — pas de compte
partagé, pas d'intermédiaire.

```bash
./bin/cloakcode doctor   # vérifie les dépendances, sans clé API ni réseau
./bin/cloakcode          # lance OpenCode derrière le tunnel
```

## Comment ça marche

[oniux](https://gitlab.torproject.org/tpo/core/oniux) (outil officiel du Tor
Project, namespaces Linux) isole un proxy LiteLLM dans son propre espace réseau et
force tout son trafic sortant à passer par Tor — étanche même si le proxy est mal
configuré, contrairement à un simple `HTTPS_PROXY` que certains programmes
ignorent. Ce proxy fait tourner plusieurs de tes clés API (Venice, Tinfoil) dans un
même pool : `routing_strategy: simple-shuffle` en tire une différente à chaque
requête, pour limiter la persistance d'un profil sur un seul compte. OpenCode ne
parle qu'à ce proxy, en loopback — c'est la seule pièce que tu utilises
directement.

```
OpenCode → 127.0.0.1 (LiteLLM, pool de clés) → oniux (Tor) → Venice / Tinfoil
```

Le circuit Tor se construit une fois au lancement de `cloakcode`, pas à chaque
message — le coût est au démarrage, pas dans la conversation.

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

Renseigne tes propres clés (Venice, Tinfoil) dans `litellm.config.yaml`. Le format
provider custom d'OpenCode change vite — vérifié contre
[opencode.ai/docs](https://opencode.ai/docs) au moment de l'écriture, à
recontrôler si `opencode.json.example` ne marche plus.

### Tor-over-VPN

Connecte ton VPN avant de lancer `cloakcode` — oniux route par-dessus la route par
défaut existante, aucun réglage supplémentaire à faire.

## Variables d'environnement

| Variable | Défaut | Effet |
|---|---|---|
| `CLOAKCODE_NETWORK` | `tor` | `tor` ou `none` (aucune isolation, déconseillé) |
| `CLOAKCODE_REQUIRE_VPN` | `0` | `1` = échoue si aucune interface VPN n'est active |
| `CLOAKCODE_PROXY_PORT` | `4000` | Port local du proxy LiteLLM |
| `CLOAKCODE_CONFIG_DIR` | `~/.config/cloakcode` | Dossier de config |
| `CLOAKCODE_LITELLM_CONFIG` | `$CLOAKCODE_CONFIG_DIR/litellm.config.yaml` | Config LiteLLM |
| `CLOAKCODE_LOG_FILE` | `/tmp/cloakcode-litellm.log` | Log du proxy |

## Limites

[docs/THREAT-MODEL.md](docs/THREAT-MODEL.md) — ce que ça cache (ton IP réseau) et
ce que ça ne cache pas (ton compte, ton paiement, le contenu de tes prompts). À
lire avant de faire confiance à l'outil pour autre chose que ce qu'il fait
réellement.

## Pourquoi pas un service hébergé

Un pool de clés mutualisé entre plusieurs utilisateurs anonymiserait mieux, mais
les CGU de Venice (responsable des "End Users" d'un produit tiers) et de Tinfoil
(pas de partage de clé/compte) rendent ça risqué. Auto-hébergé l'évite : chacun
reste client direct du provider, sous ses propres CGU.

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md) — pas de CLA. Idées en discussion mais pas
codées : fallback intelligent entre un modèle standard et un modèle uncensored sur
détection de refus, pool multi-provider au-delà de Venice/Tinfoil. Ouvre une issue
avant d'y toucher.

## Licence

[AGPL-3.0](LICENSE).
