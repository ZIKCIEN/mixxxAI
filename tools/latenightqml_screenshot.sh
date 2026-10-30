#!/bin/bash
# Lance le skin LateNight QML dans un profil de test separe, attend, prend une
# capture d'ecran, puis arrete Mixxx. Sert a montrer a Claude le rendu reel.
#
# IMPORTANT : LateNightQML est un skin "developpeur". Il se lance avec
# --developer et ResizableSkin=LateNightQML dans le profil (et PAS avec
# --new-ui, qui lance une autre interface).
#
# Usage : tools/latenightqml_screenshot.sh [options]
#   --seconds N      attente avant la capture (defaut : 25)
#   --profile DIR    profil de test (defaut : ~/mixxx-latenight-profile)
#   --out FICHIER    fichier PNG (defaut : build/latenightqml-screenshot.png)
#   --manual         ne capture pas : laisse Mixxx ouvert, tu testes a la main
#                    (arret avec Ctrl+C ou en fermant la fenetre)
#   -h, --help       cette aide
#
# Capture : le premier outil disponible parmi gnome-screenshot, scrot, maim,
# import (ImageMagick). Session X11 requise (pas Wayland).
#   sudo apt install scrot    # si aucun outil n'est installe

set -u -o pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$REPO/build"
BIN="$BUILD/mixxx"
SECONDS_WAIT=25
PROFILE="$HOME/mixxx-latenight-profile"
OUT="$BUILD/latenightqml-screenshot.png"
MANUAL=0

while [ $# -gt 0 ]; do
    case "$1" in
        --seconds)
            SECONDS_WAIT="${2:-}"
            shift
            ;;
        --profile)
            PROFILE="${2:-}"
            shift
            ;;
        --out)
            OUT="${2:-}"
            shift
            ;;
        --manual) MANUAL=1 ;;
        -h | --help)
            sed -n '2,19p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Option inconnue : $1" >&2
            exit 2
            ;;
    esac
    shift
done

case "$SECONDS_WAIT" in
    '' | *[!0-9]*)
        echo "--seconds attend un nombre entier" >&2
        exit 2
        ;;
esac
if [ -z "$PROFILE" ] || [ -z "$OUT" ]; then
    echo "--profile et --out attendent une valeur" >&2
    exit 2
fi

if [ ! -x "$BIN" ]; then
    echo "Binaire introuvable : $BIN" >&2
    echo "Compile d'abord : tools/latenightqml_test.sh  (ou cmake --build build)" >&2
    exit 1
fi

# Profil : meme contenu que le test de demarrage du depot (version "3.0-unstable"
# et skin LateNightQML), sans peripherique audio, pour un lancement reproductible.
mkdir -p "$PROFILE"
if [ ! -f "$PROFILE/mixxx.cfg" ]; then
    printf '[Config]\nVersion 3.0-unstable\nResizableSkin LateNightQML\n' > "$PROFILE/mixxx.cfg"
fi
if [ ! -f "$PROFILE/soundconfig.xml" ]; then
    printf '<SoundManagerConfig api="None"/>\n' > "$PROFILE/soundconfig.xml"
fi
if ! grep -q 'ResizableSkin LateNightQML' "$PROFILE/mixxx.cfg"; then
    echo "ATTENTION : $PROFILE/mixxx.cfg existe deja avec un autre skin."
    echo "  Choisis LateNight QML dans Preferences > Interface, ou supprime ce dossier."
fi

LOG="$BUILD/latenightqml-run.log"
echo "Profil : $PROFILE"
if [ "$MANUAL" = 1 ]; then
    echo "Mode manuel : Mixxx reste ouvert. Journal : $LOG"
    "$BIN" --developer --settings-path "$PROFILE" --log-level debug > "$LOG" 2>&1
    echo "Mixxx ferme (code $?). Journal : $LOG"
    exit 0
fi

pick_tool() {
    for t in gnome-screenshot scrot maim import; do
        command -v "$t" > /dev/null 2>&1 && {
            echo "$t"
            return 0
        }
    done
    return 1
}
TOOL="$(pick_tool)" || {
    echo "Aucun outil de capture (gnome-screenshot, scrot, maim, import)." >&2
    echo "Installe-en un : sudo apt install scrot" >&2
    exit 1
}
if [ "${XDG_SESSION_TYPE:-x11}" = "wayland" ]; then
    echo "ATTENTION : session Wayland, la capture peut etre noire ou refusee."
fi

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
"$BIN" --developer --settings-path "$PROFILE" --log-level debug > "$LOG" 2>&1 &
MIXXX_PID=$!
echo "Mixxx lance (pid $MIXXX_PID), capture dans ${SECONDS_WAIT}s avec $TOOL..."
for ((t = 0; t < SECONDS_WAIT; t++)); do
    kill -0 "$MIXXX_PID" 2> /dev/null || break
    sleep 1
done

if ! kill -0 "$MIXXX_PID" 2> /dev/null; then
    wait "$MIXXX_PID"
    echo "ECHEC : Mixxx s'est arrete avant la capture (code $?). Fin du journal :"
    tail -n 25 "$LOG"
    exit 1
fi

case "$TOOL" in
    gnome-screenshot) gnome-screenshot -f "$OUT" ;;
    scrot) scrot "$OUT" ;;
    maim) maim "$OUT" ;;
    import) import -window root "$OUT" ;;
esac
rc=$?

kill -TERM "$MIXXX_PID" 2> /dev/null
for ((t = 0; t < 10; t++)); do
    kill -0 "$MIXXX_PID" 2> /dev/null || break
    sleep 1
done
kill -0 "$MIXXX_PID" 2> /dev/null && kill -KILL "$MIXXX_PID" 2> /dev/null
wait "$MIXXX_PID" 2> /dev/null

if [ "$rc" -ne 0 ] || [ ! -s "$OUT" ]; then
    echo "ECHEC de la capture (code $rc)." >&2
    exit 1
fi
echo "Capture : $OUT"
echo "Envoie ce fichier dans la conversation."
echo "Erreurs QML eventuelles :"
errs="$(grep -E "qml:|TypeError|ReferenceError|Binding loop" "$LOG" | sort -u | head -n 20 || true)"
if [ -n "$errs" ]; then
    printf '%s\n' "$errs"
else
    echo "  aucune"
fi
exit 0
