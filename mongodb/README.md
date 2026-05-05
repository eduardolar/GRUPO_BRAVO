# Datos semilla (NO usar en producción)

Estos JSON son datos sintéticos para sembrar la base de datos en desarrollo
y para reproducir comportamientos durante las demos. **No** deben cargarse
contra MongoDB Atlas en producción.

## Importar en local

```bash
# Sustituye el host/puerto si tu Mongo no es local
mongoimport --db comandas_db --collection clientes --jsonArray --file clientes.json
mongoimport --db comandas_db --collection usuarios --jsonArray --file usuarios.json
# ...
```

## Notas

- Los datos personales son completamente sintéticos. Si en algún momento
  vuelves a meter nombres reales en estos archivos:
  - **violarás el principio de minimización del RGPD**, y
  - dejarás un rastro permanente en el histórico de Git que sólo se
    podría limpiar con `git filter-repo`.
- `pedidos.json` contiene un placeholder `<RELLENAR_CON_ID_REAL_TRAS_INSERTAR_CLIENTES>`.
  Antes de cargar esa colección, sustituye ese valor por el `_id` del
  cliente correspondiente.
- Como mejor práctica, **regenerar siempre con `faker`**:
  https://faker.readthedocs.io
