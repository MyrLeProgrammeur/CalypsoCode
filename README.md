# cloakcode

Un agent de codage type Claude Code (via [OpenCode](https://opencode.ai)), dont le
trafic vers l'IA passe par Tor et utilise des modèles non censurés
([Venice](https://venice.ai), [Tinfoil](https://tinfoil.sh)), avec rotation
automatique de clés API.

**Auto-hébergé.** Chacun installe et fait tourner sa propre instance, avec ses
propres clés API. Aucun compte partagé, aucun intermédiaire, aucune revente d'accès
— voir [pourquoi](#pourquoi-auto-hébergé) plus bas.

**Lis [docs/THREAT-MODEL.md](docs/THREAT-MODEL.md) avant de considérer quoi que ce
soit ici comme de l'anonymat "total".** Ce projet isole ton trafic réseau ; il ne
règle pas à lui seul l'identité de ton compte, ton moyen de paiement, ou le contenu
de tes prompts.

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

- **oniux** isole le proxy au niveau noyau (namespaces Linux) et force son trafic
  sortant à passer par Tor. Aucune fuite possible même si le proxy est mal configuré.
- **LiteLLM** fait tourner plusieurs de tes clés API dans un même pool — une clé
  différente à chaque requête, pour limiter la persistance d'un profil sur un seul
  compte.
- **OpenCode** ne parle qu'au proxy local, en loopback — c'est la seule pièce que
  tu utilises directement.

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
custom évolue vite).

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

## Licence

[AGPL-3.0](LICENSE).
