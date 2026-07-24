# Modèle de menace

Ce document dit honnêtement ce que `cloakcode` protège et ce qu'il ne protège pas.
Un outil de vie privée qui survend ses garanties est pire qu'inutile — lis ceci avant
de considérer quoi que ce soit ici comme de l'anonymat "total".

## Ce que ça protège réellement

- **Ton adresse IP face au provider (Venice, Tinfoil, ...)** : `oniux` isole le proxy
  LiteLLM au niveau noyau (namespaces Linux) et force tout son trafic sortant à
  passer par Tor. Le provider ne voit qu'un nœud de sortie Tor, jamais ton IP réelle
  ni celle de ton FAI.
- **La persistance d'une clé unique dans le temps** : avec plusieurs clés dans le
  pool de rotation, aucune requête isolée n'est facilement rattachable à "toujours
  la même clé" — utile si une clé fuite ou si tu veux limiter le profil
  comportemental accumulé sur un seul compte.
- **Les fuites réseau accidentelles** : contrairement à un simple export de variable
  `HTTPS_PROXY` que certains programmes ignorent, l'isolation par namespace d'oniux
  est étanche même si le programme wrappé se comporte mal.

## Ce que ça NE protège PAS

- **L'identité de ton compte.** Ce projet est auto-hébergé : chaque clé du pool
  reste TA propre clé, sur TON propre compte. Si ce compte est lié à ton email ou
  ta carte bancaire (c'est le cas de Tinfoil par défaut), le provider sait que
  c'est toi qui utilises le service, même s'il ne voit pas ton IP. Confidentialité
  du contenu (le provider ne peut pas lire tes prompts, garanti par leur TEE) et
  anonymat de l'identité (le provider ne sait pas qui tu es) sont deux garanties
  différentes — ce projet ne fournit que la seconde, et seulement au niveau réseau.
- **La traçabilité du paiement.** Payer Venice en crypto n'est anonyme que si la
  chaîne d'achat l'est aussi. Un achat KYC sur un exchange puis un envoi direct au
  wallet Venice reste traçable par analyse blockchain, indépendamment du réseau.
- **Un ensemble d'anonymat partagé.** La rotation ne mélange PAS ton trafic avec
  celui d'autres utilisateurs (ça, seul un service mutualisé multi-utilisateurs le
  ferait — explicitement écarté pour ce projet, voir README). Rotation sur tes
  propres clés = moins de corrélation dans le temps, pas un groupe anonyme.
- **Le contenu de tes prompts.** Ton style d'écriture, des détails de projet
  identifiables, ou simplement ton nom mentionné dans une conversation restent le
  maillon le plus faible, quel que soit le soin apporté à la couche réseau.
- **Une garantie absolue côté TEE.** La confidentialité matérielle de Tinfoil
  repose sur des hypothèses de sécurité (Intel SGX, AMD SEV, ...) qui ont déjà été
  cassées par le passé via des attaques par canal auxiliaire. Solide, pas infaillible.
- **Une corrélation de trafic par un adversaire global.** Tor reste théoriquement
  vulnérable à une analyse de timing par une entité qui observerait à la fois ton
  point d'entrée et le nœud de sortie — hors de portée d'un acteur privé, pas d'un
  État disposant d'un accès large aux infrastructures réseau.

## Pour aller plus loin, à toi de gérer

- Ne réutilise pas une identité déjà connue (email pro, pseudo habituel) pour créer
  les comptes des clés du pool si tu veux limiter la corrélation.
- Si l'anonymat du paiement compte pour toi, source ta crypto en dehors d'un chemin
  direct exchange-KYC → wallet.
- Reste attentif au contenu de ce que tu écris dans tes prompts.
