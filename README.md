# 💄 E-commerce BySofiii

> **Sistema de Base de Datos E-commerce Bysofii**
>
> Catálogo · Inventario · Clientes · Ventas · Analítica · Seguridad · 

---

## ✨ Presentación

**E-commerce BySofiii** es una solución de base de datos diseñada para soportar la operación de una tienda virtual especializada en maquillaje y belleza.

El proyecto transforma el enunciado académico de una base de datos de e-commerce en una implementación organizada sobre **MySQL 8.0+**, incorporando reglas de negocio, control de inventario, trazabilidad de ventas, histórico de precios, perfiles de acceso, automatización mediante eventos y una capa de auditoría técnica.

El catálogo está orientado al universo de belleza de BySofiii e incluye categorías como **Blush, Contorno, Corporal, Bases, Labios, Ojos, Iluminador, Polvos, Correctores, Brochas y Accesorios, Skincare y Uñas**, además de soporte para subcategorías mediante relaciones jerárquicas.

---

## 🎯 Objetivos del proyecto

- Diseñar un modelo relacional robusto y escalable para el e-commerce.
- Garantizar integridad referencial y consistencia de los datos.
- Mantener el histórico de precios y costos utilizados en cada venta.
- Gestionar productos, categorías, proveedores, clientes, ventas e inventario.
- Implementar consultas analíticas para apoyar decisiones de negocio.
- Centralizar lógica reutilizable mediante funciones y procedimientos almacenados.
- Automatizar controles de integridad y auditoría mediante triggers.
- Automatizar tareas periódicas mediante eventos programados.
- Aplicar mínimo privilegio y separación de responsabilidades mediante roles.
- Documentar las limitaciones que dependen de la configuración real del servidor MySQL.

---

## 🧩 Arquitectura funcional

```text
                         ┌────────────────────────┐
                         │   E-commerce BySofiii  │
                         └────────────┬───────────┘
                                      │
             ┌────────────────────────┼────────────────────────┐
             │                        │                        │
             ▼                        ▼                        ▼
      ┌──────────────┐        ┌──────────────┐        ┌──────────────┐
      │   Catálogo   │        │    Ventas    │        │  Clientes    │
      │ Productos    │        │ Detalle      │        │ Proveedores  │
      │ Categorías   │        │ Estados      │        │ Sucursales   │
      └──────┬───────┘        └──────┬───────┘        └──────┬───────┘
             │                       │                       │
             └───────────────────────┼───────────────────────┘
                                     ▼
                         ┌────────────────────────┐
                         │ Lógica de negocio      │
                         │ Funciones +            │
                         │ Procedimientos +       │
                         │ Triggers                │
                         └────────────┬───────────┘
                                      │
             ┌────────────────────────┼────────────────────────┐
             ▼                        ▼                        ▼
      ┌──────────────┐        ┌──────────────┐        ┌──────────────┐
      │ Seguridad    │        │ Auditoría    │        │ Automatización│
      │ Roles        │        │ Logs         │        │ Eventos       │
      │ Usuarios     │        │ Históricos   │        │ KPIs/Alertas  │
      └──────────────┘        └──────────────┘        └──────────────┘
```

---

## 🗂️ Estructura del repositorio

```text
E-commerce_BySofiii/
│
├── 01_Esquema_y_Datos.sql
├── 02_Consultas_Avanzadas.sql
├── 03_Funciones.sql
├── 04_Seguridad.sql
├── 05_Triggers.sql
├── 06_Eventos.sql
├── 07_Procedimientos_Almacenados.sql
│
├── AUDITORIA_RECTIFICACION.md
├── AUDITORIA_TECNICA.md
└── README.md
```

### 📌 Propósito de cada archivo

| Archivo | Contenido |
|---|---|
| `01_Esquema_y_Datos.sql` | Creación del esquema, tablas, restricciones, índices y datos de ejemplo. |
| `02_Consultas_Avanzadas.sql` | 20 consultas de análisis y reporteo. |
| `03_Funciones.sql` | 20 funciones definidas por el usuario. |
| `04_Seguridad.sql` | Roles, usuarios, privilegios, vistas de acceso y controles de seguridad. |
| `05_Triggers.sql` | Auditoría, integridad, stock, estados y automatizaciones mediante triggers. |
| `06_Eventos.sql` | 20 eventos programados y activación del `event_scheduler`. |
| `07_Procedimientos_Almacenados.sql` | 20 procedimientos transaccionales y operativos. |
| `AUDITORIA_RECTIFICACION.md` | Registro de hallazgos, correcciones y límites técnicos detectados durante la rectificación. |
| `AUDITORIA_TECNICA.md` | Auditoría técnica complementaria. |

---

## 🛠️ Tecnologías

- **Motor:** MySQL 8.0+
- **Lenguaje:** SQL / MySQL SQL
- **Motor de almacenamiento:** InnoDB
- **Control transaccional:** `START TRANSACTION`, `COMMIT`, `ROLLBACK`
- **Manejo de errores:** `SIGNAL`, `RESIGNAL`, handlers de excepciones
- **Seguridad:** Roles, usuarios, privilegios, vistas y límites de recursos
- **Automatización:** Triggers + Event Scheduler

---

# 🧠 Modelo de datos

El núcleo del sistema se organiza alrededor de las entidades principales exigidas por el proyecto:

- **Productos:** catálogo, precio, costo, stock, SKU, ubicación y estado.
- **Categorías:** clasificación de productos y jerarquía de categorías.
- **Proveedores:** información de contacto y abastecimiento.
- **Clientes:** identidad, cuenta, dirección, sucursal y métricas de compra.
- **Ventas:** encabezado de cada pedido, estado, sucursal y totales.
- **Detalle de ventas:** productos, cantidades y valores históricos de la transacción.

La relación entre ventas y productos se resuelve mediante `detalle_ventas` como tabla puente.

### 🔒 Histórico comercial

Cada línea de venta conserva el precio y costo utilizados en el momento de la compra mediante campos históricos. Esto evita que una modificación futura del catálogo altere el valor de una venta ya registrada.

Además, la venta conserva la dirección de envío congelada para mantener trazabilidad histórica.

---

# 💋 Categorías de BySofiii

El catálogo está personalizado para una tienda de maquillaje y belleza:

`Blush` · `Contorno` · `Corporal` · `Bases` · `Labios` · `Ojos` · `Iluminador` · `Polvos` · `Correctores` · `Brochas y Accesorios` · `Skincare` · `Uñas`

La estructura admite categorías padre e hijas mediante `id_categoria_padre`.

---

# 🧪 Cobertura funcional

| Módulo | Cobertura |
|---|---:|
| Consultas avanzadas | **20 / 20** |
| Funciones | **20 / 20** |
| Seguridad | **20 / 20 requisitos mapeados** |
| Triggers | **20 / 20** |
| Eventos | **20 / 20** |
| Procedimientos almacenados | **20 / 20** |

### 📊 Consultas de negocio incluidas

El proyecto incorpora análisis de:

- productos más vendidos;
- productos de bajas ventas;
- clientes por valor de vida;
- ventas mensuales;
- crecimiento de clientes;
- compras repetidas;
- productos comprados juntos;
- rotación de inventario;
- reabastecimiento;
- carritos abandonados;
- rendimiento de proveedores;
- ventas geográficas;
- ventas por hora;
- promociones;
- cohortes;
- margen de beneficio;
- tiempo entre compras;
- productos vistos frente a comprados;
- segmentación RFM;
- predicción simple de demanda.

---

# 🧮 Funciones definidas por el usuario

Las 20 UDFs encapsulan cálculos y reglas reutilizables, incluyendo:

`fn_CalcularTotalVenta` · `fn_VerificarDisponibilidadStock` · `fn_ObtenerPrecioProducto` · `fn_CalcularEdadCliente` · `fn_FormatearNombreCompleto` · `fn_EsClienteNuevo` · `fn_CalcularCostoEnvio` · `fn_AplicarDescuento` · `fn_ObtenerUltimaFechaCompra` · `fn_ValidarFormatoEmail` · `fn_ObtenerNombreCategoria` · `fn_ContarVentasCliente` · `fn_CalcularDiasDesdeUltimaCompra` · `fn_DeterminarEstadoLealtad` · `fn_GenerarSKU` · `fn_CalcularIVA` · `fn_ObtenerStockTotalPorCategoria` · `fn_EstimarFechaEntrega` · `fn_ConvertirMoneda` · `fn_ValidarComplejidadContraseña`

---

# 🛡️ Seguridad y roles BySofiii

Los nombres de los roles fueron personalizados para darle identidad al proyecto sin perder la correspondencia con los perfiles solicitados.

| Función del proyecto | Rol BySofiii | Usuario de laboratorio |
|---|---|---|
| Administrador del sistema | `bysofii-calamardo` | `admin_user` |
| Gerencia de marketing | `glam-boss` | `marketing_user` |
| Análisis de datos | `glam-data` | `analyst_user` |
| Inventario | `esponjita` | `inventory_user` |
| Atención al cliente | `cupid-glow` | `support_user` |
| Auditoría financiera | `contorno-financiero` | `auditor_user` |
| Visitante | `miradita` | `visitor_user` |

## Principios aplicados

- **Mínimo privilegio:** cada rol recibe únicamente el acceso requerido.
- **Separación de responsabilidades:** inventario, marketing, soporte, análisis y auditoría no comparten privilegios administrativos.
- **Protección de información sensible:** la vista `v_info_clientes_basica` evita exponer campos sensibles innecesarios.
- **Protección del precio:** inventario no tiene permiso para actualizar `precio`.
- **Aislamiento por sucursal:** las consultas operativas se exponen mediante vistas filtradas por sucursal cuando corresponde.
- **Protección de credenciales:** las contraseñas de clientes se almacenan como hash; no se almacena texto plano.
- **Control de recursos:** `analyst_user` cuenta con límite de consultas por hora.
- **Bloqueo y expiración:** las cuentas de laboratorio incorporan controles de expiración/bloqueo compatibles con la configuración del servidor.

> ⚠️ **Nota de infraestructura:** la auditoría completa de intentos de autenticación fallidos y la auditoría nativa de `GRANT/REVOKE` requieren capacidades del servidor MySQL y/o herramientas de auditoría externas al DML normal de la aplicación.

---

# 🔄 Integridad y manejo de errores

El proyecto utiliza varias capas de protección:

### Integridad estructural

- `PRIMARY KEY`
- `FOREIGN KEY`
- `UNIQUE`
- `CHECK`
- `ENUM`
- relaciones con InnoDB
- índices para columnas críticas

### Integridad de negocio

- precio mayor que cero;
- costo no negativo;
- stock no negativo;
- cantidades vendidas mayores que cero;
- emails válidos;
- calificaciones entre 1 y 5;
- prohibición de autoreferencias;
- estados de pedido válidos;
- coincidencia entre cliente y sucursal de la venta;
- control de stock antes de descontarlo.

### Manejo transaccional

Las operaciones críticas utilizan el patrón:

```sql
START TRANSACTION;

-- Validaciones y operaciones

COMMIT;
```

Ante una excepción:

```sql
ROLLBACK;
RESIGNAL;
```

Esto permite evitar operaciones parcialmente aplicadas y devolver el error al consumidor de la rutina.

---

# 💾 Persistencia y trazabilidad

La persistencia no depende únicamente del estado actual del catálogo. El diseño conserva información histórica importante:

- precio histórico por línea de venta;
- costo histórico por línea de venta;
- dirección de envío congelada;
- archivo de ventas eliminadas;
- logs de cambios de precio;
- cambios de estado de pedidos;
- registros de auditoría;
- alertas de stock;
- resúmenes de ventas y KPIs.

Las operaciones críticas se ejecutan con InnoDB y control transaccional para mantener consistencia entre las tablas relacionadas.

---

# ⚡ Triggers

El proyecto contiene **20 triggers**, orientados a integridad y trazabilidad. Entre ellos:

- auditoría de cambios de precio;
- validación de stock;
- actualización automática de stock;
- prevención de eliminación de categorías con productos;
- auditoría de nuevos clientes;
- actualización de gasto acumulado;
- fecha de modificación de productos;
- prevención de stock negativo;
- normalización de nombres;
- recálculo de totales;
- auditoría de estados;
- prevención de precios inválidos;
- alertas de stock bajo;
- archivado de ventas eliminadas;
- validación de correo;
- actualización de última compra;
- prevención de autoreferencias;
- auditoría auxiliar de cambios de permisos;
- categoría General por defecto;
- contador de productos por categoría.

---

# ⏰ Eventos programados

Se implementan **20 eventos** para tareas periódicas como:

- reportes semanales;
- limpieza de tablas temporales;
- archivado de logs;
- promociones expiradas;
- recalculo de fidelidad;
- reabastecimiento;
- mantenimiento de tablas;
- cuentas inactivas;
- consolidación diaria de ventas;
- verificación de consistencia;
- cumpleaños;
- ranking de productos;
- backup lógico complementario;
- carritos abandonados;
- KPIs mensuales;
- actualización de estructuras de consulta;
- tamaño de base de datos;
- detección de actividad sospechosa;
- rendimiento de proveedores;
- purga controlada de soft-delete.

> ⚠️ Los eventos están definidos en SQL, pero su ejecución automática depende de que el **Event Scheduler** esté habilitado y de las políticas/privilegios del servidor.

---

# 🧰 Procedimientos almacenados

Las 20 rutinas encapsulan operaciones como:

- registrar ventas;
- crear productos;
- actualizar direcciones;
- devoluciones;
- historial de compras;
- ajustes de stock;
- anonimización segura de clientes;
- descuentos por categoría;
- reportes mensuales;
- cambios de estado;
- registro de clientes;
- detalle completo de productos;
- fusión de cuentas;
- asignación de proveedores;
- búsqueda avanzada;
- dashboard administrativo;
- procesamiento de pagos;
- reseñas;
- recomendaciones relacionadas;
- movimiento entre categorías.

---

# 🚀 Instalación y ejecución

## Requisitos previos

- MySQL **8.0 o superior**.
- Usuario con privilegios administrativos para la fase de creación.
- Acceso para ejecutar archivos `.sql`.

## Orden recomendado

Ejecutar los archivos en este orden:

```text
01_Esquema_y_Datos.sql
03_Funciones.sql
05_Triggers.sql
07_Procedimientos_Almacenados.sql
06_Eventos.sql
04_Seguridad.sql
02_Consultas_Avanzadas.sql
```

### 1. Crear esquema y cargar datos

```bash
mysql -u root -p < 01_Esquema_y_Datos.sql
```

### 2. Crear funciones

```bash
mysql -u root -p ecommerce_bysofii < 03_Funciones.sql
```

### 3. Crear triggers

```bash
mysql -u root -p ecommerce_bysofii < 05_Triggers.sql
```

### 4. Crear procedimientos

```bash
mysql -u root -p ecommerce_bysofii < 07_Procedimientos_Almacenados.sql
```

### 5. Crear eventos

```bash
mysql -u root -p ecommerce_bysofii < 06_Eventos.sql
```

### 6. Crear roles y usuarios

```bash
mysql -u root -p ecommerce_bysofii < 04_Seguridad.sql
```

### 7. Ejecutar las consultas de análisis

```bash
mysql -u root -p ecommerce_bysofii < 02_Consultas_Avanzadas.sql
```

> El script de seguridad debe ejecutarse con una cuenta que tenga privilegios suficientes para crear roles, usuarios y asignar permisos.

---

# ✅ Pruebas rápidas de validación

Después de la instalación se pueden ejecutar pruebas como:

```sql
USE ecommerce_bysofii;

-- Validar que el total corresponda al subtotal.
SELECT id_venta, subtotal, total, iva, costo_envio
FROM ventas
ORDER BY id_venta;

-- Validar función de total histórico.
SELECT fn_CalcularTotalVenta(1);

-- Validar contraseña de ejemplo.
SELECT fn_ValidarComplejidadContraseña('BySofiiDemo2026!');

-- Buscar productos.
CALL sp_BuscarProductos('Blush', 1, 30000, 50000);

-- Revisar permisos.
SHOW GRANTS FOR 'admin_user'@'localhost';
SHOW GRANTS FOR 'analyst_user'@'localhost';
SHOW GRANTS FOR 'inventory_user'@'localhost';

-- Revisar eventos.
SHOW EVENTS FROM ecommerce_bysofii;

-- Revisar triggers.
SHOW TRIGGERS FROM ecommerce_bysofii;
```

### 🧪 Pruebas negativas recomendadas

Estas operaciones deben ser rechazadas por las reglas implementadas:

```sql
-- Precio inválido.
UPDATE productos SET precio = 0 WHERE id_producto = 1;

-- Stock inválido.
UPDATE productos SET stock = -1 WHERE id_producto = 1;

-- Correo inválido.
CALL sp_RegistrarNuevoCliente(
    'Cliente',
    'Prueba',
    'correo-no-valido',
    'HASH_DE_PRUEBA',
    'Calle 1 # 2-3',
    1
);
```

# 📚 Trazabilidad con el enunciado

La implementación mantiene la estructura solicitada por el proyecto:

| Sección | Implementación |
|---|---|
| Entidades principales | Productos, Categorías, Proveedores, Clientes, Ventas y Detalle de Ventas |
| Consultas avanzadas | 20 |
| Funciones | 20 |
| Seguridad | 20 requisitos mapeados |
| Triggers | 20 |
| Eventos | 20 |
| Procedimientos almacenados | 20 |
| Entrega | Scripts separados + documentación |

---


