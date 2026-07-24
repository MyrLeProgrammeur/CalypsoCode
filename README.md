<!-- remplace OWNER par ton compte/organisation GitHub une fois le dépôt poussé -->
[![License: AGPL v3](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![CI](https://github.com/OWNER/cloakcode/actions/workflows/ci.yml/badge.svg)](https://github.com/OWNER/cloakcode/actions/workflows/ci.yml)

# cloakcode

**Ton IP ne quitte jamais ta machine. Le provider ne voit qu'un nœud de sortie Tor.**

Un agent de codage type Claude Code (via [OpenCode](https://opencode.ai)), dont le
trafic vers l'IA passe par Tor et utilise des modèles non censurés
([Venice](https://venice.ai), [Tinfoil](https://tinfoil.sh)), avec rotation
automatique de clés API.

Pas un produit grand public — un outil pour devs orientés vie privée/sécu qui
veulent découpler leur usage d'un agent de code de leur identité réseau. Si tu
cherches un outil simple d'accès pour le grand public, ce n'est pas celui-ci.

**Auto-hébergé.** Chacun installe et fait tourner sa propre instance, avec ses
propres clés API. Aucun compte partagé, aucun intermédiaire, aucune revente d'accès
— voir [pourquoi](#pourquoi-auto-hébergé) plus bas.

> [!IMPORTANT]
> **Lis [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md) avant de considérer quoi que
> ce soit ici comme de l'anonymat "total".** Ce projet isole ton trafic réseau ; il
> ne règle pas à lui seul l'identité de ton compte, ton moyen de paiement, ou le
> contenu de tes prompts. Un outil de vie privée qui survend ses garanties est pire
> qu'inutile.

## Architecture

```
                    ┌────────────────────────────────┐
                    │   oniux (isolation réseau)      │
                    │  ┌────────────────────────────┐│
                    │  │  proxy LiteLLM (pool clés)  ││──Tor──▶ Venice / Tinfoil
                    │  └────────────────────────────┘│
                    └────────────────▲───────────────┘
                                      │ loopback (127.0.0.1)
                              ┌───────┴───────┐
                              │    OpenCode    │
                              └────────────────┘
```

- **[oniux](https://gitlab.torproject.org/tpo/core/oniux)** (outil officiel du Tor
  Project) isole le proxy au niveau noyau (namespaces Linux) et force son trafic
  sortant à passer par Tor. Aucune fuite possible même si le proxy est mal configuré
  — contrairement à un simple `HTTPS_PROXY` que certains programmes ignorent.
- **[LiteLLM](https://docs.litellm.ai/docs/proxy/load_balancing)** fait tourner
  plusieurs de tes clés API dans un même pool (`routing_strategy: simple-shuffle`)
  — une clé différente à chaque requête, pour limiter la persistance d'un profil
  sur un seul compte.
- **[OpenCode](https://opencode.ai)** ne parle qu'au proxy local, en loopback —
  c'est la seule pièce que tu utilises directement, cloakcode ne remplace rien
  côté agent de codage.

## Quickstart

```bash
# 1. Dépendances
cargo install --git https://gitlab.torproject.org/tpo/core/oniux oniux
pip install 'litellm[proxy]'
curl -fsSL https://opencode.ai/install | bash

# 2. Config — renseigne tes propres clés API dans le fichier copié
mkdir -p ~/.config/cloakcode
cp config/litellm.config.example.yaml ~/.config/cloakcode/litellm.config.yaml
cp config/opencode.json.example ./opencode.json   # à la racine de ton projet

# 3. Vérifie que tout est en place (aucune clé requise pour cette étape)
./bin/cloakcode doctor

# 4. Lance
./bin/cloakcode
```

## Installation

```bash
# oniux (Rust, cf. https://gitlab.torproject.org/tpo/core/oniux)
cargo install --git https://gitlab.torproject.org/tpo/core/oniux oniux

# LiteLLM (proxy)
pip install 'litellm[proxy]'

# OpenCode
curl -fsSL https://opencode.ai/install | bash
```

## Configuration

```bash
mkdir -p ~/.config/cloakcode
cp config/litellm.config.example.yaml ~/.config/cloakcode/litellm.config.yaml
# renseigne tes propres clés API (Venice, Tinfoil...) dans ce fichier ou en variables d'env
```

Copie aussi `config/opencode.json.example` vers `opencode.json` à la racine de ton
projet (ou l'emplacement attendu par ta version d'OpenCode — vérifie la
[doc officielle](https://opencode.ai/docs) si ça a bougé, le format des providers
custom évolue vite ; structure vérifiée contre la doc `provider` d'OpenCode au
moment de l'écriture de ce README).

## Diagnostic

```bash
./bin/cloakcode doctor     # ou : ./bin/cloakcode --check
```

Vérifie la présence d'`oniux`, `litellm`, `opencode`, et l'existence du fichier de
config LiteLLM — sans avoir besoin de clés API ni de réseau. Un `✗` par élément
manquant, avec l'action pour le corriger. Sortie non nulle si quelque chose manque
— utile en script ou avant d'ouvrir une issue.

## Utilisation

```bash
./bin/cloakcode
```

Variables d'environnement utiles :

| Variable | Défaut | Effet |
|---|---|---|
| `CLOAKCODE_NETWORK` | `tor` | `tor` (isolation oniux) ou `none` (aucune isolation — déconseillé) |
| `CLOAKCODE_REQUIRE_VPN` | `0` | `1` = échoue si aucune interface VPN active n'est détectée |
| `CLOAKCODE_PROXY_PORT` | `4000` | Port local du proxy LiteLLM |
| `CLOAKCODE_CONFIG_DIR` | `~/.config/cloakcode` | Dossier de config cloakcode |
| `CLOAKCODE_LITELLM_CONFIG` | `$CLOAKCODE_CONFIG_DIR/litellm.config.yaml` | Chemin du fichier de config LiteLLM |
| `CLOAKCODE_LOG_FILE` | `/tmp/cloakcode-litellm.log` | Fichier de log du proxy LiteLLM |

### Tor-over-VPN

Aucun code spécifique n'est nécessaire : connecte ton VPN au niveau système avant de
lancer `cloakcode`. oniux route par-dessus la route par défaut existante, donc si ton
VPN est déjà actif, son trafic Tor passe naturellement à travers.

## Pourquoi auto-hébergé

Un service hébergé façon OpenRouter (pool de clés mutualisé entre plusieurs
utilisateurs) donnerait un vrai gain d'anonymat par mutualisation — mais Venice
impose que l'opérateur d'un produit tiers reste responsable des actions de ses
utilisateurs finaux, et Tinfoil interdit explicitement le partage de clés/comptes.
Combiné à une conception qui anonymise volontairement l'origine des requêtes, ces
deux contraintes sont difficiles à concilier. Le modèle auto-hébergé les évite
entièrement : chacun reste directement client du provider, sous ses propres CGU.

## Roadmap

Rien ci-dessous n'est implémenté — ce sont des pistes, pas des engagements.

- **Fallback/routing intelligent entre modèles** : basculer automatiquement d'un
  modèle "standard" vers un modèle "uncensored" sur détection de refus. Écarté
  pour l'instant volontairement — le pool actuel reste une rotation uniforme
  simple, sans logique de bascule. Pourrait avoir du sens plus tard, mais ajoute
  de la complexité et des questions de confiance (qui décide qu'une réponse est
  un refus ?) qui méritent leur propre discussion avant du code.
- **Pool mixte multi-providers dans une même session** : au-delà de Venice et
  Tinfoil, faire tourner d'autres providers compatibles OpenAI dans le même pool
  de rotation.
- Contributions et idées bienvenues sur ces sujets via une issue — voir
  [CONTRIBUTING.md](CONTRIBUTING.md).

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md). Pas de CLA, AGPL-3.0 simple.

## Licence

[AGPL-3.0](LICENSE).
