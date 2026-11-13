-- ============================================================================
-- sql/schema.sql
-- ----------------------------------------------------------------------------
-- Script para crear la base de datos y las tablas que usa el proyecto.
-- Ejecutar este archivo una sola vez en MySQL/MariaDB antes de usar la app.
-- ============================================================================

-- Crea la base de datos si todavía no existe.
CREATE DATABASE IF NOT EXISTS sena_v3
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_general_ci;

-- Selecciona la base de datos recién creada para las siguientes instrucciones.
USE sena_v3;

-- ----------------------------------------------------------------------------
-- Tabla de aprendices
-- ----------------------------------------------------------------------------
-- Columna nueva en esta versión:
--   - estado: indica si el aprendiz sigue activo en el programa o ya se
--     retiró. En vez de BORRAR el registro cuando alguien se retira (lo
--     que dejaría huérfanas sus notas y su cuenta de usuario), simplemente
--     se marca como 'retirado'. Esto es responsabilidad del docente o el
--     coordinador (acción "Inactivar por retiro" en el listado).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS aprendices (
  id INT AUTO_INCREMENT PRIMARY KEY,      -- Identificador único autoincremental
  nombre VARCHAR(150) NOT NULL,           -- Nombre completo del aprendiz
  ficha VARCHAR(50) NOT NULL,             -- Número de ficha del programa de formación
  estado ENUM('activo', 'retirado') NOT NULL DEFAULT 'activo' -- Estado del aprendiz
);

-- ----------------------------------------------------------------------------
-- Tabla de usuarios: soporta login, roles Y recuperación de contraseña.
--
-- Columnas nuevas en esta versión:
--   - correo: obligatorio y único; es a donde se envía el enlace de recuperación.
--   - token_recuperacion: cadena aleatoria de un solo uso, generada cuando la
--     persona pide "olvidé mi contraseña"; NULL en el uso normal del sistema.
--   - token_expira: fecha/hora hasta la que ese token es válido (1 hora desde
--     que se generó); pasado ese tiempo, el enlace deja de funcionar.
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS usuarios (
  id INT AUTO_INCREMENT PRIMARY KEY,               -- Identificador único del usuario
  nombre VARCHAR(150) NOT NULL,                    -- Nombre completo de la persona
  usuario VARCHAR(50) NOT NULL UNIQUE,              -- Nombre de usuario para iniciar sesión (único)
  correo VARCHAR(150) NOT NULL UNIQUE,              -- Correo al que llega el enlace de recuperación (único)
  contrasena VARCHAR(255) NOT NULL,                 -- Contraseña ENCRIPTADA (hash bcrypt de password_hash)
  rol ENUM('aprendiz', 'docente', 'coordinador') NOT NULL, -- Rol que define los permisos
  aprendiz_id INT NULL,                             -- FK opcional: cuál fila de "aprendices" es este usuario
  token_recuperacion VARCHAR(64) NULL,               -- Token de un solo uso para restablecer la contraseña
  token_expira DATETIME NULL,                        -- Fecha/hora límite de validez del token
  fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha en que se creó la cuenta

  -- Si se elimina el aprendiz vinculado, la cuenta de usuario NO se borra:
  -- simplemente su aprendiz_id vuelve a NULL (ON DELETE SET NULL).
  CONSTRAINT fk_usuario_aprendiz
    FOREIGN KEY (aprendiz_id) REFERENCES aprendices(id)
    ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- Tabla de notas: registra las calificaciones que un docente sube por cada
-- aprendiz y asignatura/actividad.
--   - aprendiz_id: a quién pertenece la nota. Si se BORRA el aprendiz (acción
--     administrativa poco común, ya que lo normal es "retirarlo", no
--     eliminarlo), sus notas se eliminan en cascada porque ya no tendrían
--     dueño (ON DELETE CASCADE).
--   - docente_id: qué cuenta de usuario (rol docente o coordinador) registró
--     la nota, solo para trazabilidad. Si esa cuenta se elimina, la nota NO
--     desaparece, solo pierde la referencia (ON DELETE SET NULL).
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notas (
  id INT AUTO_INCREMENT PRIMARY KEY,
  aprendiz_id INT NOT NULL,
  asignatura VARCHAR(150) NOT NULL,
  nota DECIMAL(3,1) NOT NULL,             -- Ej: 4.5  (escala 0.0 a 5.0)
  docente_id INT NULL,
  fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_nota_aprendiz
    FOREIGN KEY (aprendiz_id) REFERENCES aprendices(id)
    ON DELETE CASCADE,

  CONSTRAINT fk_nota_docente
    FOREIGN KEY (docente_id) REFERENCES usuarios(id)
    ON DELETE SET NULL
);

-- ----------------------------------------------------------------------------
-- Datos de ejemplo para que ADSO pueda probar el login, los 3 dashboards y
-- la recuperación de contraseña de una vez. IMPORTANTE: la contraseña NUNCA
-- se guarda en texto plano; los valores de abajo son hashes bcrypt generados
-- con password_hash() en PHP, equivalentes a las contraseñas indicadas en
-- cada comentario. Los correos son ficticios, solo para pruebas locales.
-- ----------------------------------------------------------------------------

-- Se crea primero un aprendiz de ejemplo, para poder vincularlo a la cuenta
-- de prueba con rol "aprendiz" (su id será 1 en una base de datos nueva).
INSERT INTO aprendices (nombre, ficha) VALUES ('Juan Pérez', '2825621');

INSERT INTO usuarios (nombre, usuario, correo, contrasena, rol, aprendiz_id) VALUES
  -- Usuario: aprendiz1  /  Contraseña real: aprendiz123
  ('Juan Pérez', 'aprendiz1', 'aprendiz1@ejemplo.com',
   '$2y$10$yv0iu75xGDakg6g0XX.xM.bLak5KMoPYTgPIH4.Kobz.OVAosil9C', 'aprendiz', 1),
  -- Usuario: docente1   /  Contraseña real: docente123
  ('Docente de Prueba', 'docente1', 'docente1@ejemplo.com',
   '$2y$10$niKNZJ2ArnrU.MCGnRKX2emt2LzjixfYlTHE4wQ3nYBDQRreCW2.C', 'docente', NULL),
  -- Usuario: coordinador1  /  Contraseña real: coordinador123
  ('Coordinador de Prueba', 'coordinador1', 'coordinador1@ejemplo.com',
   '$2y$10$pmdKuVFqMlE72jgN.ODFEOHzV0Z92pBJLCxVhwjIPLXxeL1ZOE2i.', 'coordinador', NULL);

-- ----------------------------------------------------------------------------
-- NOTA para bases de datos que YA tenían datos de una versión anterior del
-- proyecto (sin correo / sin token de recuperación): en vez de correr todo
-- este script, ejecuta solo estas líneas y luego asigna un correo a cada
-- usuario ya existente (UPDATE usuarios SET correo = '...' WHERE usuario = '...'):
--
-- ALTER TABLE usuarios ADD COLUMN correo VARCHAR(150) NULL AFTER usuario;
-- ALTER TABLE usuarios ADD COLUMN token_recuperacion VARCHAR(64) NULL;
-- ALTER TABLE usuarios ADD COLUMN token_expira DATETIME NULL;
-- -- Luego de asignar correos a todos los usuarios existentes:
-- ALTER TABLE usuarios MODIFY correo VARCHAR(150) NOT NULL UNIQUE;
-- ----------------------------------------------------------------------------

-- ----------------------------------------------------------------------------
-- MIGRACIÓN para bases de datos que YA existían antes de agregar el estado
-- del aprendiz (activo/retirado) y la tabla de notas. Ejecuta esto UNA sola
-- vez si tu base de datos ya tenía datos de una versión anterior:
-- ----------------------------------------------------------------------------
-- ALTER TABLE aprendices
--   ADD COLUMN estado ENUM('activo', 'retirado') NOT NULL DEFAULT 'activo';
--
-- CREATE TABLE IF NOT EXISTS notas (
--   id INT AUTO_INCREMENT PRIMARY KEY,
--   aprendiz_id INT NOT NULL,
--   asignatura VARCHAR(150) NOT NULL,
--   nota DECIMAL(3,1) NOT NULL,
--   docente_id INT NULL,
--   fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
--   CONSTRAINT fk_nota_aprendiz FOREIGN KEY (aprendiz_id) REFERENCES aprendices(id) ON DELETE CASCADE,
--   CONSTRAINT fk_nota_docente FOREIGN KEY (docente_id) REFERENCES usuarios(id) ON DELETE SET NULL
-- );
-- ----------------------------------------------------------------------------
