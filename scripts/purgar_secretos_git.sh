#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# purgar_secretos_git.sh — Elimina .env (y cualquier otro fichero sensible)
# del histórico completo de Git usando git-filter-repo.
#
# ⚠ ESTE SCRIPT REESCRIBE EL HISTORIAL Y FUERZA UN PUSH.
# ⚠ Cualquier persona que tenga clones del repositorio deberá:
#       git fetch --all
#       git reset --hard origin/<rama>
# ⚠ NO ejecutar sin haber:
#   1) Hecho copia completa del repo (zip, fork privado, etc.).
#   2) Avisado al equipo.
#   3) Rotado las credenciales que estaban en el .env (ya filtradas).
#   4) Hecho privado el repositorio mientras dura la operación.
#
# Uso:
#   bash scripts/purgar_secretos_git.sh           # dry-run (no fuerza nada)
#   bash scripts/purgar_secretos_git.sh --apply   # aplica y hace push --force
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

APPLY="${1:-}"

if ! command -v git-filter-repo >/dev/null 2>&1; then
    echo "❌ git-filter-repo no está instalado."
    echo "   Instalación recomendada:"
    echo "     pip install git-filter-repo"
    echo "   o vía Homebrew/Chocolatey/Scoop según el sistema."
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

echo "▶ Repositorio: $REPO_ROOT"
echo "▶ Rama actual: $(git rev-parse --abbrev-ref HEAD)"

# Lista de patrones a eliminar del histórico.
# Añade aquí cualquier otro fichero o carpeta que deba purgarse.
read -r -d '' PATHS <<'EOF' || true
.env
backend/.env
backend/env
backend/env.local
frontend/build
EOF

if [[ "$APPLY" != "--apply" ]]; then
    echo ""
    echo "── DRY RUN ──────────────────────────────────────────────"
    echo "Se purgarían del histórico estos paths:"
    echo "$PATHS" | sed 's/^/  - /'
    echo ""
    echo "Para aplicar:  bash scripts/purgar_secretos_git.sh --apply"
    exit 0
fi

# Pre-vuelo:
if [[ -n "$(git status --porcelain)" ]]; then
    echo "❌ Hay cambios sin commitear. Limpia el árbol antes de continuar."
    exit 1
fi

# Confirmación final
echo ""
echo "⚠  Vas a REESCRIBIR el historial de Git."
echo "⚠  Esto requiere un push --force al remoto."
read -r -p "Escribe 'CONFIRMAR' para continuar: " ANSWER
if [[ "$ANSWER" != "CONFIRMAR" ]]; then
    echo "Operación cancelada."
    exit 1
fi

# Backup local antes de reescribir
BACKUP_BRANCH="backup-pre-purge-$(date +%Y%m%d-%H%M%S)"
git branch "$BACKUP_BRANCH"
echo "✔ Rama de backup local creada: $BACKUP_BRANCH"

# Construye los argumentos --path-glob / --path para git-filter-repo
ARGS=()
while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    ARGS+=(--path "$p")
done <<< "$PATHS"

echo "▶ Ejecutando git-filter-repo --invert-paths con los patrones..."
git filter-repo --force --invert-paths "${ARGS[@]}"

echo "✔ Histórico reescrito."
echo ""
echo "▶ El remoto fue eliminado por filter-repo. Reañádelo:"
echo "    git remote add origin <url>"
echo ""
echo "▶ Push forzado a origin (todas las ramas y tags):"
echo "    git push --force --all"
echo "    git push --force --tags"
echo ""
echo "▶ Tras el push:"
echo "    1) Avisa al equipo: deben re-clonar o resetear su copia."
echo "    2) Verifica con git ls-files que .env ya NO aparece."
echo "    3) Mantén el repo privado hasta confirmar la limpieza."
