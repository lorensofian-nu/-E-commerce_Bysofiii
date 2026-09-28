-- ============================================================
-- E-commerce BySofiii
-- 01_Esquema_y_Datos.sql
-- Motor objetivo: MySQL 8.0+
-- ============================================================

DROP DATABASE IF EXISTS ecommerce_bysofii;
CREATE DATABASE ecommerce_bysofii
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE ecommerce_bysofii;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE sucursales (
    id_sucursal INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    ciudad VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    direccion VARCHAR(255) NOT NULL,
    activa BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE usuario_sucursal (
    id_usuario_sucursal INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    login_usuario VARCHAR(100) NOT NULL UNIQUE,
    id_sucursal INT UNSIGNED NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_usuario_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE categorias (
    id_categoria INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(500),
    id_categoria_padre INT UNSIGNED NULL,
    producto_count INT UNSIGNED NOT NULL DEFAULT 0,
    CONSTRAINT fk_categoria_padre
        FOREIGN KEY (id_categoria_padre) REFERENCES categorias(id_categoria)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE proveedores (
    id_proveedor INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    email_contacto VARCHAR(190) NOT NULL UNIQUE,
    telefono_contacto VARCHAR(40),
    ciudad VARCHAR(100),
    activo BOOLEAN NOT NULL DEFAULT TRUE
) ENGINE=InnoDB;

CREATE TABLE clientes (
    id_cliente INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    email VARCHAR(190) NOT NULL UNIQUE,
    `contraseña` VARCHAR(255) NOT NULL COMMENT 'Debe almacenar únicamente hash Argon2id/bcrypt, nunca texto plano',
    direccion_envio VARCHAR(255),
    ciudad VARCHAR(100),
    region VARCHAR(100),
    fecha_nacimiento DATE NULL,
    id_sucursal INT UNSIGNED NOT NULL,
    id_referido_por INT UNSIGNED NULL,
    total_gastado DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (total_gastado >= 0),
    fecha_ultimo_pedido DATETIME NULL,
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultimo_acceso DATETIME NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    deleted_at DATETIME NULL,
    CONSTRAINT fk_cliente_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal),
    CONSTRAINT fk_cliente_referido FOREIGN KEY (id_referido_por) REFERENCES clientes(id_cliente)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT chk_cliente_email CHECK (email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$')
) ENGINE=InnoDB;

CREATE TABLE productos (
    id_producto INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(180) NOT NULL UNIQUE,
    descripcion TEXT,
    precio DECIMAL(12,2) NOT NULL CHECK (precio > 0),
    costo DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (costo >= 0),
    stock INT NOT NULL DEFAULT 0 CHECK (stock >= 0),
    stock_minimo INT UNSIGNED NOT NULL DEFAULT 5,
    sku VARCHAR(80) NOT NULL UNIQUE,
    peso_kg DECIMAL(8,3) NOT NULL DEFAULT 0.100 CHECK (peso_kg > 0),
    id_categoria INT UNSIGNED NULL,
    id_proveedor INT UNSIGNED NOT NULL,
    ubicacion VARCHAR(100) NOT NULL DEFAULT 'Bodega principal',
    fecha_creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    deleted_at DATETIME NULL,
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_producto_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE promociones (
    id_promocion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL UNIQUE,
    descuento_pct DECIMAL(5,2) NOT NULL CHECK (descuento_pct > 0 AND descuento_pct <= 100),
    fecha_inicio DATETIME NOT NULL,
    fecha_fin DATETIME NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_promocion_fechas CHECK (fecha_fin > fecha_inicio)
) ENGINE=InnoDB;

CREATE TABLE producto_promocion (
    id_producto INT UNSIGNED NOT NULL,
    id_promocion INT UNSIGNED NOT NULL,
    PRIMARY KEY (id_producto, id_promocion),
    CONSTRAINT fk_pp_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE,
    CONSTRAINT fk_pp_promocion FOREIGN KEY (id_promocion) REFERENCES promociones(id_promocion) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE ventas (
    id_venta INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    id_sucursal INT UNSIGNED NOT NULL,
    fecha_venta DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('Pendiente de Pago','Pagado','Procesando','Enviado','Entregado','Cancelado','Devuelto') NOT NULL DEFAULT 'Pendiente de Pago',
    subtotal DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (subtotal >= 0),
    iva DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (iva >= 0),
    costo_envio DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (costo_envio >= 0),
    total DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (total >= 0),
    direccion_envio_congelada VARCHAR(255) NULL,
    codigo_pago VARCHAR(120) NULL,
    fecha_pago DATETIME NULL,
    CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_venta_sucursal FOREIGN KEY (id_sucursal) REFERENCES sucursales(id_sucursal)
) ENGINE=InnoDB;

CREATE TABLE detalle_ventas (
    id_detalle INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venta INT UNSIGNED NOT NULL,
    id_producto INT UNSIGNED NOT NULL,
    cantidad INT UNSIGNED NOT NULL CHECK (cantidad > 0),
    precio_unitario_congelado DECIMAL(12,2) NOT NULL CHECK (precio_unitario_congelado > 0),
    costo_unitario_congelado DECIMAL(12,2) NOT NULL DEFAULT 0 CHECK (costo_unitario_congelado >= 0),
    subtotal DECIMAL(14,2) AS (cantidad * precio_unitario_congelado) STORED,
    CONSTRAINT uq_venta_producto UNIQUE (id_venta, id_producto),
    CONSTRAINT fk_detalle_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE carritos (
    id_carrito INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado ENUM('Activo','Abandonado','Convertido') NOT NULL DEFAULT 'Activo',
    CONSTRAINT fk_carrito_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
        ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE carrito_detalle (
    id_carrito INT UNSIGNED NOT NULL,
    id_producto INT UNSIGNED NOT NULL,
    cantidad INT UNSIGNED NOT NULL CHECK (cantidad > 0),
    agregado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_carrito, id_producto),
    CONSTRAINT fk_cd_carrito FOREIGN KEY (id_carrito) REFERENCES carritos(id_carrito)
        ON DELETE CASCADE,
    CONSTRAINT fk_cd_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
        ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE vistas_producto (
    id_vista BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NULL,
    id_producto INT UNSIGNED NOT NULL,
    visto_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    session_token VARCHAR(128) NULL,
    CONSTRAINT fk_vista_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE SET NULL,
    CONSTRAINT fk_vista_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE resenas_producto (
    id_resena INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    id_producto INT UNSIGNED NOT NULL,
    id_venta INT UNSIGNED NULL,
    calificacion TINYINT UNSIGNED NOT NULL CHECK (calificacion BETWEEN 1 AND 5),
    comentario VARCHAR(1000),
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_resena_cliente_producto_venta UNIQUE (id_cliente, id_producto, id_venta),
    CONSTRAINT fk_resena_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE,
    CONSTRAINT fk_resena_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE RESTRICT,
    CONSTRAINT fk_resena_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE intentos_pago (
    id_intento BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venta INT UNSIGNED NULL,
    id_cliente INT UNSIGNED NOT NULL,
    resultado ENUM('Exitoso','Fallido') NOT NULL,
    motivo VARCHAR(255),
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_intento_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE SET NULL,
    CONSTRAINT fk_intento_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE creditos_cliente (
    id_credito BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    id_venta INT UNSIGNED NULL,
    monto DECIMAL(14,2) NOT NULL CHECK (monto > 0),
    motivo VARCHAR(255) NOT NULL,
    estado ENUM('Pendiente','Aplicado','Cancelado') NOT NULL DEFAULT 'Pendiente',
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_credito_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_credito_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE ajustes_stock (
    id_ajuste BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_producto INT UNSIGNED NOT NULL,
    id_usuario VARCHAR(100) NOT NULL,
    stock_anterior INT NOT NULL,
    stock_nuevo INT NOT NULL,
    motivo VARCHAR(500) NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ajuste_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
) ENGINE=InnoDB;

CREATE TABLE log_cambios_precio (
    id_log BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_producto INT UNSIGNED NOT NULL,
    precio_anterior DECIMAL(12,2) NOT NULL,
    precio_nuevo DECIMAL(12,2) NOT NULL,
    modificado_por VARCHAR(100) NOT NULL,
    cambiado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE log_estados_pedido (
    id_log BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venta INT UNSIGNED NOT NULL,
    estado_anterior VARCHAR(40) NOT NULL,
    estado_nuevo VARCHAR(40) NOT NULL,
    cambiado_por VARCHAR(100) NOT NULL,
    cambiado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_log_estado_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE auditoria_eventos (
    id_auditoria BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_evento VARCHAR(80) NOT NULL,
    entidad VARCHAR(80) NOT NULL,
    id_entidad BIGINT UNSIGNED NULL,
    descripcion VARCHAR(1000) NOT NULL,
    usuario_bd VARCHAR(128) NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE alertas_stock (
    id_alerta BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_producto INT UNSIGNED NOT NULL,
    stock_actual INT NOT NULL,
    stock_minimo INT NOT NULL,
    estado ENUM('Pendiente','Atendida') NOT NULL DEFAULT 'Pendiente',
    creada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atendida_en DATETIME NULL,
    CONSTRAINT fk_alerta_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE venta_archivo (
    id_archivo BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_venta INT UNSIGNED NOT NULL,
    id_cliente INT UNSIGNED NOT NULL,
    id_sucursal INT UNSIGNED NOT NULL,
    fecha_venta DATETIME NOT NULL,
    estado VARCHAR(40) NOT NULL,
    subtotal DECIMAL(14,2) NOT NULL,
    iva DECIMAL(14,2) NOT NULL,
    costo_envio DECIMAL(12,2) NOT NULL,
    total DECIMAL(14,2) NOT NULL,
    detalles_json JSON NOT NULL,
    archivado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    archivado_por VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE logs_cambios_permisos (
    id_log BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cuenta_objetivo VARCHAR(200) NOT NULL,
    accion VARCHAR(30) NOT NULL,
    privilegio VARCHAR(200) NOT NULL,
    ejecutado_por VARCHAR(200) NOT NULL,
    ejecutado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacion VARCHAR(500)
) ENGINE=InnoDB;

CREATE TABLE auditoria_login_fallido (
    id_fallo BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    usuario_intentado VARCHAR(128) NOT NULL,
    host_origen VARCHAR(255),
    motivo VARCHAR(500),
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE solicitudes_permiso (
    id_solicitud BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cuenta_objetivo VARCHAR(200) NOT NULL,
    accion VARCHAR(30) NOT NULL,
    privilegio VARCHAR(200) NOT NULL,
    solicitado_por VARCHAR(200) NOT NULL,
    estado ENUM('Solicitado','Aprobado','Rechazado') NOT NULL DEFAULT 'Solicitado',
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE tabla_temporal_procesos (
    id_temp BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave VARCHAR(100) NOT NULL,
    valor JSON NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE logs_historicos (
    id_historico BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tipo_log VARCHAR(50) NOT NULL,
    id_origen BIGINT UNSIGNED NOT NULL,
    payload JSON NOT NULL,
    archivado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE reporte_ventas_semanales (
    id_reporte BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    semana_inicio DATE NOT NULL,
    semana_fin DATE NOT NULL,
    cantidad_ventas INT UNSIGNED NOT NULL DEFAULT 0,
    ingresos DECIMAL(16,2) NOT NULL DEFAULT 0,
    generado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (semana_inicio)
) ENGINE=InnoDB;

CREATE TABLE reorder_list (
    id_reorden BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_producto INT UNSIGNED NOT NULL,
    stock_actual INT NOT NULL,
    stock_minimo INT NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    atendido BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_reorden_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE resumen_ventas_diarias (
    fecha DATE PRIMARY KEY,
    cantidad_ventas INT UNSIGNED NOT NULL DEFAULT 0,
    ingresos DECIMAL(16,2) NOT NULL DEFAULT 0,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE rankings_productos (
    id_producto INT UNSIGNED PRIMARY KEY,
    unidades_vendidas BIGINT UNSIGNED NOT NULL DEFAULT 0,
    ingresos DECIMAL(16,2) NOT NULL DEFAULT 0,
    posicion INT UNSIGNED NULL,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ranking_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE kpis_mensuales (
    periodo CHAR(7) PRIMARY KEY,
    ventas INT UNSIGNED NOT NULL DEFAULT 0,
    ingresos DECIMAL(16,2) NOT NULL DEFAULT 0,
    clientes_nuevos INT UNSIGNED NOT NULL DEFAULT 0,
    ticket_promedio DECIMAL(16,2) NOT NULL DEFAULT 0,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE backup_critico (
    id_backup BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    tabla_nombre VARCHAR(100) NOT NULL,
    filas_json JSON NOT NULL,
    generado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE tamano_bd_log (
    id_log BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    esquema VARCHAR(100) NOT NULL,
    bytes_datos BIGINT UNSIGNED NOT NULL DEFAULT 0,
    bytes_indices BIGINT UNSIGNED NOT NULL DEFAULT 0,
    bytes_total BIGINT UNSIGNED NOT NULL DEFAULT 0,
    registrado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE actividad_sospechosa (
    id_actividad BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NULL,
    descripcion VARCHAR(1000) NOT NULL,
    cantidad_eventos INT UNSIGNED NOT NULL,
    detectado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revisado BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_actividad_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE rendimiento_proveedores (
    id_reporte BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_proveedor INT UNSIGNED NOT NULL,
    periodo CHAR(7) NOT NULL,
    unidades_vendidas BIGINT UNSIGNED NOT NULL DEFAULT 0,
    ingresos DECIMAL(16,2) NOT NULL DEFAULT 0,
    posicion INT UNSIGNED NULL,
    generado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (id_proveedor, periodo),
    CONSTRAINT fk_rendimiento_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor)
) ENGINE=InnoDB;

CREATE TABLE carritos_archivo (
    id_archivo BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_carrito INT UNSIGNED NOT NULL,
    id_cliente INT UNSIGNED NOT NULL,
    creado_en DATETIME NOT NULL,
    actualizado_en DATETIME NOT NULL,
    detalles_json JSON NOT NULL,
    archivado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

CREATE TABLE cumpleanios_cupones (
    id_cupon BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    fecha_nacimiento DATE NOT NULL,
    codigo VARCHAR(60) NOT NULL UNIQUE,
    porcentaje DECIMAL(5,2) NOT NULL DEFAULT 10.00,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    utilizado BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_cupon_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_producto_categoria ON productos(id_categoria);
CREATE INDEX idx_producto_proveedor ON productos(id_proveedor);
CREATE INDEX idx_producto_stock ON productos(stock, stock_minimo);
CREATE INDEX idx_venta_cliente_fecha ON ventas(id_cliente, fecha_venta);
CREATE INDEX idx_venta_sucursal_fecha ON ventas(id_sucursal, fecha_venta);
CREATE INDEX idx_venta_fecha ON ventas(fecha_venta);
CREATE INDEX idx_detalle_producto ON detalle_ventas(id_producto);
CREATE INDEX idx_vistas_producto_fecha ON vistas_producto(id_producto, visto_en);
CREATE INDEX idx_carritos_estado_fecha ON carritos(estado, actualizado_en);
CREATE INDEX idx_intentos_pago_cliente_fecha ON intentos_pago(id_cliente, creado_en);

-- ============================================================
-- Datos de ejemplo de E-commerce BySofiii (maquillaje)
-- ============================================================

INSERT INTO sucursales (id_sucursal,nombre,ciudad,region,direccion) VALUES
(1,'BySofiii Bucaramanga','Bucaramanga','Santander','Calle 35 # 18-20'),
(2,'BySofiii Floridablanca','Floridablanca','Santander','Carrera 27 # 31-55'),
(3,'BySofiii Barranquilla','Barranquilla','Atlántico','Carrera 52 # 76-18');

INSERT INTO categorias (id_categoria,nombre,descripcion,id_categoria_padre) VALUES
(1,'Blush','Rubores en crema, polvo y líquidos para dar color a las mejillas',NULL),
(2,'Contorno','Productos para definir y esculpir el rostro',NULL),
(3,'Corporal','Maquillaje y cuidado cosmético para cuerpo',NULL),
(4,'Bases','Bases y tintes para unificar el tono',NULL),
(5,'Labios','Labiales, tintas, gloss y delineadores',NULL),
(6,'Ojos','Sombras, máscaras y delineadores',NULL),
(7,'Iluminador','Productos para aportar luz al rostro y cuerpo',NULL),
(8,'Polvos','Polvos sueltos y compactos para sellar',NULL),
(9,'Correctores','Correctores de cobertura y neutralización',NULL),
(10,'Brochas y Accesorios','Brochas, esponjas y accesorios de aplicación',NULL),
(11,'Skincare','Preparación y cuidado básico de la piel',NULL),
(12,'Uñas','Esmaltes y accesorios para uñas',NULL),
(13,'Blush Cremoso','Subcategoría de blush cremoso',1),
(14,'Contorno en Crema','Subcategoría de contorno en crema',2),
(15,'Body Glow','Subcategoría corporal iluminadora',3);

INSERT INTO proveedores (id_proveedor,nombre,email_contacto,telefono_contacto,ciudad,activo) VALUES
(1,'Cosmética Andina SAS','ventas@cosmeticaandina.co','+57 300 111 2233','Bogotá',1),
(2,'Glow Supply Colombia','comercial@glowsupply.co','+57 301 222 3344','Medellín',1),
(3,'Pink Lab Distribuciones','pedidos@pinklab.co','+57 302 333 4455','Cali',1),
(4,'Makeup House Pro','proveedores@makeuphouse.co','+57 303 444 5566','Bogotá',1);

INSERT INTO productos
(id_producto,nombre,descripcion,precio,costo,stock,stock_minimo,sku,peso_kg,id_categoria,id_proveedor,ubicacion,fecha_creacion,fecha_modificacion,activo)
VALUES
(1,'Blush Nube Rosa','Blush líquido de acabado natural.',42000,22000,28,8,'BSF-BLU-0001',0.090,1,1,'Estante A1','2026-01-05 10:00:00','2026-01-05 10:00:00',1),
(2,'Blush Cerecita','Blush en polvo tono cereza.',38000,19000,24,7,'BSF-BLU-0002',0.075,1,2,'Estante A2','2026-01-08 10:00:00','2026-01-08 10:00:00',1),
(3,'Contorno Latte','Stick cremoso para esculpir.',52000,27000,16,5,'BSF-CON-0001',0.110,2,1,'Estante B1','2026-01-10 10:00:00','2026-01-10 10:00:00',1),
(4,'Contorno Espresso','Paleta de contorno compacto.',59000,31000,14,5,'BSF-CON-0002',0.140,2,3,'Estante B2','2026-01-12 10:00:00','2026-01-12 10:00:00',1),
(5,'Body Glow Vainilla','Iluminador corporal con microdestellos.',64000,33000,12,4,'BSF-COR-0001',0.180,3,4,'Estante C1','2026-01-15 10:00:00','2026-01-15 10:00:00',1),
(6,'Base Piel Fresca','Base líquida de cobertura media.',78000,41000,18,6,'BSF-BAS-0001',0.120,4,1,'Estante D1','2026-01-18 10:00:00','2026-01-18 10:00:00',1),
(7,'Gloss Sugar Kiss','Gloss transparente de alto brillo.',34000,16000,40,10,'BSF-LAB-0001',0.060,5,2,'Estante E1','2026-01-20 10:00:00','2026-01-20 10:00:00',1),
(8,'Máscara Pestañina WOW','Máscara negra alargadora.',46000,21000,25,8,'BSF-OJO-0001',0.080,6,3,'Estante F1','2026-01-22 10:00:00','2026-01-22 10:00:00',1),
(9,'Iluminador Luna Pop','Iluminador compacto de acabado glow.',55000,28000,21,6,'BSF-ILU-0001',0.070,7,2,'Estante G1','2026-01-24 10:00:00','2026-01-24 10:00:00',1),
(10,'Polvo Nube Fijador','Polvo suelto para sellar maquillaje.',51000,25000,17,5,'BSF-POL-0001',0.100,8,4,'Estante H1','2026-01-27 10:00:00','2026-01-27 10:00:00',1),
(11,'Corrector Matcha','Corrector neutralizador de subtono.',39000,18000,20,6,'BSF-CORR-0001',0.065,9,3,'Estante I1','2026-01-28 10:00:00','2026-01-28 10:00:00',1),
(12,'Esponjita BySofiii','Esponja suave para aplicar base y corrector.',22000,9000,35,10,'BSF-ACC-0001',0.030,10,4,'Estante J1','2026-01-30 10:00:00','2026-01-30 10:00:00',1),
(13,'Serum Glow Prep','Suero ligero para preparar la piel.',68000,36000,10,4,'BSF-SKN-0001',0.100,11,1,'Estante K1','2026-02-02 10:00:00','2026-02-02 10:00:00',1),
(14,'Esmalte Pink Pop','Esmalte rosa de larga duración.',26000,10000,30,8,'BSF-UNA-0001',0.055,12,3,'Estante L1','2026-02-05 10:00:00','2026-02-05 10:00:00',1),
(15,'Blush Cloud Peach','Blush cremoso melocotón.',45000,23000,15,5,'BSF-BCR-0001',0.085,13,2,'Estante A3','2026-02-08 10:00:00','2026-02-08 10:00:00',1),
(16,'Contorno Cream Mocha','Contorno en crema tono mocha.',57000,29000,11,4,'BSF-CCR-0001',0.095,14,1,'Estante B3','2026-02-10 10:00:00','2026-02-10 10:00:00',1),
(17,'Body Glow Rosé','Aceite seco iluminador corporal.',71000,37000,8,5,'BSF-BDY-0002',0.210,15,4,'Estante C2','2026-02-12 10:00:00','2026-02-12 10:00:00',1);

INSERT INTO clientes
(id_cliente,nombre,apellido,email,`contraseña`,direccion_envio,ciudad,region,fecha_nacimiento,id_sucursal,id_referido_por,fecha_registro,ultimo_acceso,activo)
VALUES
(1,'sofia','martinez','sofia1@demo.bysofii.co','$2y$12$C8JLbmktRk/D6VIVQ3J9XOysSTnr20dJq.rSkdUmzH16LSN8x6EBy','Calle 42 # 10-10','Bucaramanga','Santander','2002-04-15',1,NULL,'2026-01-03 09:10:00','2026-09-20 10:00:00',1),
(2,'valentina','ruiz','vale2@demo.bysofii.co','$2y$12$5pmCLoXU0r.MP/fdPQPVmusAy/g3NK2gXyhmjNCcXZKclM1ToWBry','Carrera 27 # 50-20','Floridablanca','Santander','2000-07-22',2,1,'2026-01-10 11:20:00','2026-09-15 12:00:00',1),
(3,'camila','gomez','cami3@demo.bysofii.co','$2y$12$OW2EdctFQzw0wK057.HyYObDNyeGTITvDu6e7qNgkgNS1b/JphrR.','Calle 80 # 20-12','Bucaramanga','Santander','1999-10-03',1,1,'2026-02-05 14:10:00','2026-08-30 16:00:00',1),
(4,'isabella','torres','isa4@demo.bysofii.co','$2y$12$svz0EwU.eTQk72dLzIQQaemZpbegXXGyybvlhz8oBBbuYLXzfcSiy','Carrera 33 # 18-90','Barranquilla','Atlántico','2001-02-11',3,2,'2026-02-15 10:00:00','2026-09-01 09:00:00',1),
(5,'juliana','diaz','juli5@demo.bysofii.co','$2y$12$vg3h2EbcgJKfdgdPMptnv.pRY38g7JCZYwQC6n10fPDKW0YhfRPxO','Calle 55 # 9-14','Bucaramanga','Santander','1998-12-20',1,3,'2026-03-02 13:30:00','2026-08-12 13:00:00',1),
(6,'laura','suarez','laura6@demo.bysofii.co','$2y$12$Q6hdq88Sdvm6whsS2eIu4e4A7IJ.bZViCo4SXAa5VqcScmmTwKyIC','Carrera 29 # 44-11','Floridablanca','Santander','2003-05-07',2,4,'2026-03-15 15:45:00','2026-07-02 11:00:00',1),
(7,'mariana','perez','mari7@demo.bysofii.co','$2y$12$U3EJBZTYJfyn2oZ2vO30B.9/LeaPOLpIvFJQlIYOr5g/FkDxpuH1C','Calle 51 # 8-12','Bucaramanga','Santander','1997-09-18',1,5,'2026-04-01 09:00:00','2026-09-21 18:00:00',1),
(8,'daniela','castro','dani8@demo.bysofii.co','$2y$12$MZmbZxy5wtRaofi88ZWc1.gE81Ee6Tas06IKm5eoH2l.Umnpw6sby','Carrera 40 # 22-60','Barranquilla','Atlántico','2002-11-30',3,4,'2026-04-20 17:00:00','2026-05-20 12:00:00',1),
(9,'paula','vargas','pau9@demo.bysofii.co','$2y$12$b6//FXsnr.CyxFfdJglPhezXEdqQjC5C0qVMiyBApvrr.xxxbk7Ke','Calle 34 # 12-50','Bucaramanga','Santander','2000-01-25',1,2,'2026-05-03 10:30:00','2026-09-10 10:00:00',1),
(10,'gabriela','moreno','gaby10@demo.bysofii.co','$2y$12$myYShLhKkYcldqMLw48tauhmNIn1DKgPoCIaICd9HXBHFRAZKHTfa','Carrera 25 # 30-40','Floridablanca','Santander','1996-03-14',2,6,'2026-05-11 12:00:00','2026-06-10 09:00:00',1),
(11,'emilia','ramirez','emi11@demo.bysofii.co','$2y$12$rrxaTWaIzuuU11f6MoJ25e9EKhtWGHpPrltldWI2EC.C8Ne5K.oNe','Calle 17 # 7-44','Bucaramanga','Santander','2004-08-09',1,7,'2026-06-01 16:00:00','2026-06-20 15:00:00',1),
(12,'manuela','ortiz','manu12@demo.bysofii.co','$2y$12$1y3f9GvjBE3qOaJNsbuHBOmUffEtse4z0vQtFN8WVkrAbNcm0bsUW','Carrera 53 # 75-10','Barranquilla','Atlántico','1995-06-28',3,9,'2026-06-19 08:00:00','2026-09-22 14:00:00',1);

INSERT INTO promociones (id_promocion,nombre,descuento_pct,fecha_inicio,fecha_fin,activo) VALUES
(1,'Glow de Junio',15,'2026-06-01 00:00:00','2026-06-30 23:59:59',1),
(2,'Blush Weekend',10,'2026-07-10 00:00:00','2026-07-31 23:59:59',1),
(3,'Body Shine Agosto',20,'2026-08-01 00:00:00','2026-08-31 23:59:59',1);

INSERT INTO producto_promocion VALUES
(1,1),(9,1),(5,3),(17,3),(2,2),(15,2);

-- Ventas históricas: fechas, sucursales y estados válidos para analítica.
INSERT INTO ventas
(id_venta,id_cliente,id_sucursal,fecha_venta,estado,subtotal,iva,costo_envio,total,direccion_envio_congelada,codigo_pago,fecha_pago)
VALUES
(1,1,1,'2026-01-18 10:15:00','Entregado',76000,14440,6000,96440,'Calle 42 # 10-10','PAY-DEMO-001','2026-01-18 10:16:00'),
(2,2,2,'2026-02-08 12:30:00','Entregado',100000,19000,7000,126000,'Carrera 27 # 50-20','PAY-DEMO-002','2026-02-08 12:31:00'),
(3,1,1,'2026-03-05 19:10:00','Entregado',104000,19760,6000,129760,'Calle 42 # 10-10','PAY-DEMO-003','2026-03-05 19:11:00'),
(4,3,1,'2026-03-22 14:20:00','Entregado',102000,19380,6000,127380,'Calle 80 # 20-12','PAY-DEMO-004','2026-03-22 14:21:00'),
(5,4,3,'2026-04-03 11:45:00','Enviado',109000,20710,9000,138710,'Carrera 33 # 18-90','PAY-DEMO-005','2026-04-03 11:46:00'),
(6,5,1,'2026-04-18 20:10:00','Entregado',76000,14440,6000,96440,'Calle 55 # 9-14','PAY-DEMO-006','2026-04-18 20:11:00'),
(7,2,2,'2026-05-02 09:25:00','Entregado',116000,22040,7000,145040,'Carrera 27 # 50-20','PAY-DEMO-007','2026-05-02 09:26:00'),
(8,6,2,'2026-05-14 16:30:00','Procesando',94000,17860,7000,118860,'Carrera 29 # 44-11','PAY-DEMO-008','2026-05-14 16:31:00'),
(9,7,1,'2026-05-29 18:05:00','Entregado',137000,26030,6000,169030,'Calle 51 # 8-12','PAY-DEMO-009','2026-05-29 18:06:00'),
(10,1,1,'2026-06-06 13:10:00','Entregado',142000,26980,6000,174980,'Calle 42 # 10-10','PAY-DEMO-010','2026-06-06 13:11:00'),
(11,8,3,'2026-06-12 15:40:00','Enviado',68000,12920,9000,89920,'Carrera 40 # 22-60','PAY-DEMO-011','2026-06-12 15:41:00'),
(12,9,1,'2026-06-27 10:50:00','Entregado',93000,17670,6000,116670,'Calle 34 # 12-50','PAY-DEMO-012','2026-06-27 10:51:00'),
(13,2,2,'2026-07-09 12:10:00','Entregado',141000,26790,7000,174790,'Carrera 27 # 50-20','PAY-DEMO-013','2026-07-09 12:11:00'),
(14,5,1,'2026-07-19 17:45:00','Entregado',118000,22420,6000,146420,'Calle 55 # 9-14','PAY-DEMO-014','2026-07-19 17:46:00'),
(15,7,1,'2026-07-28 21:05:00','Enviado',93000,17670,6000,116670,'Calle 51 # 8-12','PAY-DEMO-015','2026-07-28 21:06:00'),
(16,10,2,'2026-08-03 09:50:00','Entregado',112000,21280,7000,140280,'Carrera 25 # 30-40','PAY-DEMO-016','2026-08-03 09:51:00'),
(17,1,1,'2026-08-17 18:30:00','Entregado',151000,28690,6000,185690,'Calle 42 # 10-10','PAY-DEMO-017','2026-08-17 18:31:00'),
(18,11,1,'2026-08-21 13:15:00','Procesando',85000,16150,6000,107150,'Calle 17 # 7-44','PAY-DEMO-018','2026-08-21 13:16:00'),
(19,12,3,'2026-09-05 20:20:00','Pagado',128000,24320,9000,161320,'Carrera 53 # 75-10','PAY-DEMO-019','2026-09-05 20:21:00'),
(20,3,1,'2026-09-12 11:35:00','Entregado',106000,20140,6000,132140,'Calle 80 # 20-12','PAY-DEMO-020','2026-09-12 11:36:00'),
(21,4,3,'2026-09-15 18:55:00','Entregado',156000,29640,9000,194640,'Carrera 33 # 18-90','PAY-DEMO-021','2026-09-15 18:56:00'),
(22,6,2,'2026-09-18 14:25:00','Pagado',112000,21280,7000,140280,'Carrera 29 # 44-11','PAY-DEMO-022','2026-09-18 14:26:00');

INSERT INTO detalle_ventas (id_venta,id_producto,cantidad,precio_unitario_congelado,costo_unitario_congelado) VALUES
(1,1,1,42000,22000),(1,7,1,34000,16000),
(2,3,1,52000,27000),(2,12,1,22000,9000),(2,14,1,26000,10000),
(3,5,1,64000,33000),(3,9,1,40000,28000),
(4,6,1,78000,41000),(4,11,1,24000,18000),
(5,8,1,46000,21000),(5,10,1,51000,25000),(5,14,1,12000,10000),
(6,2,2,38000,19000),
(7,1,1,42000,22000),(7,3,1,52000,27000),(7,12,1,22000,9000),
(8,4,1,59000,31000),(8,7,1,35000,16000),
(9,15,1,45000,23000),(9,17,1,71000,37000),(9,12,1,21000,9000),
(10,5,1,64000,33000),(10,6,1,78000,41000),
(11,13,1,68000,36000),
(12,2,1,38000,19000),(12,9,1,55000,28000),
(13,15,1,45000,23000),(13,16,1,57000,29000),(13,12,1,22000,9000),(13,14,1,17000,10000),
(14,3,1,52000,27000),(14,6,1,66000,41000),
(15,7,1,34000,16000),(15,10,1,51000,25000),(15,12,1,8000,9000),
(16,1,1,42000,22000),(16,8,1,46000,21000),(16,11,1,24000,18000),
(17,5,1,64000,33000),(17,9,1,55000,28000),(17,15,1,32000,23000),
(18,4,1,59000,31000),(18,14,1,26000,10000),
(19,17,1,71000,37000),(19,16,1,57000,29000),
(20,2,1,38000,19000),(20,3,1,52000,27000),(20,12,1,16000,9000),
(21,1,2,42000,22000),(21,9,1,55000,28000),(21,7,1,17000,16000),
(22,6,1,78000,41000),(22,10,1,34000,25000);

-- Carritos: algunos activos y otros abandonados para analítica.
INSERT INTO carritos (id_carrito,id_cliente,creado_en,actualizado_en,estado) VALUES
(1,8,'2026-09-20 10:00:00','2026-09-24 10:00:00','Abandonado'),
(2,9,'2026-09-24 11:00:00','2026-09-27 12:00:00','Abandonado'),
(3,10,'2026-09-25 15:00:00','2026-09-28 09:00:00','Activo'),
(4,12,'2026-09-22 18:00:00','2026-09-26 20:00:00','Abandonado'),
(5,11,'2026-09-27 13:00:00','2026-09-28 10:00:00','Activo');

INSERT INTO carrito_detalle (id_carrito,id_producto,cantidad,agregado_en) VALUES
(1,5,1,'2026-09-20 10:10:00'),(1,9,1,'2026-09-20 10:11:00'),
(2,1,1,'2026-09-24 11:10:00'),(2,12,1,'2026-09-24 11:12:00'),
(3,17,1,'2026-09-28 08:55:00'),(3,7,2,'2026-09-28 08:56:00'),
(4,15,1,'2026-09-22 18:10:00'),(4,16,1,'2026-09-22 18:11:00'),
(5,6,1,'2026-09-28 09:10:00');

INSERT INTO vistas_producto (id_cliente,id_producto,visto_en,session_token) VALUES
(1,1,'2026-09-20 10:00:00','s1'),(1,2,'2026-09-20 10:01:00','s1'),(2,1,'2026-09-21 11:00:00','s2'),
(3,6,'2026-09-22 12:00:00','s3'),(4,5,'2026-09-22 13:00:00','s4'),(5,17,'2026-09-23 14:00:00','s5'),
(6,3,'2026-09-24 15:00:00','s6'),(7,1,'2026-09-24 16:00:00','s7'),(8,9,'2026-09-25 17:00:00','s8'),
(9,12,'2026-09-26 18:00:00','s9'),(10,6,'2026-09-26 19:00:00','s10'),(11,10,'2026-09-27 20:00:00','s11'),
(NULL,1,'2026-09-27 20:05:00','guest1'),(NULL,5,'2026-09-27 20:10:00','guest2'),
(NULL,1,'2026-09-27 20:15:00','guest3'),(NULL,1,'2026-09-27 20:20:00','guest4');

INSERT INTO resenas_producto (id_cliente,id_producto,id_venta,calificacion,comentario) VALUES
(1,1,1,5,'Color precioso y se difumina muy fácil.'),
(2,3,2,5,'El stick se trabaja súper bien.'),
(1,5,3,4,'Bonito glow para eventos.'),
(3,6,4,5,'Cobertura media y cómoda.'),
(5,2,6,4,'Buen tono y duración.'),
(7,15,9,5,'El blush cremoso quedó hermoso.');

INSERT INTO intentos_pago (id_venta,id_cliente,resultado,motivo,creado_en) VALUES
(1,1,'Exitoso','Pago aprobado','2026-01-18 10:16:00'),
(2,2,'Exitoso','Pago aprobado','2026-02-08 12:31:00'),
(8,6,'Fallido','Fondos insuficientes','2026-05-14 16:30:30'),
(8,6,'Fallido','CVV inválido','2026-05-14 16:31:10'),
(8,6,'Fallido','Tarjeta rechazada','2026-05-14 16:31:40'),
(16,10,'Exitoso','Pago aprobado','2026-08-03 09:51:00');

UPDATE categorias c
SET producto_count = (SELECT COUNT(*) FROM productos p WHERE p.id_categoria = c.id_categoria);

UPDATE clientes c
SET total_gastado = COALESCE((
    SELECT SUM(v.total) FROM ventas v
    WHERE v.id_cliente = c.id_cliente
      AND v.estado NOT IN ('Cancelado','Devuelto')
),0),
fecha_ultimo_pedido = (
    SELECT MAX(v.fecha_venta) FROM ventas v
    WHERE v.id_cliente = c.id_cliente
      AND v.estado NOT IN ('Cancelado','Devuelto')
);

-- Datos auxiliares para que los eventos tengan trabajo desde la primera ejecución.
INSERT INTO tabla_temporal_procesos(clave,valor,creado_en) VALUES
('demo_cache',JSON_OBJECT('origen','BySofiii'),CURRENT_TIMESTAMP);

SET FOREIGN_KEY_CHECKS = 1;
