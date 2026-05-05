#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# check-ci.sh — Reproduce LOCALMENTE los mismos pasos que ejecuta GitHub Actions.
#
# Úsalo antes de hacer push para no descubrir el fallo en el remoto:
#     bash scripts/check-ci.sh             # ejecuta TODO
#     bash scripts/check-ci.sh frontend    # sólo frontend
#     bash scripts/check-ci.sh backend     # sólo backend
#     bash scripts/check-ci.sh fix         # auto-fix de formato y lints
#
# Si algún paso falla, imprime el comando exacto que arregla el problema.
# ─────────────────────────────────────────────────────────────────────────────

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # reset

# Acumula nombres de pasos rotos para imprimir un resumen al final.
FAILED=()

step() { printf "\n${BLUE}▶ %s${NC}\n" "$1"; }
ok()   { printf "${GREEN}✔ %s${NC}\n" "$1"; }
fail() { printf "${RED}✘ %s${NC}\n" "$1"; FAILED+=("$1"); }
hint() { printf "${YELLOW}  → %s${NC}\n" "$1"; }

# ───────────── Backend ────────────────────────────────────────────────────────
# Detecta el ejecutable de Python disponible (py, python3, python).
detect_python() {
    if command -v py >/dev/null 2>&1; then echo "py -3"
    elif command -v python3 >/dev/null 2>&1; then echo "python3"
    elif command -v python >/dev/null 2>&1; then echo "python"
    else return 1
    fi
}

run_backend() {
    step "Backend · pytest"
    local PY
    if ! PY=$(detect_python); then
        fail "Backend tests (no se encontró Python)"
        hint "Instala Python 3.12 y vuelve a ejecutar."
        return
    fi
    if (cd backend && $PY -m pytest tests/ --tb=short -q); then
        ok "Backend tests"
    else
        fail "Backend tests (pytest)"
        hint "Reproduce: cd backend && $PY -m pytest tests/ -v --tb=short"
        hint "Sólo un test:  $PY -m pytest tests/test_X.py::TestNombre -v"
        hint "Si dice 'No module named pytest':  $PY -m pip install -r backend/requirements.txt"
    fi
}

# ───────────── Frontend ───────────────────────────────────────────────────────
run_frontend_format() {
    step "Frontend · dart format check"
    if (cd frontend && dart format --output=none --set-exit-if-changed lib test); then
        ok "Format"
    else
        fail "Frontend · dart format"
        hint "Para arreglarlo:  cd frontend && dart format lib test"
    fi
}

run_frontend_analyze() {
    step "Frontend · flutter analyze (--fatal-warnings --fatal-infos)"
    if (cd frontend && flutter analyze --no-pub --fatal-warnings --fatal-infos); then
        ok "Analyze"
    else
        fail "Frontend · flutter analyze"
        hint "Auto-fix:  cd frontend && dart fix --apply && dart format lib test"
        hint "Re-comprobar:  flutter analyze --no-pub --fatal-warnings --fatal-infos"
    fi
}

run_frontend_tests() {
    step "Frontend · flutter test"
    if (cd frontend && flutter test --reporter compact test/); then
        ok "Frontend tests"
    else
        fail "Frontend · flutter test"
        hint "Reproduce:  cd frontend && flutter test --reporter expanded test/"
        hint "Sólo un fichero:  flutter test test/ruta/al/fichero_test.dart"
    fi
}

run_frontend() {
    run_frontend_format
    run_frontend_analyze
    run_frontend_tests
}

# ───────────── Auto-fix ───────────────────────────────────────────────────────
run_fix() {
    step "Auto-fix · dart fix --apply"
    (cd frontend && dart fix --apply) || true
    step "Auto-fix · dart format lib test"
    (cd frontend && dart format lib test) || true
    ok "Auto-fix aplicado. Revisa los cambios con:  git diff"
    echo ""
    hint "Después ejecuta:  bash scripts/check-ci.sh"
}

# ───────────── Main ───────────────────────────────────────────────────────────
case "${1:-all}" in
    all)        run_backend; run_frontend ;;
    backend)    run_backend ;;
    frontend)   run_frontend ;;
    fix)        run_fix; exit 0 ;;
    *)
        echo "Uso: $0 [all|backend|frontend|fix]"
        exit 2
        ;;
esac

echo ""
echo "──────────────────────────────────────────────"
if [[ ${#FAILED[@]} -eq 0 ]]; then
    printf "${GREEN}✅ Todo verde. Puedes pushear con confianza.${NC}\n"
    exit 0
else
    printf "${RED}❌ Han fallado %d paso(s):${NC}\n" "${#FAILED[@]}"
    for f in "${FAILED[@]}"; do echo "   - $f"; done
    echo ""
    printf "${YELLOW}Pista global: ${NC}prueba primero ${YELLOW}bash scripts/check-ci.sh fix${NC} y vuelve a ejecutar.\n"
    exit 1
fi
