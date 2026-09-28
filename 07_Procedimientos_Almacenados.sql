-- ============================================================
-- 07_Procedimientos_Almacenados.sql
-- 20 procedimientos almacenados transaccionales/de negocio
-- ============================================================
USE ecommerce_bysofii;

DROP PROCEDURE IF EXISTS sp_RealizarNuevaVenta;
DROP PROCEDURE IF EXISTS sp_AgregarNuevoProducto;
DROP PROCEDURE IF EXISTS sp_ActualizarDireccionCliente;
DROP PROCEDURE IF EXISTS sp_ProcesarDevolucion;
DROP PROCEDURE IF EXISTS sp_ObtenerHistorialComprasCliente;
DROP PROCEDURE IF EXISTS sp_AjustarNivelStock;
DROP PROCEDURE IF EXISTS sp_EliminarClienteDeFormaSegura;
DROP PROCEDURE IF EXISTS sp_AplicarDescuentoPorCategoria;
DROP PROCEDURE IF EXISTS sp_GenerarReporteMensualVentas;
DROP PROCEDURE IF EXISTS sp_CambiarEstadoPedido;
DROP PROCEDURE IF EXISTS sp_RegistrarNuevoCliente;
DROP PROCEDURE IF EXISTS sp_ObtenerDetallesProductoCompleto;
DROP PROCEDURE IF EXISTS sp_FusionarCuentasCliente;
DROP PROCEDURE IF EXISTS sp_AsignarProductoAProveedor;
DROP PROCEDURE IF EXISTS sp_BuscarProductos;
DROP PROCEDURE IF EXISTS sp_ObtenerDashboardAdmin;
DROP PROCEDURE IF EXISTS sp_ProcesarPago;
DROP PROCEDURE IF EXISTS sp_AñadirReseñaProducto;
DROP PROCEDURE IF EXISTS sp_ObtenerProductosRelacionados;
DROP PROCEDURE IF EXISTS sp_MoverProductosEntreCategorias;

DELIMITER $$

-- 1. Realiza una venta completa a partir de un JSON de items:
-- [{"id_producto":1,"cantidad":2},...]
CREATE PROCEDURE sp_RealizarNuevaVenta(
    IN p_id_cliente INT,
    IN p_id_sucursal INT,
    IN p_items_json JSON
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_id_venta INT;
    DECLARE v_subtotal DECIMAL(14,2);
    DECLARE v_iva DECIMAL(14,2);
    DECLARE v_envio DECIMAL(12,2);
    DECLARE v_total DECIMAL(14,2);
    DECLARE v_direccion VARCHAR(255);
    DECLARE v_faltantes INT DEFAULT 0;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET @bysofii_items_json=NULL;
        RESIGNAL;
    END;

    SET @bysofii_items_json=NULL;

    IF p_items_json IS NULL OR JSON_LENGTH(p_items_json)=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La venta debe contener al menos un producto';
    END IF;

    START TRANSACTION;

    SELECT direccion_envio INTO v_direccion
    FROM clientes
    WHERE id_cliente=p_id_cliente AND activo=TRUE
    FOR UPDATE;

    IF v_direccion IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cliente inexistente, inactivo o sin dirección de envío';
    END IF;

    SELECT COUNT(*) INTO v_faltantes
    FROM (
        SELECT id_producto,SUM(cantidad) AS cantidad
        FROM JSON_TABLE(p_items_json,'$[*]' COLUMNS(
            id_producto INT PATH '$.id_producto',
            cantidad INT PATH '$.cantidad'
        )) j
        GROUP BY id_producto
    ) j
    LEFT JOIN productos p ON p.id_producto=j.id_producto AND p.activo=TRUE
    WHERE p.id_producto IS NULL OR j.cantidad<=0 OR p.stock<j.cantidad;

    IF v_faltantes>0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Uno o más productos no tienen stock suficiente';
    END IF;

    -- Bloqueo de filas de inventario para evitar carreras de concurrencia.
    SELECT p.id_producto,p.stock
    FROM productos p
    JOIN (
      SELECT DISTINCT id_producto
      FROM JSON_TABLE(p_items_json,'$[*]' COLUMNS(id_producto INT PATH '$.id_producto')) j
    ) x ON x.id_producto=p.id_producto
    FOR UPDATE;

    SELECT COALESCE(SUM(j.cantidad*p.precio),0)
      INTO v_subtotal
    FROM JSON_TABLE(p_items_json,'$[*]' COLUMNS(
        id_producto INT PATH '$.id_producto',
        cantidad INT PATH '$.cantidad'
    )) j
    JOIN productos p ON p.id_producto=j.id_producto;

    SET v_iva=fn_CalcularIVA(v_subtotal);
    -- El envío se estima por peso de los items usando una tarifa simple.
    SELECT CASE
      WHEN SUM(j.cantidad*p.peso_kg)<=1 THEN 6000
      WHEN SUM(j.cantidad*p.peso_kg)<=3 THEN 9000
      ELSE 12000
    END
    INTO v_envio
    FROM JSON_TABLE(p_items_json,'$[*]' COLUMNS(
        id_producto INT PATH '$.id_producto',
        cantidad INT PATH '$.cantidad'
    )) j
    JOIN productos p ON p.id_producto=j.id_producto;

    SET v_total=ROUND(v_subtotal+v_iva+v_envio,2);
    SET @bysofii_items_json=p_items_json;

    INSERT INTO ventas(
        id_cliente,id_sucursal,estado,subtotal,iva,costo_envio,total,direccion_envio_congelada
    ) VALUES(
        p_id_cliente,p_id_sucursal,'Pagado',v_subtotal,v_iva,v_envio,v_total,v_direccion
    );

    SET v_id_venta=LAST_INSERT_ID();

    INSERT INTO detalle_ventas(id_venta,id_producto,cantidad,precio_unitario_congelado,costo_unitario_congelado)
    SELECT v_id_venta,j.id_producto,j.cantidad,p.precio,p.costo
    FROM JSON_TABLE(p_items_json,'$[*]' COLUMNS(
        id_producto INT PATH '$.id_producto',
        cantidad INT PATH '$.cantidad'
    )) j
    JOIN productos p ON p.id_producto=j.id_producto;

    INSERT INTO intentos_pago(id_venta,id_cliente,resultado,motivo)
    VALUES(v_id_venta,p_id_cliente,'Exitoso','Pago aprobado por procedimiento');

    SET @bysofii_items_json=NULL;
    COMMIT;

    SELECT v_id_venta AS id_venta_creada,v_total AS total_venta;
END$$

-- 2. Agrega un producto con SKU automático.
CREATE PROCEDURE sp_AgregarNuevoProducto(
    IN p_nombre VARCHAR(180),
    IN p_descripcion TEXT,
    IN p_precio DECIMAL(12,2),
    IN p_costo DECIMAL(12,2),
    IN p_stock INT,
    IN p_stock_minimo INT,
    IN p_id_categoria INT,
    IN p_id_proveedor INT,
    IN p_peso_kg DECIMAL(8,3),
    IN p_ubicacion VARCHAR(100)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_sku VARCHAR(80);
    DECLARE v_nombre_categoria VARCHAR(100);

    IF p_precio<=0 OR p_costo<0 OR p_stock<0 OR p_stock_minimo<0 OR p_peso_kg<=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Valores numéricos de producto inválidos';
    END IF;
    IF EXISTS(SELECT 1 FROM productos WHERE nombre=p_nombre) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El nombre del producto ya existe';
    END IF;
    SELECT nombre INTO v_nombre_categoria FROM categorias WHERE id_categoria=p_id_categoria;
    IF v_nombre_categoria IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La categoría no existe';
    END IF;

    SET v_sku=fn_GenerarSKU(p_nombre,v_nombre_categoria);
    IF EXISTS(SELECT 1 FROM productos WHERE sku=v_sku) THEN
        SET v_sku=CONCAT(v_sku,'-',UNIX_TIMESTAMP());
    END IF;

    INSERT INTO productos(
      nombre,descripcion,precio,costo,stock,stock_minimo,sku,peso_kg,id_categoria,id_proveedor,ubicacion
    ) VALUES(
      p_nombre,p_descripcion,p_precio,p_costo,p_stock,p_stock_minimo,v_sku,p_peso_kg,p_id_categoria,p_id_proveedor,p_ubicacion
    );

    SELECT LAST_INSERT_ID() AS id_producto_creado,v_sku AS sku_generado;
END$$

-- 3. Actualiza dirección actual del cliente y carritos abiertos; ventas pasadas conservan su snapshot.
CREATE PROCEDURE sp_ActualizarDireccionCliente(
    IN p_id_cliente INT,
    IN p_nueva_direccion VARCHAR(255),
    IN p_ciudad VARCHAR(100),
    IN p_region VARCHAR(100)
)
MODIFIES SQL DATA
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    IF p_nueva_direccion IS NULL OR TRIM(p_nueva_direccion)='' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La dirección no puede estar vacía';
    END IF;
    START TRANSACTION;
    UPDATE clientes
    SET direccion_envio=p_nueva_direccion,ciudad=p_ciudad,region=p_region
    WHERE id_cliente=p_id_cliente AND activo=TRUE;
    IF ROW_COUNT()=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cliente inexistente o inactivo';
    END IF;
    UPDATE carritos
    SET actualizado_en=CURRENT_TIMESTAMP
    WHERE id_cliente=p_id_cliente AND estado='Activo';
    COMMIT;
END$$

-- 4. Gestiona devolución, ajusta stock y genera crédito.
CREATE PROCEDURE sp_ProcesarDevolucion(
    IN p_id_venta INT,
    IN p_id_cliente INT,
    IN p_id_producto INT,
    IN p_cantidad INT,
    IN p_motivo VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_precio DECIMAL(12,2);
    DECLARE v_disponible INT;
    DECLARE v_credito DECIMAL(14,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_cantidad<=0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cantidad de devolución inválida';
    END IF;

    START TRANSACTION;

    SELECT d.cantidad,d.precio_unitario_congelado
      INTO v_disponible,v_precio
    FROM detalle_ventas d JOIN ventas v ON v.id_venta=d.id_venta
    WHERE d.id_venta=p_id_venta
      AND d.id_producto=p_id_producto
      AND v.id_cliente=p_id_cliente
      AND v.estado NOT IN ('Cancelado','Devuelto')
    FOR UPDATE;

    IF v_disponible IS NULL OR p_cantidad>v_disponible THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='La cantidad devuelta supera la cantidad comprada';
    END IF;
    UPDATE productos SET stock=stock+p_cantidad WHERE id_producto=p_id_producto;

    SET v_credito=ROUND(p_cantidad*v_precio,2);
    INSERT INTO creditos_cliente(id_cliente,id_venta,monto,motivo)
    VALUES(p_id_cliente,p_id_venta,v_credito,p_motivo);

    IF p_cantidad=v_disponible THEN
        UPDATE ventas SET estado='Devuelto' WHERE id_venta=p_id_venta;
    ELSE
        UPDATE detalle_ventas
        SET cantidad=cantidad-p_cantidad
        WHERE id_venta=p_id_venta AND id_producto=p_id_producto;
    END IF;

    COMMIT;
END$$

-- 5. Historial completo de compras.
CREATE PROCEDURE sp_ObtenerHistorialComprasCliente(IN p_id_cliente INT)
READS SQL DATA
BEGIN
    SELECT v.id_venta,v.fecha_venta,v.estado,v.subtotal,v.iva,v.costo_envio,v.total,
           d.id_producto,p.nombre,d.cantidad,d.precio_unitario_congelado,d.subtotal AS subtotal_linea
    FROM ventas v
    JOIN detalle_ventas d ON d.id_venta=v.id_venta
    JOIN productos p ON p.id_producto=d.id_producto
    WHERE v.id_cliente=p_id_cliente
    ORDER BY v.fecha_venta DESC,v.id_venta DESC;
END$$

-- 6. Ajuste manual de stock con motivo y auditoría.
CREATE PROCEDURE sp_AjustarNivelStock(
    IN p_id_producto INT,
    IN p_stock_nuevo INT,
    IN p_motivo VARCHAR(500)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_anterior INT;
    START TRANSACTION;

    SELECT stock INTO v_anterior FROM productos WHERE id_producto=p_id_producto FOR UPDATE;
    IF v_anterior IS NULL THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Producto inexistente';
    END IF;
    IF p_stock_nuevo<0 THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Stock nuevo inválido';
    END IF;
    IF p_motivo IS NULL OR TRIM(p_motivo)='' THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El motivo es obligatorio';
    END IF;

    UPDATE productos SET stock=p_stock_nuevo WHERE id_producto=p_id_producto;
    INSERT INTO ajustes_stock(id_producto,id_usuario,stock_anterior,stock_nuevo,motivo)
    VALUES(p_id_producto,USER(),v_anterior,p_stock_nuevo,p_motivo);
END$$

-- 7. Anonimiza datos de cliente sin romper FKs.
CREATE PROCEDURE sp_EliminarClienteDeFormaSegura(IN p_id_cliente INT)
MODIFIES SQL DATA
BEGIN
    DECLARE v_email VARCHAR(190);
    SELECT email INTO v_email FROM clientes WHERE id_cliente=p_id_cliente FOR UPDATE;
    IF v_email IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cliente inexistente'; END IF;

    UPDATE clientes
    SET nombre='Cliente',
        apellido='Anonimizado',
        email=CONCAT('anon-',id_cliente,'-',UNIX_TIMESTAMP(),'@bysofii.local'),
        `contraseña`='ANONIMIZADO',
        direccion_envio=NULL,
        ciudad=NULL,
        region=NULL,
        fecha_nacimiento=NULL,
        id_referido_por=NULL,
        activo=FALSE,
        deleted_at=CURRENT_TIMESTAMP
    WHERE id_cliente=p_id_cliente;
END$$

-- 8. Aplica descuento lógico por categoría: ajusta precios y audita por trigger.
CREATE PROCEDURE sp_AplicarDescuentoPorCategoria(
    IN p_id_categoria INT,
    IN p_porcentaje DECIMAL(5,2)
)
MODIFIES SQL DATA
BEGIN
    IF p_porcentaje<=0 OR p_porcentaje>100 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Porcentaje de descuento inválido';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM categorias WHERE id_categoria=p_id_categoria) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Categoría inexistente';
    END IF;

    UPDATE productos
    SET precio=fn_AplicarDescuento(precio,p_porcentaje)
    WHERE id_categoria=p_id_categoria AND activo=TRUE;
END$$

-- 9. Reporte mensual.
CREATE PROCEDURE sp_GenerarReporteMensualVentas(IN p_anio INT,IN p_mes INT)
READS SQL DATA
BEGIN
    DECLARE v_sucursal INT DEFAULT NULL;

    IF p_mes<1 OR p_mes>12 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Mes inválido';
    END IF;

    SELECT id_sucursal INTO v_sucursal
    FROM usuario_sucursal
    WHERE login_usuario=SUBSTRING_INDEX(USER(),'@',1)
      AND activo=TRUE
    LIMIT 1;

    SELECT COUNT(*) AS cantidad_ventas,
           COALESCE(SUM(total),0) AS ingresos,
           COALESCE(AVG(total),0) AS ticket_promedio,
           COUNT(DISTINCT id_cliente) AS clientes_compradores
    FROM ventas
    WHERE YEAR(fecha_venta)=p_anio AND MONTH(fecha_venta)=p_mes
      AND estado NOT IN ('Cancelado','Devuelto')
      AND (v_sucursal IS NULL OR id_sucursal=v_sucursal);
END$$

-- 10. Cambia estado de pedido de forma controlada.
CREATE PROCEDURE sp_CambiarEstadoPedido(IN p_id_venta INT,IN p_nuevo_estado VARCHAR(40))
MODIFIES SQL DATA
BEGIN
    DECLARE v_estado VARCHAR(40);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT estado INTO v_estado FROM ventas WHERE id_venta=p_id_venta FOR UPDATE;
    IF v_estado IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Venta inexistente'; END IF;

    IF p_nuevo_estado NOT IN ('Pendiente de Pago','Pagado','Procesando','Enviado','Entregado','Cancelado','Devuelto') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Estado de pedido inválido';
    END IF;

    UPDATE ventas SET estado=p_nuevo_estado WHERE id_venta=p_id_venta;
    COMMIT;
END$$

-- 11. Registra nuevo cliente verificando email.
CREATE PROCEDURE sp_RegistrarNuevoCliente(
    IN p_nombre VARCHAR(100),
    IN p_apellido VARCHAR(100),
    IN p_email VARCHAR(190),
    IN p_contrasena_hash VARCHAR(255),
    IN p_direccion VARCHAR(255),
    IN p_ciudad VARCHAR(100),
    IN p_region VARCHAR(100),
    IN p_fecha_nacimiento DATE,
    IN p_id_sucursal INT,
    IN p_id_referido_por INT
)
MODIFIES SQL DATA
BEGIN
    IF NOT fn_ValidarFormatoEmail(p_email) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Email inválido'; END IF;
    IF EXISTS(SELECT 1 FROM clientes WHERE email=p_email) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El email ya está registrado'; END IF;
    IF p_contrasena_hash IS NULL OR CHAR_LENGTH(p_contrasena_hash)<20 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El almacenamiento de contraseña debe ser un hash robusto';
    END IF;
    IF p_id_referido_por IS NOT NULL AND p_id_referido_por=(SELECT COALESCE(MAX(id_cliente)+1,1) FROM clientes) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Referido inválido';
    END IF;

    INSERT INTO clientes(nombre,apellido,email,`contraseña`,direccion_envio,ciudad,region,fecha_nacimiento,id_sucursal,id_referido_por)
    VALUES(p_nombre,p_apellido,p_email,p_contrasena_hash,p_direccion,p_ciudad,p_region,p_fecha_nacimiento,p_id_sucursal,p_id_referido_por);

    SELECT LAST_INSERT_ID() AS id_cliente_creado;
END$$

-- 12. Detalles completos del producto.
CREATE PROCEDURE sp_ObtenerDetallesProductoCompleto(IN p_id_producto INT)
READS SQL DATA
BEGIN
    SELECT p.*,c.nombre AS categoria,pr.nombre AS proveedor,pr.email_contacto,pr.telefono_contacto
    FROM productos p
    LEFT JOIN categorias c ON c.id_categoria=p.id_categoria
    LEFT JOIN proveedores pr ON pr.id_proveedor=p.id_proveedor
    WHERE p.id_producto=p_id_producto;
END$$

-- 13. Fusiona cuentas manteniendo referencias históricas.
CREATE PROCEDURE sp_FusionarCuentasCliente(IN p_id_origen INT,IN p_id_destino INT)
MODIFIES SQL DATA
BEGIN
    DECLARE v_email_origen VARCHAR(190);
    IF p_id_origen=p_id_destino THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Las cuentas deben ser diferentes'; END IF;

    START TRANSACTION;
    SELECT email INTO v_email_origen FROM clientes WHERE id_cliente=p_id_origen FOR UPDATE;
    IF v_email_origen IS NULL OR NOT EXISTS(SELECT 1 FROM clientes WHERE id_cliente=p_id_destino) THEN
        ROLLBACK;
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Cuenta origen o destino inexistente';
    END IF;

    UPDATE ventas SET id_cliente=p_id_destino WHERE id_cliente=p_id_origen;
    UPDATE resenas_producto SET id_cliente=p_id_destino WHERE id_cliente=p_id_origen;
    UPDATE intentos_pago SET id_cliente=p_id_destino WHERE id_cliente=p_id_origen;
    UPDATE creditos_cliente SET id_cliente=p_id_destino WHERE id_cliente=p_id_origen;
    UPDATE carritos SET id_cliente=p_id_destino WHERE id_cliente=p_id_origen;

    UPDATE clientes
    SET activo=FALSE,
        deleted_at=CURRENT_TIMESTAMP,
        nombre='Cuenta',
        apellido='Fusionada',
        email=CONCAT('fusion-',id_cliente,'-',UNIX_TIMESTAMP(),'@bysofii.local'),
        `contraseña`='FUSIONADA',
        direccion_envio=NULL
    WHERE id_cliente=p_id_origen;

    UPDATE clientes
    SET total_gastado=(
          SELECT COALESCE(SUM(v.total),0)
          FROM ventas v
          WHERE v.id_cliente=p_id_destino
            AND v.estado NOT IN ('Cancelado','Devuelto')
        ),
        fecha_ultimo_pedido=(
          SELECT MAX(v.fecha_venta)
          FROM ventas v
          WHERE v.id_cliente=p_id_destino
            AND v.estado NOT IN ('Cancelado','Devuelto')
        )
    WHERE id_cliente=p_id_destino;

    COMMIT;
END$$

-- 14. Asigna/cambia proveedor.
CREATE PROCEDURE sp_AsignarProductoAProveedor(IN p_id_producto INT,IN p_id_proveedor INT)
MODIFIES SQL DATA
BEGIN
    IF NOT EXISTS(SELECT 1 FROM productos WHERE id_producto=p_id_producto) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Producto inexistente'; END IF;
    IF NOT EXISTS(SELECT 1 FROM proveedores WHERE id_proveedor=p_id_proveedor AND activo=TRUE) THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Proveedor inexistente o inactivo'; END IF;
    UPDATE productos SET id_proveedor=p_id_proveedor WHERE id_producto=p_id_producto;
END$$

-- 15. Búsqueda avanzada de productos.
CREATE PROCEDURE sp_BuscarProductos(
    IN p_nombre VARCHAR(180),
    IN p_id_categoria INT,
    IN p_precio_min DECIMAL(12,2),
    IN p_precio_max DECIMAL(12,2)
)
READS SQL DATA
BEGIN
    SELECT p.id_producto,p.nombre,p.precio,p.stock,p.sku,c.nombre AS categoria
    FROM productos p
    LEFT JOIN categorias c ON c.id_categoria=p.id_categoria
    WHERE p.activo=TRUE
      AND (p_nombre IS NULL OR p.nombre LIKE CONCAT('%',p_nombre,'%'))
      AND (p_id_categoria IS NULL OR p.id_categoria=p_id_categoria)
      AND (p_precio_min IS NULL OR p.precio>=p_precio_min)
      AND (p_precio_max IS NULL OR p.precio<=p_precio_max)
    ORDER BY p.nombre;
END$$

-- 16. Dashboard administrativo.
CREATE PROCEDURE sp_ObtenerDashboardAdmin()
READS SQL DATA
BEGIN
    SELECT
      (SELECT COALESCE(SUM(total),0) FROM ventas WHERE DATE(fecha_venta)=CURRENT_DATE AND estado NOT IN ('Cancelado','Devuelto')) AS ventas_hoy,
      (SELECT COUNT(*) FROM clientes WHERE DATE(fecha_registro)=CURRENT_DATE) AS clientes_nuevos_hoy,
      (SELECT COUNT(*) FROM productos WHERE activo=TRUE AND stock<stock_minimo) AS productos_bajo_stock,
      (SELECT COUNT(*) FROM carritos WHERE estado='Abandonado') AS carritos_abandonados,
      (SELECT COALESCE(AVG(total),0) FROM ventas WHERE estado NOT IN ('Cancelado','Devuelto')) AS ticket_promedio_historico;
END$$

-- 17. Procesa un pago simulado.
CREATE PROCEDURE sp_ProcesarPago(IN p_id_venta INT,IN p_aprobado BOOLEAN)
MODIFIES SQL DATA
BEGIN
    DECLARE v_cliente INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT id_cliente INTO v_cliente FROM ventas WHERE id_venta=p_id_venta FOR UPDATE;
    IF v_cliente IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Venta inexistente'; END IF;

    IF p_aprobado THEN
        UPDATE ventas
        SET estado='Pagado',codigo_pago=CONCAT('PAY-',UUID()),fecha_pago=CURRENT_TIMESTAMP
        WHERE id_venta=p_id_venta;
        INSERT INTO intentos_pago(id_venta,id_cliente,resultado,motivo)
        VALUES(p_id_venta,v_cliente,'Exitoso','Pago aprobado');
    ELSE
        INSERT INTO intentos_pago(id_venta,id_cliente,resultado,motivo)
        VALUES(p_id_venta,v_cliente,'Fallido','Pago rechazado');
    END IF;
    COMMIT;
END$$

-- 18. Añade reseña solo si el cliente compró el producto.
CREATE PROCEDURE sp_AñadirReseñaProducto(
    IN p_id_cliente INT,
    IN p_id_producto INT,
    IN p_id_venta INT,
    IN p_calificacion INT,
    IN p_comentario VARCHAR(1000)
)
MODIFIES SQL DATA
BEGIN
    IF p_calificacion<1 OR p_calificacion>5 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Calificación fuera de rango'; END IF;
    IF NOT EXISTS(
        SELECT 1 FROM detalle_ventas d JOIN ventas v ON v.id_venta=d.id_venta
        WHERE d.id_venta=p_id_venta AND d.id_producto=p_id_producto AND v.id_cliente=p_id_cliente
          AND v.estado IN ('Procesando','Enviado','Entregado','Pagado')
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='El cliente no compró este producto en la venta indicada';
    END IF;

    INSERT INTO resenas_producto(id_cliente,id_producto,id_venta,calificacion,comentario)
    VALUES(p_id_cliente,p_id_producto,p_id_venta,p_calificacion,p_comentario);
END$$

-- 19. Productos relacionados por co-compra.
CREATE PROCEDURE sp_ObtenerProductosRelacionados(IN p_id_producto INT)
READS SQL DATA
BEGIN
    SELECT p2.id_producto,p2.nombre,
           COUNT(*) AS compras_conjuntas
    FROM detalle_ventas d1
    JOIN detalle_ventas d2 ON d1.id_venta=d2.id_venta AND d2.id_producto<>p_id_producto
    JOIN ventas v ON v.id_venta=d1.id_venta
    JOIN productos p2 ON p2.id_producto=d2.id_producto
    WHERE d1.id_producto=p_id_producto
      AND v.estado NOT IN ('Cancelado','Devuelto')
    GROUP BY p2.id_producto,p2.nombre
    ORDER BY compras_conjuntas DESC
    LIMIT 10;
END$$

-- 20. Mueve productos entre categorías y sincroniza contadores.
CREATE PROCEDURE sp_MoverProductosEntreCategorias(IN p_id_categoria_origen INT,IN p_id_categoria_destino INT)
MODIFIES SQL DATA
BEGIN
    DECLARE v_cantidad INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_id_categoria_origen=p_id_categoria_destino THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Las categorías deben ser diferentes';
    END IF;
    IF NOT EXISTS(SELECT 1 FROM categorias WHERE id_categoria=p_id_categoria_origen)
       OR NOT EXISTS(SELECT 1 FROM categorias WHERE id_categoria=p_id_categoria_destino) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Categoría origen o destino inexistente';
    END IF;

    START TRANSACTION;
    SELECT COUNT(*) INTO v_cantidad FROM productos WHERE id_categoria=p_id_categoria_origen FOR UPDATE;
    UPDATE productos SET id_categoria=p_id_categoria_destino WHERE id_categoria=p_id_categoria_origen;

    UPDATE categorias
    SET producto_count=(SELECT COUNT(*) FROM productos WHERE id_categoria= categorias.id_categoria)
    WHERE id_categoria IN (p_id_categoria_origen,p_id_categoria_destino);

    COMMIT;
    SELECT v_cantidad AS productos_movidos;
END$$

DELIMITER ;

-- Grants de ejecución se completan en 04_Seguridad.sql después de crear los objetos.
