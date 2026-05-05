# Esquema lógico de la base de datos — MongoDB

**Última revisión**: 4 de mayo de 2026
**Motor real**: MongoDB (Atlas en producción, contenedor `mongo:7` en local).
**Base de datos**: `comandas_db`.

> ⚠ La versión anterior de este documento describía un modelo relacional
> con tablas (USUARIOS, CLIENTES, DETALLE_PEDIDO, etc.) que **no es** lo que
> el código realmente persiste. Este documento ha sido reescrito para
> reflejar el estado actual del proyecto.

---

## 1. Colecciones

| Colección | Constante en `database.py` | Propósito |
| --- | --- | --- |
| `usuarios` | `coleccion_usuarios` | Usuarios unificados: clientes finales, camareros, cocineros, admins, super_admins. |
| `productos` | `coleccion_productos` | Productos del menú. Cada uno con su lista embebida de ingredientes. |
| `categorias` | `coleccion_categorias` | Categorías de productos. |
| `pedidos` | `coleccion_pedidos` | Pedidos en local, a domicilio y para recoger. Items embebidos. |
| `mesas` | `coleccion_mesas` | Mesas físicas del restaurante con código QR único. |
| `reservas` | `coleccion_reservas` | Reservas de mesa por fecha/hora. |
| `ingredientes` | `coleccion_ingredientes` | Inventario de ingredientes con stock actual. |
| `restaurantes` | `coleccion_restaurantes` | Configuración multi-restaurante. |
| `cupones` | `coleccion_cupones` | Cupones promocionales con código único. |
| `auditoria` | `coleccion_auditoria` | Trazabilidad de acciones críticas (USUARIO_CREADO, ROL_CAMBIADO, …). |
| `auditoria_pagos` | `coleccion_auditoria_pagos` | Eventos del módulo de pagos (Stripe, PayPal). |
| `tickets` | `db.tickets` | Tickets abiertos por mesa (acumulan items hasta cerrarse). |

## 2. Diseño de documentos (esquemas orientativos)

MongoDB no impone esquema. Los siguientes diccionarios describen los
campos que el código actual escribe y lee. Los marcados con `?` son
opcionales según la operación.

### 2.1 `usuarios`

```json
{
  "_id": ObjectId,
  "nombre": "string",
  "correo": "string (lowercase, único)",
  "password_hash": "bcrypt",
  "rol": "cliente|camarero|cocinero|admin|super_admin",
  "restaurante_id": "string?",
  "telefono": "string?",
  "direccion": "string?",
  "latitud": "number?",
  "longitud": "number?",
  "is_verified": "bool",
  "activo": "bool",
  "consentimiento_rgpd": "bool",
  "consentimiento_fecha": "ISO 8601",
  "consentimiento_ip": "string",
  "consentimiento_version": "string",
  "verification_code": "string? (TTL 15 min)",
  "verification_code_expiry": "ISO 8601?",
  "reset_code": "string? (TTL 15 min)",
  "reset_code_expiry": "ISO 8601?",
  "totp_enabled": "bool",
  "totp_secret": "string?",
  "email_2fa_enabled": "bool",
  "login_code_2fa": "string? (TTL 15 min)",
  "login_code_2fa_expiry": "ISO 8601?",
  "recovery_codes": ["sha256-hex"],
  "rgpd_baja": "bool",
  "rgpd_baja_fecha": "ISO 8601?"
}
```

### 2.2 `productos`

```json
{
  "_id": ObjectId,
  "nombre": "string",
  "descripcion": "string",
  "precio": "number",
  "categoria": "string",
  "restaurante_id": "string",
  "imagenUrl": "string?",
  "ingredientes": [
    {"nombre": "string", "cantidad_receta": "number"}
  ]
}
```

### 2.3 `categorias`

```json
{
  "_id": ObjectId,
  "nombre": "string",
  "restaurante_id": "string"
}
```

### 2.4 `pedidos`

```json
{
  "_id": ObjectId,
  "usuario_id": "string",
  "items": [
    {
      "producto_id": "string",
      "nombre": "string",
      "cantidad": "number",
      "precio": "number",
      "sin": ["ingrediente"]
    }
  ],
  "tipo_entrega": "local|domicilio|recoger",
  "metodo_pago": "string",
  "total": "number",
  "notas": "string?",
  "fecha": "ISO 8601",
  "estado": "pendiente|preparando|listo|entregado|cancelado",
  "estado_pago": "pendiente|pagado|fallido",
  "referencia_pago": "string?",
  "stripe_payment_intent_id": "string?",
  "fecha_pago": "ISO 8601?",
  "direccion_entrega": "string?",
  "mesa_id": "string?",
  "numero_mesa": "number?",
  "restaurante_id": "string?",
  "latitud": "number? (sólo durante ciclo activo)",
  "longitud": "number? (eliminado al pasar a entregado/cancelado)"
}
```

### 2.5 `mesas`

```json
{
  "_id": ObjectId,
  "numero": "number",
  "capacidad": "number",
  "estado": "libre|ocupada|reservada",
  "codigo_qr": "string (único)",
  "restaurante_id": "string"
}
```

### 2.6 `reservas`

```json
{
  "_id": ObjectId,
  "user_id": "string",
  "fecha": "ISO 8601",
  "hora": "string",
  "personas": "number",
  "estado": "confirmada|cancelada|finalizada",
  "mesa_id": "string?",
  "restaurante_id": "string"
}
```

### 2.7 `ingredientes`

```json
{
  "_id": ObjectId,
  "nombre": "string",
  "cantidad_actual": "number",
  "stock_minimo": "number",
  "unidad": "string (texto libre por ahora)",
  "restaurante_id": "string"
}
```

### 2.8 `restaurantes`

```json
{
  "_id": ObjectId,
  "nombre": "string",
  "direccion": "string",
  "horario": {"...": "..."},
  "activo": "bool"
}
```

### 2.9 `cupones`

```json
{
  "_id": ObjectId,
  "codigo": "string (uppercase, único)",
  "tipo": "porcentaje|fijo",
  "valor": "number",
  "descripcion": "string",
  "activo": "bool",
  "usos_maximos": "number?",
  "usos_actuales": "number",
  "fecha_inicio": "YYYY-MM-DD?",
  "fecha_fin": "YYYY-MM-DD?"
}
```

### 2.10 `auditoria`

```json
{
  "_id": ObjectId,
  "fecha": "ISO 8601",
  "accion": "USUARIO_CREADO|USUARIO_EDITADO|USUARIO_ELIMINADO|ROL_CAMBIADO|...",
  "actor": "correo del actor",
  "objetivo": "correo|id afectado",
  "detalle": "string"
}
```

### 2.11 `auditoria_pagos`

```json
{
  "_id": ObjectId,
  "fecha": "ISO 8601",
  "evento": "stripe.intent_created|stripe.webhook.succeeded|...",
  "proveedor": "stripe|paypal|apple_pay|google_pay",
  "importe": "number?",
  "moneda": "string?",
  "referencia": "string?",
  "estado": "string",
  "detalle": "string?",
  "ip": "string?"
}
```

### 2.12 `tickets`

```json
{
  "_id": ObjectId,
  "mesa_id": "string",
  "estado": "abierto|cerrado",
  "items": [
    {"producto_id": "string", "nombre": "string", "cantidad": "number",
     "precio_unitario": "number", "subtotal": "number"}
  ],
  "total": "number",
  "fecha": "ISO 8601",
  "fecha_cierre": "ISO 8601?"
}
```

## 3. Relaciones efectivas (referencias)

MongoDB es no-relacional, pero el dominio sí tiene referencias lógicas:

- `pedidos.usuario_id` → `usuarios._id`
- `pedidos.mesa_id` → `mesas._id`
- `pedidos.restaurante_id` → `restaurantes._id`
- `pedidos.items[].producto_id` → `productos._id`
- `productos.categoria` → `categorias.nombre` (string, no `_id`)
- `productos.ingredientes[].nombre` → `ingredientes.nombre`
- `reservas.mesa_id` → `mesas._id`
- `tickets.mesa_id` → `mesas._id`
- `auditoria.actor` / `auditoria.objetivo` → `usuarios.correo`

## 4. Índices

Definidos en `backend/scripts/init_indexes.py`. Lista resumida:

- `usuarios.correo` → único
- `usuarios.rol`, `usuarios.restaurante_id`
- `pedidos {user_id, fecha desc}`, `pedidos {restaurante_id, estado, fecha desc}`
- `pedidos.estado_pago`, `pedidos.stripe_payment_intent_id` (sparse)
- `mesas.codigo_qr` → único sparse
- `mesas {restaurante_id, estado}`
- `reservas {restaurante_id, fecha}`, `reservas.user_id`
- `productos {restaurante_id, categoria}`
- `cupones.codigo` → único, `cupones.activo`
- `auditoria.fecha desc`, `auditoria_pagos.fecha desc`

## 5. Diferencias respecto al modelo relacional original

Estas son las decisiones de diseño que se tomaron en la implementación
y que difieren del esquema relacional descrito en versiones anteriores
del documento:

| Cambio | Justificación |
| --- | --- |
| `USUARIOS` y `CLIENTES` se unifican en `usuarios` | Un cliente final también es un usuario con autenticación; mantener dos colecciones duplicaba lógica de login y de baja RGPD. |
| No existe colección `DETALLE_PEDIDO` | MongoDB favorece embeber: los items viajan dentro del documento `pedidos.items`. Reduce JOINs, transacciones y latencia. |
| No se almacenan `dni` ni `salario` | Minimización de datos personales (RGPD). El `dni` no es necesario para el negocio digital y exigiría medidas de cifrado adicionales. |
| `unidad_medida` es texto libre, no enum | Pendiente de migrar a enum si se requiere homogeneizar. |
| No existe `MOVIMIENTOS_ALMACEN` | Los descuentos se aplican atómicamente sobre `ingredientes.cantidad_actual` desde el flujo de pedido. La auditoría queda en `auditoria_pagos` para pagos y en `auditoria` para acciones de gestión. |

## 6. Migraciones recomendadas

- Renombrar campos en notación inconsistente: `codigoQr`/`codigo_qr`,
  `restauranteId`/`restaurante_id`. Convención: **snake_case en BD**,
  **camelCase en API/JSON**. Aplicar serializadores en frontera.
- Migrar `unidad` de ingredientes a enum.
- Verificar y migrar valores legacy de `rol` (`mesero`, `administrador`,
  `superadministrador`) a los canónicos (`camarero`, `admin`,
  `super_admin`).

## 7. Ejecución

```bash
cd backend
python -m scripts.init_indexes   # crea índices (idempotente)
```
