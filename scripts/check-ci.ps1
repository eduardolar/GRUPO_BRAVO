# ─────────────────────────────────────────────────────────────────────────────
# check-ci.ps1 — Reproduce LOCALMENTE los pasos de GitHub Actions en Windows.
#
# Uso:
#     pwsh scripts/check-ci.ps1            # todo
#     pwsh scripts/check-ci.ps1 frontend
#     pwsh scripts/check-ci.ps1 backend
#     pwsh scripts/check-ci.ps1 fix        # auto-fix de formato y lints
#
# Si algún paso falla, imprime el comando exacto que arregla el problema.
# ─────────────────────────────────────────────────────────────────────────────

param([string]$Target = 'all')

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$failed = New-Object System.Collections.ArrayList

function Step($msg)  { Write-Host "`n▶ $msg" -ForegroundColor Cyan }
function Ok($msg)    { Write-Host "✔ $msg" -ForegroundColor Green }
function Fail($msg)  { Write-Host "✘ $msg" -ForegroundColor Red; [void]$failed.Add($msg) }
function Hint($msg)  { Write-Host "  → $msg" -ForegroundColor Yellow }

function Get-Python {
    if (Get-Command py -ErrorAction SilentlyContinue)      { return @('py', '-3') }
    if (Get-Command python3 -ErrorAction SilentlyContinue) { return @('python3') }
    if (Get-Command python -ErrorAction SilentlyContinue)  { return @('python') }
    return $null
}

function Run-Backend {
    Step "Backend · pytest"
    $py = Get-Python
    if ($null -eq $py) {
        Fail "Backend tests (no se encontró Python)"
        Hint "Instala Python 3.12 y vuelve a ejecutar."
        return
    }
    Push-Location backend
    & $py[0] $py[1..($py.Length - 1)] -m pytest tests/ --tb=short -q
    $code = $LASTEXITCODE
    Pop-Location
    if ($code -eq 0) { Ok "Backend tests" }
    else {
        Fail "Backend tests (pytest)"
        $pyShown = $py -join ' '
        Hint "Reproduce:  cd backend; $pyShown -m pytest tests/ -v --tb=short"
        Hint "Sólo un test:  $pyShown -m pytest tests/test_X.py::TestNombre -v"
        Hint "Si dice 'No module named pytest':  $pyShown -m pip install -r backend/requirements.txt"
    }
}

function Run-FrontendFormat {
    Step "Frontend · dart format check"
    Push-Location frontend
    dart format --output=none --set-exit-if-changed lib test
    if ($LASTEXITCODE -eq 0) { Ok "Format" }
    else {
        Fail "Frontend · dart format"
        Hint "Para arreglarlo:  cd frontend; dart format lib test"
    }
    Pop-Location
}

function Run-FrontendAnalyze {
    Step "Frontend · flutter analyze (--fatal-warnings --fatal-infos)"
    Push-Location frontend
    flutter analyze --no-pub --fatal-warnings --fatal-infos
    if ($LASTEXITCODE -eq 0) { Ok "Analyze" }
    else {
        Fail "Frontend · flutter analyze"
        Hint "Auto-fix:  cd frontend; dart fix --apply; dart format lib test"
        Hint "Re-comprobar:  flutter analyze --no-pub --fatal-warnings --fatal-infos"
    }
    Pop-Location
}

function Run-FrontendTests {
    Step "Frontend · flutter test"
    Push-Location frontend
    flutter test --reporter compact test/
    if ($LASTEXITCODE -eq 0) { Ok "Frontend tests" }
    else {
        Fail "Frontend · flutter test"
        Hint "Reproduce:  cd frontend; flutter test --reporter expanded test/"
        Hint "Sólo un fichero:  flutter test test/ruta/al/fichero_test.dart"
    }
    Pop-Location
}

function Run-Frontend {
    Run-FrontendFormat
    Run-FrontendAnalyze
    Run-FrontendTests
}

function Run-Fix {
    Step "Auto-fix · dart fix --apply"
    Push-Location frontend
    dart fix --apply
    Step "Auto-fix · dart format lib test"
    dart format lib test
    Pop-Location
    Ok "Auto-fix aplicado. Revisa los cambios con:  git diff"
    Hint "Después ejecuta:  pwsh scripts/check-ci.ps1"
}

switch ($Target.ToLower()) {
    'all'      { Run-Backend; Run-Frontend }
    'backend'  { Run-Backend }
    'frontend' { Run-Frontend }
    'fix'      { Run-Fix; exit 0 }
    default {
        Write-Host "Uso: $($MyInvocation.MyCommand.Name) [all|backend|frontend|fix]"
        exit 2
    }
}

Write-Host ""
Write-Host "──────────────────────────────────────────────"
if ($failed.Count -eq 0) {
    Write-Host "✅ Todo verde. Puedes pushear con confianza." -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ Han fallado $($failed.Count) paso(s):" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "   - $_" }
    Write-Host ""
    Write-Host "Pista global: prueba primero  pwsh scripts/check-ci.ps1 fix  y vuelve a ejecutar." -ForegroundColor Yellow
    exit 1
}
