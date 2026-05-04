# Documentación legal

Carpeta con los documentos legales y de cumplimiento del proyecto. **Todos
son plantillas base** redactadas conforme a la legislación española y
europea vigente; **antes de publicarlas o usarlas como definitivas debe
revisarlas un asesor jurídico** y completar los campos `<...>` con los
datos reales de la empresa.

## Contenido

| Documento | Destino | Estado |
| --- | --- | --- |
| [Política de Privacidad](politica_privacidad.md) | Público — `https://grupobravo.com/privacidad` | Plantilla |
| [Aviso Legal](aviso_legal.md) | Público | Plantilla |
| [Política de Cookies](politica_cookies.md) | Público | Plantilla |
| [Registro de Actividades de Tratamiento (RAT)](registro_actividades_tratamiento.md) | **Interno** (sólo bajo requerimiento de la AEPD) | Plantilla |
| [Plantilla notificación brecha](plantilla_brecha.md) | Interno (preparada para enviar a AEPD si ocurre una brecha) | Plantilla |

## Procedimiento para hacerlas definitivas

1. Revisión jurídica externa.
2. Sustituir todos los `<...>` por datos reales (CIF, dirección, etc.).
3. Quitar los avisos `> ⚠ ...` del comienzo de cada archivo.
4. Subir las versiones públicas (privacidad/aviso legal/cookies) al
   sitio web `grupobravo.com` en las URL ya enlazadas desde la app y
   los correos transaccionales.
5. Versionar cada cambio en este repositorio (esto sirve como
   evidencia de la trazabilidad de las versiones).

## URLs ya enlazadas desde el código

- Política de Privacidad: `https://grupobravo.com/privacidad` — enlazada
  desde el pie RGPD de los correos transaccionales y desde la pantalla
  de registro de la app.
- Email de contacto RGPD: `privacidad@grupobravo.com` — enlazado desde
  los correos.

Si cambias estas URL, **actualiza también** las constantes
`_FOOTER_RGPD` en:
- `backend/routes/usuarios.py`
- `backend/routes/auth.py`
- `frontend/lib/screens/cliente/registro_screen.dart` (texto del
  consentimiento).
