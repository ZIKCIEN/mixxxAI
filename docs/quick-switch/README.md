# Quick Switch multi-écrans — intégration expérimentale pour Mixxx

Cette archive contient une première intégration dans le QML de `mixxx-main.zip` fourni pour cette conversation.

## Ce qui est ajouté

- **Écran 1** : la fenêtre Mixxx existante (platines/mixeur).
- **Écran 2** : une fenêtre détachable contenant la bibliothèque Mixxx.
- **Écran 3** : une fenêtre détachable avec 4 unités d'effets et 2 entrées auxiliaires.
- **Quick Switch** : permutation des géométries des fenêtres 1↔2, 2↔3, 1↔3, rotation et annulation.
- **Disposition persistante** : les positions et dimensions sont mémorisées via `Qt.labs.settings`.
- **Récupération** : le bouton `Récupérer` replace les fenêtres secondaires près de la fenêtre principale si un écran a été débranché.
- Les fenêtres partagent le même moteur Mixxx : aucune seconde instance du moteur audio n'est créée.

## Installation dans les sources

1. Fermer Mixxx.
2. Faire une copie de sauvegarde de `res/qml/MainWindow.qml`.
3. Extraire cette archive **à la racine du dépôt Mixxx** (le dossier `res/qml/` de l'archive doit écraser/compléter le `res/qml/` du dépôt).
4. Recompiler Mixxx avec le support QML activé (`QML=ON` selon la configuration de compilation utilisée).
5. Lancer Mixxx avec la skin QML utilisée par ce dépôt.

Le fichier `quick-switch.patch` est également fourni pour revue ou application manuelle.

## Première utilisation

1. Passer la fenêtre principale en mode fenêtré si elle démarre en plein écran.
2. Cliquer sur `Bibliothèque B` et `Effets C`.
3. Déplacer chaque fenêtre sur le moniteur voulu et ajuster sa taille.
4. Utiliser `1↔2`, `2↔3`, `1↔3` ou `Rotation`.
5. Utiliser `Annuler` pour revenir à la disposition précédente, ou `Récupérer` si une fenêtre se retrouve hors écran.

Les commandes de permutation passent les fenêtres visibles en mode fenêtré, car la géométrie d'une fenêtre plein écran/maximisée ne peut pas être échangée de façon fiable.

## Limites connues de cette première version

- **Ce n'est pas encore une intégration testée en compilation** : l'environnement de travail ne contient pas les outils Qt/QML nécessaires pour compiler ou exécuter Mixxx.
- Les permutations échangent les positions et dimensions des fenêtres. Elles ne choisissent pas un `QScreen` par identifiant natif ; il faut d'abord placer manuellement les fenêtres sur les moniteurs voulus.
- La récupération est automatique au démarrage et lors d'un changement d'écrans (délai de 750 ms) : si une fenêtre secondaire n'est plus atteignable, elle est replacée près de la fenêtre principale. Le bouton `Récupérer` reste disponible en manuel. Cette détection n'a pas été testée sur matériel.
- `Qt.labs.settings` est conservé volontairement : le QML du dépôt vise Qt 6.4+, alors que `Settings` de `QtCore` demande Qt 6.5.
- Les effets/auxiliaires sont instanciés dans la troisième fenêtre ; les routages microphone/son avancés ne sont pas encore exposés ici.
- Les dimensions minimales des fenêtres peuvent limiter l'exactitude d'un échange si l'utilisateur redimensionne une fenêtre sous les minima des autres.
- Le QML du dépôt peut évoluer ; cette modification est basée sur les fichiers de l'archive fournie.

## Plan de test rapide

- [ ] Lancer la skin QML et vérifier l'absence d'erreur de chargement QML.
- [ ] Ouvrir puis masquer la bibliothèque B : elle ne doit pas être affichée simultanément dans la fenêtre principale.
- [ ] Ouvrir/fermer la fenêtre Effets C.
- [ ] Placer les trois fenêtres sur trois écrans puis tester les trois permutations, rotation et annulation.
- [ ] Redimensionner les fenêtres, fermer Mixxx et le relancer : vérifier que la géométrie est restaurée.
- [ ] Débrancher un écran (si possible), cliquer sur `Récupérer`, vérifier que les fenêtres secondaires redeviennent accessibles.
- [ ] Pendant lecture audio, utiliser les commandes et confirmer qu'il n'y a ni coupure ni changement du moteur audio.
- [ ] Vérifier tactile, souris, clavier et contrôleurs MIDI.

