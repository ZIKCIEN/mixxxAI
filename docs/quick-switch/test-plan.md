# Plan de tests manuel — Quick Switch

## Préconditions
- Compilation Mixxx avec QML activé.
- Trois écrans idéalement, ou deux écrans pour les tests de récupération.
- Sauvegarde de `res/qml/MainWindow.qml`.

## Cas
1. **Démarrage** : la skin QML se charge sans erreur, la lecture audio fonctionne.
2. **Bibliothèque détachable** : ouvrir B ; le panneau de bibliothèque de la fenêtre principale disparaît ; fermer B ; le panneau principal peut réapparaître selon la hauteur disponible.
3. **Panneau auxiliaire** : ouvrir C ; vérifier les unités d'effets et auxiliaires ; fermer C.
4. **Permutation 1↔2** : placer fenêtres 1 et 2 sur deux moniteurs, cliquer, vérifier que leurs positions/dimensions sont échangées.
5. **Permutation 2↔3 et 1↔3** : même vérification pour chaque paire.
6. **Rotation** : vérifier 1→position 2, 2→position 3, 3→position 1.
7. **Annuler** : après permutation ou rotation, revenir aux trois géométries précédentes.
8. **Persistance** : redémarrer Mixxx et vérifier les géométries.
9. **Écran débranché** : vérifier que `Récupérer` rend les fenêtres accessibles sur le bureau restant.
10. **Audio temps réel** : lecture en cours pendant plusieurs permutations ; vérifier absence de décrochage audio.
11. **Contrôleurs** : tester souris, écran tactile, clavier et MIDI.

## Résultats à noter
- OS, version Qt, commit/branche Mixxx.
- Erreurs QML dans le journal.
- Géométrie avant/après de chaque fenêtre.
- Tout décrochage audio ou changement de focus inattendu.
