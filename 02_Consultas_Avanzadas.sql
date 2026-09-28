-- ============================================================
-- 02_Consultas_Avanzadas.sql
-- 20 consultas de negocio para E-commerce BySofiii
-- ============================================================
USE ecommerce_bysofii;

-- 1. Top 10 Productos Más Vendidos: productos con mayores ingresos históricos.
SELECT p.id_producto, p.nombre,
       SUM(d.cantidad) AS unidades_vendidas,
       ROUND(SUM(d.cantidad * d.precio_unitario_congelado),2) AS ingresos
FROM productos p
JOIN detalle_ventas d ON d.id_producto = p.id_producto
JOIN ventas v ON v.id_venta = d.id_venta
WHERE v.estado NOT IN ('Cancelado','Devuelto')
GROUP BY p.id_producto, p.nombre
ORDER BY ingresos DESC
LIMIT 10;

-- 2. Productos con Bajas Ventas: percentil inferior aproximado (10% inferior por ingreso).
WITH ventas_producto AS (
    SELECT p.id_producto, p.nombre,
           COALESCE(SUM(CASE WHEN v.estado NOT IN ('Cancelado','Devuelto') THEN d.cantidad * d.precio_unitario_congelado END),0) AS ingresos
    FROM productos p
    LEFT JOIN detalle_ventas d ON d.id_producto = p.id_producto
    LEFT JOIN ventas v ON v.id_venta = d.id_venta
    GROUP BY p.id_producto, p.nombre
),
ordenados AS (
    SELECT vp.*, NTILE(10) OVER (ORDER BY ingresos ASC) AS decil_bajo
    FROM ventas_producto vp
)
SELECT id_producto, nombre, ingresos
FROM ordenados
WHERE decil_bajo = 1
ORDER BY ingresos ASC;

-- 3. Clientes VIP: 5 clientes con mayor valor de vida basado en gasto histórico.
SELECT c.id_cliente,
       CONCAT(c.nombre,' ',c.apellido) AS cliente,
       ROUND(SUM(v.total),2) AS ltv
FROM clientes c
JOIN ventas v ON v.id_cliente = c.id_cliente
WHERE v.estado NOT IN ('Cancelado','Devuelto')
GROUP BY c.id_cliente, c.nombre, c.apellido
ORDER BY ltv DESC
LIMIT 5;

-- 4. Análisis de Ventas Mensuales.
SELECT DATE_FORMAT(fecha_venta,'%Y-%m') AS mes,
       COUNT(*) AS cantidad_ventas,
       ROUND(SUM(total),2) AS ventas_totales
FROM ventas
WHERE estado NOT IN ('Cancelado','Devuelto')
GROUP BY DATE_FORMAT(fecha_venta,'%Y-%m')
ORDER BY mes;

-- 5. Crecimiento de Clientes: nuevos registros por trimestre.
SELECT YEAR(fecha_registro) AS anio,
       QUARTER(fecha_registro) AS trimestre,
       COUNT(*) AS clientes_nuevos
FROM clientes
GROUP BY YEAR(fecha_registro), QUARTER(fecha_registro)
ORDER BY anio, trimestre;

-- 6. Tasa de Compra Repetida.
SELECT ROUND(
    100 * SUM(CASE WHEN compras > 1 THEN 1 ELSE 0 END) / COUNT(*),2
) AS tasa_compra_repetida_pct
FROM (
    SELECT c.id_cliente, COUNT(v.id_venta) AS compras
    FROM clientes c
    LEFT JOIN ventas v ON v.id_cliente = c.id_cliente
      AND v.estado NOT IN ('Cancelado','Devuelto')
    GROUP BY c.id_cliente
) x;

-- 7. Productos Comprados Juntos Frecuentemente.
SELECT d1.id_producto AS producto_a, p1.nombre AS nombre_a,
       d2.id_producto AS producto_b, p2.nombre AS nombre_b,
       COUNT(*) AS transacciones_juntas
FROM detalle_ventas d1
JOIN detalle_ventas d2
  ON d1.id_venta = d2.id_venta
 AND d1.id_producto < d2.id_producto
JOIN productos p1 ON p1.id_producto = d1.id_producto
JOIN productos p2 ON p2.id_producto = d2.id_producto
JOIN ventas v ON v.id_venta = d1.id_venta
WHERE v.estado NOT IN ('Cancelado','Devuelto')
GROUP BY d1.id_producto,p1.nombre,d2.id_producto,p2.nombre
ORDER BY transacciones_juntas DESC, producto_a, producto_b
LIMIT 20;

-- 8. Rotación de Inventario por Categoría (unidades vendidas / stock promedio aproximado actual).
SELECT c.id_categoria, c.nombre,
       COALESCE(SUM(CASE WHEN v.id_venta IS NOT NULL THEN d.cantidad ELSE 0 END),0) AS unidades_vendidas,
       COALESCE(SUM(DISTINCT p.stock),0) AS stock_actual,
       ROUND(COALESCE(SUM(CASE WHEN v.id_venta IS NOT NULL THEN d.cantidad ELSE 0 END),0) /
             NULLIF(SUM(DISTINCT p.stock),0),2) AS rotacion_aprox
FROM categorias c
LEFT JOIN productos p ON p.id_categoria = c.id_categoria
LEFT JOIN detalle_ventas d ON d.id_producto = p.id_producto
LEFT JOIN ventas v ON v.id_venta = d.id_venta
 AND v.estado NOT IN ('Cancelado','Devuelto')
GROUP BY c.id_categoria,c.nombre
ORDER BY rotacion_aprox DESC;

-- 9. Productos que Necesitan Reabastecimiento.
SELECT id_producto,nombre,stock,stock_minimo
FROM productos
WHERE stock < stock_minimo
  AND activo = TRUE
ORDER BY (stock_minimo-stock) DESC, nombre;

-- 10. Análisis de Carrito Abandonado (simulado): clientes sin venta en 72 h desde carrito actualizado.
SELECT c.id_cliente,
       CONCAT(c.nombre,' ',c.apellido) AS cliente,
       ca.id_carrito,
       ca.actualizado_en,
       TIMESTAMPDIFF(HOUR,ca.actualizado_en,CURRENT_TIMESTAMP) AS horas_abandonado
FROM carritos ca
JOIN clientes c ON c.id_cliente = ca.id_cliente
WHERE ca.estado = 'Abandonado'
  AND ca.actualizado_en < CURRENT_TIMESTAMP - INTERVAL 72 HOUR
  AND NOT EXISTS (
      SELECT 1 FROM ventas v
      WHERE v.id_cliente = ca.id_cliente
        AND v.fecha_venta > ca.actualizado_en
        AND v.estado NOT IN ('Cancelado','Devuelto')
  )
ORDER BY ca.actualizado_en;

-- 11. Rendimiento de Proveedores por volumen de ventas.
SELECT pr.id_proveedor, pr.nombre,
       COALESCE(SUM(CASE WHEN v.id_venta IS NOT NULL THEN d.cantidad ELSE 0 END),0) AS unidades_vendidas,
       ROUND(COALESCE(SUM(CASE WHEN v.id_venta IS NOT NULL THEN d.cantidad*d.precio_unitario_congelado ELSE 0 END),0),2) AS ingresos
FROM proveedores pr
LEFT JOIN productos p ON p.id_proveedor = pr.id_proveedor
LEFT JOIN detalle_ventas d ON d.id_producto = p.id_producto
LEFT JOIN ventas v ON v.id_venta = d.id_venta
 AND v.estado NOT IN ('Cancelado','Devuelto')
GROUP BY pr.id_proveedor,pr.nombre
ORDER BY unidades_vendidas DESC, ingresos DESC;

-- 12. Análisis Geográfico de Ventas por ciudad y región.
SELECT c.ciudad,c.region,
       COUNT(v.id_venta) AS pedidos,
       ROUND(COALESCE(SUM(v.total),0),2) AS ingresos
FROM clientes c
JOIN ventas v ON v.id_cliente = c.id_cliente
WHERE v.estado NOT IN ('Cancelado','Devuelto')
GROUP BY c.ciudad,c.region
ORDER BY ingresos DESC;

-- 13. Ventas por Hora del Día.
SELECT HOUR(fecha_venta) AS hora,
       COUNT(*) AS pedidos,
       ROUND(SUM(total),2) AS ingresos
FROM ventas
WHERE estado NOT IN ('Cancelado','Devuelto')
GROUP BY HOUR(fecha_venta)
ORDER BY pedidos DESC,hora;

-- 14. Impacto de Promociones: comparar ventas antes/durante/después de la campaña.
SELECT p.id_producto,p.nombre,pr.nombre AS promocion,
       SUM(CASE WHEN v.fecha_venta < pr.fecha_inicio THEN d.cantidad*d.precio_unitario_congelado ELSE 0 END) AS antes,
       SUM(CASE WHEN v.fecha_venta BETWEEN pr.fecha_inicio AND pr.fecha_fin THEN d.cantidad*d.precio_unitario_congelado ELSE 0 END) AS durante,
       SUM(CASE WHEN v.fecha_venta > pr.fecha_fin THEN d.cantidad*d.precio_unitario_congelado ELSE 0 END) AS despues
FROM producto_promocion pp
JOIN productos p ON p.id_producto = pp.id_producto
JOIN promociones pr ON pr.id_promocion = pp.id_promocion
LEFT JOIN detalle_ventas d ON d.id_producto = p.id_producto
LEFT JOIN ventas v ON v.id_venta = d.id_venta
  AND v.estado NOT IN ('Cancelado','Devuelto')
GROUP BY p.id_producto,p.nombre,pr.id_promocion,pr.nombre,pr.fecha_inicio,pr.fecha_fin;

-- 15. Análisis de Cohort: retención mensual desde primera compra.
WITH primeras AS (
    SELECT id_cliente, DATE_FORMAT(MIN(fecha_venta),'%Y-%m') AS cohort_mes
    FROM ventas
    WHERE estado NOT IN ('Cancelado','Devuelto')
    GROUP BY id_cliente
)
SELECT f.cohort_mes,
       DATE_FORMAT(v.fecha_venta,'%Y-%m') AS mes_actividad,
       COUNT(DISTINCT v.id_cliente) AS clientes_activos
FROM primeras f
JOIN ventas v ON v.id_cliente = f.id_cliente
WHERE v.estado NOT IN ('Cancelado','Devuelto')
GROUP BY f.cohort_mes,DATE_FORMAT(v.fecha_venta,'%Y-%m')
ORDER BY f.cohort_mes,mes_actividad;

-- 16. Margen de Beneficio por Producto.
SELECT p.id_producto,p.nombre,
       ROUND(SUM(d.cantidad*d.precio_unitario_congelado),2) AS ingresos,
       ROUND(SUM(d.cantidad*d.costo_unitario_congelado),2) AS costo,
       ROUND(SUM(d.cantidad*(d.precio_unitario_congelado-d.costo_unitario_congelado)),2) AS margen,
       ROUND(100*SUM(d.cantidad*(d.precio_unitario_congelado-d.costo_unitario_congelado)) /
             NULLIF(SUM(d.cantidad*d.precio_unitario_congelado),0),2) AS margen_pct
FROM productos p
JOIN detalle_ventas d ON d.id_producto = p.id_producto
JOIN ventas v ON v.id_venta = d.id_venta
WHERE v.estado NOT IN ('Cancelado','Devuelto')
GROUP BY p.id_producto,p.nombre
ORDER BY margen DESC;

-- 17. Tiempo Promedio Entre Compras por cliente.
WITH ordenes AS (
    SELECT id_cliente,fecha_venta,
           LAG(fecha_venta) OVER(PARTITION BY id_cliente ORDER BY fecha_venta) AS compra_anterior
    FROM ventas
    WHERE estado NOT IN ('Cancelado','Devuelto')
)
SELECT id_cliente,
       ROUND(AVG(TIMESTAMPDIFF(DAY,compra_anterior,fecha_venta)),2) AS dias_promedio_entre_compras
FROM ordenes
WHERE compra_anterior IS NOT NULL
GROUP BY id_cliente
ORDER BY dias_promedio_entre_compras;

-- 18. Productos Más Vistos vs. Más Comprados.
WITH vistas AS (
    SELECT id_producto,COUNT(*) AS vistas
    FROM vistas_producto
    GROUP BY id_producto
),
compras AS (
    SELECT d.id_producto,SUM(d.cantidad) AS unidades
    FROM detalle_ventas d
    JOIN ventas v ON v.id_venta=d.id_venta
    WHERE v.estado NOT IN ('Cancelado','Devuelto')
    GROUP BY d.id_producto
)
SELECT p.id_producto,p.nombre,
       COALESCE(v.vistas,0) AS vistas,
       COALESCE(c.unidades,0) AS unidades_compradas
FROM productos p
LEFT JOIN vistas v ON v.id_producto=p.id_producto
LEFT JOIN compras c ON c.id_producto=p.id_producto
ORDER BY vistas DESC,unidades_compradas DESC;

-- 19. Segmentación de Clientes (RFM): recencia, frecuencia y monetario.
WITH base AS (
    SELECT c.id_cliente,
           MAX(v.fecha_venta) AS ultima_compra,
           COUNT(v.id_venta) AS frecuencia,
           COALESCE(SUM(v.total),0) AS monetario
    FROM clientes c
    LEFT JOIN ventas v ON v.id_cliente=c.id_cliente
      AND v.estado NOT IN ('Cancelado','Devuelto')
    GROUP BY c.id_cliente
),
scored AS (
    SELECT b.*,
           NTILE(5) OVER(ORDER BY DATEDIFF(CURRENT_DATE,DATE(b.ultima_compra)) DESC) AS r_score,
           NTILE(5) OVER(ORDER BY b.frecuencia) AS f_score,
           NTILE(5) OVER(ORDER BY b.monetario) AS m_score
    FROM base b
)
SELECT s.*,
       CONCAT(s.r_score,s.f_score,s.m_score) AS rfm,
       CASE
         WHEN s.r_score >= 4 AND s.f_score >= 4 AND s.m_score >= 4 THEN 'VIP'
         WHEN s.r_score >= 3 AND s.f_score >= 3 THEN 'Leal'
         WHEN s.r_score <= 2 AND s.f_score <= 2 THEN 'En riesgo'
         ELSE 'Oportunidad'
       END AS segmento
FROM scored s
ORDER BY s.r_score DESC,s.f_score DESC,s.m_score DESC;

-- 20. Predicción de Demanda Simple: promedio de unidades de los últimos 3 meses para una categoría.
SET @categoria_objetivo = 1; -- Blush
WITH ventas_mensuales AS (
    SELECT DATE_FORMAT(v.fecha_venta,'%Y-%m') AS mes,
           SUM(d.cantidad) AS unidades
    FROM ventas v
    JOIN detalle_ventas d ON d.id_venta=v.id_venta
    JOIN productos p ON p.id_producto=d.id_producto
    WHERE p.id_categoria=@categoria_objetivo
      AND v.estado NOT IN ('Cancelado','Devuelto')
      AND v.fecha_venta >= DATE_SUB(CURRENT_DATE,INTERVAL 3 MONTH)
    GROUP BY DATE_FORMAT(v.fecha_venta,'%Y-%m')
)
SELECT @categoria_objetivo AS id_categoria,
       ROUND(COALESCE(AVG(unidades),0),2) AS demanda_proyectada_proximo_mes_unidades
FROM ventas_mensuales;
