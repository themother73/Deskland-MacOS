# Deskscape — un fond d'écran adaptatif pour macOS

[English](README.md) · **Français** · [Version Windows (README d'origine)](README.windows.md)

Deskscape est une **adaptation macOS non officielle** de [Deskland Preview](https://github.com/BLEZZ0102/Deskland), un fond d'écran Windows qui transforme l'espace autour de vos icônes de bureau en paysage vivant. Déplacez, ajoutez ou supprimez une icône : la plage, la prairie, les nuages et leurs ombres se redessinent doucement autour d'elle, en temps réel. Sans compte, sans IA, sans connexion internet.

![Prairie](docs/images/meadow.webp)

![Plage](docs/images/beach.webp)

*Images issues de Deskland Preview d'origine.*

Ce projet **n'est ni affilié ni approuvé par les auteurs de Deskland**. Les illustrations et le code des thèmes sont les leurs (GPL-3.0) ; l'application hôte pour Mac est un travail nouveau. Voir [Crédits et licence](#crédits-et-licence).

Deux thèmes gratuits sont inclus : **Beach** (vagues turquoise, kayaks, oiseaux de mer, cocotiers) et **Meadow** (nuages et ombres qui dérivent, un garçon et son cerf-volant, un petit chat noir). Les autres thèmes de l'édition payante d'origine ne font pas partie du code ouvert et ne sont pas inclus.

---

## Installation (aucune connaissance technique requise)

**Il vous faut :** un Mac sous macOS 13 (Ventura) ou plus récent, Apple Silicon ou Intel.

1. **Téléchargez** `Deskscape-x.y.z.dmg` sur la [page des Releases](https://github.com/themother73/Deskland-MacOS/releases).
2. **Ouvrez** le `.dmg` et **glissez Deskscape sur le dossier Applications**.
3. **Lancez Deskscape** depuis Applications. La première fois, macOS peut indiquer qu'il ne peut pas vérifier l'app, car Deskscape n'est pas signée avec un certificat Apple Developer payant. C'est normal. Pour l'autoriser :
   - ouvrez **Réglages Système → Confidentialité et sécurité**, descendez et cliquez sur **Ouvrir quand même** à côté de Deskscape, puis confirmez ;
   - ou, sur d'anciennes versions de macOS : clic droit sur l'app, **Ouvrir**, puis **Ouvrir** à nouveau ;
   - ou, dans le Terminal : `xattr -dr com.apple.quarantine /Applications/Deskscape.app`
4. **Autorisez l'accès au Finder.** Deskscape demande la permission de contrôler le Finder. Cliquez sur **OK** : c'est ainsi qu'il connaît la position de vos icônes. Si vous avez cliqué sur « Ne pas autoriser » par erreur, activez-le dans **Réglages Système → Confidentialité et sécurité → Automatisation → Deskscape → Finder**.
5. Le paysage apparaît derrière vos icônes et une **icône de parasol** s'affiche dans la barre des menus. La fenêtre de réglages s'ouvre à chaque lancement manuel (pas quand l'app démarre avec la session).

**Le lancer avec le Mac :** icône de la barre des menus → *Lancer à l'ouverture de session*.

**Quitter :** icône de la barre des menus → *Quitter Deskscape*. Votre fond d'écran habituel revient.

**Désinstaller :** quittez Deskscape, puis glissez-le de Applications à la Corbeille. Vos réglages sont dans `~/Library/Application Support/Deskscape` et peuvent aussi être supprimés.

---

## L'icône de la barre des menus

| Élément | Ce qu'il fait |
|---|---|
| **Thème** | Passer de Beach à Meadow. |
| **Qualité du rendu** | *Native* est la plus nette. *Économique* dessine à moitié résolution sur les écrans Retina et consomme bien moins de GPU. |
| **Mettre l'animation en pause** | Fige l'animation (presque aucun CPU ni GPU utilisé en pause). |
| **Économie d'énergie** | Pause optionnelle sur batterie et/ou en mode économie d'énergie (activée par défaut). |
| **Consommation** | CPU, mémoire et GPU en direct. |
| **Réglages…** | Ouvre la fenêtre de réglages : chaque paramètre de chaque thème (distance du rivage, nuages, kayaks, chaton…) est enregistré automatiquement. Elle permet aussi de créer des images et vidéos à partager sans révéler vos données (vos vraies icônes et noms de fichiers sont remplacés par des exemples). |
| **Recharger / Afficher les icônes détectées** | Outils de dépannage, voir plus bas. |

Deskscape se met en pause tout seul quand le bureau est entièrement caché (app en plein écran, autre Space, écran en veille).

---

## Pour un résultat optimal

Deskscape lit la position de vos icônes dans le Finder. Sa précision dépend de la façon dont votre bureau est rangé :

- **Idéal :** clic droit sur le bureau → *Trier par → Aucun* (ou *Aligner sur la grille*). Deskscape obtient alors la position exacte de chaque icône.
- **Si votre bureau est trié** (par nom, type, date…), le Finder ne révèle pas les positions : Deskscape **simule la grille** dans laquelle le Finder range les icônes. Cela fonctionne bien dans la plupart des cas, mais peut être décalé de quelques pixels.
- Les **Piles** (*Présentation → Utiliser les piles*) ne sont pas gérées. Désactivez-les pour un résultat précis.

Si le paysage ne s'aligne pas avec vos icônes, utilisez l'icône de la barre des menus → **Afficher les icônes détectées** : des rectangles rouges montrent ce que Deskscape croit être l'emplacement de vos icônes. S'ils sont décalés, [ouvrez un ticket](https://github.com/themother73/Deskland-MacOS/issues) avec une capture d'écran, la taille de vos icônes (*Présentation → Afficher les options de présentation*) et votre version de macOS.

---

## Dépannage

| Problème | À essayer |
|---|---|
| Le paysage ne réagit pas à mes icônes | Vérifiez **Réglages Système → Confidentialité et sécurité → Automatisation → Deskscape → Finder**. Puis icône de la barre des menus → *Recharger*. |
| Rien ne s'affiche | Quittez et relancez Deskscape. Vérifiez que l'animation n'est pas en pause (icône de la barre des menus). |
| Le Mac chauffe / la batterie descend vite | Icône de la barre des menus → *Qualité du rendu → Économique*, et activez *Pause sur batterie*. |
| Un seul écran est couvert | Normal : seul l'écran principal est géré pour l'instant. |
| macOS refuse d'ouvrir l'app | Voir l'étape 3 de l'installation ci-dessus. |

---

## Compiler depuis les sources

Prérequis : macOS 13+, Xcode ou les Command Line Tools (Swift 5.9+).

```bash
git clone https://github.com/themother73/Deskland-MacOS.git
cd Deskland-MacOS/macos
./build.sh        # produit build/Deskscape.app (universel arm64 + x86_64)
./make-dmg.sh     # produit dist/Deskscape-<version>.dmg et sa somme SHA-256
```

Plus de détails pour les développeurs dans [macos/README.md](macos/README.md).

---

## Organisation du dépôt (macOS et Windows)

Ce dépôt est un **fork** de Deskland Preview. Le code Windows d'origine est conservé tel quel, volontairement : le portage macOS peut ainsi continuer à recevoir les mises à jour du projet d'origine, et partage exactement les mêmes thèmes.

| Dossier | Contenu |
|---|---|
| [`macos/`](macos/) | **L'application macOS** (Swift) : tout ce qui est nouveau dans ce fork. |
| `prototype/` | Thèmes, page de réglages et illustrations de Deskland, **communs aux deux plateformes et non modifiés**. La compilation macOS les copie et leur applique quelques adaptations venant de `macos/web-overlay/`. |
| `host/`, `tools/` | L'hôte **Windows** d'origine (C# / WebView2) et l'outillage d'installeur. Non utilisés par l'app Mac. |
| `docs/` | Images utilisées dans les README. |

**Vous êtes sous Windows ?** Utilisez Deskland Preview officiel : [dernière version](https://github.com/BLEZZ0102/Deskland/releases/latest). Le README d'origine est dans [README.windows.md](README.windows.md).

---

## Limites connues

- Écran principal uniquement.
- Beach et Meadow uniquement.
- Les piles ne sont pas gérées, et un bureau trié utilise une grille simulée (voir plus haut).
- Signature « ad hoc » seulement (pas d'Apple Developer ID, pas de notarisation) : macOS affiche un avertissement au premier lancement.
- Pas encore d'icône d'application propre.
- Les performances ont été mesurées sur un seul Mac Apple Silicon : environ 23 % d'un cœur CPU et 54 % de GPU (système entier) en qualité native, environ 22 % de GPU en qualité économique, et environ 1 % de CPU et 0 % de GPU en pause.

---

## Crédits et licence

- Projet d'origine, thèmes, illustrations et interface de réglages : **Deskland Preview** par les auteurs de Deskland, [github.com/BLEZZ0102/Deskland](https://github.com/BLEZZ0102/Deskland) (v0.1.3).
- Application hôte macOS et adaptations : ce fork.
- Licence : **GPL-3.0**, comme le projet d'origine. Voir [LICENSE](LICENSE), [NOTICE](NOTICE) et [macos/THIRD_PARTY_NOTICES.md](macos/THIRD_PARTY_NOTICES.md).
- Le nom et l'icône Deskland ne sont pas concédés comme marques ([TRADEMARKS.md](TRADEMARKS.md)). Ce portage porte donc son propre nom, *Deskscape*, et précise qu'il s'agit d'une adaptation indépendante.
