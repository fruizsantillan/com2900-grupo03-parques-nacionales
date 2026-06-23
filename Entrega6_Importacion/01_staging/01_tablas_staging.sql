-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Tablas finales de estadisticas y log de importacion.
--              Las tablas de staging son tablas temporales (#) creadas
--              dentro de cada SP de importacion y destruidas al finalizar.
--
-- Datasets cubiertos:
--   CSV 1: visitas-residentes-y-no-residentes.csv         -> parques.EstadisticaVisitas
--   CSV 2: visitas-residentes-y-no-residentes-por-region  -> parques.EstadisticaVisitasPorRegion
--   CSV 3: aprn_h_ubicacion_superycatint_ha.csv           -> parques.TipoParque / parques.Parque
--   CSV 4: aprn_i_visitas_porc_2024.csv                   -> parques.EstadisticaVisitasAnual
--   CSV 5: WDPA_WDOECM_Jun2026_Public_ARG_csv.csv         -> parques.TipoParque / parques.Parque
--   JSON : API ArgentinaDatos /v1/feriados/{anio}         -> parques.Feriado
--   JSON : API dolarapi.com /v1/dolares/{tipo}            -> parques.TipoCambio
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- LOG DE IMPORTACION
-- Registra cada ejecucion de un SP de importacion:
--   fecha/hora, procedimiento, archivo fuente y contadores.
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'LogImportacion' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.LogImportacion (
        idLog          INT           IDENTITY(1,1)  NOT NULL,
        fechaHora      DATETIME                     NOT NULL DEFAULT GETDATE(),
        procedimiento  VARCHAR(200)                 NOT NULL,
        archivoFuente  VARCHAR(500)                 NULL,
        totalLeido     INT                          NOT NULL DEFAULT 0,
        insertados     INT                          NOT NULL DEFAULT 0,
        actualizados   INT                          NOT NULL DEFAULT 0,
        errores        INT                          NOT NULL DEFAULT 0,
        CONSTRAINT PK_LogImportacion PRIMARY KEY (idLog)
    );
END
GO

-- ============================================================
-- TABLAS FINALES: estadisticas nacionales de visitas
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'EstadisticaVisitas' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.EstadisticaVisitas (
        idEstadistica     INT           IDENTITY(1,1)  NOT NULL,
        periodo           DATE                         NOT NULL,
        origenVisitante   VARCHAR(50)                  NOT NULL,
        cantidadVisitas   INT                          NOT NULL,
        observaciones     VARCHAR(500)                 NULL,
        CONSTRAINT PK_EstadisticaVisitas         PRIMARY KEY (idEstadistica),
        CONSTRAINT UQ_EstadisticaVisitas_periodo UNIQUE      (periodo, origenVisitante),
        CONSTRAINT CHK_EstadisticaVisitas_visitas CHECK      (cantidadVisitas >= 0)
    );
END
GO

-- ============================================================
-- TABLAS FINALES: estadisticas de visitas por region
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'EstadisticaVisitasPorRegion' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.EstadisticaVisitasPorRegion (
        idEstadistica       INT           IDENTITY(1,1)  NOT NULL,
        periodo             DATE                         NOT NULL,
        region              VARCHAR(100)                 NOT NULL,
        origenVisitante     VARCHAR(50)                  NOT NULL,
        cantidadVisitas     INT                          NOT NULL,
        observaciones       VARCHAR(500)                 NULL,
        CONSTRAINT PK_EstadisticaVisitasPorRegion         PRIMARY KEY (idEstadistica),
        CONSTRAINT UQ_EstadisticaVisitasPorRegion_periodo UNIQUE      (periodo, region, origenVisitante),
        CONSTRAINT CHK_EstadisticaVisitasPorRegion_visitas CHECK      (cantidadVisitas >= 0)
    );
END
GO

-- ============================================================
-- TABLAS FINALES: feriados nacionales
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Feriado' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.Feriado (
        idFeriado   INT           IDENTITY(1,1)  NOT NULL,
        fecha       DATE                         NOT NULL,
        tipo        VARCHAR(100)                 NULL,
        nombre      VARCHAR(200)                 NOT NULL,
        CONSTRAINT PK_Feriado       PRIMARY KEY (idFeriado),
        CONSTRAINT UQ_Feriado_fecha UNIQUE      (fecha)
    );
END
GO

-- ============================================================
-- TABLAS FINALES: distribucion anual de visitas (%)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'EstadisticaVisitasAnual' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.EstadisticaVisitasAnual (
        idEstadistica           INT             IDENTITY(1,1)  NOT NULL,
        anio                    INT                            NOT NULL,
        residentesPorcentaje    DECIMAL(5,2)                   NOT NULL,
        noResidentesPorcentaje  DECIMAL(5,2)                   NOT NULL,
        CONSTRAINT PK_EstadisticaVisitasAnual      PRIMARY KEY (idEstadistica),
        CONSTRAINT UQ_EstadisticaVisitasAnual_anio UNIQUE      (anio),
        CONSTRAINT CHK_EstadisticaVisitasAnual_sum CHECK       (residentesPorcentaje + noResidentesPorcentaje BETWEEN 99.90 AND 100.10)
    );
END
GO

-- ============================================================
-- TABLAS FINALES: tipo de cambio USD/ARS
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'TipoCambio' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.TipoCambio (
        idTipoCambio  INT            IDENTITY(1,1)  NOT NULL,
        fecha         DATE                          NOT NULL,
        tipo          VARCHAR(20)                   NOT NULL,
        compra        DECIMAL(10,2)                 NOT NULL,
        venta         DECIMAL(10,2)                 NOT NULL,
        CONSTRAINT PK_TipoCambio           PRIMARY KEY (idTipoCambio),
        CONSTRAINT UQ_TipoCambio_fechaTipo UNIQUE      (fecha, tipo),
        CONSTRAINT CHK_TipoCambio_compra   CHECK       (compra > 0),
        CONSTRAINT CHK_TipoCambio_venta    CHECK       (venta >= compra)
    );
END
GO

PRINT 'Tablas finales y log de importacion creados correctamente.';
GO
