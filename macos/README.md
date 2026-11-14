# Deskscape — fond d'écran adaptatif pour macOS

Portage macOS non officiel de [Deskland Preview](https://github.com/BLEZZ0102/Deskland) (v0.1.3, commit `9818b57`).
Le paysage (plage, prairie, nuages, ombres) se redessine autour des icônes de votre bureau, en temps réel, sans compte ni IA.

*Unofficial macOS port of Deskland Preview. The landscape reshapes itself around your desktop icons in real time.*

Ce projet n'est ni affilié ni approuvé par les auteurs de Deskland. Le nom « Deskscape » est celui de ce portage (voir [TRADEMARKS.md](../TRADEMARKS.md)).

## Ce qui est repris, ce qui est nouveau

| | |
|---|---|
| `../prototype/` + `web-overlay/` | Thèmes Beach et Meadow, réglages, partage : repris de Deskland (`prototype/`, non modifié). `web-overlay/` ne contient que les 4 fichiers adaptés (`flat.html`, `meadow.html`, `settings.html`, `i18n/fr.json`) : boucle d'animation arrêtée en pause, paramètre `?q=1` (rendu économique), traduction française. `prepare-web.sh` les fusionne dans `web/` (généré, ignoré par git). |
| `Sources/Deskscape/` | Hôte macOS en Swift (AppKit + WebKit), remplace l'hôte Windows C# / WebView2. |

L'hôte macOS fait :

- une fenêtre plein écran au niveau « bureau », sous les icônes du Finder ;
- un pont qui recrée `window.chrome.webview` sur WKWebView (les pages web ne changent presque pas) ;
- la lecture des positions d'icônes via le Finder (AppleScript) ; si le bureau est trié, la grille est simulée ;
- un menu dans la barre des menus : thème, qualité de rendu, pause (manuelle, batterie, mode économie d'énergie), consommation en direct, réglages ;
- le démarrage à l'ouverture de session (`SMAppService`).

## Installer

Ouvrez `Deskscape-0.1.0.dmg`, glissez Deskscape dans Applications. L'app n'est **signée qu'en ad hoc** (pas de compte développeur Apple) : au premier lancement, faites clic droit → Ouvrir, ou :

```bash
xattr -dr com.apple.quarantine /Applications/Deskscape.app
```

Au premier lancement, macOS demande l'autorisation de contrôler le Finder (Réglages Système → Confidentialité et sécurité → Automatisation) : c'est ainsi que les positions des icônes sont lues.

## Compiler

Prérequis : macOS 13+, Xcode (ou les Command Line Tools) avec Swift 5.9+.

```bash
./build.sh        # → build/Deskscape.app (binaire universel arm64 + x86_64)
./make-dmg.sh     # → dist/Deskscape-<version>.dmg + somme SHA-256
```

Pour développer : `./prepare-web.sh && swift run Deskscape` (cherche le dossier `web/` généré).
`Deskscape --benchmark` mesure CPU / mémoire / GPU en animation puis en pause.

## Limites connues

- Écran principal uniquement.
- Bureau trié (« Trier par… ») : le Finder ne donne pas les positions réelles, la grille est simulée à partir de valeurs estimées (voir `IconReader.swift`, `pitchAdjust` / `margin`). Les piles ne sont pas gérées. Pour des positions exactes : « Trier par : Aucun » ou « Aligner sur la grille ».
- Le menu « Afficher les icônes détectées » dessine les rectangles lus, pour calibrer.
- Seuls Beach et Meadow sont inclus ; les autres thèmes de Deskland sont payants et absents du dépôt d'origine.
- Pas d'icône d'application ni de signature Apple Developer ID / notarisation.
- Mesures (M-series, rendu natif) : environ 23 % d'un cœur et 54 % de GPU système en animation, environ 1 % et 0 % en pause ; le mode économique ramène le GPU à environ 22 %.

## Licence

GPL-3.0, comme le projet d'origine : voir [LICENSE](../LICENSE), [NOTICE](../NOTICE) et [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Les images et le code des thèmes sont ceux de Deskland sous GPL-3.0.
