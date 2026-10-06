-- ============================================================
-- 08_Auditoria_Clientes_SQLTools.sql
-- E-commerce BySofiii | Auditoría de información sensible
-- Compatible con ejecución desde VS Code + SQLTools (MySQL 8.0+)
-- Requisito adicional definido en adicion_proyecto.md
-- ============================================================

USE ecommerce_bysofii;

-- ============================================================
-- 1. TABLA DE AUDITORÍA
-- ============================================================
-- Se conserva el historial al reejecutar: no se hace DROP TABLE.
-- Integridad: PK + FK + NOT NULL + ENUM + InnoDB.
-- Persistencia: ON DELETE RESTRICT evita dejar evidencia huérfana.
-- Optimización: índices para historial por cliente/fecha y campo/fecha.

CREATE TABLE IF NOT EXISTS Auditoria_Clientes (
    id_auditoria BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_cliente INT UNSIGNED NOT NULL,
    campo_modificado ENUM('email','direccion_envio') NOT NULL,
    valor_antiguo VARCHAR(255) NULL,
    valor_nuevo VARCHAR(255) NULL,
    fecha_modificacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_auditoria_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES clientes(id_cliente)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    INDEX idx_auditoria_clientes_cliente_fecha
        (id_cliente, fecha_modificacion),

    INDEX idx_auditoria_clientes_campo_fecha
        (campo_modificado, fecha_modificacion)
) ENGINE=InnoDB;

-- ============================================================
-- 2. TRIGGER DE AUDITORÍA
-- ============================================================
-- Requisito estricto:
--   * Nombre: trg_audit_cliente_after_update
--   * AFTER UPDATE sobre clientes
--   * Audita SOLO email y direccion_envio
--   * Guarda valor anterior y nuevo
--   * Si cambian ambos campos, registra 2 filas
--   * Si no cambia ninguno, registra 0 filas
--
-- IMPORTANTE PARA VS CODE + SQLTools:
-- Se evita BEGIN...END + DELIMITER $$ porque SQLTools puede intentar
-- enviar DELIMITER como si fuera SQL del servidor. MySQL permite que el
-- cuerpo del trigger sea una sola sentencia; aquí usamos un INSERT ...
-- SELECT con UNION ALL para registrar cero, una o dos filas.
--
-- Manejo de errores:
-- No se ocultan excepciones con un handler. Si el INSERT de auditoría
-- falla, MySQL hace fallar la sentencia que disparó el trigger; con
-- tablas InnoDB, los cambios de la sentencia se revierten como una unidad.
-- Esto mantiene la trazabilidad y evita aceptar silenciosamente un cambio
-- sin su evidencia.

DROP TRIGGER IF EXISTS trg_audit_cliente_after_update;

CREATE TRIGGER trg_audit_cliente_after_update
AFTER UPDATE ON clientes
FOR EACH ROW
INSERT INTO Auditoria_Clientes (
    id_cliente,
    campo_modificado,
    valor_antiguo,
    valor_nuevo,
    fecha_modificacion
)
SELECT
    NEW.id_cliente,
    'email',
    OLD.email,
    NEW.email,
    CURRENT_TIMESTAMP
WHERE NOT (OLD.email <=> NEW.email)

UNION ALL

SELECT
    NEW.id_cliente,
    'direccion_envio',
    OLD.direccion_envio,
    NEW.direccion_envio,
    CURRENT_TIMESTAMP
WHERE NOT (OLD.direccion_envio <=> NEW.direccion_envio);

-- ============================================================
-- 3. PRUEBAS DE CUMPLIMIENTO (COMENTADAS)
-- ============================================================
-- A) Solo email -> debe generar 1 registro:
-- UPDATE clientes
-- SET email='nuevo@bysofii.com'
-- WHERE id_cliente=1;
--
-- B) Solo direccion_envio -> debe generar 1 registro:
-- UPDATE clientes
-- SET direccion_envio='Nueva direccion'
-- WHERE id_cliente=1;
--
-- C) Ambos campos -> debe generar 2 registros:
-- UPDATE clientes
-- SET email='otro@bysofii.com',
--     direccion_envio='Otra direccion'
-- WHERE id_cliente=1;
--
-- D) Ningun campo cambia -> debe generar 0 registros:
-- UPDATE clientes
-- SET email=email,
--     direccion_envio=direccion_envio
-- WHERE id_cliente=1;
--
-- E) Verificación NULL-safe:
-- UPDATE clientes SET direccion_envio=NULL WHERE id_cliente=1;
-- UPDATE clientes SET direccion_envio='Direccion restaurada' WHERE id_cliente=1;
--
-- Consulta de verificación:
-- SELECT id_auditoria,
--        id_cliente,
--        campo_modificado,
--        valor_antiguo,
--        valor_nuevo,
--        fecha_modificacion
-- FROM Auditoria_Clientes
-- ORDER BY id_auditoria DESC;
