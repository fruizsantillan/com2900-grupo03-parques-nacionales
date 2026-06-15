-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Tablas de staging (landing zone para BULK INSERT) y tablas
--              finales de estadisticas de visitas, feriados y areas protegidas.
--              Las tablas staging reciben los datos tal como vienen del CSV, sin
--              transformar; los SPs de importacion limpian y cargan las tablas finales.
--
-- Datasets cubiertos:
--   CSV 1: visitas-residentes-y-no-residentes.csv         (separador ,  - datos.yvera.gob.ar)
--   CSV 2: visitas-residentes-y-no-residentes-por-region.csv (sep ,  - datos.yvera.gob.ar)
--   CSV 3: aprn_h_ubicacion_superycatint_ha.csv           (separador ;  - datos.gob.ar APN)
--   CSV 4: aprn_i_visitas_porc_2024.csv                   (separador ;  - datos.gob.ar APN)
--   JSON : API ArgentinaDatos /v1/feriados/{anio}         (HTTP REST)
-- =============================================

USE ParquesNacionales;
GO

-- Schema staging (landing zone): se crea si no existe
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC ('CREATE SCHEMA staging');
GO

-- ============================================================
-- STAGING: reciben exactamente las columnas del CSV
-- Se truncan antes de cada carga (no son persistentes)
-- ============================================================

-- Staging para: visitas-residentes-y-no-residentes.csv
-- Columnas del CSV: indice_tiempo, origen_visitantes, visitas, observaciones
-- Nota: indice_tiempo viene como YYYY-M-DD (ej. 2008-1-01), se guarda como VARCHAR
IF OBJECT_ID('staging.VisitasNacionales', 'U') IS NOT NULL
    DROP TABLE staging.VisitasNacionales;
GO

CREATE TABLE staging.VisitasNacionales (
    indiceTiempo      VARCHAR(20)   NULL,  -- raw: "2008-1-01"
    origenVisitantes  VARCHAR(50)   NULL,  -- residentes / no residentes / total
    visitas           VARCHAR(20)   NULL,  -- numerico como texto por si hay nulos
    observaciones     VARCHAR(500)  NULL
);
GO

-- Staging para: visitas-residentes-y-no-residentes-por-region.csv
-- Columnas del CSV: indice_tiempo, region_de_destino, origen_visitantes, visitas, observaciones
IF OBJECT_ID('staging.VisitasPorRegion', 'U') IS NOT NULL
    DROP TABLE staging.VisitasPorRegion;
GO

CREATE TABLE staging.VisitasPorRegion (
    indiceTiempo      VARCHAR(20)   NULL,  -- raw: "2008-1-01"
    regionDestino     VARCHAR(100)  NULL,  -- buenos aires / cordoba / cuyo / litoral / norte / patagonia
    origenVisitantes  VARCHAR(50)   NULL,  -- residentes / no residentes / total
    visitas           VARCHAR(20)   NULL,
    observaciones     VARCHAR(500)  NULL
);
GO

-- Staging para: feriados (respuesta JSON de ArgentinaDatos API)
-- La API devuelve: { "fecha": "YYYY-MM-DD", "tipo": "...", "nombre": "..." }
-- El SP de importacion carga fila por fila desde el cursor de OA
IF OBJECT_ID('staging.Feriados', 'U') IS NOT NULL
    DROP TABLE staging.Feriados;
GO

CREATE TABLE staging.Feriados (
    fecha   VARCHAR(10)   NULL,  -- raw: "2025-01-01"
    tipo    VARCHAR(100)  NULL,  -- inamovible / trasladable / puente / nolaborable
    nombre  VARCHAR(200)  NULL
);
GO

-- ============================================================
-- TABLAS FINALES: destino de la importacion
-- Se crean en el schema parques junto con el resto del modelo
-- ============================================================

-- Estadisticas mensuales de visitas a nivel nacional
-- Fuente: visitas-residentes-y-no-residentes.csv (datos.yvera.gob.ar)
IF OBJECT_ID('parques.EstadisticaVisitas', 'U') IS NULL
BEGIN
    CREATE TABLE parques.EstadisticaVisitas (
        idEstadistica     INT           IDENTITY(1,1)  NOT NULL,
        periodo           DATE                         NOT NULL,  -- primer dia del mes
        origenVisitante   VARCHAR(50)                  NOT NULL,  -- residentes / no residentes / total
        cantidadVisitas   INT                          NOT NULL,
        observaciones     VARCHAR(500)                 NULL,
        CONSTRAINT PK_EstadisticaVisitas              PRIMARY KEY (idEstadistica),
        CONSTRAINT UQ_EstadisticaVisitas_periodo      UNIQUE      (periodo, origenVisitante),
        CONSTRAINT CHK_EstadisticaVisitas_visitas     CHECK       (cantidadVisitas >= 0)
    );
END
GO

-- Estadisticas mensuales de visitas por region
-- Fuente: visitas-residentes-y-no-residentes-por-region.csv (datos.yvera.gob.ar)
IF OBJECT_ID('parques.EstadisticaVisitasPorRegion', 'U') IS NULL
BEGIN
    CREATE TABLE parques.EstadisticaVisitasPorRegion (
        idEstadistica       INT           IDENTITY(1,1)  NOT NULL,
        periodo             DATE                         NOT NULL,
        region              VARCHAR(100)                 NOT NULL,
        origenVisitante     VARCHAR(50)                  NOT NULL,
        cantidadVisitas     INT                          NOT NULL,
        observaciones       VARCHAR(500)                 NULL,
        CONSTRAINT PK_EstadisticaVisitasPorRegion          PRIMARY KEY (idEstadistica),
        CONSTRAINT UQ_EstadisticaVisitasPorRegion_periodo  UNIQUE      (periodo, region, origenVisitante),
        CONSTRAINT CHK_EstadisticaVisitasPorRegion_visitas CHECK       (cantidadVisitas >= 0)
    );
END
GO

-- Feriados nacionales argentinos
-- Fuente: API ArgentinaDatos (https://argentinadatos.com/v1/feriados/{anio})
IF OBJECT_ID('parques.Feriado', 'U') IS NULL
BEGIN
    CREATE TABLE parques.Feriado (
        idFeriado   INT           IDENTITY(1,1)  NOT NULL,
        fecha       DATE                         NOT NULL,
        tipo        VARCHAR(100)                 NULL,
        nombre      VARCHAR(200)                 NOT NULL,
        CONSTRAINT PK_Feriado        PRIMARY KEY (idFeriado),
        CONSTRAINT UQ_Feriado_fecha  UNIQUE      (fecha)
    );
END
GO

-- ============================================================
-- STAGING para: aprn_h_ubicacion_superycatint_ha.csv
-- Columnas: region, area_protegida, hectareas, categoria_internacional
-- Nota: separador ; y campos entre comillas dobles (FORMAT = 'CSV')
-- ============================================================
IF OBJECT_ID('staging.AreasProtegidas', 'U') IS NOT NULL
    DROP TABLE staging.AreasProtegidas;
GO

CREATE TABLE staging.AreasProtegidas (
    region                  VARCHAR(100)  NULL,  -- Centro / Nea / Noa / Patagonia norte / etc.
    areaProtegida           VARCHAR(200)  NULL,  -- nombre oficial del area
    hectareas               VARCHAR(20)   NULL,  -- superficie como texto (puede tener puntos de miles)
    categoriaInternacional  VARCHAR(200)  NULL   -- Patrimonio Mundial / Sitio Ramsar / etc.
);
GO

-- ============================================================
-- STAGING para: aprn_i_visitas_porc_2024.csv
-- Columnas: anio, residentes_en_porcentaje, no_residentes_en_porcentaje
-- Nota: separador ; y campos entre comillas dobles (FORMAT = 'CSV')
-- ============================================================
IF OBJECT_ID('staging.VisitasPorcentajeAnual', 'U') IS NOT NULL
    DROP TABLE staging.VisitasPorcentajeAnual;
GO

CREATE TABLE staging.VisitasPorcentajeAnual (
    anio                    VARCHAR(10)  NULL,
    residentesPorcentaje    VARCHAR(10)  NULL,  -- ej: "59.26"
    noResidentesPorcentaje  VARCHAR(10)  NULL   -- ej: "40.74"
);
GO

-- ============================================================
-- TABLA FINAL: estadisticas anuales de distribucion de visitas
-- Fuente: aprn_i_visitas_porc_2024.csv (datos.gob.ar APN)
-- ============================================================
IF OBJECT_ID('parques.EstadisticaVisitasAnual', 'U') IS NULL
BEGIN
    CREATE TABLE parques.EstadisticaVisitasAnual (
        idEstadistica           INT             IDENTITY(1,1)  NOT NULL,
        anio                    INT                            NOT NULL,
        residentesPorcentaje    DECIMAL(5,2)                   NOT NULL,
        noResidentesPorcentaje  DECIMAL(5,2)                   NOT NULL,
        CONSTRAINT PK_EstadisticaVisitasAnual       PRIMARY KEY (idEstadistica),
        CONSTRAINT UQ_EstadisticaVisitasAnual_anio  UNIQUE      (anio),
        CONSTRAINT CHK_EstadisticaVisitasAnual_sum  CHECK       (residentesPorcentaje + noResidentesPorcentaje BETWEEN 99.90 AND 100.10)
    );
END
GO

-- ============================================================
-- STAGING para: WDPA_WDOECM_Jun2026_Public_ARG_csv.csv
-- Fuente: protectedplanet.net (UNEP-WCMC / IUCN)
-- 34 columnas del CSV, todas como VARCHAR para aceptar cualquier valor raw.
-- Columnas clave que se usarán: NAME, DESIG, DESIG_TYPE, IUCN_CAT,
--   GIS_AREA (km²), STATUS_YR, MANG_AUTH
-- Separador: coma (,). BOM UTF-8.
-- ============================================================
IF OBJECT_ID('staging.AreasWDPA', 'U') IS NOT NULL
    DROP TABLE staging.AreasWDPA;
GO

CREATE TABLE staging.AreasWDPA (
    tipo          VARCHAR(20)    NULL,  -- Polygon / Point
    siteId        VARCHAR(20)    NULL,
    sitePid       VARCHAR(20)    NULL,
    siteType      VARCHAR(10)    NULL,  -- PA / OECM
    nameEng       VARCHAR(300)   NULL,
    name          VARCHAR(300)   NULL,  -- nombre en español ← clave
    desig         VARCHAR(200)   NULL,  -- Parque Nacional / Reserva Natural / etc.
    designEng     VARCHAR(200)   NULL,
    desigType     VARCHAR(50)    NULL,  -- National / Sub-national / etc.
    iucnCat       VARCHAR(20)    NULL,  -- Ia, Ib, II, III, IV, V, VI, Not Applicable
    intCrit       VARCHAR(100)   NULL,
    realm         VARCHAR(50)    NULL,
    repMArea      VARCHAR(30)    NULL,
    gisMArea      VARCHAR(30)    NULL,
    repArea       VARCHAR(30)    NULL,
    gisArea       VARCHAR(30)    NULL,  -- superficie en km² ← clave
    noTake        VARCHAR(50)    NULL,
    noTkArea      VARCHAR(30)    NULL,
    status        VARCHAR(50)    NULL,  -- Designated / Proposed / etc.
    statusYr      VARCHAR(10)    NULL,  -- año de designacion ← clave
    govType       VARCHAR(200)   NULL,
    govSubtype    VARCHAR(200)   NULL,
    ownType       VARCHAR(200)   NULL,
    ownSubtype    VARCHAR(200)   NULL,
    mangAuth      VARCHAR(300)   NULL,  -- Administracion de Parques Nacionales
    mangPlan      VARCHAR(500)   NULL,
    verif         VARCHAR(50)    NULL,
    metadataId    VARCHAR(20)    NULL,
    prntIso3      VARCHAR(10)    NULL,
    iso3          VARCHAR(10)    NULL,
    suppInfo      VARCHAR(500)   NULL,
    consObj       VARCHAR(500)   NULL,
    inlndWtrs     VARCHAR(50)    NULL,
    oecmAsmt      VARCHAR(50)    NULL
);
GO

-- ============================================================
-- TABLA FINAL: tipo de cambio diario
-- Fuente: API dolarapi.com (https://dolarapi.com/v1/dolares/{tipo})
-- Tipos: oficial, blue, tarjeta, mayorista, bolsa, cripto
-- Uso: calcular ingresos en moneda extranjera (Entrega 7)
-- ============================================================
IF OBJECT_ID('parques.TipoCambio', 'U') IS NULL
BEGIN
    CREATE TABLE parques.TipoCambio (
        idTipoCambio  INT            IDENTITY(1,1)  NOT NULL,
        fecha         DATE                          NOT NULL,
        tipo          VARCHAR(20)                   NOT NULL,  -- oficial / blue / tarjeta
        compra        DECIMAL(10,2)                 NOT NULL,
        venta         DECIMAL(10,2)                 NOT NULL,
        CONSTRAINT PK_TipoCambio             PRIMARY KEY (idTipoCambio),
        CONSTRAINT UQ_TipoCambio_fechaTipo   UNIQUE      (fecha, tipo),
        CONSTRAINT CHK_TipoCambio_compra     CHECK       (compra > 0),
        CONSTRAINT CHK_TipoCambio_venta      CHECK       (venta >= compra)
    );
END
GO

PRINT 'Tablas de staging y tablas finales creadas correctamente.';
GO
