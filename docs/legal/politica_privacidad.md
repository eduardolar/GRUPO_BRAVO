# Política de Privacidad — Restaurante Bravo

**Última actualización**: 4 de mayo de 2026
**Versión**: 1.0

> ⚠ **Aviso al equipo**: este texto es una **plantilla base** redactada conforme
> al RGPD (UE) 2016/679 y la LOPDGDD 3/2018. Antes de publicarlo en
> `https://grupobravo.com/privacidad`, **debe revisarlo un asesor jurídico**
> y completar los datos marcados con `<...>`.

---

## 1. Responsable del tratamiento

| Campo | Valor |
| --- | --- |
| Denominación | Grupo Bravo / Restaurante Bravo |
| CIF / NIF | `<CIF de la empresa>` |
| Domicilio | `<Dirección postal>` |
| Email de contacto | privacidad@grupobravo.com |
| Teléfono | `<Teléfono de contacto>` |
| Delegado de Protección de Datos (DPO) | `<Nombre / "No aplica">` |

## 2. Finalidades del tratamiento

Los datos personales que nos facilitas se tratan para las siguientes finalidades:

1. **Gestión de tu cuenta de usuario**: registro, inicio de sesión, recuperación
   de contraseña, doble factor (2FA) por correo o aplicación autenticadora.
2. **Gestión de pedidos**: comandas en mesa, pedidos a domicilio o para recoger,
   reservas, comunicaciones operativas (confirmaciones, estado del pedido,
   facturas).
3. **Procesamiento de pagos**: ejecución del cobro a través de nuestros
   proveedores Stripe, PayPal, Apple Pay y Google Pay.
4. **Atención al cliente**: respuesta a tus consultas, gestión de reclamaciones
   y derechos ARSULIPO.
5. **Cumplimiento de obligaciones legales**: contables, fiscales y mercantiles.
6. **Mejora del servicio**: análisis estadístico interno con datos agregados o
   anonimizados (sin perfilar individualmente).

**No realizamos** elaboración de perfiles automatizados que produzcan efectos
jurídicos sobre ti, ni decisiones automatizadas sin intervención humana.

## 3. Categorías de datos tratados

- **Identificativos**: nombre, apellidos, correo electrónico, teléfono.
- **Postales**: dirección de entrega.
- **Geolocalización**: coordenadas GPS de la dirección de entrega, sólo
  durante el ciclo activo del pedido. Tras la entrega o cancelación, las
  coordenadas son **eliminadas** del documento del pedido.
- **Transaccionales**: histórico de pedidos, importes, métodos de pago.
- **Técnicos**: IP, dispositivo, fecha/hora del consentimiento, identificadores
  de sesión.

**No tratamos** categorías especiales de datos (salud, ideología, origen,
biometría) salvo que tú las introduzcas voluntariamente en notas (p. ej.
alergias). En ese caso, la base es tu **consentimiento explícito** y se
minimiza al máximo posible.

## 4. Base jurídica del tratamiento

| Finalidad | Base legal |
| --- | --- |
| Cuenta de usuario y pedidos | Ejecución de contrato (art. 6.1.b RGPD) |
| Pagos | Ejecución de contrato + obligación legal |
| Doble factor (2FA) | Interés legítimo (seguridad de la cuenta) |
| Comunicaciones operativas | Ejecución de contrato |
| Marketing (si aplica) | Consentimiento explícito (art. 6.1.a) |
| Obligaciones contables y fiscales | Obligación legal (art. 6.1.c) |
| Geolocalización | Ejecución de contrato (entrega) y consentimiento |

## 5. Plazos de conservación

| Dato / Finalidad | Plazo |
| --- | --- |
| Cuenta de usuario activa | Mientras mantengas la cuenta |
| Cuenta tras solicitud de baja | Anonimización inmediata; se conservan datos contables del pedido durante 6 años (art. 30 Código de Comercio) |
| Geolocalización del pedido | Sólo durante el ciclo activo; eliminación al pasar a `entregado`/`cancelado` |
| Logs técnicos y de auditoría | 12 meses |
| Datos de pago (referencias) | 6 años por obligación fiscal |
| Códigos de verificación (OTP, 2FA, reset) | 15 minutos (TTL técnico) |

## 6. Destinatarios y cesiones

Tus datos pueden ser comunicados a los siguientes encargados o
corresponsables (siempre con contrato art. 28 RGPD):

| Destinatario | Finalidad | País / Mecanismo de transferencia |
| --- | --- | --- |
| Stripe Payments Europe Ltd. | Procesamiento de pagos con tarjeta | Irlanda (UE); transferencias a EE. UU. con SCC y certificación DPF |
| PayPal (Europe) S.à r.l. | Procesamiento de pagos PayPal | Luxemburgo (UE) |
| Apple Distribution International | Apple Pay | Irlanda (UE) |
| Google Ireland Ltd. | Google Pay | Irlanda (UE); transferencias a EE. UU. con SCC y DPF |
| MongoDB Atlas (MongoDB Inc.) | Almacenamiento de la base de datos | Región contratada en la UE; transferencias a EE. UU. con SCC y DPF |
| Google LLC (SMTP / Gmail) | Envío de correos transaccionales | EE. UU. con SCC y DPF |
| Hacienda y entidades financieras | Cumplimiento de obligaciones legales | España |

No realizamos cesiones a terceros con fines publicitarios sin tu
consentimiento.

## 7. Derechos del interesado (ARSULIPO)

Tienes los siguientes derechos, reconocidos en los arts. 15-22 RGPD:

- **A**cceso a tus datos.
- **R**ectificación de datos inexactos.
- **Su**presión ("derecho al olvido").
- **L**imitación del tratamiento.
- **P**ortabilidad de los datos (formato JSON).
- **O**posición al tratamiento.

Puedes ejercerlos:

1. **Desde la propia app**: pantalla "Mi cuenta" → "Descargar mis datos" o
   "Eliminar mi cuenta".
   - `GET /api/v1/usuarios/{id}/mis-datos` — descarga tus datos.
   - `DELETE /api/v1/usuarios/{id}/mi-cuenta` — anonimiza tu cuenta.
2. **Por correo**: privacidad@grupobravo.com adjuntando copia de DNI/NIE.
3. **Plazo de respuesta**: máximo un mes (prorrogable a tres en casos
   complejos, con notificación previa).

Tienes derecho a **presentar una reclamación ante la Agencia Española
de Protección de Datos** (AEPD): https://www.aepd.es

## 8. Medidas de seguridad

Aplicamos las siguientes medidas técnicas y organizativas (art. 32 RGPD):

- Autenticación con **JWT firmados** y **2FA opcional** (TOTP / correo).
- **Hash bcrypt** para contraseñas (no se almacenan en claro).
- **TLS 1.2+** en todas las comunicaciones cliente-servidor en producción.
- **Cifrado en reposo** en MongoDB Atlas.
- **Tokenización de tarjetas** vía Stripe (la app no almacena PAN/CVV).
- **Webhook firmado** de Stripe como fuente de verdad de los pagos.
- **Auditoría** de accesos críticos (creación, edición y baja de usuarios,
  cambios de rol).
- **Rate limiting** en endpoints sensibles para mitigar fuerza bruta.
- **Códigos OTP con TTL** de 15 minutos.
- Acceso a la base de datos restringido por **IP allowlist** y credenciales
  rotadas periódicamente.

## 9. Menores de edad

Para usar el servicio debes tener **16 años cumplidos** (art. 7 LOPDGDD).
Si detectamos que se han recogido datos de un menor sin el consentimiento de
los titulares de la patria potestad, los eliminaremos a la mayor brevedad.

## 10. Cookies

Consulta nuestra [Política de Cookies](politica_cookies.md) para conocer
qué identificadores almacenamos en tu dispositivo y cómo desactivarlos.

## 11. Modificaciones de esta política

Nos reservamos el derecho de actualizar esta política para adaptarla a
novedades legales o cambios del servicio. Las versiones anteriores se
conservarán y la fecha de última actualización aparecerá siempre al
inicio del documento.

## 12. Contacto

Para cualquier cuestión sobre privacidad:

- 📧 privacidad@grupobravo.com
- 📮 `<Dirección postal completa>`

Si no quedas satisfecho con nuestra respuesta, puedes contactar con la AEPD
(https://www.aepd.es) o con el Defensor del Pueblo correspondiente.
