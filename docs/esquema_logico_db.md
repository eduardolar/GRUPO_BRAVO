**Esquema Lógico de la Base de Datos - Sistema de Comandas**
(Incluye Gestión de Usuarios Unificada y Delivery)

1. **Entidades y Atributos**

*USUARIOS* (id_usuario [PK], dni, nombre, apellido, email, nombre_usuario, password_hash, salario, rol [admin, camarero, cocinero, repartidor])

*CLIENTES* (id_cliente [PK], dni, nombre, email, telefono, direccion_frecuente)

*MESAS* (id_mesa [PK], numero_mesa, capacidad, estado [libre, ocupada, reservada])

*CATEGORIAS* (id_categoria [PK], nombre_categoria)

*PRODUCTOS* (id_producto [PK], nombre, descripcion, precio, stock, id_categoria [FK])

*PEDIDOS* (id_pedido [PK], fecha, hora, total, tipo_pedido [en_local, domicilio, recoger], estado_pedido [pendiente, en_preparacion, listo, entregado, cancelado], id_usuario [FK], id_mesa [FK, opcional], id_cliente [FK, opcional])

*DETALLE_PEDIDO* (id_detalle [PK], cantidad, precio_unitario, notas, id_pedido [FK], id_producto [FK])

*DATOS_DOMICILIO* (id_domicilio [PK], direccion_envio, codigo_postal, telefono_contacto, notas_repartidor, id_pedido [FK], id_repartidor [FK])

2. **Relaciones y Cardinalidad**

USUARIOS - PEDIDOS (1:N): Un usuario (camarero) puede registrar muchos pedidos. Un pedido pertenece a un único usuario.

MESAS - PEDIDOS (1:N): Una mesa puede estar asociada a muchos pedidos a lo largo del tiempo. Un pedido en local pertenece a una mesa.

CLIENTES - PEDIDOS (1:N): Un cliente puede realizar muchos pedidos. Un pedido puede estar asociado a un cliente (opcional).

CATEGORIAS - PRODUCTOS (1:N): Una categoría engloba muchos productos. Un producto pertenece a una sola categoría.

PEDIDOS - DETALLE_PEDIDO (1:N): Un pedido contiene una o varias líneas de detalle (productos).

PRODUCTOS - DETALLE_PEDIDO (1:N): Un producto puede aparecer en muchos detalles de diferentes pedidos.

PEDIDOS - DATOS_DOMICILIO (1:1): Un pedido de tipo "domicilio" tiene una única entrada de datos de envío.

USUARIOS (Repartidor) - DATOS_DOMICILIO (1:N): Un repartidor puede entregar muchos pedidos a domicilio.