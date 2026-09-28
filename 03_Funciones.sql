-- ============================================================
-- 03_Funciones.sql
-- 20 funciones de negocio de E-commerce BySofiii
-- ============================================================
USE ecommerce_bysofii;

DROP FUNCTION IF EXISTS fn_CalcularTotalVenta;
DROP FUNCTION IF EXISTS fn_VerificarDisponibilidadStock;
DROP FUNCTION IF EXISTS fn_ObtenerPrecioProducto;
DROP FUNCTION IF EXISTS fn_CalcularEdadCliente;
DROP FUNCTION IF EXISTS fn_FormatearNombreCompleto;
DROP FUNCTION IF EXISTS fn_EsClienteNuevo;
DROP FUNCTION IF EXISTS fn_CalcularCostoEnvio;
DROP FUNCTION IF EXISTS fn_AplicarDescuento;
DROP FUNCTION IF EXISTS fn_ObtenerUltimaFechaCompra;
DROP FUNCTION IF EXISTS fn_ValidarFormatoEmail;
DROP FUNCTION IF EXISTS fn_ObtenerNombreCategoria;
DROP FUNCTION IF EXISTS fn_ContarVentasCliente;
DROP FUNCTION IF EXISTS fn_CalcularDiasDesdeUltimaCompra;
DROP FUNCTION IF EXISTS fn_DeterminarEstadoLealtad;
DROP FUNCTION IF EXISTS fn_GenerarSKU;
DROP FUNCTION IF EXISTS fn_CalcularIVA;
DROP FUNCTION IF EXISTS fn_ObtenerStockTotalPorCategoria;
DROP FUNCTION IF EXISTS fn_EstimarFechaEntrega;
DROP FUNCTION IF EXISTS fn_ConvertirMoneda;
DROP FUNCTION IF EXISTS fn_ValidarComplejidadContraseña;

DELIMITER $$

-- 1. Calcula el total de una venta específica.
CREATE FUNCTION fn_CalcularTotalVenta(p_id_venta INT)
RETURNS DECIMAL(14,2)
READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(14,2);
    SELECT COALESCE(SUM(cantidad*precio_unitario_congelado),0)
      INTO v_total
    FROM detalle_ventas
    WHERE id_venta=p_id_venta;
    RETURN v_total;
END$$

-- 2. Valida si hay stock suficiente.
CREATE FUNCTION fn_VerificarDisponibilidadStock(p_id_producto INT,p_cantidad INT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_stock INT;
    SELECT stock INTO v_stock FROM productos WHERE id_producto=p_id_producto;
    RETURN v_stock IS NOT NULL AND p_cantidad > 0 AND v_stock >= p_cantidad;
END$$

-- 3. Devuelve precio actual.
CREATE FUNCTION fn_ObtenerPrecioProducto(p_id_producto INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_precio DECIMAL(12,2);
    SELECT precio INTO v_precio FROM productos WHERE id_producto=p_id_producto;
    RETURN COALESCE(v_precio,0);
END$$

-- 4. Calcula edad a partir de fecha de nacimiento.
CREATE FUNCTION fn_CalcularEdadCliente(p_id_cliente INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_nacimiento DATE;
    SELECT fecha_nacimiento INTO v_nacimiento FROM clientes WHERE id_cliente=p_id_cliente;
    IF v_nacimiento IS NULL THEN RETURN NULL; END IF;
    RETURN TIMESTAMPDIFF(YEAR,v_nacimiento,CURRENT_DATE)
           - (DATE_FORMAT(CURRENT_DATE,'%m%d') < DATE_FORMAT(v_nacimiento,'%m%d'));
END$$

-- 5. Formatea nombre completo.
CREATE FUNCTION fn_FormatearNombreCompleto(p_id_cliente INT)
RETURNS VARCHAR(220)
READS SQL DATA
BEGIN
    DECLARE v_nombre VARCHAR(100);
    DECLARE v_apellido VARCHAR(100);
    SELECT nombre,apellido INTO v_nombre,v_apellido FROM clientes WHERE id_cliente=p_id_cliente;
    RETURN TRIM(CONCAT(
        UPPER(LEFT(TRIM(COALESCE(v_nombre,'')),1)),
        LOWER(SUBSTRING(TRIM(COALESCE(v_nombre,'')),2)),
        ' ',
        UPPER(LEFT(TRIM(COALESCE(v_apellido,'')),1)),
        LOWER(SUBSTRING(TRIM(COALESCE(v_apellido,'')),2))
    ));
END$$

-- 6. TRUE si primera compra dentro de los últimos 30 días.
CREATE FUNCTION fn_EsClienteNuevo(p_id_cliente INT)
RETURNS BOOLEAN
READS SQL DATA
BEGIN
    DECLARE v_primera DATETIME;
    SELECT MIN(fecha_venta) INTO v_primera
    FROM ventas
    WHERE id_cliente=p_id_cliente
      AND estado NOT IN ('Cancelado','Devuelto');
    RETURN v_primera IS NOT NULL AND v_primera >= CURRENT_TIMESTAMP - INTERVAL 30 DAY;
END$$

-- 7. Costo de envío aproximado por peso total.
CREATE FUNCTION fn_CalcularCostoEnvio(p_id_venta INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
    DECLARE v_peso DECIMAL(12,3);
    SELECT COALESCE(SUM(d.cantidad*p.peso_kg),0)
      INTO v_peso
    FROM detalle_ventas d
    JOIN productos p ON p.id_producto=d.id_producto
    WHERE d.id_venta=p_id_venta;
    RETURN CASE
        WHEN v_peso <= 1 THEN 6000
        WHEN v_peso <= 3 THEN 9000
        ELSE 12000
    END;
END$$

-- 8. Aplica descuento porcentual con controles de rango.
CREATE FUNCTION fn_AplicarDescuento(p_monto DECIMAL(14,2),p_porcentaje DECIMAL(5,2))
RETURNS DECIMAL(14,2)
DETERMINISTIC
NO SQL
BEGIN
    IF p_monto < 0 OR p_porcentaje < 0 OR p_porcentaje > 100 THEN
        RETURN NULL;
    END IF;
    RETURN ROUND(p_monto*(1-p_porcentaje/100),2);
END$$

-- 9. Última compra del cliente.
CREATE FUNCTION fn_ObtenerUltimaFechaCompra(p_id_cliente INT)
RETURNS DATETIME
READS SQL DATA
BEGIN
    DECLARE v_fecha DATETIME;
    SELECT MAX(fecha_venta) INTO v_fecha
    FROM ventas
    WHERE id_cliente=p_id_cliente
      AND estado NOT IN ('Cancelado','Devuelto');
    RETURN v_fecha;
END$$

-- 10. Valida formato de correo.
CREATE FUNCTION fn_ValidarFormatoEmail(p_email VARCHAR(190))
RETURNS BOOLEAN
DETERMINISTIC
NO SQL
BEGIN
    RETURN p_email IS NOT NULL
       AND p_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+[.][A-Za-z]{2,}$';
END$$

-- 11. Nombre de categoría de un producto.
CREATE FUNCTION fn_ObtenerNombreCategoria(p_id_producto INT)
RETURNS VARCHAR(100)
READS SQL DATA
BEGIN
    DECLARE v_nombre VARCHAR(100);
    SELECT c.nombre INTO v_nombre
    FROM productos p
    JOIN categorias c ON c.id_categoria=p.id_categoria
    WHERE p.id_producto=p_id_producto;
    RETURN v_nombre;
END$$

-- 12. Número de compras del cliente.
CREATE FUNCTION fn_ContarVentasCliente(p_id_cliente INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_count INT;
    SELECT COUNT(*) INTO v_count
    FROM ventas
    WHERE id_cliente=p_id_cliente
      AND estado NOT IN ('Cancelado','Devuelto');
    RETURN v_count;
END$$

-- 13. Días desde la última compra.
CREATE FUNCTION fn_CalcularDiasDesdeUltimaCompra(p_id_cliente INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_ultima DATETIME;
    SELECT MAX(fecha_venta) INTO v_ultima
    FROM ventas
    WHERE id_cliente=p_id_cliente
      AND estado NOT IN ('Cancelado','Devuelto');
    RETURN IF(v_ultima IS NULL,NULL,DATEDIFF(CURRENT_DATE,DATE(v_ultima)));
END$$

-- 14. Nivel de lealtad según gasto histórico.
CREATE FUNCTION fn_DeterminarEstadoLealtad(p_id_cliente INT)
RETURNS VARCHAR(20)
READS SQL DATA
BEGIN
    DECLARE v_gasto DECIMAL(14,2);
    SELECT COALESCE(SUM(total),0) INTO v_gasto
    FROM ventas
    WHERE id_cliente=p_id_cliente
      AND estado NOT IN ('Cancelado','Devuelto');
    RETURN CASE
      WHEN v_gasto >= 1000000 THEN 'Oro'
      WHEN v_gasto >= 500000 THEN 'Plata'
      ELSE 'Bronce'
    END;
END$$

-- 15. Genera un SKU reproducible por nombre + categoría.
CREATE FUNCTION fn_GenerarSKU(p_nombre VARCHAR(180),p_categoria VARCHAR(100))
RETURNS VARCHAR(80)
DETERMINISTIC
NO SQL
BEGIN
    RETURN CONCAT(
      'BSF-',
      UPPER(LEFT(REGEXP_REPLACE(COALESCE(p_categoria,''),'[^A-Za-z0-9]',''),8)),
      '-',
      LPAD(MOD(CRC32(CONCAT(COALESCE(p_nombre,''),'|',COALESCE(p_categoria,''))),1000000),6,'0')
    );
END$$

-- 16. IVA de una venta.
CREATE FUNCTION fn_CalcularIVA(p_total_sin_iva DECIMAL(14,2))
RETURNS DECIMAL(14,2)
DETERMINISTIC
NO SQL
BEGIN
    RETURN IF(p_total_sin_iva < 0,NULL,ROUND(p_total_sin_iva*0.19,2));
END$$

-- 17. Stock total de una categoría.
CREATE FUNCTION fn_ObtenerStockTotalPorCategoria(p_id_categoria INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_stock INT;
    SELECT COALESCE(SUM(stock),0) INTO v_stock
    FROM productos WHERE id_categoria=p_id_categoria;
    RETURN v_stock;
END$$

-- 18. Fecha estimada de entrega según región.
CREATE FUNCTION fn_EstimarFechaEntrega(p_id_venta INT)
RETURNS DATE
READS SQL DATA
BEGIN
    DECLARE v_region VARCHAR(100);
    DECLARE v_dias INT DEFAULT 5;
    SELECT c.region INTO v_region
    FROM ventas v JOIN clientes c ON c.id_cliente=v.id_cliente
    WHERE v.id_venta=p_id_venta;
    IF v_region='Santander' THEN SET v_dias=2;
    ELSEIF v_region='Atlántico' THEN SET v_dias=4;
    ELSE SET v_dias=5;
    END IF;
    RETURN DATE(DATE_ADD(COALESCE((SELECT fecha_venta FROM ventas WHERE id_venta=p_id_venta),CURRENT_TIMESTAMP),INTERVAL v_dias DAY));
END$$

-- 19. Conversión de moneda con tasas fijas de proyecto.
CREATE FUNCTION fn_ConvertirMoneda(p_monto DECIMAL(14,2),p_origen CHAR(3),p_destino CHAR(3))
RETURNS DECIMAL(14,2)
DETERMINISTIC
NO SQL
BEGIN
    DECLARE v_cop_por_unidad DECIMAL(14,4);
    DECLARE v_result DECIMAL(14,2);
    SET p_origen=UPPER(p_origen);
    SET p_destino=UPPER(p_destino);
    IF p_origen=p_destino THEN RETURN ROUND(p_monto,2); END IF;
    IF p_origen='USD' THEN SET v_cop_por_unidad=4000;
    ELSEIF p_origen='EUR' THEN SET v_cop_por_unidad=4300;
    ELSEIF p_origen='COP' THEN SET v_cop_por_unidad=1;
    ELSE RETURN NULL;
    END IF;
    IF p_destino='COP' THEN SET v_result=p_monto*v_cop_por_unidad;
    ELSEIF p_destino='USD' THEN SET v_result=p_monto*v_cop_por_unidad/4000;
    ELSEIF p_destino='EUR' THEN SET v_result=p_monto*v_cop_por_unidad/4300;
    ELSE RETURN NULL;
    END IF;
    RETURN ROUND(v_result,2);
END$$

-- 20. Valida complejidad mínima de contraseña.
CREATE FUNCTION fn_ValidarComplejidadContraseña(p_password VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
NO SQL
BEGIN
    RETURN p_password IS NOT NULL
       AND CHAR_LENGTH(p_password) >= 10
       AND p_password REGEXP '[A-Z]'
       AND p_password REGEXP '[a-z]'
       AND p_password REGEXP '[0-9]'
       AND p_password REGEXP '[^A-Za-z0-9]';
END$$

DELIMITER ;
