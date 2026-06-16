-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Creacion de tablas del modulo Concesiones.
--              Tablas: TipoDeConsesion, Empresa, Concesion, PagoConcesion
-- Dependencias: Schema 'concesiones' creado por script 01_database.sql
--               Tabla parques.Parque creada por modulo Parques
-- =============================================

USE ParquesNacionales;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'concesiones')
    EXEC('CREATE SCHEMA concesiones');
GO

-- ============================================================
-- TABLA: TipoDeConsesion
-- Lookup de tipos de actividad concesionada
-- Ejemplos: Gastronomia, Turismo aventura, Comercio minorista
-- ============================================================
CREATE TABLE concesiones.TipoDeConsesion (
    idTipoConcesion  INT          IDENTITY(1,1)  NOT NULL,
    descripcion      VARCHAR(100)                NOT NULL,
    CONSTRAINT PK_TipoDeConsesion             PRIMARY KEY (idTipoConcesion),
    CONSTRAINT UQ_TipoDeConsesion_descripcion UNIQUE      (descripcion)
);
GO

-- ============================================================
-- TABLA: Empresa
-- Datos de la empresa concesionaria
-- ============================================================
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
GO

-- ============================================================
-- TABLA: Concesion
-- Contrato de concesion entre una empresa y un parque
-- ============================================================
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
GO

-- ============================================================
-- TABLA: PagoConcesion
-- Historial de pagos de canon mensual por concesion
-- La constraint UQ_PagoConcesion_periodo impide duplicados a nivel DB
-- (ademas de la validacion en el SP de negocio)
-- ============================================================
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
GO
