-- 1. Usuarios
CREATE TABLE usuarios (
    id_usuario INT AUTO_INCREMENT PRIMARY KEY,
    dni VARCHAR(10) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    nombre_usuario VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    rol ENUM('admin', 'camarero', 'cocinero', 'repartidor') NOT NULL
);

-- 2. Mesas
CREATE TABLE mesas (
    id_mesa INT AUTO_INCREMENT PRIMARY KEY,
    numero_mesa INT UNIQUE NOT NULL,
    estado ENUM('libre', 'ocupada', 'reservada') DEFAULT 'libre'
);

-- 3. Categorías
CREATE TABLE categorias (
    id_categoria INT AUTO_INCREMENT PRIMARY KEY,
    nombre_categoria VARCHAR(50) NOT NULL
);

-- 4. Productos
CREATE TABLE productos (
    id_producto INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio DECIMAL(10, 2) NOT NULL,
    stock INT DEFAULT 0,
    id_categoria INT,
    FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria)
);

-- 5. Pedidos
CREATE TABLE pedidos (
    id_pedido INT AUTO_INCREMENT PRIMARY KEY,
    fecha_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tipo_pedido ENUM('en_local', 'domicilio', 'recoger') NOT NULL,
    estado_pedido ENUM('pendiente', 'preparacion', 'listo', 'entregado') DEFAULT 'pendiente',
    id_usuario INT,
    id_mesa INT NULL,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario),
    FOREIGN KEY (id_mesa) REFERENCES mesas(id_mesa)
);

-- 6. Detalle de Pedido
CREATE TABLE detalle_pedido (
    id_detalle INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido INT,
    id_producto INT,
    cantidad INT NOT NULL,
    notas TEXT,
    FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

-- 7. Reservas
CREATE TABLE reservas (
    id_reserva INT AUTO_INCREMENT PRIMARY KEY,
    id_mesa INT,
    fecha_reserva DATE NOT NULL,
    hora_reserva TIME NOT NULL,
    num_personas INT NOT NULL,
    estado ENUM('confirmada', 'cancelada', 'finalizada') DEFAULT 'confirmada',
    FOREIGN KEY (id_mesa) REFERENCES mesas(id_mesa)
);

-- 8. Ingredientes
CREATE TABLE ingredientes (
    id_ingrediente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    cantidad_actual DECIMAL(10, 2) NOT NULL,
    unidad_medida ENUM('kg', 'l', 'unidades', 'g') NOT NULL,
    stock_minimo DECIMAL(10, 2) NOT NULL
);

SET FOREIGN_KEY_CHECKS = 1;


-- Añadí las tablas que faltaban

USE comandas_db;

-- 9. Tabla de Clientes (Faltaba para reservas y domicilio)
CREATE TABLE IF NOT EXISTS clientes (
    id_cliente INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    telefono VARCHAR(20),
    direccion_frecuente VARCHAR(255)
);

-- 10. Tabla de Datos de Domicilio (relaciona pedido con repartidor )
CREATE TABLE IF NOT EXISTS datos_domicilio (
    id_domicilio INT AUTO_INCREMENT PRIMARY KEY,
    id_pedido INT UNIQUE,
    direccion_envio VARCHAR(255) NOT NULL,
    codigo_postal VARCHAR(10),
    telefono_contacto VARCHAR(20),
    notas_repartidor TEXT,
    id_repartidor INT,
    FOREIGN KEY (id_pedido) REFERENCES pedidos(id_pedido),
    FOREIGN KEY (id_repartidor) REFERENCES usuarios(id_usuario)
);

-- 11. Tabla de movimientos de almacén (Control de stock para cocineros)
CREATE TABLE IF NOT EXISTS movimientos_almacen (
    id_movimiento INT AUTO_INCREMENT PRIMARY KEY,
    tipo ENUM('entrada', 'salida', 'ajuste') NOT NULL,
    cantidad DECIMAL(10, 2) NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    id_ingrediente INT,
    id_usuario INT, -- El cocinero o admin que hace el movimiento
    FOREIGN KEY (id_ingrediente) REFERENCES ingredientes(id_ingrediente),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

-- Modificación (Para que Pedidos pueda tener Clientes)
-- Como la tabla pedidos ya existe,se le añade la columna faltante:
ALTER TABLE pedidos ADD COLUMN id_cliente INT;
ALTER TABLE pedidos ADD FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente);
