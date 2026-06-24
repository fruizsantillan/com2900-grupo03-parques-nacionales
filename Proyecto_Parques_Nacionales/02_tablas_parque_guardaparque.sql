-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Creacion de tablas del modulo Base.
--              Tablas: TipoParque, Ubicacion, Parque (schema parques)
--                      Guardaparque, AsignacionGuardaparque (schema personal)
-- Dependencias: Schemas creados por 01_creacion_db_schemas.sql
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- TABLA: TipoParque
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'TipoParque' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.TipoParque (
        idTipoParque  INT           IDENTITY(1,1) NOT NULL,
        descripcion   VARCHAR(100)  NOT NULL,
        CONSTRAINT PK_TipoParque PRIMARY KEY (idTipoParque)
    );
END
GO

-- ============================================================
-- TABLA: Ubicacion
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Ubicacion' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.Ubicacion (
        idUbicacion  INT            IDENTITY(1,1) NOT NULL,
        direccion    VARCHAR(100)   NOT NULL,
        provincia    VARCHAR(50)    NOT NULL,
        latitud      DECIMAL(9,6)   NOT NULL,
        longitud     DECIMAL(9,6)   NOT NULL,
        CONSTRAINT PK_Ubicacion PRIMARY KEY (idUbicacion)
    );
END
GO

-- ============================================================
-- TABLA: Parque
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Parque' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.Parque (
        idParque       INT            IDENTITY(1,1) NOT NULL,
        nombre         VARCHAR(100)   NOT NULL,
        superficie     DECIMAL(18,2)  NOT NULL,
        idTipoParque   INT            NOT NULL,
        idUbicacion    INT            NOT NULL,
        CONSTRAINT PK_Parque PRIMARY KEY (idParque),
        CONSTRAINT FK_Parque_TipoParque FOREIGN KEY (idTipoParque) REFERENCES parques.TipoParque (idTipoParque),
        CONSTRAINT FK_Parque_Ubicacion  FOREIGN KEY (idUbicacion)  REFERENCES parques.Ubicacion  (idUbicacion)
    );
END
GO

-- ============================================================
-- TABLA: Guardaparque (schema personal)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Guardaparque' AND s.name = 'personal')
BEGIN
    CREATE TABLE personal.Guardaparque (
        dni              INT            NOT NULL,
        apyn             VARCHAR(50)    NOT NULL,
        email            VARCHAR(100)   NULL,
        telefono         VARCHAR(50)    NULL,
        localidad        VARCHAR(50)    NULL,
        fechaNacimiento  DATETIME       NULL,
        CONSTRAINT PK_Guardaparque PRIMARY KEY (dni)
    );
END
GO

-- ============================================================
-- TABLA: AsignacionGuardaparque (schema personal)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'AsignacionGuardaparque' AND s.name = 'personal')
BEGIN
    CREATE TABLE personal.AsignacionGuardaparque (
        idAsignacion   INT            IDENTITY(1,1) NOT NULL,
        fechaInicio    DATE           NOT NULL,
        fechaFin       DATE           NULL,
        motivoEgreso   VARCHAR(255)   NULL,
        idParque       INT            NOT NULL,
        dni            INT            NOT NULL,
        CONSTRAINT PK_AsignacionGuardaparque PRIMARY KEY (idAsignacion),
        CONSTRAINT FK_AsignacionGuardaparque_Parque       FOREIGN KEY (idParque) REFERENCES parques.Parque          (idParque),
        CONSTRAINT FK_AsignacionGuardaparque_Guardaparque FOREIGN KEY (dni)      REFERENCES personal.Guardaparque   (dni)
    );
END
GO
