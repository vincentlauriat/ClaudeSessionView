# ARCHITECTURE

## Vue d'ensemble

`ClaudeSessionView` est un utilitaire macOS barre de menu (SwiftUI `MenuBarExtra`, pas d'icône Dock, `LSUIElement`) qui affiche l'usage réel du compte Anthropic par rapport à la fenêtre de session 5h et à la fenêtre hebdomadaire 7j. Il interroge directement l'endpoint officiel qu'utilisent Claude Code et Claude Desktop eux-mêmes — ce n'est **pas** une reconstruction locale (voir Historique ci-dessous pour les deux approches abandonnées).

## Flux de données

```
Keychain macOS ("Claude Code-credentials")
        │  (KeychainCredentials : /usr/bin/security find-generic-password)
        ▼
   OAuthCredentials (accessToken, expiresAt)
        │  (UsageAPIClient : GET https://api.anthropic.com/api/oauth/usage,
        │   Authorization: Bearer <token>, anthropic-beta: oauth-2025-04-20)
        ▼
   RateLimitUsage (fiveHour / sevenDay : percent, resetsAt)
        │  (UsageViewModel : refresh toutes les 5 min, backoff exponentiel sur 429)
        ▼
  Label MenuBarExtra (% compact) + UsagePopoverView (détail)
```

## Composants

| Fichier | Rôle |
|---|---|
| `ClaudeSessionViewApp.swift` | `@main`, scènes `MenuBarExtra` + `Settings`, label compact, injection locale/color-scheme |
| `Models/AppSettings.swift` | Réglages utilisateur observables persistés dans `UserDefaults` ; lancement au démarrage adossé à `SMAppService` |
| `Services/KeychainCredentials.swift` | Lecture du token OAuth stocké par Claude Code dans le Keychain macOS |
| `Services/UsageAPIClient.swift` | Appel HTTPS authentifié vers l'API réelle Anthropic + décodage JSON (`RateLimitUsage`, `RateLimitWindow`, `UsageFetchError`) |
| `ViewModels/UsageViewModel.swift` | État observable, timer de refresh (5 min), backoff exponentiel sur rate-limit (429) |
| `Views/UsagePopoverView.swift` | UI détail (Liquid Glass) : cartes en verre par fenêtre, % colorés par sévérité, countdowns de reset, message d'erreur, boutons réglages/quitter |
| `Views/SettingsView.swift` | Fenêtre d'options (`Form`) : affichage barre de menu, restant/consommé, lancement au démarrage, langue, thème |
| `Localizable.xcstrings` | String Catalog, source `en` + `fr` + `zh-Hans` |

## L'endpoint réel

`GET https://api.anthropic.com/api/oauth/usage`, authentifié avec le même token OAuth que Claude Code stocke dans le Keychain (service `"Claude Code-credentials"`, compte = nom d'utilisateur macOS ou fallback service-seul). Header requis : `anthropic-beta: oauth-2025-04-20`. Réponse pertinente :

```json
{
  "five_hour": { "utilization": 26.0, "resets_at": "2026-07-20T16:59:59.716759+00:00" },
  "seven_day": { "utilization": 34.0, "resets_at": "2026-07-24T17:59:59.716783+00:00" }
}
```

Point d'attention : `resets_at` a une précision sous-seconde variable (6 chiffres fractionnaires observés). Le parsing essaie d'abord `ISO8601DateFormatter` avec `.withFractionalSeconds` ; si ça échoue, un repli retire la partie fractionnaire par une regex ciblée sur `hh:mm:ss.xxxxxx` (pas un remplacement aveugle sur toute la chaîne) avant de reparser — la précision sous-seconde n'a de toute façon aucune utilité pour un countdown de reset.

Le champ `is_active` (par entrée du tableau `limits`) n'est volontairement **pas** utilisé pour masquer l'affichage : le % renvoyé par l'API est toujours affiché tel quel.

## Pourquoi cette bascule (historique)

- **v1** : somme brute de tokens (`input + output + cache_creation + cache_read`) reconstruite depuis les transcripts locaux `~/.claude/projects/**/*.jsonl`. Bug signalé par Vincent ("calculs inexactes") : chaque message relit l'intégralité du contexte caché, donc la somme comptait le même contenu des milliers de fois (jusqu'à 1,65 milliard de "tokens" sur 7 jours).
- **v2** : correctif par coût $ pondéré selon la vraie tarification Anthropic (cache read ×0.1, write 1h ×2, write 5m ×1.25), vérifié au centime près contre `claude --output-format json`. Toujours faux dans l'absolu : Vincent a signalé un écart de 86% (app) vs 24% (Claude Desktop) pour la même fenêtre — preuve qu'aucune reconstruction locale, même correctement pondérée, ne reflète la vraie comptabilité de rate-limit d'Anthropic (mécanisme interne non documenté, distinct d'un simple budget $).
- **v3 (actuelle)** : abandon total de la reconstruction locale au profit de l'appel direct à l'API réelle, celle que Claude Code et Claude Desktop utilisent en interne — vérifié en curl et en comparant les logs du binaire compilé : % cohérents avec Claude Desktop.

## Limites connues

- Dépend du token OAuth stocké par Claude Code dans le Keychain — si Claude Code n'a jamais été lancé sur cette machine, ou si le token a expiré sans qu'aucune commande `claude` récente ne l'ait rafraîchi, l'app affiche un message d'erreur explicite plutôt que de deviner une valeur.
- Pas de refresh OAuth automatique : dépend de Claude Code pour rafraîchir le Keychain lors d'un usage normal.
- Polling limité à toutes les 5 minutes avec backoff exponentiel sur 429, pour éviter de se faire rate-limiter par l'API elle-même.
- `KeychainCredentials.read()` reste basé sur le subprocess `/usr/bin/security` plutôt que l'API native `SecItemCopyMatching` : testé et abandonné (voir UX ci-dessous), le natif bloque indéfiniment depuis un binaire de dev non signé sur cet item Keychain précis.

## UX Liquid Glass (macOS 26+)

`UsagePopoverView` utilise le design Liquid Glass (WWDC 2025) : chaque fenêtre (5h, 7j) est une carte `.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))`, les deux regroupées dans un `GlassEffectContainer` — requis dès que plusieurs éléments de verre sont visuellement proches ("le verre ne peut pas échantillonner du verre", sinon rendu incohérent entre les cartes). Boutons en `.buttonStyle(.glassProminent)` (Rafraîchir) / `.buttonStyle(.glass)` (Quitter). Couleur de sévérité (vert < 50 %, orange 50-80 %, rouge > 80 %) sur le % et la barre de progression de chaque carte.

`glassBackgroundEffect` n'est volontairement pas utilisé pour le fond du panneau : sa documentation trouvée est orientée visionOS (plans, volumes, ornements), périmètre macOS ambigu. Le chrome système de `MenuBarExtra(.window)` applique déjà Liquid Glass automatiquement sur macOS 26+.

## Réglages, localisation & thème

La fenêtre d'options est une scène SwiftUI `Settings` standard (⌘, / ouverte depuis le popover via `@Environment(\.openSettings)`), donc elle fonctionne même si l'app est `LSUIElement` sans fenêtre principale. `AppSettings` est un objet `@Observable` injecté dans les deux scènes ; chaque réglage écrit dans `UserDefaults` dans son `didSet`. Cinq réglages :

| Réglage | Effet |
|---|---|
| Affichage barre de menu | `.fiveHour` / `.sevenDay` / `.iconOnly` — quel pourcentage (ou juste l'icône) le label affiche |
| Afficher le restant | Affiche `100 − consommé` au lieu du consommé, dans le label et le popover ; la couleur de sévérité reste indexée sur le *consommé* (rouge = danger) |
| Lancement au démarrage | `SMAppService.mainApp.register()` / `.unregister()` ; le toggle reflète `SMAppService.mainApp.status`, resynchronisé à l'apparition de la fenêtre |
| Langue | `.system` / français / anglais / chinois |
| Thème | `.system` / clair / sombre |

**La bascule à chaud de la langue et du thème** repose sur l'injection de `\.environment(\.locale, …)` et `.preferredColorScheme(…)` à la racine des deux scènes. SwiftUI résout `Text(LocalizedStringKey)` selon la locale de l'environnement et les localisations compilées du bundle : changer le picker met donc à jour l'UI sans relancer. À noter : `String(localized:locale:)` ne sélectionne **pas** une traduction via son argument `locale:` (ce paramètre ne sert qu'au formatage des interpolations) — donc toute string visible passe par `Text`, jamais par une `String` pré-formatée. Le label de la barre de menu est volontairement purement numérique (`"45%"`) et neutre linguistiquement. Les localisations supportées sont déclarées via `CFBundleLocalizations` (en/fr/zh-Hans) pour que l'override runtime les trouve toujours.

## Stack & distribution

- SwiftUI `MenuBarExtra` (**macOS 26.0+ uniquement**, relevé depuis 14.0 — obligatoire pour Liquid Glass, ces API n'existent pas avant ; décision assumée sans discussion, app perso mono-machine tournant déjà macOS 27). Pas de cible iOS.
- XcodeGen (`project.yml`) pour la génération du projet.
- Pas de App Sandbox : nécessaire pour shell-out vers `/usr/bin/security` et lire un item Keychain créé par une autre application (Claude Code). Distribution Developer ID prévue à terme, cohérent avec le reste du parc d'apps macOS de Vincent.
