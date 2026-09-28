-- ============================================================
-- 05_Triggers.sql
-- 20 triggers de integridad, auditoría y automatización
-- ============================================================
USE ecommerce_bysofii;

DROP TRIGGER IF EXISTS trg_audit_precio_producto_after_update;
DROP TRIGGER IF EXISTS trg_check_stock_before_insert_venta;
DROP TRIGGER IF EXISTS trg_update_stock_after_insert_venta;
DROP TRIGGER IF EXISTS trg_prevent_delete_categoria_with_products;
DROP TRIGGER IF EXISTS trg_log_new_customer_after_insert;
DROP TRIGGER IF EXISTS trg_update_total_gastado_cliente;
DROP TRIGGER IF EXISTS trg_set_fecha_modificacion_producto;
DROP TRIGGER IF EXISTS trg_prevent_negative_stock;
DROP TRIGGER IF EXISTS trg_capitalize_nombre_cliente;
DROP TRIGGER IF EXISTS trg_recalculate_total_venta_on_detalle_change;
DROP TRIGGER IF EXISTS trg_log_order_status_change;
DROP TRIGGER IF EXISTS trg_prevent_price_zero_or_less;
DROP TRIGGER IF EXISTS trg_send_stock_alert_on_low_stock;
DROP TRIGGER IF EXISTS trg_archive_deleted_venta;
DROP TRIGGER IF EXISTS trg_validate_email_format_on_customer;
DROP TRIGGER IF EXISTS trg_update_last_order_date_customer;
DROP TRIGGER IF EXISTS trg_prevent_self_referral;
DROP TRIGGER IF EXISTS trg_log_permission_changes;
DROP TRIGGER IF EXISTS trg_assign_default_category_on_null;
DROP TRIGGER IF EXISTS trg_update_producto_count_in_categoria;

DELIMITER $$

-- 1. Auditoría de cambios de precio.
CREATE TRIGGER trg_audit_precio_producto_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NOT (OLD.precio <=> NEW.precio) THEN
        INSERT INTO log_cambios_precio(id_producto,precio_anterior,precio_nuevo,modificado_por)
        VALUES(NEW.id_producto,OLD.precio,NEW.precio,USER());
    END IF;
END$$

-- 2. Verifica stock antes de crear una venta.
-- La app/procedimiento coloca en @bysofii_items_json el detalle a procesar.
CREATE TRIGGER trg_check_stock_before_insert_venta
BEFORE INSERT ON ventas
FOR EACH ROW
BEGIN
    DECLARE v_faltantes INT DEFAULT 0;
    IF @bysofii_items_json IS NULL THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT='Las ventas deben procesarse mediante sp_RealizarNuevaVenta';
    END IF;
    IF @bysofii_items_json IS NOT NULL THEN
        SELECT COUNT(*)
        INTO v_faltantes
        FROM (
            SELECT id_producto,SUM(cantidad) AS cantidad
            FROM JSON_TABLE(
                @bysofii_items_json,
                '$[*]' COLUMNS(
                    id_producto INT PATH '$.id_producto',
                    cantidad INT PATH '$.cantidad'
                )
            ) j
            GROUP BY id_producto
        ) j
        LEFT JOIN productos p ON p.id_producto=j.id_producto
        WHERE p.id_producto IS NULL OR j.cantidad <= 0 OR p.stock < j.cantidad;

        IF v_faltantes > 0 THEN
            SIGNAL SQLSTATE '45000'
              SET MESSAGE_TEXT='Stock insuficiente para uno o más productos de la venta';
        END IF;
    END IF;
    IF NEW.total < 0 OR NEW.subtotal < 0 OR NEW.iva < 0 OR NEW.costo_envio < 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT='Los importes de la venta no pueden ser negativos';
    END IF;
END$$

-- 3. Decrementa stock justo después de insertar encabezado de venta.
CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    IF @bysofii_items_json IS NOT NULL THEN
        UPDATE productos p
        JOIN (
            SELECT id_producto,SUM(cantidad) AS cantidad
            FROM JSON_TABLE(
                @bysofii_items_json,
                '$[*]' COLUMNS(
                    id_producto INT PATH '$.id_producto',
                    cantidad INT PATH '$.cantidad'
                )
            ) j
            GROUP BY id_producto
        ) x ON x.id_producto=p.id_producto
        SET p.stock=p.stock-x.cantidad
        WHERE p.id_producto=x.id_producto;
    END IF;
END$$

-- 4. Impide eliminar categorías con productos asociados.
CREATE TRIGGER trg_prevent_delete_categoria_with_products
BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    IF EXISTS(SELECT 1 FROM productos WHERE id_categoria=OLD.id_categoria) THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT='No se puede eliminar una categoría que tiene productos asociados';
    END IF;
END$$

-- 5. Audita creación de clientes.
CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria_eventos(tipo_evento,entidad,id_entidad,descripcion,usuario_bd)
    VALUES('ALTA_CLIENTE','clientes',NEW.id_cliente,
           CONCAT('Nuevo cliente registrado: ',NEW.email),USER());
END$$

-- 6. Actualiza gasto acumulado después de una venta confirmada.
CREATE TRIGGER trg_update_total_gastado_cliente
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    IF NEW.estado NOT IN ('Cancelado','Devuelto') THEN
        UPDATE clientes
        SET total_gastado=total_gastado+NEW.total
        WHERE id_cliente=NEW.id_cliente;
    END IF;
END$$

-- 7. Actualiza fecha de modificación de producto.
CREATE TRIGGER trg_set_fecha_modificacion_producto
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    SET NEW.fecha_modificacion=CURRENT_TIMESTAMP;
END$$

-- 8. Impide stock negativo.
CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT='El stock no puede quedar por debajo de cero';
    END IF;
END$$

-- 9. Normaliza primera letra de nombre y apellido.
CREATE TRIGGER trg_capitalize_nombre_cliente
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    SET NEW.nombre = CONCAT(UPPER(LEFT(TRIM(NEW.nombre),1)),LOWER(SUBSTRING(TRIM(NEW.nombre),2)));
    SET NEW.apellido = CONCAT(UPPER(LEFT(TRIM(NEW.apellido),1)),LOWER(SUBSTRING(TRIM(NEW.apellido),2)));
END$$

-- 10. Recalcula total de una venta cuando se edita una línea.
-- Para cambios de varias líneas se recomienda sp_RealizarNuevaVenta/consultas de control.
CREATE TRIGGER trg_recalculate_total_venta_on_detalle_change
AFTER UPDATE ON detalle_ventas
FOR EACH ROW
BEGIN
    DECLARE v_old_total DECIMAL(14,2);
    DECLARE v_new_subtotal DECIMAL(14,2);
    DECLARE v_envio DECIMAL(12,2);
    DECLARE v_new_total DECIMAL(14,2);

    SELECT total,costo_envio
      INTO v_old_total,v_envio
    FROM ventas
    WHERE id_venta=NEW.id_venta
    FOR UPDATE;

    SELECT COALESCE(SUM(d.cantidad*d.precio_unitario_congelado),0)
      INTO v_new_subtotal
    FROM detalle_ventas d
    WHERE d.id_venta=NEW.id_venta;

    SET v_new_total=ROUND(v_new_subtotal + ROUND(v_new_subtotal*0.19,2) + v_envio,2);

    UPDATE ventas
    SET subtotal=v_new_subtotal,
        iva=ROUND(v_new_subtotal*0.19,2),
        total=v_new_total
    WHERE id_venta=NEW.id_venta;

    UPDATE clientes c
    JOIN ventas v ON v.id_cliente=c.id_cliente
    SET c.total_gastado=GREATEST(0,c.total_gastado+(v_new_total-v_old_total))
    WHERE v.id_venta=NEW.id_venta
      AND v.estado NOT IN ('Cancelado','Devuelto');
END$$

-- 11. Audita cambios de estado del pedido.
CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF NOT (OLD.estado <=> NEW.estado) THEN
        INSERT INTO log_estados_pedido(id_venta,estado_anterior,estado_nuevo,cambiado_por)
        VALUES(NEW.id_venta,OLD.estado,NEW.estado,USER());

        IF OLD.estado NOT IN ('Cancelado','Devuelto')
           AND NEW.estado IN ('Cancelado','Devuelto') THEN
            UPDATE clientes
            SET total_gastado=GREATEST(0,total_gastado-NEW.total)
            WHERE id_cliente=NEW.id_cliente;
        ELSEIF OLD.estado IN ('Cancelado','Devuelto')
           AND NEW.estado NOT IN ('Cancelado','Devuelto') THEN
            UPDATE clientes
            SET total_gastado=total_gastado+NEW.total
            WHERE id_cliente=NEW.id_cliente;
        END IF;

        UPDATE clientes
        SET fecha_ultimo_pedido=(
            SELECT MAX(v2.fecha_venta)
            FROM ventas v2
            WHERE v2.id_cliente=NEW.id_cliente
              AND v2.estado NOT IN ('Cancelado','Devuelto')
        )
        WHERE id_cliente=NEW.id_cliente;
    END IF;
END$$

-- 12. Impide precios cero o negativos durante actualizaciones.
CREATE TRIGGER trg_prevent_price_zero_or_less
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT='El precio debe ser mayor que cero';
    END IF;
END$$

-- 13. Genera alerta si el stock queda por debajo del mínimo.
CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < NEW.stock_minimo
       AND (OLD.stock >= OLD.stock_minimo OR OLD.stock_minimo <> NEW.stock_minimo) THEN
        INSERT INTO alertas_stock(id_producto,stock_actual,stock_minimo)
        VALUES(NEW.id_producto,NEW.stock,NEW.stock_minimo);
    END IF;
END$$

-- 14. Archiva venta antes de eliminarla, incluyendo líneas históricas.
CREATE TRIGGER trg_archive_deleted_venta
BEFORE DELETE ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO venta_archivo(
      id_venta,id_cliente,id_sucursal,fecha_venta,estado,subtotal,iva,costo_envio,total,detalles_json,archivado_por
    )
    VALUES(
      OLD.id_venta,OLD.id_cliente,OLD.id_sucursal,OLD.fecha_venta,OLD.estado,
      OLD.subtotal,OLD.iva,OLD.costo_envio,OLD.total,
      COALESCE((
        SELECT JSON_ARRAYAGG(JSON_OBJECT(
          'id_producto',d.id_producto,
          'cantidad',d.cantidad,
          'precio_unitario_congelado',d.precio_unitario_congelado,
          'costo_unitario_congelado',d.costo_unitario_congelado
        ))
        FROM detalle_ventas d WHERE d.id_venta=OLD.id_venta
      ),JSON_ARRAY()),
      USER()
    );
END$$

-- 15. Valida correo al insertar cliente.
CREATE TRIGGER trg_validate_email_format_on_customer
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF NEW.email IS NULL OR NEW.email NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$' THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT='Formato de email inválido';
    END IF;
END$$

-- 16. Actualiza fecha de última orden del cliente.
CREATE TRIGGER trg_update_last_order_date_customer
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    IF NEW.estado NOT IN ('Cancelado','Devuelto') THEN
        UPDATE clientes
        SET fecha_ultimo_pedido=NEW.fecha_venta
        WHERE id_cliente=NEW.id_cliente
          AND (fecha_ultimo_pedido IS NULL OR fecha_ultimo_pedido<NEW.fecha_venta);
    END IF;
END$$

-- 17. Impide autoreferidos.
CREATE TRIGGER trg_prevent_self_referral
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF NEW.id_referido_por IS NOT NULL AND NEW.id_referido_por=NEW.id_cliente THEN
        SIGNAL SQLSTATE '45000'
          SET MESSAGE_TEXT='Un cliente no puede referirse a sí mismo';
    END IF;
END$$

-- 18. Audita solicitudes de cambios de permisos.
-- MySQL no permite un trigger sobre mysql.grants: este trigger deja trazabilidad
-- sobre la tabla controlada por la aplicación antes de ejecutar el GRANT real.
CREATE TRIGGER trg_log_permission_changes
AFTER INSERT ON solicitudes_permiso
FOR EACH ROW
BEGIN
    INSERT INTO logs_cambios_permisos(cuenta_objetivo,accion,privilegio,ejecutado_por,observacion)
    VALUES(NEW.cuenta_objetivo,NEW.accion,NEW.privilegio,NEW.solicitado_por,
           CONCAT('Solicitud de cambio de permisos; estado=',NEW.estado));
END$$

-- 19. Si llega un producto sin categoría, usa General; se crea en 01 por seguridad.
CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NULL THEN
        INSERT IGNORE INTO categorias(nombre,descripcion)
        VALUES('General','Categoría automática para productos sin clasificación');
        SET NEW.id_categoria=(SELECT id_categoria FROM categorias WHERE nombre='General');
    END IF;
END$$

-- 20. Mantiene el contador de productos al insertar.
-- Los movimientos de categoría se realizan de forma transaccional por el procedimiento
-- sp_MoverProductosEntreCategorias, que sincroniza ambos contadores.
CREATE TRIGGER trg_update_producto_count_in_categoria
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    UPDATE categorias
    SET producto_count=producto_count+1
    WHERE id_categoria=NEW.id_categoria;
END$$

DELIMITER ;

-- Sincronización inicial por si el archivo se ejecuta sobre datos ya existentes.
UPDATE categorias c
SET producto_count=(SELECT COUNT(*) FROM productos p WHERE p.id_categoria=c.id_categoria);
