-- ============================================================
-- 04_Seguridad.sql
-- Seguridad, roles, usuarios, permisos y controles de acceso
-- ============================================================
USE ecommerce_bysofii;

-- Vista segura para atención al cliente.
DROP VIEW IF EXISTS v_info_clientes_basica;
CREATE VIEW v_info_clientes_basica AS
SELECT id_cliente,
       CONCAT(nombre,' ',apellido) AS nombre_completo,
       email,
       ciudad,
       region,
       fecha_registro,
       activo
FROM clientes
WHERE activo=TRUE;


-- Vistas con control de fila por sucursal usando el usuario autenticado.
DROP VIEW IF EXISTS v_ventas_por_sucursal;
CREATE VIEW v_ventas_por_sucursal AS
SELECT v.*
FROM ventas v
JOIN usuario_sucursal us ON us.id_sucursal=v.id_sucursal
WHERE us.login_usuario=SUBSTRING_INDEX(USER(),'@',1)
  AND us.activo=TRUE;

DROP VIEW IF EXISTS v_detalle_ventas_por_sucursal;
CREATE VIEW v_detalle_ventas_por_sucursal AS
SELECT d.*
FROM detalle_ventas d
JOIN ventas v ON v.id_venta=d.id_venta
JOIN usuario_sucursal us ON us.id_sucursal=v.id_sucursal
WHERE us.login_usuario=SUBSTRING_INDEX(USER(),'@',1)
  AND us.activo=TRUE;

-- En entorno de laboratorio se eliminan roles/usuarios del proyecto
-- para que el script sea repetible. Cambiar contraseñas antes de producción.
DROP USER IF EXISTS
    'admin_user'@'localhost',
    'marketing_user'@'localhost',
    'inventory_user'@'localhost',
    'support_user'@'localhost',
    'analyst_user'@'localhost',
    'auditor_user'@'localhost',
    'visitor_user'@'localhost';

DROP ROLE IF EXISTS
    'bysofii-calamardo'@'%',
    'glam-boss'@'%',
    'glam-data'@'%',
    'esponjita'@'%',
    'cupid-glow'@'%',
    'contorno-financiero'@'%',
    'miradita'@'%';

-- Roles originales de BySofiii:
-- bysofii-calamardo = Administrador_Sistema
-- glam-boss          = Gerente_Marketing
-- glam-data          = Analista_Datos
-- esponjita          = Empleado_Inventario
-- cupid-glow         = Atencion_Cliente
-- contorno-financiero= Auditor_Financiero
-- miradita           = Visitante

CREATE ROLE 'bysofii-calamardo'@'%';
CREATE ROLE 'glam-boss'@'%';
CREATE ROLE 'glam-data'@'%';
CREATE ROLE 'esponjita'@'%';
CREATE ROLE 'cupid-glow'@'%';
CREATE ROLE 'contorno-financiero'@'%';
CREATE ROLE 'miradita'@'%';

-- Administrador: privilegios completos sobre el esquema.
GRANT ALL PRIVILEGES ON ecommerce_bysofii.* TO 'bysofii-calamardo'@'%';

-- Gerente de marketing: solo lectura de clientes/ventas y ejecución de reportes.
GRANT SELECT (id_cliente,nombre,apellido,email,direccion_envio,ciudad,region,fecha_registro,activo) ON ecommerce_bysofii.clientes TO 'glam-boss'@'%';
GRANT SELECT ON ecommerce_bysofii.v_ventas_por_sucursal TO 'glam-boss'@'%';
GRANT SELECT ON ecommerce_bysofii.v_detalle_ventas_por_sucursal TO 'glam-boss'@'%';
GRANT SELECT ON ecommerce_bysofii.productos TO 'glam-boss'@'%';
GRANT EXECUTE ON PROCEDURE ecommerce_bysofii.sp_GenerarReporteMensualVentas TO 'glam-boss'@'%';

-- Analista: lectura de todas las tablas de negocio y reportes, excluyendo auditoría.
GRANT SELECT ON ecommerce_bysofii.sucursales TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.categorias TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.proveedores TO 'glam-data'@'%';
GRANT SELECT (id_cliente,nombre,apellido,email,direccion_envio,ciudad,region,fecha_nacimiento,id_sucursal,id_referido_por,total_gastado,fecha_ultimo_pedido,fecha_registro,ultimo_acceso,activo,deleted_at) ON ecommerce_bysofii.clientes TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.productos TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.promociones TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.producto_promocion TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.v_ventas_por_sucursal TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.v_detalle_ventas_por_sucursal TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.carritos TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.carrito_detalle TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.vistas_producto TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.resenas_producto TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.intentos_pago TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.creditos_cliente TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.ajustes_stock TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.reporte_ventas_semanales TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.reorder_list TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.resumen_ventas_diarias TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.rankings_productos TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.kpis_mensuales TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.tamano_bd_log TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.rendimiento_proveedores TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.carritos_archivo TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.cumpleanios_cupones TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.alertas_stock TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.venta_archivo TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.usuario_sucursal TO 'glam-data'@'%';
GRANT SELECT ON ecommerce_bysofii.backup_critico TO 'glam-data'@'%';
GRANT EXECUTE ON FUNCTION ecommerce_bysofii.fn_ValidarFormatoEmail TO 'glam-data'@'%';
-- Se impide explícitamente DELETE/TRUNCATE: no se concede ningún privilegio DML de escritura.
-- El límite de consultas es por cuenta; se aplica al usuario analyst_user más abajo.

-- Inventario: puede leer productos y modificar exclusivamente stock/ubicacion.
GRANT SELECT ON ecommerce_bysofii.productos TO 'esponjita'@'%';
GRANT SELECT ON ecommerce_bysofii.categorias TO 'esponjita'@'%';
GRANT UPDATE (stock,ubicacion) ON ecommerce_bysofii.productos TO 'esponjita'@'%';
REVOKE UPDATE (precio) ON ecommerce_bysofii.productos FROM 'esponjita'@'%';
GRANT EXECUTE ON PROCEDURE ecommerce_bysofii.sp_AjustarNivelStock TO 'esponjita'@'%';

-- Atención al cliente: acceso a clientes/ventas, sin UPDATE de productos/precio.
GRANT SELECT ON ecommerce_bysofii.v_info_clientes_basica TO 'cupid-glow'@'%';
GRANT SELECT ON ecommerce_bysofii.v_ventas_por_sucursal TO 'cupid-glow'@'%';
GRANT SELECT ON ecommerce_bysofii.v_detalle_ventas_por_sucursal TO 'cupid-glow'@'%';
GRANT EXECUTE ON PROCEDURE ecommerce_bysofii.sp_ActualizarDireccionCliente TO 'cupid-glow'@'%';
REVOKE UPDATE ON ecommerce_bysofii.productos FROM 'cupid-glow'@'%';

-- Auditor financiero: lectura de ventas, productos y logs de precio.
GRANT SELECT ON ecommerce_bysofii.v_ventas_por_sucursal TO 'contorno-financiero'@'%';
GRANT SELECT ON ecommerce_bysofii.v_detalle_ventas_por_sucursal TO 'contorno-financiero'@'%';
GRANT SELECT ON ecommerce_bysofii.productos TO 'contorno-financiero'@'%';
GRANT SELECT ON ecommerce_bysofii.log_cambios_precio TO 'contorno-financiero'@'%';

-- Visitante: solo catálogo de productos.
GRANT SELECT ON ecommerce_bysofii.productos TO 'miradita'@'%';

-- Usuarios de ejemplo. Contraseñas de laboratorio: reemplazar antes de producción.
CREATE USER 'admin_user'@'localhost' IDENTIFIED BY 'BySofii_Admin_2026!ChangeMe' PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER 'marketing_user'@'localhost' IDENTIFIED BY 'BySofii_Marketing_2026!ChangeMe' PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER 'inventory_user'@'localhost' IDENTIFIED BY 'BySofii_Inventory_2026!ChangeMe' PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER 'support_user'@'localhost' IDENTIFIED BY 'BySofii_Support_2026!ChangeMe' PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER 'analyst_user'@'localhost' IDENTIFIED BY 'BySofii_Analyst_2026!ChangeMe' PASSWORD EXPIRE INTERVAL 90 DAY
  WITH MAX_QUERIES_PER_HOUR 300;
CREATE USER 'auditor_user'@'localhost' IDENTIFIED BY 'BySofii_Auditor_2026!ChangeMe' PASSWORD EXPIRE INTERVAL 90 DAY;
CREATE USER 'visitor_user'@'localhost' IDENTIFIED BY 'BySofii_Visitor_2026!ChangeMe' PASSWORD EXPIRE INTERVAL 90 DAY;

GRANT 'bysofii-calamardo'@'%' TO 'admin_user'@'localhost';
GRANT 'glam-boss'@'%' TO 'marketing_user'@'localhost';
GRANT 'esponjita'@'%' TO 'inventory_user'@'localhost';
GRANT 'cupid-glow'@'%' TO 'support_user'@'localhost';
GRANT 'glam-data'@'%' TO 'analyst_user'@'localhost';
GRANT 'contorno-financiero'@'%' TO 'auditor_user'@'localhost';
GRANT 'miradita'@'%' TO 'visitor_user'@'localhost';

SET DEFAULT ROLE
    'bysofii-calamardo'@'%' TO 'admin_user'@'localhost',
    'glam-boss'@'%' TO 'marketing_user'@'localhost',
    'esponjita'@'%' TO 'inventory_user'@'localhost',
    'cupid-glow'@'%' TO 'support_user'@'localhost',
    'glam-data'@'%' TO 'analyst_user'@'localhost',
    'contorno-financiero'@'%' TO 'auditor_user'@'localhost',
    'miradita'@'%' TO 'visitor_user'@'localhost';

-- Asociación de cada cuenta de aplicación a su sucursal.
INSERT INTO usuario_sucursal(login_usuario,id_sucursal) VALUES
('marketing_user',1),
('inventory_user',1),
('support_user',1),
('analyst_user',1),
('auditor_user',1),
('visitor_user',1),
('admin_user',1)
ON DUPLICATE KEY UPDATE id_sucursal=VALUES(id_sucursal),activo=TRUE;

-- Root remoto: en el laboratorio se elimina cualquier root@% creado por error.
-- Esto NO toca root@localhost.
DROP USER IF EXISTS 'root'@'%';

-- Preparación para auditoría de intentos de login fallidos.
-- La tabla auditoria_login_fallido queda disponible para la aplicación.
-- Los fallos de autenticación del servidor MySQL ocurren antes de ejecutar SQL
-- y NO pueden ser capturados por un trigger SQL estándar; deben integrarse
-- mediante el error log o un componente de auditoría del servidor.
CREATE OR REPLACE VIEW v_seguridad_resumen AS
SELECT 'roles' AS control,
       COUNT(*) AS cantidad
FROM mysql.role_edges
WHERE FROM_HOST='%' AND TO_HOST='%';

-- Verificación recomendada al finalizar.
SHOW GRANTS FOR 'admin_user'@'localhost';
SHOW GRANTS FOR 'analyst_user'@'localhost';
SHOW GRANTS FOR 'inventory_user'@'localhost';
SHOW GRANTS FOR 'support_user'@'localhost';
