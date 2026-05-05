# Cómo contribuir a Grupo Bravo

Esta guía resume **cómo pasar la pipeline de CI antes de pushear** y qué hacer
si te falla. Si lees esto porque GitHub Actions te ha mostrado un job en rojo,
ve al apartado [Mi PR está en rojo, ¿qué hago?](#mi-pr-está-en-rojo-qué-hago).

---

## TL;DR

```bash
# Antes de pushear, ejecuta:
bash scripts/check-ci.sh        # Linux/Mac
pwsh scripts/check-ci.ps1       # Windows

# Si el script falla, casi siempre el atajo es:
bash scripts/check-ci.sh fix    # Linux/Mac
pwsh scripts/check-ci.ps1 fix   # Windows
```

El script ejecuta exactamente los mismos comandos que GitHub Actions, así que
si te pasa en local, te pasará en remoto, y viceversa.

---

## Qué comprueba la CI

La pipeline está definida en [`.github/workflows/ci.yml`](.github/workflows/ci.yml)
y tiene **dos jobs paralelos**:

### 🐍 Backend (pytest)

| Paso | Comando | Qué comprueba |
| --- | --- | --- |
| Tests | `pytest tests/ -v --tb=short` | Que los 66+ tests pasen. Usa **mongomock**, no toca MongoDB real. |

### 🎯 Frontend (Flutter)

| Paso | Comando | Qué comprueba |
| --- | --- | --- |
| Format check | `dart format --set-exit-if-changed lib test` | Que el código siga el formato estándar de Dart. |
| Static analysis | `flutter analyze --fatal-warnings --fatal-infos` | Que no haya **errores**, **warnings** ni **infos** (lints). |
| Tests with coverage | `flutter test --coverage test/` | Que los 100+ tests pasen y genera `coverage/lcov.info`. |

> ⚠ El check `--fatal-infos` hace que **cualquier sugerencia del linter** rompa
> la build (ej. `unused_import`, `prefer_const_constructors`,
> `curly_braces_in_flow_control_structures`). No es opcional: la CI lo
> exige.

---

## Mi PR está en rojo, ¿qué hago?

Cuando un job falla, abre la pestaña **Summary** del run. Cada paso roto deja
un bloque con:

- Qué falló.
- El **comando exacto** que lo arregla.
- En el caso de formato, un diff completo en un `<details>`.

A continuación están los tres fallos más comunes y su solución.

### 1. ❌ "Hay archivos sin formatear"

**Causa**: subiste código sin pasar `dart format`.

**Arréglalo**:

```bash
cd frontend
dart format lib test
git add -u && git commit -m "chore: dart format"
git push
```

### 2. ❌ "flutter analyze ha encontrado issues"

**Causa**: el código tiene warnings o sugerencias del linter (lints).

**Arréglalo**, en orden:

```bash
cd frontend

# 1) Auto-fix automático (resuelve la mayoría):
dart fix --apply
dart format lib test

# 2) Si quedan issues, lístalos:
flutter analyze --no-pub --fatal-warnings --fatal-infos
```

Lo que `dart fix` no resuelve, sigue las pistas del log. Casos típicos:

| Issue | Fix |
| --- | --- |
| `unused_field` / `unused_import` | Borra el campo/import. |
| `use_build_context_synchronously` | Añade `if (!mounted) return;` después del `await`. |
| `deprecated_member_use` | Usa la API nueva indicada en el mensaje (ej. `withValues(alpha:)` en vez de `withOpacity`). |
| `curly_braces_in_flow_control_structures` | Encierra el cuerpo del `if`/`for` en `{ }`. |
| `prefer_const_constructors` | Pon `const` delante del constructor. |

### 3. ❌ "Tests del frontend han fallado"

**Causa**: un test rompió. Mira el log con líneas que empiezan por `[E]` o
`FAILED`.

**Arréglalo**:

```bash
cd frontend

# Reproducir todos los tests con detalle:
flutter test --reporter expanded test/

# Reproducir SOLO el archivo que falla:
flutter test test/ruta/al/fichero_test.dart

# Reproducir SOLO un test concreto del archivo:
flutter test test/ruta/al/fichero_test.dart --plain-name "nombre del test"
```

### 4. ❌ "Tests del backend han fallado"

**Arréglalo**:

```bash
cd backend
pip install -r requirements.txt
pytest tests/ -v --tb=short

# Sólo un test:
pytest tests/test_auth_utils.py::TestNombre::test_x -v
```

---

## Cómo añadir un test nuevo

### Backend

Los tests viven en `backend/tests/`. Añade `test_*.py`. El `conftest.py`:

- Inyecta `mongomock` antes de importar `database`.
- Limpia todas las colecciones tras cada test.
- Provee un fixture `client` con `TestClient(app)`.

```python
# backend/tests/test_mi_feature.py
def test_endpoint_devuelve_200(client):
    response = client.get("/api/v1/mi-endpoint")
    assert response.status_code == 200
```

### Frontend

Los tests viven en `frontend/test/`. Convención:

- `test/models/<nombre>_model_test.dart` para modelos puros (parsing,
  copyWith…).
- `test/services/<nombre>_test.dart` para servicios (helpers, parsers,
  AuthSession…).
- `test/widgets/<nombre>_test.dart` para widgets aislados.

```dart
// test/widgets/mi_widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/components/mi_widget.dart';

void main() {
  testWidgets('renderiza el label', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: MiWidget(label: 'Hola')),
    ));
    expect(find.text('Hola'), findsOneWidget);
  });
}
```

---

## Pre-push (opcional pero muy recomendado)

Para que `git push` ejecute la pipeline automáticamente y aborte si falla,
crea `.git/hooks/pre-push`:

```bash
#!/usr/bin/env bash
# .git/hooks/pre-push
exec bash scripts/check-ci.sh
```

```powershell
# Windows: .git/hooks/pre-push
#!/usr/bin/env pwsh
exec pwsh scripts/check-ci.ps1
```

Y dale permisos de ejecución (`chmod +x .git/hooks/pre-push` en Linux/Mac).

---

## Convenciones de commit

Aunque no las imponemos en CI todavía, seguimos
[Conventional Commits](https://www.conventionalcommits.org/) cuando es posible:

- `feat:` nueva funcionalidad
- `fix:` corrección de bug
- `chore:` tareas de mantenimiento (formato, deps, CI)
- `docs:` documentación
- `test:` añadir o arreglar tests
- `refactor:` cambio que no añade ni quita features

Ejemplo: `fix(auth): impide reutilizar reset_code expirado`.

---

## ¿Aún tienes dudas?

Abre un issue con la etiqueta `pregunta` o pregunta en el canal interno del
equipo. La pipeline está diseñada para no pisar a nadie: si te bloquea es
porque queremos que lo descubras tú antes de que el cambio llegue a `main`.
