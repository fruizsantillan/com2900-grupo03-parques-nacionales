-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Creacion de tablas del modulo Concesiones.
--              Tablas: TipoDeConsesion, Empresa, Concesion, PagoConcesion
-- Dependencias: Schemas creados por 01_creacion_db_schemas.sql
--               Tabla parques.Parque creada por modulo Parques
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- TABLA: TipoDeConsesion
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'TipoDeConsesion' AND s.name = 'concesiones')
BEGIN
    CREATE TABLE concesiones.TipoDeConsesion (
        idTipoConcesion  INT          IDENTITY(1,1)  NOT NULL,
        descripcion      VARCHAR(100)                NOT NULL,
        CONSTRAINT PK_TipoDeConsesion             PRIMARY KEY (idTipoConcesion),
        CONSTRAINT UQ_TipoDeConsesion_descripcion UNIQUE      (descripcion)
    );
END
GO

-- ============================================================
-- TABLA: Empresa
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Empresa' AND s.name = 'concesiones')
BEGIN
    CREATE TABLE concesiones.Empresa (
        idEmpresa    INT          IDENTITY(1,1)  NOT NULL,
        razonSocial  VARCHAR(200)                NOT NULL,
        cuit         VARCHAR(20)                 NOT NULL,
        contacto     VARCHAR(100)                NULL,
        email        VARCHAR(100)                NULL,
        telefono     VARCHAR(50)                 NULL,
        CONSTRAINT PK_Empresa      PRIMARY KEY (idEmpresa),
        CONSTRAINT UQ_Empresa_cuit UNIQUE      (cuit)
    );
END
GO

-- ============================================================
-- TABLA: Concesion
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Concesion' AND s.name = 'concesiones')
BEGIN
    CREATE TABLE concesiones.Concesion (
        idConcesion      INT           IDENTITY(1,1)  NOT NULL,
        descripcion      VARCHAR(100)                 NOT NULL,
        idTipoConcesion  INT                          NOT NULL,
        idParque         INT                          NOT NULL,
        idEmpresa        INT                          NOT NULL,
        fechaInicio      DATE                         NOT NULL,
        fechaFin         DATE                         NOT NULL,
        canonMensual     DECIMAL(18,2)                NOT NULL,
        CONSTRAINT PK_Concesion                 PRIMARY KEY (idConcesion),
        CONSTRAINT FK_Concesion_TipoDeConsesion FOREIGN KEY (idTipoConcesion) REFERENCES concesiones.TipoDeConsesion(idTipoConcesion),
        CONSTRAINT FK_Concesion_Empresa         FOREIGN KEY (idEmpresa)       REFERENCES concesiones.Empresa(idEmpresa),
        CONSTRAINT FK_Concesion_Parque          FOREIGN KEY (idParque)        REFERENCES parques.Parque(idParque),
        CONSTRAINT CHK_Concesion_fechas         CHECK (fechaFin > fechaInicio),
        CONSTRAINT CHK_Concesion_canonMensual   CHECK (canonMensual > 0)
    );
END
GO

-- ============================================================
-- TABLA: PagoConcesion
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'PagoConcesion' AND s.name = 'concesiones')
BEGIN
    CREATE TABLE concesiones.PagoConcesion (
        idPagoConcesion  INT           IDENTITY(1,1)  NOT NULL,
        idConcesion      INT                          NOT NULL,
        monto            DECIMAL(18,2)                NOT NULL,
        fechaPago        DATE                         NOT NULL,
        periodoAnio      INT                          NOT NULL,
        periodoMes       INT                          NOT NULL,
        CONSTRAINT PK_PagoConcesion              PRIMARY KEY (idPagoConcesion),
        CONSTRAINT FK_PagoConcesion_Concesion    FOREIGN KEY (idConcesion) REFERENCES concesiones.Concesion(idConcesion),
        CONSTRAINT CHK_PagoConcesion_periodoMes  CHECK (periodoMes BETWEEN 1 AND 12),
        CONSTRAINT CHK_PagoConcesion_periodoAnio CHECK (periodoAnio >= 2020),
        CONSTRAINT CHK_PagoConcesion_monto       CHECK (monto > 0),
        CONSTRAINT UQ_PagoConcesion_periodo      UNIQUE (idConcesion, periodoAnio, periodoMes)
    );
END
GO
