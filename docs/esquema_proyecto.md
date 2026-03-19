#  Planificación del Sistema de Comandas - Bar/Cafetería/Restaurante

##  Flujos de la App

1. **Flujo de acceso:**
   *Login de empleado (camarero/cocinero/admin)*
   - El empleado introduce su pin o credenciales.
   - El sistema valida el rol (camarero, cocinero o administrador).

2. **Flujo de servicio (Camarero):**
   *Vista principal* 
   - Ver el mapa de mesas (colores según estado: Verdes:libres, Naranjas: ocupadas, Rojas: pendientes de pago).
   - Seleccionar mesa -> Abrir comanda.
   - Añadir productos (buscando por categorías o nombre).
   - Notas (opcional), ejm: "sin hielo", "con sacarina", etc
   - Confirmar pedido -> se envía automáticamente a cocina.

3. **Flujo de preparación (Cocina):**
   - Pantalla con lista de platos pendientes (ordenados por tiempo de espera).
   - El cocinero marca "En preparación".
   - Al terminar, marca "Pedido listo" ( para avisar al camarero).

4. **Flujo de cierre y pago:**
   - Seleccionar mesa ocupada -> Ver resumen de cuenta.
   - Seleccionar método de pago (efectivo o tarjeta).
   - Imprimir ticket y marcar mesa como "Libre".


    ## Esquema de BBDD (tablas)

- **Usuarios:** id, nombre, pin_seguridad, rol.
- **Mesas:** id, numero_messa, estado (libre/ocupada).
- **Categorias:** id, nombre (Bebidas, Raciones, Bocadillos).
- **Productos:** id, nombre, precio, categoria_id, disponible (bool).
- **Comandas:** id, mesa_id, usuario_id, fecha, estado (abierta/cerrada).
- **Detalle_Comanda:** id, comanda_id, producto_id, cantidad, notas.