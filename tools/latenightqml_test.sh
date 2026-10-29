#!/bin/bash
# Tests de reference du skin LateNight QML (a lancer AVANT et APRES une
# modification du layout). Compile la cible de test, lance les tests existants
# du skin sans fenetre (offscreen) et ecrit un rapport a coller dans la
# conversation avec Claude.
#
# Tests lances :
#   - QmlSkins/QmlStartupSmokeTest.Starts/LateNightQML  (le skin demarre)
#   - LateNightLayoutStateTest.*                        (etat du layout)
#   - ThemeQmlTest.*                                    (theme et ressources)
#
# Usage : tools/latenightqml_test.sh [--no-build] [--no-pull] [--filter MOTIF]
#   --no-build      ne pas compiler, utiliser build/mixxx-test existant
#   --no-pull       ne pas lancer "git pull"
#   --filter MOTIF  filtre gtest personnalise (remplace les tests ci-dessus)
#   -h, --help      cette aide
#
# Le rapport est ecrit dans build/latenightqml-report.txt.

set -u -o pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="$REPO/build"
REPORT="$BUILD/latenightqml-report.txt"
FILTER='QmlSkins/QmlStartupSmokeTest.Starts/LateNightQML:LateNightLayoutStateTest.*:ThemeQmlTest.*'
DO_BUILD=1
PULL=1

while [ $# -gt 0 ]; do
    case "$1" in
        --no-build) DO_BUILD=0 ;;
        --no-pull) PULL=0 ;;
        --filter)
            FILTER="${2:-}"
            shift
            ;;
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
if [ -z "$FILTER" ]; then
    echo "--filter attend un motif gtest" >&2
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

section "Environnement"
log "date : $(date -Is)"
log "commit : $(git -C "$REPO" rev-parse --short HEAD 2> /dev/null || echo inconnu) ($(git -C "$REPO" rev-parse --abbrev-ref HEAD 2> /dev/null || echo ?))"
log "qt : $(pkg-config --modversion Qt6Core 2> /dev/null || echo inconnu)"
log "filtre : $FILTER"

if [ "$PULL" = 1 ]; then
    section "Mise a jour (git pull)"
    git -C "$REPO" pull --ff-only 2>&1 | tee -a "$REPORT"
fi

if [ "$DO_BUILD" = 1 ]; then
    section "Compilation de mixxx-test"
    if [ ! -f "$BUILD/CMakeCache.txt" ]; then
        log "configuration cmake (Debug)..."
        if ! cmake -S "$REPO" -B "$BUILD" -DCMAKE_BUILD_TYPE=Debug > "$BUILD/configure.log" 2>&1; then
            log "ECHEC de cmake (configuration). Dernieres lignes :"
            tail -n 30 "$BUILD/configure.log" | tee -a "$REPORT"
            finish
            exit 1
        fi
    fi
    ERR_PATTERN='error:|erreur :|fatal error|undefined reference|Killed|signal terminated|internal compiler error|out of memory|\*\*\*|Error [0-9]+|Erreur [0-9]+'
    ok=0
    half=$(( ($(nproc) + 1) / 2 ))
    for jobs in "$(nproc)" "$half" 1; do
        [ "$jobs" -lt 1 ] && jobs=1
        log "compilation (--parallel $jobs)..."
        if cmake --build "$BUILD" --target mixxx-test --parallel "$jobs" > "$BUILD/build-test.log" 2>&1; then
            ok=1
            break
        fi
        log "echec avec --parallel $jobs"
        [ "$jobs" -eq 1 ] && break
    done
    if [ "$ok" -ne 1 ]; then
        log "ECHEC de la compilation, meme en serie. Premiere erreur :"
        grep -n -m5 -B3 -A8 -E "$ERR_PATTERN" "$BUILD/build-test.log" | tee -a "$REPORT"
        log "--- 25 dernieres lignes ---"
        tail -n 25 "$BUILD/build-test.log" | tee -a "$REPORT"
        finish
        exit 1
    fi
    log "compilation terminee."
fi

BIN="$BUILD/mixxx-test"
if [ ! -x "$BIN" ]; then
    section "Tests"
    log "Binaire introuvable : $BIN (relance sans --no-build)."
    finish
    exit 1
fi

section "Tests (sans fenetre, 10 minutes maximum)"
TESTLOG="$BUILD/latenightqml-test.log"
(cd "$BUILD" && QT_QPA_PLATFORM=offscreen timeout -s TERM -k 10 600 "$BIN" --gtest_filter="$FILTER" > "$TESTLOG" 2>&1)
rc=$?
passed="$(grep -c '^\[       OK \]' "$TESTLOG")"
failed="$(grep -c '^\[  FAILED  \] .* ([0-9]* ms)' "$TESTLOG")"
log "code de sortie : $rc | reussis : $passed | echecs : $failed"
case "$rc" in
    0) log "OK : tous les tests selectionnes passent." ;;
    124) log "ECHEC : delai de 10 minutes depasse." ;;
    139 | 134) log "PLANTAGE du programme de test (code $rc)." ;;
    *) log "ECHEC : au moins un test a echoue (ou aucun test ne correspond au filtre)." ;;
esac
if grep -q "No tests ran\|0 tests from 0 test suites" "$TESTLOG"; then
    log "ATTENTION : le filtre ne correspond a aucun test. Liste des tests disponibles :"
    log "  $BIN --gtest_list_tests | grep -i -E 'latenight|theme|smoke'"
fi

section "Details"
grep -E '^\[  FAILED  \]|^\[       OK \]|Failure|Expected|Actual|Which is' "$TESTLOG" | head -n 60 | tee -a "$REPORT"
if [ "$rc" -ne 0 ]; then
    log "--- 40 dernieres lignes du journal de tests ---"
    tail -n 40 "$TESTLOG" | tee -a "$REPORT"
fi

finish
[ "$rc" -eq 0 ]
