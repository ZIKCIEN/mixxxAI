#!/usr/bin/env bash
# Usage : depuis la racine d'un clone de ZIKCIEN/mixxxAI, avec crate-sidebar-guard.patch et PR_BODY_crate.md dans ce dossier.
set -euo pipefail
BASE="${1:-main}"
BRANCH="fix-crate-sidebar-null"
git fetch origin
git switch "$BASE"
git pull
git switch -c "$BRANCH"
git apply --check crate-sidebar-guard.patch
git apply crate-sidebar-guard.patch
git add src/library/trackset/crate/cratefeature.cpp
git commit -m "CrateFeature: garde contre un widget de barre laterale absent (UI QML)"
git push -u origin "$BRANCH"
gh pr create --base "$BASE" --head "$BRANCH" \
  --title "CrateFeature : éviter un plantage à la création d'un bac sans barre latérale (UI QML)" \
  --body-file PR_BODY_crate.md
