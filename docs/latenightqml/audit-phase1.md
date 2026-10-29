# LateNight QML — audit pour la phase 1 (panneaux intégrés redimensionnables)

Périmètre (voir la synthèse de décisions) : une seule fenêtre native, un seul
écran, un seul moteur audio ; pas de fenêtre secondaire, pas de Quick Switch.
Cet audit est une lecture de `res/skins/LateNightQML` à `ee17a272`. Rien n'a
été modifié, compilé ou testé dans ce commit.

## Structure actuelle de `MainWindow.qml` (973 lignes)

- `Toolbar` en haut (hauteur fixe), puis un `SplitView` vertical (`splitView`)
  qui occupe le reste de la fenêtre.
- Le `SplitView` ne contient que **deux volets** :
  1. `WaveformStack` (formes d'onde) — déjà redimensionnable par poignée
     (`SplitView.minimumHeight`, `preferredHeight`, mémorisation de
     `lastVisiblePreferredHeight`).
  2. `deckPane` (un `Rectangle`) — contient **tout le reste** en positionnement
     manuel (`y`, `anchors`) : decks 1 à 4, mixeur, `effectsSection`,
     `samplersSection`, `micAuxSection` et le `Loader` de la bibliothèque
     (`library`, ancré sous `micAuxSection`).
- La hauteur minimale de `deckPane` est `requiredPaneHeight` = decks + FX +
  samplers + micro/aux. Quand la bibliothèque est active, `deckPane` remplit
  la hauteur restante ; sinon sa hauteur maximale est ce minimum.

## Constat

| Section | Aujourd'hui | Redimensionnable ? |
|---|---|---|
| Formes d'onde | volet de `splitView` | Oui (poignée) |
| Decks 1/2, 3/4 | enfants de `deckPane`, hauteur calculée (`deckRowHeight`) | Non |
| Mixeur | enfant de `deckPane` | Non |
| FX | `Item` `effectsSection`, hauteur = `effectsRack.implicitHeight` ou 0 | Non (afficher/masquer) |
| Samples | `Item` `samplersSection`, idem | Non (afficher/masquer) |
| AUX / Micro | `Item` `micAuxSection`, idem | Non (afficher/masquer) |
| Bibliothèque | `Loader` ancré en bas de `deckPane`, prend l'espace restant | Indirectement |
| Oscilloscope | à confirmer (voir « Questions ouvertes ») | — |

Conséquence : seule la frontière formes d'onde / reste est ajustable à la
souris. FX, Samples et AUX ne sont pas des volets.

## Contraintes à préserver

- Animations de layout (`LayoutAnimation`, `bigLibraryTransition`,
  `deckModeTransition`) : les hauteurs sont pilotées par des valeurs animées ;
  un volet déplaçable ne doit pas se battre avec elles (cf. le garde
  `splitterResizing` déjà utilisé pour les formes d'onde).
- `LayoutState.qml` (21 lignes) calcule `effectiveDeckSize` (Mini/Compact/Full)
  et `showCompactVuMeters` ; il a un test unitaire
  (`src/test/latenightlayoutstate_test.cpp`).
- Tests existants qui chargent le skin :
  `src/test/qml/qmlstartupsmoketest.cpp`, `src/test/themeqml_test.cpp`,
  `src/test/latenightlayoutstate_test.cpp`. Ils doivent rester verts.
- Nombre de decks inchangé (2 ou 4), liaisons de contrôle et MIDI inchangés.
- Le skin déclare des `ControlProxy` `[Skin]` dans `MainWindow.qml` ; tout état
  de panneaux persistant devra passer par ce mécanisme ou un autre déjà
  présent, à confirmer avant de choisir.

## Proposition de section pilote

**Bibliothèque** : elle a déjà un comportement de « remplit l'espace restant »
et un seul `Loader`. L'extraire du positionnement manuel de `deckPane` pour en
faire un **troisième volet** du `SplitView` valide l'approche avec un
risque limité, et correspond à la décision du document (bibliothèque en panneau
intégré, destinée à la fenêtre 2 plus tard). FX/Samples/AUX viendraient
ensuite, un par un.

Risque principal : la hauteur de `deckPane` est aujourd'hui calculée à partir
des sections qu'il contient ; la déplacer hors de `deckPane` change qui
détermine `requiredPaneHeight` et peut casser les animations de bascule
« grande bibliothèque ».

## Questions ouvertes

1. L'« oscilloscope » du document correspond-il aux formes d'onde
   (`WaveformStack`) ou à un autre composant ? Je n'ai pas trouvé de composant
   de ce nom.
2. Faut-il mémoriser les hauteurs de volets d'une session à l'autre ? Si oui,
   où (réglages Mixxx ou contrôles `[Skin]`) ?
3. Écran tactile : taille cible des poignées et des boutons (actuellement
   poignée de 9 px de haut, zone de saisie de 12 px).
