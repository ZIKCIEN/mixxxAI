## Objectif
PR de base : sections de LateNight QML en panneaux intégrés redimensionnables, dans la fenêtre principale existante (une fenêtre, un écran). Multi-écran et Quick Switch sont hors périmètre.

## Changements
- Nouveau composant `Controls/SectionPane.qml` : panneau intégré au `SplitView` principal, jamais plus petit que son contenu, agrandissable avec la poignée qui le suit. La hauteur choisie est conservée tant que l'application tourne, y compris quand le panneau est masqué puis réaffiché.
- FX, Samples et AUX deviennent des panneaux du `SplitView` (au lieu d'éléments positionnés à la main dans `deckPane`).
- La bibliothèque sort de `deckPane` : elle devient le panneau qui occupe l'espace restant.
- `deckPane` ne contient plus que les decks et le mixeur (hauteur fixe).
- La zone de contact des poignées passe de 12 à 20 px (tactile).
- La poignée qui suit `deckPane` est masquée, car elle ne peut rien déplacer.
- Décks, formes d'onde, mixeur, contrôles audio et nombre de decks/samplers : inchangés.

## Points d'attention pour la revue
- Les ressorts (`SpringAnimation`) qui animaient les racks sont remplacés par l'animation `LayoutAnimation` déjà utilisée pour les formes d'onde.
- Le mode « grande bibliothèque » : la bibliothèque n'est plus ancrée aux decks, elle suit la hauteur de `deckPane`.
- `Oscilloscope` : pas de composant distinct dans le skin, c'est `WaveformStack` (déjà redimensionnable).
- Un bloc commenté mort (`Skin.SamplerRow`) a été supprimé.

## Vérifications
- [ ] Mixxx compile et le skin se charge sans erreur QML
- [ ] Redimensionnement : formes d'onde, FX, Samples, AUX, sans chevauchement ni contrôle masqué
- [ ] Afficher/masquer chaque section, avec 2 et 4 decks
- [ ] Mode grande bibliothèque (avec et sans decks), puis retour
- [ ] Chargement de morceaux, lecture, commandes audio
- [ ] Souris, clavier, tactile, MIDI
- [ ] `latenightlayoutstate_test` passe (3 tests `SectionPane` ajoutés, non exécutés par l'auteur)
- [ ] Captures d'écran jointes
