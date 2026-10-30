#!/bin/bash
# Prend une capture du skin LateNight QML pour plusieurs versions (commits) du
# dossier res/skins/LateNightQML, chacune avec un profil NEUF, puis remet le
# skin a l'etat de la version actuelle. Sert a trouver quel commit change le
# rendu, et a voir si un defaut est aleatoire (meme commit teste deux fois).
#
# Le skin est lu directement depuis les sources : aucune recompilation.
#
# Usage : tools/latenightqml_compare_shots.sh [--seconds N] [commit ...]
#   par defaut : ee17a272 5e5591f4 521553aa 521553aa
#   (origine, zone de saisie 24 px, poignees de sections, poignees de nouveau)
#
# Sortie : build/shot-<n>-<commit>.png  (a envoyer dans la conversation)
# Prerequis : build/mixxx compile, un outil de capture (voir
# latenightqml_screenshot.sh), dossier res/skins/LateNightQML sans modification.

set -u -o pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$REPO/build"
SKIN_DIR="res/skins/LateNightQML"
SECONDS_WAIT=25
REVS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --seconds)
            SECONDS_WAIT="${2:-}"
            shift
            ;;
        -h | --help)
            sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        -*)
            echo "Option inconnue : $1" >&2
            exit 2
            ;;
        *) REVS+=("$1") ;;
    esac
    shift
done
[ "${#REVS[@]}" -eq 0 ] && REVS=(ee17a272 5e5591f4 521553aa 521553aa)
case "$SECONDS_WAIT" in
    '' | *[!0-9]*)
        echo "--seconds attend un nombre entier" >&2
        exit 2
        ;;
esac

cd "$REPO" || exit 1

if [ -n "$(git status --porcelain -- "$SKIN_DIR")" ]; then
    echo "ARRET : $SKIN_DIR contient des modifications non enregistrees :" >&2
    git status --short -- "$SKIN_DIR" >&2
    echo "Enregistre-les (git commit) ou annule-les avant de lancer ce script." >&2
    exit 1
fi
if [ ! -x "$BUILD/mixxx" ]; then
    echo "Binaire introuvable : $BUILD/mixxx (compile d'abord)." >&2
    exit 1
fi
for r in "${REVS[@]}"; do
    git rev-parse --verify --quiet "${r}^{commit}" > /dev/null || {
        echo "Commit inconnu : $r" >&2
        exit 2
    }
done

restore() {
    git checkout HEAD -- "$SKIN_DIR" > /dev/null 2>&1
    echo
    echo "Skin remis a la version actuelle ($(git rev-parse --short HEAD))."
    if [ -n "$(git status --porcelain -- "$SKIN_DIR")" ]; then
        echo "ATTENTION : $SKIN_DIR n'est pas propre :"
        git status --short -- "$SKIN_DIR"
    else
        echo "git status : propre."
    fi
}
trap restore EXIT

mkdir -p "$BUILD"
OUTS=()
n=0
for rev in "${REVS[@]}"; do
    n=$((n + 1))
    short="$(git rev-parse --short "$rev")"
    profile="$HOME/mixxx-latenight-cmp-$n"
    out="$BUILD/shot-$n-$short.png"
    echo
    echo "=== [$n/${#REVS[@]}] commit $short ==="
    rm -rf "$profile"
    git checkout "$rev" -- "$SKIN_DIR" || {
        echo "echec du checkout de $rev"
        continue
    }
    if "$REPO/tools/latenightqml_screenshot.sh" --seconds "$SECONDS_WAIT" --profile "$profile" --out "$out"; then
        OUTS+=("$out")
    else
        echo "capture $n echouee (voir le message ci-dessus)"
    fi
done

echo
echo "=== Captures obtenues (${#OUTS[@]}) ==="
for f in "${OUTS[@]}"; do ls -l "$f" | awk '{print $5" octets  "$NF}'; done
echo "Envoie ces fichiers dans la conversation, dans cet ordre."
