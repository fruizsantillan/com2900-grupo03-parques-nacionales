-- =============================================
-- Universidad: Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Comisión: 01-2900 | Grupo 03
-- Integrantes: Del Vecchio Fabrizio, Ocampos Horacio,
--              Ruiz Santillán Facundo, Lago Franco Nehuen
-- Fecha: 15/06/2026
-- Descripción: Creación de tablas del módulo Guías, Tours y Atracciones
-- =============================================

USE ParquesNacionales;
GO

-- GUIA
IF NOT EXISTS (SELECT 1 FROM sys.tables t 
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Guia' AND s.name = 'personal')
BEGIN
    CREATE TABLE personal.Guia (
        dni                    INT                NOT NULL,
        apyn                   VARCHAR(100)       NOT NULL,
        especialidad           VARCHAR(100)       NULL,
        titulo                 VARCHAR(100)       NULL,
        habilitaciones         VARCHAR(255)       NULL,
        vigenciaAutorizacion   DATE               NOT NULL,
        CONSTRAINT PK_Guia_dni PRIMARY KEY (dni)
    );
END
GO

-- TOUR
IF NOT EXISTS (SELECT 1 FROM sys.tables t 
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Tour' AND s.name = 'actividades')
BEGIN
    CREATE TABLE actividades.Tour (
        idTour      INT IDENTITY(1,1)   NOT NULL,
        nombre      VARCHAR(100)        NOT NULL,
        descripcion VARCHAR(255)        NULL,
        duracion    INT                 NOT NULL, -- en minutos
        cupoMaximo  INT                 NOT NULL,
        precio      DECIMAL(18,2)       NOT NULL DEFAULT 0,
        idParque    INT                 NOT NULL,
        CONSTRAINT PK_Tour              PRIMARY KEY (idTour),
        CONSTRAINT FK_Tour_Parque       FOREIGN KEY (idParque) REFERENCES parques.Parque(idParque),
        CONSTRAINT CHK_Tour_duracion    CHECK (duracion > 0),
        CONSTRAINT CHK_Tour_cupo        CHECK (cupoMaximo > 0),
        CONSTRAINT CHK_Tour_precio      CHECK (precio >= 0)
    );
END
GO

-- ATRACCION
IF NOT EXISTS (SELECT 1 FROM sys.tables t 
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Atraccion' AND s.name = 'actividades')
BEGIN
    CREATE TABLE actividades.Atraccion (
        idAtraccion     INT IDENTITY(1,1)   NOT NULL,
        nombre          VARCHAR(100)        NOT NULL,
        descripcion     VARCHAR(255)        NULL,
        tipo            VARCHAR(50)         NULL,
        precio          DECIMAL(18,2)       NOT NULL DEFAULT 0,
        duracion        INT                 NOT NULL, -- en minutos
        cupoMaximo      INT                 NOT NULL,
        idParque        INT                 NOT NULL,
        CONSTRAINT PK_Atraccion             PRIMARY KEY (idAtraccion),
        CONSTRAINT FK_Atraccion_Parque      FOREIGN KEY (idParque) REFERENCES parques.Parque(idParque),
        CONSTRAINT CHK_Atraccion_duracion   CHECK (duracion > 0),
        CONSTRAINT CHK_Atraccion_cupo       CHECK (cupoMaximo > 0),
        CONSTRAINT CHK_Atraccion_precio     CHECK (precio >= 0)
    );
END
GO

-- ASIGNACION GUIA
IF NOT EXISTS (SELECT 1 FROM sys.tables t 
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'AsignacionGuia' AND s.name = 'personal')
BEGIN
    CREATE TABLE personal.AsignacionGuia (
        idAsignacion    INT IDENTITY(1,1)   NOT NULL,
        idTour          INT                 NOT NULL,
        dniGuia         INT                 NOT NULL,
        fechaInicio     DATE                NOT NULL,
        fechaFin        DATE                NOT NULL,
        CONSTRAINT PK_AsignacionGuia         PRIMARY KEY (idAsignacion),
        CONSTRAINT FK_AsignacionGuia_Tour    FOREIGN KEY (idTour) REFERENCES actividades.Tour(idTour),
        CONSTRAINT FK_AsignacionGuia_dniGuia FOREIGN KEY (dniGuia) REFERENCES personal.Guia(dni),
        CONSTRAINT CHK_AsignacionGuia_fechas CHECK (fechaFin >= fechaInicio)
    );
END
GO