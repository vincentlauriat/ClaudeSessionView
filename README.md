# ClaudeSessionView

App macOS menu bar affichant l'usage réel du compte Anthropic : % de la session en cours (5h) et de la semaine (7j), avec countdown de reset exact — la même donnée que Claude Desktop.

## Pourquoi

L'app interroge directement l'endpoint officiel `GET https://api.anthropic.com/api/oauth/usage`, authentifié avec le token OAuth que Claude Code stocke lui-même dans le Keychain macOS. C'est exactement ce que Claude Code et Claude Desktop utilisent en interne — pas une estimation ni une reconstruction locale.

## Ce que ça affiche

- **Barre de menu** : % réel de la session 5h en cours.
- **Popover (clic)**, design Liquid Glass (macOS 26+) :
  - Session (5h) et Semaine (7j) : deux cartes en verre, % réel coloré selon la sévérité (vert/orange/rouge), countdown + heure exacte de reset.
  - Message d'erreur explicite si les identifiants sont introuvables/expirés ou en cas de rate-limiting (dernières valeurs connues gardées affichées).
  - Bouton rafraîchir (glass), horodatage de dernière vérification.

## Limites (assumées, pas des bugs)

- **Dépend du Keychain Claude Code** : si Claude Code n'a jamais tourné sur cette machine, ou si le token OAuth a expiré, l'app affiche un message d'erreur explicite plutôt que de deviner un chiffre.
- **Pas de refresh OAuth automatique** — Claude Code rafraîchit lui-même le token dans le Keychain lors d'un usage normal.
- **Polling toutes les 5 minutes** (avec backoff exponentiel sur rate-limiting) pour ne pas se faire limiter par l'API.

## Build

```bash
xcodegen generate
xcodebuild -scheme ClaudeSessionView -configuration Debug CODE_SIGNING_ALLOWED=NO build
open build/Debug/ClaudeSessionView.app   # ou via Xcode directement
```

## Stack

SwiftUI `MenuBarExtra`, **macOS 26+** (Liquid Glass), XcodeGen. Voir [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Roadmap

- [ ] Icône d'app custom
- [ ] Option lancer au démarrage
- [ ] Script de release/DMG/notarization
