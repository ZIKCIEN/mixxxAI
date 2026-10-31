## Problème
Dans `CrateFeature::slotCreateCrate()`, `m_pSidebarWidget` est utilisé sans vérification après la création d'un bac. Quand la bibliothèque est affichée par l'interface QML (par exemple le skin LateNight QML via `LegacyLibraryItem`), il n'y a pas de widget de barre latérale : le pointeur est nul et la création d'un bac peut faire planter l'application.

## Correction
Ajout de la garde `&& m_pSidebarWidget`, comme `BasePlaylistFeature` le fait déjà pour les listes de lecture (`if (!m_pSidebarWidget) { ... }`). Le bac est créé dans tous les cas ; seule la sélection dans la barre latérale est ignorée quand elle n'existe pas.

## Vérifications
- [ ] Interface classique : créer un bac, il est développé et sélectionné dans la barre latérale (comportement inchangé)
- [ ] Skin LateNight QML : créer un bac depuis la bibliothèque, sans plantage
