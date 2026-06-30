-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Creación de roles de seguridad y asignación de permisos
--
-- rol_admin:           Control total sobre todos los esquemas del sistema.
-- rol_importador:      Solo EXECUTE sobre los SP de importación de datos externos.
-- rol_consultas:       Solo lectura sobre datos no sensibles; acceso a datos
--                      sensibles (DNI/CUIT) unicamente via SP de descifrado.
-- rol_operador_ventas: Solo EXECUTE sobre los SP del esquema de ventas.
-- =============================================

USE ParquesNacionales;
GO

-- 1. Crear los roles de base de datos
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_admin')
    CREATE ROLE rol_admin;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_importador')
    CREATE ROLE rol_importador;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_consultas')
    CREATE ROLE rol_consultas;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'rol_operador_ventas')
    CREATE ROLE rol_operador_ventas;
GO

-- 2. Permisos para rol_admin: control total
GRANT CONTROL ON SCHEMA::parques        TO rol_admin;
GRANT CONTROL ON SCHEMA::personal       TO rol_admin;
GRANT CONTROL ON SCHEMA::actividades    TO rol_admin;
GRANT CONTROL ON SCHEMA::ventas         TO rol_admin;
GRANT CONTROL ON SCHEMA::concesiones    TO rol_admin;
GO

-- 3. Permisos para rol_importador: solo ejecutar SPs de importación
GRANT EXECUTE ON parques.ImportarVisitasNacionales   TO rol_importador;
GRANT EXECUTE ON parques.ImportarVisitasPorRegion     TO rol_importador;
GRANT EXECUTE ON parques.ImportarVisitasAnual         TO rol_importador;
GRANT EXECUTE ON parques.ImportarAreasProtegidas      TO rol_importador;
GRANT EXECUTE ON parques.ImportarAreasWDPA            TO rol_importador;
GRANT EXECUTE ON parques.ImportarFeriados             TO rol_importador;
GRANT EXECUTE ON parques.ImportarTipoCambio           TO rol_importador;
GO

-- 4. Permisos para rol_consultas: solo lectura sobre datos no sensibles
GRANT SELECT ON SCHEMA::parques      TO rol_consultas;
GRANT EXECUTE ON personal.Guia_ObtenerPorId          TO rol_consultas;
GRANT EXECUTE ON actividades.Tour_ObtenerPorId       TO rol_consultas;
GRANT EXECUTE ON actividades.Atraccion_ObtenerPorId  TO rol_consultas;
GO

-- 5. Permisos para rol_operador_ventas
GRANT EXECUTE ON SCHEMA::ventas TO rol_operador_ventas;
GO

-- 6. Crear usuarios de ejemplo y asignarlos a roles para testing
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_admin_demo')
BEGIN
    CREATE USER usr_admin_demo WITHOUT LOGIN;
    ALTER ROLE rol_admin ADD MEMBER usr_admin_demo;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_consultas_demo')
BEGIN
    CREATE USER usr_consultas_demo WITHOUT LOGIN;
    ALTER ROLE rol_consultas ADD MEMBER usr_consultas_demo;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'usr_importador_demo')
BEGIN
    CREATE USER usr_importador_demo WITHOUT LOGIN;
    ALTER ROLE rol_importador ADD MEMBER usr_importador_demo;
END
GO

-- 7. Restricción explícita de acceso directo a columnas/tablas sensibles
-- Esto obliga a rol_consultas a usar SOLO los SP de descifrado
-- para acceder al DNI/CUIT en texto plano.
-- Nota: estos REVOKE son explícitos por documentación, aunque el GRANT
-- del punto 4 ya no incluye estas tablas (pertenecen a otros esquemas).
REVOKE SELECT ON personal.Guia FROM rol_consultas;
REVOKE SELECT ON personal.Guardaparque FROM rol_consultas;
REVOKE SELECT ON concesiones.Empresa FROM rol_consultas;
GO

-- Otorga permiso únicamente a los SP que contienen la lógica de descifrado
GRANT EXECUTE ON personal.Guia_ObtenerDniDescifrado         TO rol_consultas;
GRANT EXECUTE ON personal.Guardaparque_ObtenerDniDescifrado TO rol_consultas;
GRANT EXECUTE ON concesiones.Empresa_ObtenerCuitDescifrado  TO rol_consultas;
GO

-- Permite que el rol_consultas pueda "abrir" la llave y usar el certificado dentro del SP
GRANT VIEW DEFINITION ON SYMMETRIC KEY::ClaveSimetricaDatosSensibles TO rol_consultas;
GRANT CONTROL ON CERTIFICATE::CertDatosSensibles TO rol_consultas;
GO