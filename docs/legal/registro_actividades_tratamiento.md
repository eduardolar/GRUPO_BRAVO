# Registro de Actividades de Tratamiento (RAT) — Restaurante Bravo

**Última actualización**: 4 de mayo de 2026
**Versión**: 1.0
**Documento elaborado conforme al art. 30 RGPD y al modelo orientativo
publicado por la AEPD ("Facilita RGPD").**

> ⚠ **Documento interno**. No publicar en la web. Debe estar a disposición
> de la AEPD en caso de inspección. Revisar al menos **anualmente** y
> cada vez que se incorpore una nueva finalidad o un nuevo encargado.

---

## Datos del responsable

| Campo | Valor |
| --- | --- |
| Denominación social | `<Razón social completa>` |
| CIF | `<CIF>` |
| Domicilio | `<Dirección postal completa>` |
| Email | privacidad@grupobravo.com |
| Teléfono | `<Teléfono>` |
| Representante legal | `<Nombre / cargo>` |
| Delegado de Protección de Datos | `<Nombre / "No designado por no ser obligatorio (art. 37 RGPD)">` |

---

## Actividad 01 — Gestión de cuentas de usuario

| Campo | Detalle |
| --- | --- |
| **Finalidad** | Registro, autenticación, recuperación de contraseña, doble factor (2FA) |
| **Base jurídica** | Ejecución de contrato (art. 6.1.b RGPD) e interés legítimo (seguridad) |
| **Categorías de interesados** | Clientes finales, empleados, administradores |
| **Categorías de datos** | Nombre, correo, teléfono, dirección, contraseña hash, código 2FA, IP de consentimiento |
| **Categorías de destinatarios** | Personal autorizado del responsable, Google (proveedor SMTP) |
| **Transferencias internacionales** | Google LLC (EE. UU.) bajo SCC + DPF |
| **Plazos de supresión** | Mientras la cuenta esté activa; 6 años desde la baja para datos contables del pedido |
| **Medidas técnicas y organizativas** | Hash bcrypt, JWT, 2FA opcional (TOTP/email), TLS, cifrado en reposo en MongoDB Atlas, auditoría, rate limiting, TTL en códigos OTP |

## Actividad 02 — Gestión de pedidos y reservas

| Campo | Detalle |
| --- | --- |
| **Finalidad** | Toma y procesamiento de comandas, pedidos a domicilio, para recoger y reservas de mesa |
| **Base jurídica** | Ejecución de contrato (art. 6.1.b RGPD) |
| **Categorías de interesados** | Clientes finales |
| **Categorías de datos** | Identificativos (nombre, correo, teléfono), dirección de entrega, geolocalización (sólo durante el ciclo activo), histórico de productos, importes, notas (incluyendo alergias si las introduce el usuario) |
| **Categorías de destinatarios** | Restaurantes (cocina, sala), repartidores, Stripe / PayPal / Apple Pay / Google Pay |
| **Transferencias internacionales** | Stripe, Google, Apple en EE. UU., bajo SCC + DPF |
| **Plazos de supresión** | Datos del pedido: 6 años por obligación contable. Geolocalización: eliminada al cerrar el pedido (estados `entregado`/`cancelado`) |
| **Medidas técnicas y organizativas** | Tokenización de tarjeta vía Stripe (no se almacena PAN/CVV), webhook firmado de Stripe, transacciones atómicas en stock, auditoría de pagos |

## Actividad 03 — Procesamiento de pagos

| Campo | Detalle |
| --- | --- |
| **Finalidad** | Cobro de pedidos mediante proveedores externos |
| **Base jurídica** | Ejecución de contrato + obligación legal (facturación) |
| **Categorías de interesados** | Clientes finales |
| **Categorías de datos** | Importe, divisa, referencia del pago (PaymentIntent/orderId), estado del pago, identificadores de pedido. **Los datos de tarjeta no se almacenan en nuestros servidores.** |
| **Categorías de destinatarios** | Stripe Payments Europe Ltd., PayPal (Europe) S.à r.l., Apple Distribution International, Google Ireland Ltd., Hacienda |
| **Transferencias internacionales** | EE. UU. con SCC + DPF |
| **Plazos de supresión** | 6 años (art. 30 Código de Comercio, art. 29 LGT) |
| **Medidas técnicas y organizativas** | Stripe SAQ-A; nunca se reciben datos de tarjeta en backend; verificación del estado del pago vía webhook firmado antes de marcar el pedido como pagado |

## Actividad 04 — Comunicaciones operativas por correo

| Campo | Detalle |
| --- | --- |
| **Finalidad** | Envío de correos transaccionales (verificación de cuenta, códigos 2FA, recuperación de contraseña, factura) |
| **Base jurídica** | Ejecución de contrato (art. 6.1.b) e interés legítimo (seguridad) |
| **Categorías de interesados** | Clientes finales y empleados |
| **Categorías de datos** | Nombre, correo, contenido del mensaje, fecha de envío |
| **Categorías de destinatarios** | Google LLC (Gmail SMTP) |
| **Transferencias internacionales** | EE. UU. (SCC + DPF) |
| **Plazos de supresión** | 12 meses para logs de envío |
| **Medidas técnicas y organizativas** | TLS en SMTP, app-password rotada periódicamente, pie RGPD en cada plantilla de correo |

## Actividad 05 — Auditoría y seguridad de la información

| Campo | Detalle |
| --- | --- |
| **Finalidad** | Registro de acciones críticas (creación, edición, baja de usuarios, cambios de rol, accesos administrativos) y de eventos de pago |
| **Base jurídica** | Interés legítimo (art. 6.1.f) — garantizar la seguridad e integridad del sistema (considerando 49 RGPD) |
| **Categorías de interesados** | Empleados, administradores, clientes finales |
| **Categorías de datos** | Identificador de actor, acción, objetivo, IP, timestamp, detalle |
| **Categorías de destinatarios** | Personal autorizado del responsable |
| **Transferencias internacionales** | Almacenamiento en MongoDB Atlas (SCC + DPF) |
| **Plazos de supresión** | 12 meses |
| **Medidas técnicas y organizativas** | Acceso restringido por rol (`admin`/`super_admin`), índices, cifrado en reposo |

## Actividad 06 — Geolocalización para entrega

| Campo | Detalle |
| --- | --- |
| **Finalidad** | Permitir el reparto a domicilio mediante coordenadas GPS de la dirección de entrega |
| **Base jurídica** | Ejecución de contrato + consentimiento explícito (uso de Geolocator en el dispositivo) |
| **Categorías de interesados** | Clientes finales que solicitan envío a domicilio |
| **Categorías de datos** | Latitud, longitud asociadas al pedido; opcionalmente almacenadas en el perfil del usuario como dirección por defecto |
| **Categorías de destinatarios** | Personal del restaurante encargado del reparto |
| **Transferencias internacionales** | Ninguna específica |
| **Plazos de supresión** | Eliminadas del pedido al pasar a `entregado` o `cancelado`; eliminables del perfil mediante el endpoint de baja RGPD |
| **Medidas técnicas y organizativas** | Pantalla previa con explicación de la finalidad antes de solicitar el permiso al sistema operativo; minimización (sólo durante ciclo activo); permisos no se solicitan cuando no es necesario |

---

## Encargados del tratamiento (art. 28 RGPD)

| Encargado | Servicio | Contrato | Última verificación |
| --- | --- | --- | --- |
| MongoDB Inc. | Almacenamiento (Atlas) | DPA estándar de MongoDB Atlas | `<fecha>` |
| Stripe Payments Europe Ltd. | Procesamiento de pagos | DPA Stripe | `<fecha>` |
| PayPal (Europe) S.à r.l. | Procesamiento de pagos | DPA PayPal | `<fecha>` |
| Google LLC | SMTP (Gmail) | Términos de Google Workspace | `<fecha>` |
| Apple Distribution International | Apple Pay | Términos del Apple Developer Program | `<fecha>` |
| `<Hosting / Cloud provider>` | Infraestructura | DPA del proveedor | `<fecha>` |

---

## Análisis de riesgo (resumen)

| Riesgo | Probabilidad | Impacto | Medidas |
| --- | --- | --- | --- |
| Acceso no autorizado a la base de datos | Media | Alto | TLS, IP allowlist, credenciales rotadas, auditoría, JWT con expiración |
| Filtración de credenciales en repo | Baja (tras la remediación) | Alto | `.env` fuera de git, pre-commit con `gitleaks`, secret manager |
| Compromiso de cuenta de usuario | Media | Medio | bcrypt, 2FA opcional, rate limiting, TTL de códigos OTP |
| Fraude de pago | Baja | Alto | Webhook firmado de Stripe como fuente de verdad |
| Pérdida de stock por race condition | Baja | Medio | Transacciones MongoDB; fallback atómico cuando es standalone |
| Filtración de datos por correo | Baja | Medio | App-password de Gmail rotada, TLS SMTP |

## Brechas de seguridad

Existe procedimiento documentado para notificar brechas a la AEPD en
**72 horas** (art. 33 RGPD) y a los afectados (art. 34 RGPD) si supone
un riesgo alto. Plantilla de comunicación en `docs/legal/plantilla_brecha.md`
`<crear si no existe>`.

## Revisiones

| Fecha | Responsable | Cambios |
| --- | --- | --- |
| 2026-05-04 | `<Nombre>` | Creación inicial del RAT (v1.0) |

---

## Notas finales

- Este RAT es **obligatorio** si la organización tiene 250 o más
  empleados, o si trata datos de manera no ocasional, o si trata
  categorías especiales o relativas a condenas penales (art. 30.5 RGPD).
  Aunque tu organización quede fuera por número de empleados, **mantenerlo
  es buena práctica y exigible cuando se realizan tratamientos a gran
  escala**.
- Documento sujeto a revisión por asesoría legal antes de considerarlo
  definitivo.
