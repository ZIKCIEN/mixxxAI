#!/usr/bin/env bash
# Prépare les deux branches du dépôt ZIKCIEN/mixxxAI et ouvre les PR.
# Usage : ./go.sh [branche_de_référence]   (défaut : main)
# Prérequis : git et gh (GitHub CLI) installés, puis `gh auth login` déjà fait.
set -euo pipefail
BASE="${1:-main}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_URL="https://github.com/ZIKCIEN/mixxxAI.git"

command -v git >/dev/null || { echo "git est requis"; exit 1; }
command -v gh >/dev/null || { echo "gh (GitHub CLI) est requis : https://cli.github.com"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Lance d'abord : gh auth login"; exit 1; }

if [ ! -d "$HERE/mixxxAI/.git" ]; then
  git clone "$REPO_URL" "$HERE/mixxxAI"
fi
cd "$HERE/mixxxAI"

cp "$HERE"/CLAUDEAI.patch "$HERE"/PR_BODY.md "$HERE"/prepare_git.sh \
   "$HERE"/crate-sidebar-guard.patch "$HERE"/PR_BODY_crate.md "$HERE"/prepare_git_crate.sh .
mkdir -p tools && cp "$HERE"/latenight_qml_devtest.sh tools/   # reste local, non commité

echo "== 1/2 : PR panneaux redimensionnables (branche CLAUDEAI, brouillon) =="
./prepare_git.sh "$BASE"

echo "== 2/2 : PR garde cratefeature (branche fix-crate-sidebar-null) =="
./prepare_git_crate.sh "$BASE"

git switch CLAUDEAI
echo "Terminé. Pour tester : tools/latenight_qml_devtest.sh --tests"
