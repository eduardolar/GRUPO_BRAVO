# Plantilla de notificación de brecha de seguridad (art. 33 y 34 RGPD)

Documento interno. Si se produce una brecha de seguridad de datos
personales, **se debe notificar a la AEPD en un plazo máximo de 72 horas**
desde el momento en que se tiene conocimiento, salvo que sea improbable
que constituya un riesgo para los derechos y libertades de las personas
físicas.

Si la brecha entraña **alto riesgo**, se debe comunicar también a los
afectados sin dilación indebida (art. 34 RGPD).

---

## Procedimiento interno

1. **Detección y contención**
   - Persona que detecta: registra fecha, hora, sistema y descripción.
   - Aislar el sistema afectado para detener el incidente.
   - Cambiar credenciales potencialmente comprometidas.

2. **Evaluación**
   - ¿Qué datos personales se han visto afectados?
   - ¿Cuántos interesados aproximados?
   - ¿Probabilidad e impacto en derechos y libertades?

3. **Decisión sobre notificación**
   - Si **es probable** que entrañe riesgo → notificar a la AEPD (≤ 72 h).
   - Si entrañe **alto riesgo** → notificar también a los afectados.
   - Si **no entraña riesgo** (cifrado robusto, datos ininteligibles, etc.)
     → documentar la decisión, pero no notificar.

4. **Notificación a la AEPD**
   - Sede electrónica: https://sedeagpd.gob.es/sede-electronica-web/vistas/formBrechaSeguridad/procedimientoBrechaSeguridad.jsf
   - Adjuntar el formulario interno de brecha (apartado siguiente).

5. **Notificación a los afectados** (si procede)
   - Comunicación clara, en lenguaje sencillo, indicando la naturaleza
     de la brecha, las consecuencias probables y las medidas adoptadas.

6. **Documentación**
   - Registrar todas las brechas (incluso las no notificadas) en
     `docs/legal/registro_brechas.md` con su análisis.

---

## Formulario interno de la brecha

Completar y enviar a `privacidad@grupobravo.com` lo antes posible.

```
1. Datos identificativos
   - Responsable: <Razón social, CIF>
   - DPO o persona de contacto: <Nombre, email, teléfono>

2. Datos de la brecha
   - Fecha y hora de detección: <YYYY-MM-DD HH:MM>
   - Fecha aproximada del inicio: <YYYY-MM-DD HH:MM>
   - ¿Continúa abierta? Sí / No

3. Origen
   - <Acceso no autorizado / pérdida de dispositivo / phishing /
     ransomware / vulnerabilidad explotada / error humano / otro>

4. Sistemas afectados
   - <Backend / MongoDB Atlas / SMTP / Stripe / app móvil / etc.>

5. Datos personales afectados
   - Categorías: <identificativos, postales, geolocalización, pago,
     hashes de contraseña, ...>
   - Número aproximado de interesados: <N>
   - Categorías de interesados: <clientes, empleados, ...>

6. Posibles consecuencias
   - <Suplantación, fraude, daños reputacionales, pérdida económica,
     discriminación, ...>

7. Medidas adoptadas
   - <Rotación de credenciales, parcheo, bloqueo de cuentas,
     comunicación a afectados, ...>

8. Medidas previstas
   - <Auditoría externa, refuerzo de controles, formación,
     actualización de políticas, ...>
```

---

## Plantilla de comunicación a los afectados

> Asunto: Notificación de incidente de seguridad — Restaurante Bravo
>
> Estimado/a `<nombre>`:
>
> Te escribimos para informarte de un incidente de seguridad que afecta a
> determinados datos personales que tenías registrados en Restaurante Bravo.
>
> **¿Qué ha pasado?**
> El día `<fecha>` detectamos `<descripción breve>`. Como consecuencia,
> los siguientes datos pueden haberse visto comprometidos: `<categorías>`.
>
> **¿Qué hemos hecho?**
> - `<Medidas adoptadas>`.
> - Hemos notificado el incidente a la Agencia Española de Protección de
>   Datos.
>
> **¿Qué te recomendamos?**
> - `<Cambiar tu contraseña / activar 2FA / vigilar movimientos en tu
>   tarjeta...>`
>
> Lamentamos profundamente este incidente. Si tienes cualquier duda,
> escríbenos a privacidad@grupobravo.com.
>
> Atentamente,
> Restaurante Bravo
