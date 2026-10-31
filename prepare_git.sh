#!/usr/bin/env bash
# Usage : depuis la racine d'un clone de ZIKCIEN/mixxxAI, avec CLAUDEAI.patch et PR_BODY.md dans ce dossier.
set -euo pipefail
BASE="${1:-main}"
git fetch origin
if git show-ref --verify --quiet refs/remotes/origin/CLAUDEAI; then
  git switch CLAUDEAI
else
  git switch "$BASE"
  git pull
  git switch -c CLAUDEAI
fi
git apply --check CLAUDEAI.patch
git apply CLAUDEAI.patch
git add res/skins/LateNightQML src/test/latenightlayoutstate_test.cpp
git commit -m "LateNight QML: panneaux integres redimensionnables (FX, Samples, AUX, bibliotheque)"
git push -u origin CLAUDEAI
gh pr create --base "$BASE" --head CLAUDEAI \
  --title "LateNight QML : panneaux intégrés redimensionnables (une fenêtre, un écran)" \
  --body-file PR_BODY.md --draft
