#!/bin/bash
# Boucle de test de developpement pour le skin LateNight QML (panneaux integres).
#
# Fait, dans l'ordre : mise a jour du code, controle de syntaxe des fichiers QML
# du skin, compilation, (option) tests unitaires LateNight, lancement de Mixxx
# avec le skin LateNightQML pendant quelques secondes, puis ecrit un rapport
# texte a coller dans la conversation avec Claude.
#
# Usage : tools/latenight_qml_devtest.sh [options]
#   --no-pull        ne pas lancer "git pull"
#   --no-build       ne pas (re)compiler, reutiliser build/
#   --tests          compiler et lancer LateNightLayoutStateTest.* (mixxx-test)
#   --seconds N      duree de la execution de test (defaut : 25)
#   --offscreen      lancer sans fenetre (QT_QPA_PLATFORM=offscreen)
#   --release        premiere configuration en Release (sinon Debug)
#   --profile DIR    dossier de reglages pour le test (defaut : ~/mixxx-latenight-profile)
#   -h, --help       cette aide
#
# Le rapport est ecrit dans build/latenight-report.txt.

set -u -o pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$REPO/build"
REPORT="$BUILD/latenight-report.txt"

PULL=1
DO_BUILD=1
RUN_SECONDS=25
OFFSCREEN=0
RELEASE=0
PROFILE="$HOME/mixxx-latenight-profile"
RUN_TESTS=0
SKIN="LateNightQML"

usage() {
    sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [ $# -gt 0 ]; do
    case "$1" in
        --no-pull) PULL=0 ;;
        --no-build) DO_BUILD=0 ;;
        --tests) RUN_TESTS=1 ;;
        --offscreen) OFFSCREEN=1 ;;
        --release) RELEASE=1 ;;
        --seconds)
            RUN_SECONDS="${2:-}"
            shift
            ;;
        --profile)
            PROFILE="${2:-}"
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            echo "Option inconnue : $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

case "$RUN_SECONDS" in
    '' | *[!0-9]*)
        echo "--seconds attend un nombre entier" >&2
        exit 2
        ;;
esac
if [ -z "$PROFILE" ]; then
    echo "--profile attend un dossier" >&2
    exit 2
fi

mkdir -p "$BUILD"
: > "$REPORT"

log() { printf '%s\n' "$*" | tee -a "$REPORT"; }
section() {
    log ""
    log "=== $* ==="
}
finish() {
    section "Fin"
    log "Rapport complet : $REPORT"
    log "Colle-le dans la conversation avec : cat $REPORT"
}

# --- Environnement -----------------------------------------------------------
section "Environnement"
log "date : $(date -Is)"
log "commit : $(git -C "$REPO" rev-parse --short HEAD 2>/dev/null || echo inconnu) ($(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || echo ?))"
if [ -r /etc/os-release ]; then
    log "systeme : $( (. /etc/os-release; echo "${PRETTY_NAME:-?} (base : ${UBUNTU_CODENAME:-${VERSION_CODENAME:-?}})") )"
fi
log "qt : $(pkg-config --modversion Qt6Core 2>/dev/null || echo inconnu)"
log "session : ${XDG_SESSION_TYPE:-?} / DISPLAY=${DISPLAY:-aucun}"
if command -v xrandr > /dev/null 2>&1; then
    log "ecrans : $(xrandr --listmonitors 2> /dev/null | head -1)"
fi

# --- Mise a jour -------------------------------------------------------------
if [ "$PULL" = 1 ]; then
    section "Mise a jour (git pull)"
    git -C "$REPO" pull --ff-only 2>&1 | tee -a "$REPORT"
    if [ "${PIPESTATUS[0]}" != 0 ]; then
        log "ATTENTION : git pull a echoue (modifications locales ?). Le test continue sur le code actuel."
    fi
fi

# --- Controle de syntaxe (equilibre des accolades) ---------------------------
section "Controle de syntaxe QML (accolades, crochets, parentheses)"
if command -v python3 > /dev/null 2>&1; then
    python3 -I - "$REPO" 2>&1 << 'EOF' | tee -a "$REPORT"
import sys, os
repo = sys.argv[1]
import glob
files = sorted(glob.glob(os.path.join(repo, "res/skins/LateNightQML/**/*.qml"), recursive=True))
files = [os.path.relpath(f, repo) for f in files]
pairs = {")": "(", "]": "[", "}": "{"}

def check(path):
    s = open(path, encoding="utf-8").read()
    stack, i, n, line = [], 0, len(s), 1
    while i < n:
        c = s[i]
        if c == "\n":
            line += 1
        if s.startswith("//", i):
            while i < n and s[i] != "\n":
                i += 1
            continue
        if s.startswith("/*", i):
            j = s.find("*/", i)
            j = n if j < 0 else j + 2
            line += s.count("\n", i, j)
            i = j
            continue
        if c in "\"'`":
            q = c
            i += 1
            while i < n and s[i] != q:
                if s[i] == "\\":
                    i += 1
                i += 1
            i += 1
            continue
        if c in "([{":
            stack.append((c, line))
        elif c in ")]}":
            if not stack or stack[-1][0] != pairs[c]:
                return "ERREUR : '%s' inattendu ligne %d" % (c, line)
            stack.pop()
        i += 1
    if stack:
        return "ERREUR : '%s' ouvert ligne %d jamais ferme" % stack[-1]
    return "OK"

bad = 0
for f in files:
    p = os.path.join(repo, f)
    r = check(p) if os.path.exists(p) else "fichier absent"
    if r != "OK":
        bad += 1
        print("%s : %s" % (f, r))
print("%d fichier(s) QML controle(s), %d probleme(s)." % (len(files), bad))
if not os.path.exists(os.path.join(repo, "res/skins/LateNightQML/Controls/SectionPane.qml")):
    print("NOTE : Controls/SectionPane.qml absent (patch CLAUDEAI non applique ?)")
EOF
else
    log "python3 absent : controle ignore"
fi

# --- Compilation -------------------------------------------------------------
if [ "$DO_BUILD" = 1 ]; then
    section "Compilation"
    if [ ! -f "$BUILD/CMakeCache.txt" ]; then
        build_type=Debug
        [ "$RELEASE" = 1 ] && build_type=Release
        log "configuration cmake ($build_type)..."
        if ! cmake -S "$REPO" -B "$BUILD" -DCMAKE_BUILD_TYPE="$build_type" > "$BUILD/configure.log" 2>&1; then
            log "ECHEC de cmake (configuration). Dernieres lignes :"
            tail -n 30 "$BUILD/configure.log" | tee -a "$REPORT"
            finish
            exit 1
        fi
    fi
    log "compilation en cours (peut etre longue la premiere fois)..."
    cmake --build "$BUILD" --parallel "$(nproc)" > "$BUILD/build.log" 2>&1
    rc=$?
    if [ "$rc" -ne 0 ]; then
        log "ECHEC de la compilation (code $rc). Relance en serie pour isoler la premiere erreur..."
        cmake --build "$BUILD" --parallel 1 > "$BUILD/build-serial.log" 2>&1
        # Motif strict : "error:" avec deux-points, pas le mot dans un nom de fichier
        # (ex. errordialoghandler.cpp).
        ERR_PATTERN='error:|erreur :|fatal error|undefined reference|Killed|signal terminated|\*\*\*|Error [0-9]+|Erreur [0-9]+'
        grep -n -m5 -B3 -A8 -E "$ERR_PATTERN" "$BUILD/build-serial.log" | tee -a "$REPORT"
        log "--- 25 dernieres lignes du journal ---"
        tail -n 25 "$BUILD/build-serial.log" | tee -a "$REPORT"
        finish
        exit 1
    fi
    log "compilation terminee sans erreur."
fi

if [ "$RUN_TESTS" = 1 ]; then
    section "Tests unitaires LateNight (LateNightLayoutStateTest.*)"
    if [ "$DO_BUILD" = 1 ]; then
        cmake --build "$BUILD" --target mixxx-test --parallel "$(nproc)" > "$BUILD/build-tests.log" 2>&1 \
            || { log "ECHEC de la compilation de mixxx-test :"; tail -n 30 "$BUILD/build-tests.log" | tee -a "$REPORT"; }
    fi
    if [ -x "$BUILD/mixxx-test" ]; then
        (cd "$BUILD" && ./mixxx-test --gtest_filter='LateNightLayoutStateTest.*' 2>&1) | tail -n 60 | tee -a "$REPORT"
    else
        log "mixxx-test introuvable (Mixxx compile avec -DBUILD_TESTING=ON et GTest ?)."
    fi
fi

section "Support QML"
if [ ! -f "$BUILD/CMakeCache.txt" ]; then
    log "Aucun build existant dans $BUILD : relance sans --no-build."
    finish
    exit 1
fi
qml_state="$(grep -E '^QML:' "$BUILD/CMakeCache.txt" 2> /dev/null || true)"
log "${qml_state:-option QML introuvable dans CMakeCache.txt}"
case "$qml_state" in
    *=ON) ;;
    *)
        log "ECHEC : Mixxx est compile sans QML (Qt 6.4 ou plus requis). le skin LateNight QML n'est pas disponible."
        finish
        exit 1
        ;;
esac

# --- Lancement de test -------------------------------------------------------
BIN="$BUILD/mixxx"
if [ ! -x "$BIN" ]; then
    section "Lancement"
    log "Binaire introuvable : $BIN (compile d'abord, sans --no-build)."
    finish
    exit 1
fi

section "Lancement de test (${RUN_SECONDS}s)"
mkdir -p "$PROFILE"
RUNLOG="$BUILD/run.log"
if [ "$OFFSCREEN" = 1 ]; then
    export QT_QPA_PLATFORM=offscreen
    log "mode sans fenetre (offscreen)"
fi
log "profil de test : $PROFILE"
# Le skin QML se choisit dans les preferences : avec --developer (sans --new-ui),
# Mixxx charge le skin QML configure. On l'ecrit dans un profil de test neuf.
CFG="$PROFILE/mixxx.cfg"
if [ ! -f "$CFG" ]; then
    printf '[Config]\nResizableSkin %s\n' "$SKIN" > "$CFG"
    log "profil neuf : skin $SKIN ecrit dans $CFG"
elif ! grep -q "ResizableSkin $SKIN" "$CFG"; then
    log "ATTENTION : $CFG existe deja sans 'ResizableSkin $SKIN'. Choisis le skin dans Preferences > Interface, ou supprime ce profil de test."
fi
MIXXX_ARGS=(--developer --settings-path "$PROFILE" --log-level debug)
CRASH_RE='SIGSEGV|SIGABRT|SIGBUS|SIGFPE|SIGILL'
if command -v gdb > /dev/null 2>&1; then
    # Mixxx est lance directement sous gdb : un plantage (meme rare ou
    # aleatoire) donne tout de suite sa pile d'appels. A la fin du delai, on
    # envoie SIGTERM a Mixxx lui-meme (pas a gdb) pour un arret normal.
    log "lancement sous gdb (pile d'appels automatique en cas de plantage)"
    gdb -batch -ex "handle SIGTERM nostop noprint pass" -ex run -ex "bt 30" \
        --args "$BIN" "${MIXXX_ARGS[@]}" > "$RUNLOG" 2>&1 &
    GDB_PID=$!
    for ((t = 0; t < RUN_SECONDS; t++)); do
        kill -0 "$GDB_PID" 2> /dev/null || break
        sleep 1
    done
    timed_out=0
    if kill -0 "$GDB_PID" 2> /dev/null; then
        timed_out=1
        pkill -TERM -P "$GDB_PID" 2> /dev/null
        for ((t = 0; t < 15; t++)); do
            kill -0 "$GDB_PID" 2> /dev/null || break
            sleep 1
        done
        if kill -0 "$GDB_PID" 2> /dev/null; then
            pkill -KILL -P "$GDB_PID" 2> /dev/null
            kill -KILL "$GDB_PID" 2> /dev/null
        fi
    fi
    wait "$GDB_PID" 2> /dev/null
    if grep -q -E "$CRASH_RE" "$RUNLOG"; then
        log "PLANTAGE detecte. Pile d'appels :"
        grep -E "$CRASH_RE|^#[0-9]+ " "$RUNLOG" | head -n 40 | tee -a "$REPORT"
    elif [ "$timed_out" = 1 ]; then
        log "OK : Mixxx est reste lance ${RUN_SECONDS}s puis a ete arrete (comportement normal)."
    else
        log "Mixxx s'est ferme de lui-meme avant la fin du delai (sans plantage detecte)."
    fi
else
    log "gdb absent (sudo apt install gdb) : lancement simple, sans pile d'appels."
    timeout -s TERM -k 5 "$RUN_SECONDS" "$BIN" "${MIXXX_ARGS[@]}" > "$RUNLOG" 2>&1
    rc=$?
    case "$rc" in
        124) log "OK : Mixxx est reste lance ${RUN_SECONDS}s puis a ete arrete (comportement normal)." ;;
        0) log "Mixxx s'est ferme de lui-meme (code 0) avant la fin du delai." ;;
        *) log "SORTIE ANORMALE : code $rc (plantage probable avant ${RUN_SECONDS}s)." ;;
    esac
fi

# --- Analyse des journaux ----------------------------------------------------
section "Erreurs QML et lignes LateNight"
PATTERN='LateNightQML|SectionPane|SplitView|MainWindow\.qml|is not installed|ReferenceError|TypeError|Cannot assign|Unable to assign|Cannot read property|is not defined|Binding loop|module .* not found|QQmlApplicationEngine failed'
LOGS=("$RUNLOG")
for f in "$PROFILE/mixxx.log" "$PROFILE/log/mixxx.log"; do
    [ -f "$f" ] && LOGS+=("$f")
done
matches="$(grep -h -E "$PATTERN" "${LOGS[@]}" 2> /dev/null | sort -u)"
if [ -z "$matches" ]; then
    log "aucune ligne correspondante."
else
    count="$(printf '%s\n' "$matches" | wc -l)"
    log "$count ligne(s) distincte(s) (60 premieres) :"
    printf '%s\n' "$matches" | head -n 60 | tee -a "$REPORT"
fi

section "Fin de la sortie du programme (30 dernieres lignes)"
tail -n 30 "$RUNLOG" | tee -a "$REPORT"

section "A verifier a la main"
log "1. Le skin LateNight QML s'affiche (barre d'outils, formes d'onde, decks)."
log "2. Afficher/masquer FX, Samples, AUX : chaque panneau apparait/disparait, sans controle masque."
log "3. Tirer les poignees entre panneaux : la bibliotheque absorbe la difference."
log "4. Mode grande bibliotheque (avec et sans decks), puis retour."
log "5. Avec 2 puis 4 decks : pas de chevauchement. Redimensionner la fenetre (mini 1280x720)."
log "6. Lecture d'un morceau, commandes audio, souris/clavier/tactile/MIDI."

finish
