# Contribuer à cloakcode

Merci de l'intérêt. Ce projet est petit, de niche, et volontairement simple —
les contributions sont bienvenues mais gardons cet esprit.

## Pas de CLA

Aucun Contributor License Agreement n'est demandé. cloakcode est sous
[AGPL-3.0](LICENSE) et le restera ; il n'y a pas de double licence commerciale
prévue qui nécessiterait de récupérer les droits sur ta contribution. Ton code
reste sous AGPL-3.0, comme le reste du projet.

## Avant de proposer une PR

- **Bugs et petites corrections** : ouvre une PR directement, avec une
  description de ce qui était cassé.
- **Nouvelles fonctionnalités ou changements de comportement** : ouvre une
  issue d'abord pour en discuter. En particulier, tout ce qui touche à
  l'isolation réseau (`oniux`) ou au modèle de menace mérite une discussion
  avant du code — une régression silencieuse ici a des conséquences réelles
  pour les utilisateurs.
- **`docs/THREAT-MODEL.md`** : ce document doit rester honnête, pas
  promotionnel. Si ta contribution change ce que l'outil protège ou ne
  protège pas, mets ce fichier à jour dans la même PR.

## Vérifications locales avant de pousser

Il n'y a pas de suite de tests (le projet est un script bash + de la config,
pas une application). Avant de pousser :

```bash
# Syntaxe et bonnes pratiques du script principal
shellcheck bin/cloakcode

# Le script ne plante pas, même sans les dépendances installées
./bin/cloakcode doctor

# YAML/JSON des fichiers de config valides
yamllint config/*.yaml
python3 -m json.tool config/opencode.json.example > /dev/null
```

La CI (`.github/workflows/ci.yml`) refait ces mêmes vérifications sur chaque
PR.

## Style

- Bash : `set -euo pipefail`, pas de dépendance à des bashismes non portables
  au-delà de ce qui est déjà utilisé dans `bin/cloakcode`.
- Commentaires et messages utilisateur du script en français (cohérence avec
  l'existant) ; documentation (README, ce fichier) en français également.
- Pas d'ajout de dépendance runtime sans discussion préalable — l'idée est de
  rester un wrapper fin autour d'oniux, LiteLLM et OpenCode, pas de devenir un
  gros projet à maintenir.

## Périmètre

Ce qui est explicitement **hors scope** pour l'instant (voir
[Roadmap](README.md#roadmap) dans le README) : tout service hébergé/mutualisé
entre plusieurs utilisateurs, et toute logique de fallback/routing
intelligent entre modèles. Les PRs dans ces directions seront probablement
refusées ou redirigées vers une discussion de fond — pas parce que l'idée est
mauvaise, mais parce que ce ne sont pas des décisions à prendre au fil d'une
PR de code.
