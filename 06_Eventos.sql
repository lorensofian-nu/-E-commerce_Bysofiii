-- ============================================================
-- 06_Eventos.sql
-- 20 eventos programados de mantenimiento y negocio
-- ============================================================
USE ecommerce_bysofii;

SET GLOBAL event_scheduler = ON;

DROP EVENT IF EXISTS evt_generate_weekly_sales_report;
DROP EVENT IF EXISTS evt_cleanup_temp_tables_daily;
DROP EVENT IF EXISTS evt_archive_old_logs_monthly;
DROP EVENT IF EXISTS evt_deactivate_expired_promotions_hourly;
DROP EVENT IF EXISTS evt_recalculate_customer_loyalty_tiers_nightly;
DROP EVENT IF EXISTS evt_generate_reorder_list_daily;
DROP EVENT IF EXISTS evt_rebuild_indexes_weekly;
DROP EVENT IF EXISTS evt_suspend_inactive_accounts_quarterly;
DROP EVENT IF EXISTS evt_aggregate_daily_sales_data;
DROP EVENT IF EXISTS evt_check_data_consistency_nightly;
DROP EVENT IF EXISTS evt_send_birthday_greetings_daily;
DROP EVENT IF EXISTS evt_update_product_rankings_hourly;
DROP EVENT IF EXISTS evt_backup_critical_tables_daily;
DROP EVENT IF EXISTS evt_clear_abandoned_carts_daily;
DROP EVENT IF EXISTS evt_calculate_monthly_kpis;
DROP EVENT IF EXISTS evt_refresh_materialized_views_nightly;
DROP EVENT IF EXISTS evt_log_database_size_weekly;
DROP EVENT IF EXISTS evt_detect_fraudulent_activity_hourly;
DROP EVENT IF EXISTS evt_generate_supplier_performance_report_monthly;
DROP EVENT IF EXISTS evt_purge_soft_deleted_records_weekly;

-- Tabla mínima solicitada por el enunciado.
CREATE TABLE IF NOT EXISTS reporte_ventas_semanales (
    id_reporte BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    semana_inicio DATE NOT NULL,
    semana_fin DATE NOT NULL,
    cantidad_ventas INT UNSIGNED NOT NULL DEFAULT 0,
    ingresos DECIMAL(16,2) NOT NULL DEFAULT 0,
    generado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (semana_inicio)
) ENGINE=InnoDB;

DELIMITER $$

-- 1. Reporte semanal de ventas.
CREATE EVENT evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO reporte_ventas_semanales(semana_inicio,semana_fin,cantidad_ventas,ingresos)
    SELECT DATE_SUB(CURRENT_DATE,INTERVAL WEEKDAY(CURRENT_DATE) DAY),
           CURRENT_DATE,
           COUNT(*),
           COALESCE(SUM(total),0)
    FROM ventas
    WHERE fecha_venta >= DATE_SUB(CURRENT_DATE,INTERVAL WEEKDAY(CURRENT_DATE) DAY)
      AND estado NOT IN ('Cancelado','Devuelto')
    ON DUPLICATE KEY UPDATE
       semana_fin=VALUES(semana_fin),
       cantidad_ventas=VALUES(cantidad_ventas),
       ingresos=VALUES(ingresos),
       generado_en=CURRENT_TIMESTAMP;
END$$

-- 2. Limpieza diaria de tabla temporal.
CREATE EVENT evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
    DELETE FROM tabla_temporal_procesos WHERE creado_en < CURRENT_TIMESTAMP - INTERVAL 1 DAY$$

-- 3. Archiva logs con más de 6 meses.
CREATE EVENT evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 1 MONTH
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO logs_historicos(tipo_log,id_origen,payload)
    SELECT 'PRECIO',id_log,
           JSON_OBJECT('id_producto',id_producto,'precio_anterior',precio_anterior,'precio_nuevo',precio_nuevo,
                       'modificado_por',modificado_por,'cambiado_en',cambiado_en)
    FROM log_cambios_precio
    WHERE cambiado_en < CURRENT_TIMESTAMP - INTERVAL 6 MONTH;

    DELETE FROM log_cambios_precio
    WHERE cambiado_en < CURRENT_TIMESTAMP - INTERVAL 6 MONTH;
END$$

-- 4. Desactiva promociones expiradas cada hora.
CREATE EVENT evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP + INTERVAL 1 HOUR
ON COMPLETION PRESERVE
ENABLE
DO
    UPDATE promociones
    SET activo=FALSE
    WHERE fecha_fin<CURRENT_TIMESTAMP AND activo=TRUE$$

-- 5. Recalcula niveles de lealtad cada noche en auditoría.
CREATE EVENT evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO auditoria_eventos(tipo_evento,entidad,id_entidad,descripcion,usuario_bd)
    SELECT 'LEALTAD_NOCTURNA','clientes',c.id_cliente,
           CONCAT('Nivel recalculado: ',fn_DeterminarEstadoLealtad(c.id_cliente)),USER()
    FROM clientes c
    WHERE c.activo=TRUE;
END$$

-- 6. Genera lista de reabastecimiento diariamente.
CREATE EVENT evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO reorder_list(id_producto,stock_actual,stock_minimo)
    SELECT p.id_producto,p.stock,p.stock_minimo
    FROM productos p
    WHERE p.stock<p.stock_minimo
      AND p.activo=TRUE
      AND NOT EXISTS(
          SELECT 1 FROM reorder_list r
          WHERE r.id_producto=p.id_producto AND r.atendido=FALSE
      );
END$$

-- 7. Optimiza índices mediante actualización de estadísticas.
CREATE EVENT evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_TIMESTAMP + INTERVAL 7 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    ANALYZE TABLE productos,ventas,detalle_ventas,clientes;
END$$

-- 8. Suspende cuentas sin actividad por más de un año.
CREATE EVENT evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 3 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 3 MONTH
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    UPDATE clientes
    SET activo=FALSE
    WHERE activo=TRUE
      AND COALESCE(ultimo_acceso,fecha_ultimo_pedido,fecha_registro) < CURRENT_TIMESTAMP - INTERVAL 1 YEAR;
END$$

-- 9. Agrega ventas diarias.
CREATE EVENT evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO resumen_ventas_diarias(fecha,cantidad_ventas,ingresos)
    SELECT CURRENT_DATE - INTERVAL 1 DAY,COUNT(*),COALESCE(SUM(total),0)
    FROM ventas
    WHERE DATE(fecha_venta)=CURRENT_DATE-INTERVAL 1 DAY
      AND estado NOT IN ('Cancelado','Devuelto')
    ON DUPLICATE KEY UPDATE
       cantidad_ventas=VALUES(cantidad_ventas),
       ingresos=VALUES(ingresos),
       actualizado_en=CURRENT_TIMESTAMP;
END$$

-- 10. Busca inconsistencias críticas.
CREATE EVENT evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO auditoria_eventos(tipo_evento,entidad,id_entidad,descripcion,usuario_bd)
    SELECT 'CONSISTENCIA','ventas',v.id_venta,'Venta sin detalle detectada',USER()
    FROM ventas v
    WHERE NOT EXISTS(SELECT 1 FROM detalle_ventas d WHERE d.id_venta=v.id_venta)
      AND v.estado NOT IN ('Cancelado','Devuelto');

    INSERT INTO auditoria_eventos(tipo_evento,entidad,id_entidad,descripcion,usuario_bd)
    SELECT 'CONSISTENCIA','productos',p.id_producto,
           CONCAT('Stock negativo detectado: ',p.stock),USER()
    FROM productos p
    WHERE p.stock<0;
END$$

-- 11. Lista clientes cumpleañeros y crea cupón.
CREATE EVENT evt_send_birthday_greetings_daily
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT IGNORE INTO cumpleanios_cupones(id_cliente,fecha_nacimiento,codigo,porcentaje)
    SELECT id_cliente,fecha_nacimiento,
           CONCAT('BDAY-',id_cliente,'-',DATE_FORMAT(CURRENT_DATE,'%Y%m%d')),10
    FROM clientes
    WHERE activo=TRUE
      AND fecha_nacimiento IS NOT NULL
      AND MONTH(fecha_nacimiento)=MONTH(CURRENT_DATE)
      AND DAY(fecha_nacimiento)=DAY(CURRENT_DATE);
END$$

-- 12. Actualiza ranking de productos cada hora.
CREATE EVENT evt_update_product_rankings_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP + INTERVAL 1 HOUR
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE FROM rankings_productos;

    INSERT INTO rankings_productos(id_producto,unidades_vendidas,ingresos,posicion)
    SELECT id_producto,unidades_vendidas,ingresos,
           ROW_NUMBER() OVER(ORDER BY ingresos DESC)
    FROM (
        SELECT d.id_producto,
               SUM(d.cantidad) AS unidades_vendidas,
               SUM(d.cantidad*d.precio_unitario_congelado) AS ingresos
        FROM detalle_ventas d
        JOIN ventas v ON v.id_venta=d.id_venta
        WHERE v.estado NOT IN ('Cancelado','Devuelto')
        GROUP BY d.id_producto
    ) z;
END$$

-- 13. Backup lógico interno de tablas críticas en JSON.
CREATE EVENT evt_backup_critical_tables_daily
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO backup_critico(tabla_nombre,filas_json)
    SELECT 'productos',COALESCE(JSON_ARRAYAGG(JSON_OBJECT(
        'id_producto',id_producto,'nombre',nombre,'precio',precio,'costo',costo,'stock',stock,'sku',sku
    )),JSON_ARRAY())
    FROM productos;

    INSERT INTO backup_critico(tabla_nombre,filas_json)
    SELECT 'ventas',COALESCE(JSON_ARRAYAGG(JSON_OBJECT(
        'id_venta',id_venta,'id_cliente',id_cliente,'fecha_venta',fecha_venta,'estado',estado,'total',total
    )),JSON_ARRAY())
    FROM ventas;
END$$

-- 14. Archiva y limpia carritos abandonados >72 horas.
CREATE EVENT evt_clear_abandoned_carts_daily
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO carritos_archivo(id_carrito,id_cliente,creado_en,actualizado_en,detalles_json)
    SELECT ca.id_carrito,ca.id_cliente,ca.creado_en,ca.actualizado_en,
           COALESCE((
             SELECT JSON_ARRAYAGG(JSON_OBJECT('id_producto',cd.id_producto,'cantidad',cd.cantidad))
             FROM carrito_detalle cd WHERE cd.id_carrito=ca.id_carrito
           ),JSON_ARRAY())
    FROM carritos ca
    WHERE ca.estado='Abandonado'
      AND ca.actualizado_en<CURRENT_TIMESTAMP-INTERVAL 72 HOUR;

    DELETE FROM carritos
    WHERE estado='Abandonado'
      AND actualizado_en<CURRENT_TIMESTAMP-INTERVAL 72 HOUR;
END$$

-- 15. Calcula KPIs mensuales.
CREATE EVENT evt_calculate_monthly_kpis
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 1 MONTH
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO kpis_mensuales(periodo,ventas,ingresos,clientes_nuevos,ticket_promedio)
    SELECT DATE_FORMAT(DATE_SUB(CURRENT_DATE,INTERVAL 1 MONTH),'%Y-%m'),
           COUNT(v.id_venta),
           COALESCE(SUM(v.total),0),
           (SELECT COUNT(*) FROM clientes c
            WHERE DATE_FORMAT(c.fecha_registro,'%Y-%m')=DATE_FORMAT(DATE_SUB(CURRENT_DATE,INTERVAL 1 MONTH),'%Y-%m')),
           COALESCE(AVG(v.total),0)
    FROM ventas v
    WHERE DATE_FORMAT(v.fecha_venta,'%Y-%m')=DATE_FORMAT(DATE_SUB(CURRENT_DATE,INTERVAL 1 MONTH),'%Y-%m')
      AND v.estado NOT IN ('Cancelado','Devuelto')
    ON DUPLICATE KEY UPDATE
       ventas=VALUES(ventas),ingresos=VALUES(ingresos),
       clientes_nuevos=VALUES(clientes_nuevos),ticket_promedio=VALUES(ticket_promedio),
       actualizado_en=CURRENT_TIMESTAMP;
END$$

-- 16. Refresca "vista materializada" simulada de rankings.
CREATE EVENT evt_refresh_materialized_views_nightly
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_TIMESTAMP + INTERVAL 1 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE FROM rankings_productos;
    INSERT INTO rankings_productos(id_producto,unidades_vendidas,ingresos,posicion)
    SELECT id_producto,unidades_vendidas,ingresos,
           ROW_NUMBER() OVER(ORDER BY ingresos DESC)
    FROM (
      SELECT d.id_producto,SUM(d.cantidad) unidades_vendidas,
             SUM(d.cantidad*d.precio_unitario_congelado) ingresos
      FROM detalle_ventas d JOIN ventas v ON v.id_venta=d.id_venta
      WHERE v.estado NOT IN ('Cancelado','Devuelto')
      GROUP BY d.id_producto
    ) x;
END$$

-- 17. Registra tamaño de la base.
CREATE EVENT evt_log_database_size_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_TIMESTAMP + INTERVAL 7 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO tamano_bd_log(esquema,bytes_datos,bytes_indices,bytes_total)
    SELECT table_schema,
           COALESCE(SUM(data_length),0),
           COALESCE(SUM(index_length),0),
           COALESCE(SUM(data_length+index_length),0)
    FROM information_schema.tables
    WHERE table_schema='ecommerce_bysofii'
    GROUP BY table_schema;
END$$

-- 18. Detecta actividad de pago sospechosa.
CREATE EVENT evt_detect_fraudulent_activity_hourly
ON SCHEDULE EVERY 1 HOUR
STARTS CURRENT_TIMESTAMP + INTERVAL 1 HOUR
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO actividad_sospechosa(id_cliente,descripcion,cantidad_eventos)
    SELECT x.id_cliente,
           'Tres o más pagos fallidos durante las últimas 24 horas',
           x.cantidad_eventos
    FROM (
      SELECT id_cliente,COUNT(*) AS cantidad_eventos
      FROM intentos_pago
      WHERE resultado='Fallido'
        AND creado_en>=CURRENT_TIMESTAMP-INTERVAL 24 HOUR
      GROUP BY id_cliente
      HAVING COUNT(*)>=3
    ) x
    WHERE NOT EXISTS(
      SELECT 1 FROM actividad_sospechosa a
      WHERE a.id_cliente=x.id_cliente
        AND a.detectado_en>=CURRENT_TIMESTAMP-INTERVAL 24 HOUR
        AND a.revisado=FALSE
    );
END$$

-- 19. Reporte mensual de proveedores.
CREATE EVENT evt_generate_supplier_performance_report_monthly
ON SCHEDULE EVERY 1 MONTH
STARTS CURRENT_TIMESTAMP + INTERVAL 1 MONTH
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    INSERT INTO rendimiento_proveedores(id_proveedor,periodo,unidades_vendidas,ingresos,posicion)
    SELECT id_proveedor,
           DATE_FORMAT(DATE_SUB(CURRENT_DATE,INTERVAL 1 MONTH),'%Y-%m'),
           unidades,ingresos,
           ROW_NUMBER() OVER(ORDER BY ingresos DESC)
    FROM (
      SELECT pr.id_proveedor,
             SUM(d.cantidad) unidades,
             SUM(d.cantidad*d.precio_unitario_congelado) ingresos
      FROM proveedores pr
      JOIN productos p ON p.id_proveedor=pr.id_proveedor
      JOIN detalle_ventas d ON d.id_producto=p.id_producto
      JOIN ventas v ON v.id_venta=d.id_venta
      WHERE DATE_FORMAT(v.fecha_venta,'%Y-%m')=DATE_FORMAT(DATE_SUB(CURRENT_DATE,INTERVAL 1 MONTH),'%Y-%m')
        AND v.estado NOT IN ('Cancelado','Devuelto')
      GROUP BY pr.id_proveedor
    ) x
    ON DUPLICATE KEY UPDATE
       unidades_vendidas=VALUES(unidades_vendidas),
       ingresos=VALUES(ingresos),
       posicion=VALUES(posicion),
       generado_en=CURRENT_TIMESTAMP;
END$$

-- 20. Purga soft-delete antiguo cuando no existe dependencia histórica.
CREATE EVENT evt_purge_soft_deleted_records_weekly
ON SCHEDULE EVERY 1 WEEK
STARTS CURRENT_TIMESTAMP + INTERVAL 7 DAY
ON COMPLETION PRESERVE
ENABLE
DO
BEGIN
    DELETE p
    FROM productos p
    WHERE p.deleted_at IS NOT NULL
      AND p.deleted_at<CURRENT_TIMESTAMP-INTERVAL 30 DAY
      AND NOT EXISTS(SELECT 1 FROM detalle_ventas d WHERE d.id_producto=p.id_producto);

    DELETE c
    FROM clientes c
    WHERE c.deleted_at IS NOT NULL
      AND c.deleted_at<CURRENT_TIMESTAMP-INTERVAL 30 DAY
      AND NOT EXISTS(SELECT 1 FROM ventas v WHERE v.id_cliente=c.id_cliente);
END$$

DELIMITER ;

SHOW EVENTS FROM ecommerce_bysofii;
