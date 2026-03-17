-- =========================
-- ROLES DE BASE DE DATOS
-- =========================
CREATE ROLE gerente_role;
CREATE ROLE mesero_role;
CREATE ROLE recepcionista_role;
CREATE ROLE cocina_role;
CREATE ROLE cajero_role;

-- Quitar permisos públicos
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;


--GERENTE CONTROL TOTAL
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO gerente_role;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO gerente_role;


--MESERO
-- Mesas
GRANT SELECT, UPDATE ON mesa TO mesero_role;

-- Clientes y reservaciones
GRANT SELECT, INSERT, UPDATE ON cliente TO mesero_role;

-- Orden
GRANT SELECT, INSERT ON orden TO mesero_role;
GRANT SELECT, INSERT ON orden_detalle TO mesero_role;

-- Solo lectura de menú
GRANT SELECT ON categoria_menu TO mesero_role;
GRANT SELECT ON platillo TO mesero_role;

--RECEPCIONISTA
GRANT SELECT, INSERT, UPDATE ON reservacion TO recepcionista_role;


---COCINA

---CAJERO
GRANT SELECT ON orden TO cajero_role;
GRANT UPDATE ON orden TO cajero_role;

GRANT SELECT ON orden_detalle TO cajero_role;

GRANT INSERT ON pago TO cajero_role;
GRANT SELECT ON pago TO cajero_role;

GRANT SELECT ON cliente TO cajero_role;

GRANT UPDATE ON mesa TO cajero_role; 


-- =========================================================
-- SISTEMA RESTAURANTE (PostgreSQL)
-- Modelo realista: operación + administración
-- =========================================================

BEGIN;

-- =========================
-- 0) LIMPIEZA (opcional)
-- =========================
-- Nota: comenta esta sección si no quieres borrar estructuras previas.
DROP TABLE IF EXISTS orden_detalle CASCADE;
DROP TABLE IF EXISTS orden CASCADE;
DROP TABLE IF EXISTS pago CASCADE;
DROP TABLE IF EXISTS reservacion CASCADE;
DROP TABLE IF EXISTS mesa CASCADE;

DROP TABLE IF EXISTS receta_ingrediente CASCADE;
DROP TABLE IF EXISTS platillo CASCADE;
DROP TABLE IF EXISTS categoria_menu CASCADE;

DROP TABLE IF EXISTS inventario_movimiento CASCADE;
DROP TABLE IF EXISTS insumo CASCADE;
DROP TABLE IF EXISTS proveedor CASCADE;
DROP TABLE IF EXISTS compra_detalle CASCADE;
DROP TABLE IF EXISTS compra CASCADE;

DROP TABLE IF EXISTS turno_asignacion CASCADE;
DROP TABLE IF EXISTS turno CASCADE;

DROP TABLE IF EXISTS empleado CASCADE;
DROP TABLE IF EXISTS rol CASCADE;

DROP TABLE IF EXISTS cliente CASCADE;


SELECT * FROM orden_detalle;



-- =========================
-- 1) CATÁLOGOS Y PERSONAS
-- =========================

CREATE TABLE rol (
  rol_id      SERIAL PRIMARY KEY,
  nombre      VARCHAR(50) NOT NULL UNIQUE,
  descripcion VARCHAR(200)
);

CREATE TABLE empleado (
  empleado_id SERIAL PRIMARY KEY,
  nombre      VARCHAR(60) NOT NULL,
  apellido_p  VARCHAR(60) NOT NULL,
  apellido_m  VARCHAR(60),
  telefono    VARCHAR(20),
  email       VARCHAR(120) UNIQUE,
  password    VARCHAR(120) NOT NULL DEFAULT 'password123', -- Agregado para testing
  fecha_alta  DATE NOT NULL DEFAULT CURRENT_DATE,
  activo      BOOLEAN NOT NULL DEFAULT TRUE,
  rol_id      INT NOT NULL REFERENCES rol(rol_id)
);

CREATE TABLE cliente (
  cliente_id  SERIAL PRIMARY KEY,
  nombre      VARCHAR(80) NOT NULL,
  telefono    VARCHAR(20),
  email       VARCHAR(120),
  creado_en   TIMESTAMP NOT NULL DEFAULT NOW()
);

-- =========================
-- 2) OPERACIÓN: MESAS, RESERVAS, ÓRDENES, PAGOS
-- =========================

CREATE TABLE mesa (
  mesa_id     SERIAL PRIMARY KEY,
  numero      INT NOT NULL UNIQUE,
  capacidad   INT NOT NULL CHECK (capacidad BETWEEN 1 AND 20),
  ubicacion   VARCHAR(50) NOT NULL CHECK (ubicacion IN ('SALON', 'TERRAZA', 'BARRA', 'PRIVADO')),
  estado      VARCHAR(20) NOT NULL DEFAULT 'LIBRE'
             CHECK (estado IN ('LIBRE', 'RESERVADA', 'OCUPADA', 'FUERA_SERVICIO'))
);

CREATE TABLE reservacion (
  reservacion_id SERIAL PRIMARY KEY,
  cliente_id     INT NOT NULL REFERENCES cliente(cliente_id),
  mesa_id        INT REFERENCES mesa(mesa_id),
  fecha_hora     TIMESTAMP NOT NULL,
  personas       INT NOT NULL CHECK (personas BETWEEN 1 AND 20),
  estado         VARCHAR(20) NOT NULL DEFAULT 'PROGRAMADA'
                CHECK (estado IN ('PROGRAMADA', 'CONFIRMADA', 'CANCELADA', 'NO_SHOW', 'COMPLETADA')),
  notas          VARCHAR(250),
  creado_en      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE orden (
  orden_id      SERIAL PRIMARY KEY,
  mesa_id       INT NOT NULL REFERENCES mesa(mesa_id),
  mesero_id     INT NOT NULL REFERENCES empleado(empleado_id),
  cliente_id    INT REFERENCES cliente(cliente_id),
  reservacion_id INT REFERENCES reservacion(reservacion_id),
  fecha_apertura TIMESTAMP NOT NULL DEFAULT NOW(),
  fecha_cierre   TIMESTAMP,
  estado        VARCHAR(20) NOT NULL DEFAULT 'ABIERTA'
               CHECK (estado IN ('ABIERTA', 'ENVIADA_COCINA', 'SERVIDA', 'CERRADA', 'CANCELADA')),
  observaciones VARCHAR(250)
);

-- =========================
-- 3) MENÚ REALISTA: CATEGORÍAS, PLATILLOS, RECETAS
-- =========================

CREATE TABLE categoria_menu (
  categoria_id SERIAL PRIMARY KEY,
  nombre       VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE platillo (
  platillo_id   SERIAL PRIMARY KEY,
  categoria_id  INT NOT NULL REFERENCES categoria_menu(categoria_id),
  nombre        VARCHAR(120) NOT NULL,
  descripcion   VARCHAR(250),
  precio        NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
  disponible    BOOLEAN NOT NULL DEFAULT TRUE,
  UNIQUE (categoria_id, nombre)
);

CREATE TABLE orden_detalle (
  orden_detalle_id SERIAL PRIMARY KEY,
  orden_id     INT NOT NULL REFERENCES orden(orden_id) ON DELETE CASCADE,
  platillo_id  INT NOT NULL REFERENCES platillo(platillo_id),
  cantidad     INT NOT NULL CHECK (cantidad >= 1),
  precio_unit  NUMERIC(10,2) NOT NULL CHECK (precio_unit >= 0),
  estado       VARCHAR(25) NOT NULL DEFAULT 'CAPTURADO'
              CHECK (estado IN ('CAPTURADO', 'EN_PREPARACION', 'LISTO', 'SERVIDO', 'CANCELADO')),
  notas        VARCHAR(250)
);

CREATE TABLE pago (
  pago_id      SERIAL PRIMARY KEY,
  orden_id     INT NOT NULL REFERENCES orden(orden_id) ON DELETE CASCADE,
  fecha_pago   TIMESTAMP NOT NULL DEFAULT NOW(),
  metodo       VARCHAR(20) NOT NULL CHECK (metodo IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
  monto        NUMERIC(10,2) NOT NULL CHECK (monto > 0),
  referencia   VARCHAR(80)
);

-- =========================
-- 4) ADMIN: TURNOS (OPERACIÓN DE PERSONAL)
-- =========================

CREATE TABLE turno (
  turno_id     SERIAL PRIMARY KEY,
  nombre       VARCHAR(40) NOT NULL UNIQUE,
  hora_inicio  TIME NOT NULL,
  hora_fin     TIME NOT NULL,
  CHECK (hora_fin <> hora_inicio)
);

CREATE TABLE turno_asignacion (
  turno_asignacion_id SERIAL PRIMARY KEY,
  turno_id      INT NOT NULL REFERENCES turno(turno_id),
  empleado_id   INT NOT NULL REFERENCES empleado(empleado_id),
  fecha         DATE NOT NULL,
  UNIQUE (turno_id, empleado_id, fecha)
);

-- =========================
-- 5) ADMIN: PROVEEDORES, COMPRAS, INSUMOS, INVENTARIO
-- =========================

CREATE TABLE proveedor (
  proveedor_id SERIAL PRIMARY KEY,
  nombre       VARCHAR(120) NOT NULL UNIQUE,
  telefono     VARCHAR(20),
  email        VARCHAR(120),
  rfc          VARCHAR(20),
  direccion    VARCHAR(200)
);

CREATE TABLE compra (
  compra_id     SERIAL PRIMARY KEY,
  proveedor_id  INT NOT NULL REFERENCES proveedor(proveedor_id),
  comprador_id  INT NOT NULL REFERENCES empleado(empleado_id),
  fecha_compra  TIMESTAMP NOT NULL DEFAULT NOW(),
  folio         VARCHAR(30) UNIQUE,
  estado        VARCHAR(20) NOT NULL DEFAULT 'RECIBIDA'
               CHECK (estado IN ('PENDIENTE', 'RECIBIDA', 'CANCELADA')),
  total         NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0)
);

CREATE TABLE insumo (
  insumo_id     SERIAL PRIMARY KEY,
  nombre        VARCHAR(120) NOT NULL UNIQUE,
  unidad        VARCHAR(20) NOT NULL CHECK (unidad IN ('KG', 'G', 'L', 'ML', 'PZA')),
  stock_actual  NUMERIC(12,3) NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
  stock_minimo  NUMERIC(12,3) NOT NULL DEFAULT 0 CHECK (stock_minimo >= 0),
  activo        BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE compra_detalle (
  compra_detalle_id SERIAL PRIMARY KEY,
  compra_id     INT NOT NULL REFERENCES compra(compra_id) ON DELETE CASCADE,
  insumo_id     INT NOT NULL REFERENCES insumo(insumo_id),
  cantidad      NUMERIC(12,3) NOT NULL CHECK (cantidad > 0),
  costo_unit    NUMERIC(12,2) NOT NULL CHECK (costo_unit >= 0),
  subtotal      NUMERIC(12,2) NOT NULL CHECK (subtotal >= 0)
);

CREATE TABLE inventario_movimiento (
  movimiento_id SERIAL PRIMARY KEY,
  insumo_id     INT NOT NULL REFERENCES insumo(insumo_id),
  fecha         TIMESTAMP NOT NULL DEFAULT NOW(),
  tipo          VARCHAR(20) NOT NULL CHECK (tipo IN ('ENTRADA_COMPRA', 'SALIDA_PRODUCCION', 'AJUSTE')),
  cantidad      NUMERIC(12,3) NOT NULL CHECK (cantidad > 0),
  referencia    VARCHAR(60),
  notas         VARCHAR(250)
);

-- Recetas: relación platillo-insumo (cuánto insumo se usa por platillo)
CREATE TABLE receta_ingrediente (
  receta_id    SERIAL PRIMARY KEY,
  platillo_id  INT NOT NULL REFERENCES platillo(platillo_id) ON DELETE CASCADE,
  insumo_id    INT NOT NULL REFERENCES insumo(insumo_id),
  cantidad     NUMERIC(12,3) NOT NULL CHECK (cantidad > 0),
  UNIQUE (platillo_id, insumo_id)
);

-- =========================
-- 6) DATOS DE EJEMPLO (COHERENTES)
-- =========================

-- Roles
INSERT INTO rol (nombre, descripcion) VALUES
('ADMIN', 'Control total del sistema'),
('GERENTE', 'Supervisión y reportes'),
('MESERO', 'Atención a mesas y captura de órdenes'),
('COCINA', 'Preparación y seguimiento de platillos'),
('CAJERO', 'Cobros y cierres');

-- Empleados
INSERT INTO empleado (nombre, apellido_p, apellido_m, telefono, email, password, rol_id) VALUES
('Carlos', 'Ruiz', 'Hernández', '2711002001', 'carlos.ruiz@resto.mx', 'pwd_gerente', (SELECT rol_id FROM rol WHERE nombre='GERENTE')),
('Ana', 'López', 'Martínez',   '2711002002', 'ana.lopez@resto.mx',   'pwd_mesero', (SELECT rol_id FROM rol WHERE nombre='MESERO')),
('Luis', 'Santos', 'Díaz',     '2711002003', 'luis.santos@resto.mx', 'pwd_mesero', (SELECT rol_id FROM rol WHERE nombre='MESERO')),
('Marta', 'García', 'Pérez',   '2711002004', 'marta.garcia@resto.mx','pwd_cajero',(SELECT rol_id FROM rol WHERE nombre='CAJERO')),
('Jorge', 'Vega', 'Nava',      '2711002005', 'jorge.vega@resto.mx',  'pwd_cocina',  (SELECT rol_id FROM rol WHERE nombre='COCINA'));

-- Turnos
INSERT INTO turno (nombre, hora_inicio, hora_fin) VALUES
('MATUTINO', '07:00', '15:00'),
('VESPERTINO', '15:00', '23:00');

-- Asignaciones (mismo día)
INSERT INTO turno_asignacion (turno_id, empleado_id, fecha) VALUES
((SELECT turno_id FROM turno WHERE nombre='MATUTINO'), (SELECT empleado_id FROM empleado WHERE email='ana.lopez@resto.mx'), CURRENT_DATE),
((SELECT turno_id FROM turno WHERE nombre='MATUTINO'), (SELECT empleado_id FROM empleado WHERE email='luis.santos@resto.mx'), CURRENT_DATE),
((SELECT turno_id FROM turno WHERE nombre='MATUTINO'), (SELECT empleado_id FROM empleado WHERE email='marta.garcia@resto.mx'), CURRENT_DATE),
((SELECT turno_id FROM turno WHERE nombre='MATUTINO'), (SELECT empleado_id FROM empleado WHERE email='jorge.vega@resto.mx'), CURRENT_DATE);

-- Mesas
INSERT INTO mesa (numero, capacidad, ubicacion, estado) VALUES
(1, 2, 'SALON', 'LIBRE'),
(2, 4, 'SALON', 'LIBRE'),
(3, 6, 'TERRAZA', 'LIBRE'),
(4, 4, 'BARRA', 'LIBRE'),
(5, 10, 'PRIVADO', 'FUERA_SERVICIO');

-- Clientes
INSERT INTO cliente (nombre, telefono, email) VALUES
('Juan Pérez', '2712003001', 'juan.perez@mail.com'),
('Laura Gómez', '2712003002', 'laura.gomez@mail.com'),
('Empresa ACME (Comidas)', '2712003999', 'facturacion@acme.com');

-- Reservación (para hoy por la tarde)
INSERT INTO reservacion (cliente_id, mesa_id, fecha_hora, personas, estado, notas) VALUES
((SELECT cliente_id FROM cliente WHERE nombre='Laura Gómez'),
 (SELECT mesa_id FROM mesa WHERE numero=2),
 NOW() + INTERVAL '4 hours',
 4,
 'CONFIRMADA',
 'Cumpleaños, traer vela');

-- Categorías del menú
INSERT INTO categoria_menu (nombre) VALUES
('ENTRADAS'),
('PLATO FUERTE'),
('BEBIDAS'),
('POSTRES');

-- Platillos (precios realistas)
INSERT INTO platillo (categoria_id, nombre, descripcion, precio, disponible) VALUES
((SELECT categoria_id FROM categoria_menu WHERE nombre='ENTRADAS'), 'Guacamole con totopos', 'Aguacate, pico de gallo y totopos', 85.00, TRUE),
((SELECT categoria_id FROM categoria_menu WHERE nombre='PLATO FUERTE'), 'Tacos al pastor (5)', 'Tortilla, pastor, piña, cilantro y cebolla', 120.00, TRUE),
((SELECT categoria_id FROM categoria_menu WHERE nombre='PLATO FUERTE'), 'Hamburguesa clásica', 'Carne 150g, queso, lechuga, jitomate', 145.00, TRUE),
((SELECT categoria_id FROM categoria_menu WHERE nombre='BEBIDAS'), 'Agua de horchata 500ml', 'Bebida tradicional', 35.00, TRUE),
((SELECT categoria_id FROM categoria_menu WHERE nombre='POSTRES'), 'Pay de limón', 'Rebanada', 65.00, TRUE);

-- Proveedores
INSERT INTO proveedor (nombre, telefono, email, rfc, direccion) VALUES
('Central de Abastos Córdoba', '2715006001', 'ventas@abastoscordoba.mx', 'CAC010101ABC', 'Av. Principal 123, Córdoba, Ver.'),
('Carnes El Buen Corte',       '2715006002', 'contacto@buencorte.mx',   'CEB020202DEF', 'Calle 5 #45, Córdoba, Ver.');

-- Insumos (inventario)
INSERT INTO insumo (nombre, unidad, stock_actual, stock_minimo) VALUES
('Aguacate', 'KG', 5.000, 2.000),
('Tortilla de maíz', 'PZA', 200.000, 50.000),
('Carne al pastor', 'KG', 8.000, 3.000),
('Piña', 'KG', 3.000, 1.000),
('Arroz', 'KG', 10.000, 3.000),
('Leche', 'L', 12.000, 4.000),
('Limón', 'KG', 4.000, 2.000);

-- Recetas (cuánto se consume por platillo)
-- Guacamole: 0.25 kg de aguacate
INSERT INTO receta_ingrediente (platillo_id, insumo_id, cantidad) VALUES
((SELECT platillo_id FROM platillo WHERE nombre='Guacamole con totopos'),
 (SELECT insumo_id FROM insumo WHERE nombre='Aguacate'),
 0.250);

-- Tacos al pastor (5): 5 tortillas + 0.200 kg pastor + 0.050 kg piña
INSERT INTO receta_ingrediente (platillo_id, insumo_id, cantidad) VALUES
((SELECT platillo_id FROM platillo WHERE nombre='Tacos al pastor (5)'),
 (SELECT insumo_id FROM insumo WHERE nombre='Tortilla de maíz'),
 5.000),
((SELECT platillo_id FROM platillo WHERE nombre='Tacos al pastor (5)'),
 (SELECT insumo_id FROM insumo WHERE nombre='Carne al pastor'),
 0.200),
((SELECT platillo_id FROM platillo WHERE nombre='Tacos al pastor (5)'),
 (SELECT insumo_id FROM insumo WHERE nombre='Piña'),
 0.050);

-- Agua de horchata: 0.100 kg arroz + 0.300 L leche
INSERT INTO receta_ingrediente (platillo_id, insumo_id, cantidad) VALUES
((SELECT platillo_id FROM platillo WHERE nombre='Agua de horchata 500ml'),
 (SELECT insumo_id FROM insumo WHERE nombre='Arroz'),
 0.100),
((SELECT platillo_id FROM platillo WHERE nombre='Agua de horchata 500ml'),
 (SELECT insumo_id FROM insumo WHERE nombre='Leche'),
 0.300);

-- Pay de limón: 0.050 kg limón + 0.100 L leche
INSERT INTO receta_ingrediente (platillo_id, insumo_id, cantidad) VALUES
((SELECT platillo_id FROM platillo WHERE nombre='Pay de limón'),
 (SELECT insumo_id FROM insumo WHERE nombre='Limón'),
 0.050),
((SELECT platillo_id FROM platillo WHERE nombre='Pay de limón'),
 (SELECT insumo_id FROM insumo WHERE nombre='Leche'),
 0.100);

-- Compra (entrada de inventario)
INSERT INTO compra (proveedor_id, comprador_id, folio, estado, total) VALUES
((SELECT proveedor_id FROM proveedor WHERE nombre='Central de Abastos Córdoba'),
 (SELECT empleado_id FROM empleado WHERE email='carlos.ruiz@resto.mx'),
 'FAC-2026-0001',
 'RECIBIDA',
 0);

INSERT INTO compra_detalle (compra_id, insumo_id, cantidad, costo_unit, subtotal) VALUES
((SELECT compra_id FROM compra WHERE folio='FAC-2026-0001'),
 (SELECT insumo_id FROM insumo WHERE nombre='Aguacate'),
 3.000, 55.00, 165.00),
((SELECT compra_id FROM compra WHERE folio='FAC-2026-0001'),
 (SELECT insumo_id FROM insumo WHERE nombre='Limón'),
 2.000, 28.00, 56.00);

-- Actualiza total de compra (suma de subtotales)
UPDATE compra
SET total = (
  SELECT COALESCE(SUM(subtotal), 0)
  FROM compra_detalle
  WHERE compra_detalle.compra_id = compra.compra_id
)
WHERE folio = 'FAC-2026-0001';

-- Movimientos de inventario por compra
INSERT INTO inventario_movimiento (insumo_id, tipo, cantidad, referencia, notas) VALUES
((SELECT insumo_id FROM insumo WHERE nombre='Aguacate'), 'ENTRADA_COMPRA', 3.000, 'FAC-2026-0001', 'Entrada por compra'),
((SELECT insumo_id FROM insumo WHERE nombre='Limón'), 'ENTRADA_COMPRA', 2.000, 'FAC-2026-0001', 'Entrada por compra');

-- Ajuste de stock_actual por compras (simulación coherente)
UPDATE insumo SET stock_actual = stock_actual + 3.000 WHERE nombre='Aguacate';
UPDATE insumo SET stock_actual = stock_actual + 2.000 WHERE nombre='Limón';

-- =========================
-- 7) FLUJO OPERATIVO REAL: CREAR ORDEN, ENVIAR A COCINA, SERVIR, COBRAR
-- =========================

-- Cambia mesa 2 a OCUPADA (llega la reservación)
UPDATE mesa SET estado='OCUPADA' WHERE numero=2;

-- Crear orden para mesa 2, mesero Ana, cliente Laura, ligada a la reservación
INSERT INTO orden (mesa_id, mesero_id, cliente_id, reservacion_id, estado, observaciones)
VALUES (
  (SELECT mesa_id FROM mesa WHERE numero=2),
  (SELECT empleado_id FROM empleado WHERE email='ana.lopez@resto.mx'),
  (SELECT cliente_id FROM cliente WHERE nombre='Laura Gómez'),
  (SELECT reservacion_id FROM reservacion WHERE estado='CONFIRMADA' AND cliente_id=(SELECT cliente_id FROM cliente WHERE nombre='Laura Gómez') LIMIT 1),
  'ABIERTA',
  'Mesa con reservación de cumpleaños'
);

-- Agregar items a la orden (cantidades realistas)
-- 1 guacamole, 2 tacos pastor, 4 horchatas, 1 pay
INSERT INTO orden_detalle (orden_id, platillo_id, cantidad, precio_unit, estado, notas) VALUES
((SELECT orden_id FROM orden ORDER BY orden_id DESC LIMIT 1),
 (SELECT platillo_id FROM platillo WHERE nombre='Guacamole con totopos'),
 1, 85.00, 'CAPTURADO', 'Sin cebolla'),

((SELECT orden_id FROM orden ORDER BY orden_id DESC LIMIT 1),
 (SELECT platillo_id FROM platillo WHERE nombre='Tacos al pastor (5)'),
 2, 120.00, 'CAPTURADO', NULL),

((SELECT orden_id FROM orden ORDER BY orden_id DESC LIMIT 1),
 (SELECT platillo_id FROM platillo WHERE nombre='Agua de horchata 500ml'),
 4, 35.00, 'CAPTURADO', '2 sin hielo'),

((SELECT orden_id FROM orden ORDER BY orden_id DESC LIMIT 1),
 (SELECT platillo_id FROM platillo WHERE nombre='Pay de limón'),
 1, 65.00, 'CAPTURADO', 'Para cumpleaños');

-- Enviar a cocina
UPDATE orden SET estado='ENVIADA_COCINA' WHERE orden_id = (SELECT orden_id FROM orden ORDER BY orden_id DESC LIMIT 1);
UPDATE orden_detalle SET estado='EN_PREPARACION'
WHERE orden_id = (SELECT orden_id FROM orden ORDER BY orden_id DESC LIMIT 1);

-- Simulación: platillos listos y servidos
UPDATE orden_detalle SET estado='LISTO'
WHERE orden_id = (SELECT orden_id FROM orden ORDER BY orden_id DESC LIMIT 1)
AND platillo_id IN (
  SELECT platillo_id FROM platillo WHERE nombre IN ('Guacamole con totopos','Tacos al pastor (5)')
);

UPDATE orden_detalle SET estado='SERVIDO'
WHERE orden_id = (SELECT orden_id FROM orden ORDER BY orden_id DESC LIMIT 1)
AND platillo_id IN (
  SELECT platillo_id FROM platillo WHERE nombre IN ('Guacamole con totopos','Tacos al pastor (5)','Agua de horchata 500ml','Pay de limón')
);

-- Orden servida
UPDATE orden SET estado='SERVIDA' WHERE orden_id = (SELECT orden_id FROM orden ORDER BY orden_id DESC LIMIT 1);

-- Salidas de inventario por producción (consumo por recetas)
-- Nota: aquí se registra el movimiento; el ajuste de stock se hace abajo.
-- Guacamole (1): aguacate 0.25
-- Tacos (2): tortilla 10, pastor 0.4, piña 0.1
-- Horchata (4): arroz 0.4, leche 1.2
-- Pay (1): limón 0.05, leche 0.1

INSERT INTO inventario_movimiento (insumo_id, tipo, cantidad, referencia, notas) VALUES
((SELECT insumo_id FROM insumo WHERE nombre='Aguacate'), 'SALIDA_PRODUCCION', 0.250, 'ORD-ULTIMA', 'Guacamole x1'),
((SELECT insumo_id FROM insumo WHERE nombre='Tortilla de maíz'), 'SALIDA_PRODUCCION', 10.000, 'ORD-ULTIMA', 'Tacos pastor x2'),
((SELECT insumo_id FROM insumo WHERE nombre='Carne al pastor'), 'SALIDA_PRODUCCION', 0.400, 'ORD-ULTIMA', 'Tacos pastor x2'),
((SELECT insumo_id FROM insumo WHERE nombre='Piña'), 'SALIDA_PRODUCCION', 0.100, 'ORD-ULTIMA', 'Tacos pastor x2'),
((SELECT insumo_id FROM insumo WHERE nombre='Arroz'), 'SALIDA_PRODUCCION', 0.400, 'ORD-ULTIMA', 'Horchata x4'),
((SELECT insumo_id FROM insumo WHERE nombre='Leche'), 'SALIDA_PRODUCCION', 1.300, 'ORD-ULTIMA', 'Horchata x4 + Pay x1'),
((SELECT insumo_id FROM insumo WHERE nombre='Limón'), 'SALIDA_PRODUCCION', 0.050, 'ORD-ULTIMA', 'Pay x1');

-- Ajuste de stock_actual por consumo (simulación coherente)
UPDATE insumo SET stock_actual = stock_actual - 0.250 WHERE nombre='Aguacate';
UPDATE insumo SET stock_actual = stock_actual - 10.000 WHERE nombre='Tortilla de maíz';
UPDATE insumo SET stock_actual = stock_actual - 0.400 WHERE nombre='Carne al pastor';
UPDATE insumo SET stock_actual = stock_actual - 0.100 WHERE nombre='Piña';
UPDATE insumo SET stock_actual = stock_actual - 0.400 WHERE nombre='Arroz';
UPDATE insumo SET stock_actual = stock_actual - 1.300 WHERE nombre='Leche';
UPDATE insumo SET stock_actual = stock_actual - 0.050 WHERE nombre='Limón';

-- Cobro (pago con tarjeta)
-- Total esperado: 85 + (2*120) + (4*35) + 65 = 85 + 240 + 140 + 65 = 530
INSERT INTO pago (orden_id, metodo, monto, referencia)
VALUES (
  (SELECT orden_id FROM orden ORDER BY orden_id DESC LIMIT 1),
  'TARJETA',
  530.00,
  'VISA-****-1234'
);

-- Cerrar orden
UPDATE orden
SET estado='CERRADA', fecha_cierre=NOW()
WHERE orden_id = (SELECT orden_id FROM orden ORDER BY orden_id DESC LIMIT 1);

-- Liberar mesa
UPDATE mesa SET estado='LIBRE' WHERE numero=2;

-- Marcar reservación como completada
UPDATE reservacion SET estado='COMPLETADA'
WHERE reservacion_id = (SELECT reservacion_id FROM reservacion WHERE estado='CONFIRMADA' LIMIT 1);

COMMIT;
