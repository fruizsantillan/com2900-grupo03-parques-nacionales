-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Script unificado Entrega 6 - Staging, tablas finales y SPs de importacion CSV y API.
-- =============================================

USE ParquesNacionales;
GO


-- ============================================================
-- STAGING - Tablas de landing zone y tablas finales
-- ============================================================

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

GO

-- Schema staging (landing zone): se crea si no existe
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC ('CREATE SCHEMA staging');
GO

-- STAGING: reciben exactamente las columnas del CSV
-- Se truncan antes de cada carga (no son persistentes)

-- Staging para: visitas-residentes-y-no-residentes.csv
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

-- TABLAS FINALES: destino de la importacion
-- Se crean en el schema parques junto con el resto del modelo

-- Estadisticas mensuales de visitas a nivel nacional
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

-- STAGING para: aprn_h_ubicacion_superycatint_ha.csv
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

-- STAGING para: aprn_i_visitas_porc_2024.csv
IF OBJECT_ID('staging.VisitasPorcentajeAnual', 'U') IS NOT NULL
    DROP TABLE staging.VisitasPorcentajeAnual;
GO

CREATE TABLE staging.VisitasPorcentajeAnual (
    anio                    VARCHAR(10)  NULL,
    residentesPorcentaje    VARCHAR(10)  NULL,  -- ej: "59.26"
    noResidentesPorcentaje  VARCHAR(10)  NULL   -- ej: "40.74"
);
GO

-- TABLA FINAL: estadisticas anuales de distribucion de visitas
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

-- STAGING para: WDPA_WDOECM_Jun2026_Public_ARG_csv.csv
-- 34 columnas del CSV, todas como VARCHAR para aceptar cualquier valor raw.
--   GIS_AREA (km²), STATUS_YR, MANG_AUTH
-- Separador: coma (,). BOM UTF-8.
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

-- TABLA FINAL: tipo de cambio diario
-- Tipos: oficial, blue, tarjeta, mayorista, bolsa, cripto
-- Uso: calcular ingresos en moneda extranjera (Entrega 7)
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

GO


-- ============================================================
-- IMPORTACION - Visitas nacionales mensuales (CSV)
-- ============================================================

--         a DATE usando DATEFROMPARTS para garantizar el primer dia del mes.
--               SP sp_ImportarVisitasNacionales hace UPSERT en parques.EstadisticaVisitas

GO

-- SP: sp_ImportarVisitasNacionales
-- Carga el CSV de visitas nacionales en la tabla de staging y
-- luego ejecuta el upsert hacia la tabla final.
-- Parametro: @vRutaArchivo = ruta completa al CSV en el servidor
CREATE OR ALTER PROCEDURE parques.sp_ImportarVisitasNacionales
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql       NVARCHAR(MAX);
    DECLARE @vFilas     INT;
    DECLARE @vInsertadas INT = 0;
    DECLARE @vActualizadas INT = 0;

    -- --------------------------------------------------------
    -- Paso 1: Limpiar staging antes de la carga
    -- --------------------------------------------------------
    TRUNCATE TABLE staging.VisitasNacionales;

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT del CSV en staging
    -- El CSV tiene BOM UTF-8 (CODEPAGE 65001) y encabezado en fila 1.
    -- El campo indice_tiempo viene como YYYY-M-DD (sin cero en el mes).
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT staging.VisitasNacionales
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FIELDTERMINATOR  = '','',
            ROWTERMINATOR    = ''\n'',
            FIRSTROW         = 2,
            CODEPAGE         = ''65001'',
            TABLOCK
        );
    ';
    EXEC sp_executesql @vSql;

    SELECT @vFilas = COUNT(*) FROM staging.VisitasNacionales;
    PRINT 'Filas cargadas en staging: ' + CAST(@vFilas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: Transformacion y UPSERT hacia tabla final
    -- indice_tiempo "2008-1-01" -> DATEFROMPARTS(2008, 1, 1)
    -- Se parsea con PARSENAME reemplazando '-' por '.'
    -- --------------------------------------------------------
    -- Tabla temporal para capturar el resultado del MERGE
    CREATE TABLE #vMergeOutput (accion NVARCHAR(10));

    BEGIN TRANSACTION;
    BEGIN TRY
        MERGE parques.EstadisticaVisitas AS destino
        USING (
            SELECT
                DATEFROMPARTS(
                    CAST(PARSENAME(REPLACE(LTRIM(RTRIM(indiceTiempo)), '-', '.'), 3) AS INT),
                    CAST(PARSENAME(REPLACE(LTRIM(RTRIM(indiceTiempo)), '-', '.'), 2) AS INT),
                    1  -- siempre primer dia del mes
                )                                          AS periodo,
                LOWER(LTRIM(RTRIM(origenVisitantes)))      AS origenVisitante,
                CAST(NULLIF(LTRIM(RTRIM(visitas)), '') AS INT) AS cantidadVisitas,
                NULLIF(LTRIM(RTRIM(observaciones)), '')    AS observaciones
            FROM staging.VisitasNacionales
            WHERE indiceTiempo IS NOT NULL
              AND origenVisitantes IS NOT NULL
              AND visitas IS NOT NULL
              AND visitas != ''
        ) AS origen
        ON  destino.periodo           = origen.periodo
        AND destino.origenVisitante   = origen.origenVisitante

        WHEN MATCHED AND (
            destino.cantidadVisitas != origen.cantidadVisitas
            OR ISNULL(destino.observaciones,'') != ISNULL(origen.observaciones,'')
        ) THEN
            UPDATE SET
                destino.cantidadVisitas = origen.cantidadVisitas,
                destino.observaciones   = origen.observaciones

        WHEN NOT MATCHED BY TARGET THEN
            INSERT (periodo, origenVisitante, cantidadVisitas, observaciones)
            VALUES (origen.periodo, origen.origenVisitante, origen.cantidadVisitas, origen.observaciones)

        OUTPUT $action
        INTO   #vMergeOutput (accion);

        SELECT
            @vInsertadas   = SUM(CASE WHEN accion = 'INSERT' THEN 1 ELSE 0 END),
            @vActualizadas = SUM(CASE WHEN accion = 'UPDATE' THEN 1 ELSE 0 END)
        FROM #vMergeOutput;

        DROP TABLE #vMergeOutput;

        COMMIT TRANSACTION;

        PRINT 'Importacion completada exitosamente.';
        PRINT 'Filas procesadas desde CSV: ' + CAST(@vFilas AS VARCHAR);
        PRINT 'Filas insertadas: '    + CAST(ISNULL(@vInsertadas, 0)   AS VARCHAR);
        PRINT 'Filas actualizadas: '  + CAST(ISNULL(@vActualizadas, 0) AS VARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#vMergeOutput') IS NOT NULL
            DROP TABLE #vMergeOutput;
        THROW;
    END CATCH;
END
GO

-- NOTA DE USO:
-- Ajustar la ruta al CSV segun el servidor SQL Server.
-- Ejemplo ejecucion:
--
-- EXEC parques.sp_ImportarVisitasNacionales
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\visitas-residentes-y-no-residentes.csv';
--
-- Si SQL Server esta en el mismo equipo, usar ruta local.
-- Si es remoto, el archivo debe estar accesible desde el servidor.
PRINT 'SP parques.sp_ImportarVisitasNacionales creado correctamente.';
GO

GO


-- ============================================================
-- IMPORTACION - Visitas por region (CSV)
-- ============================================================

--   Regiones: buenos aires, cordoba, cuyo, litoral, norte, patagonia
--         a DATE usando DATEFROMPARTS para garantizar el primer dia del mes.
--               SP sp_ImportarVisitasPorRegion hace UPSERT en parques.EstadisticaVisitasPorRegion

GO

-- SP: sp_ImportarVisitasPorRegion
-- Carga el CSV de visitas por region en staging y luego
-- hace el upsert hacia la tabla final.
-- Parametro: @vRutaArchivo = ruta completa al CSV en el servidor
CREATE OR ALTER PROCEDURE parques.sp_ImportarVisitasPorRegion
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql        NVARCHAR(MAX);
    DECLARE @vFilas      INT;
    DECLARE @vInsertadas   INT = 0;
    DECLARE @vActualizadas INT = 0;

    -- --------------------------------------------------------
    -- Paso 1: Limpiar staging antes de la carga
    -- --------------------------------------------------------
    TRUNCATE TABLE staging.VisitasPorRegion;

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT del CSV en staging
    -- El CSV tiene BOM UTF-8 (CODEPAGE 65001) y encabezado en fila 1.
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT staging.VisitasPorRegion
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FIELDTERMINATOR  = '','',
            ROWTERMINATOR    = ''\n'',
            FIRSTROW         = 2,
            CODEPAGE         = ''65001'',
            TABLOCK
        );
    ';
    EXEC sp_executesql @vSql;

    SELECT @vFilas = COUNT(*) FROM staging.VisitasPorRegion;
    PRINT 'Filas cargadas en staging: ' + CAST(@vFilas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: Transformacion y UPSERT hacia tabla final
    -- --------------------------------------------------------
    CREATE TABLE #vMergeOutput (accion NVARCHAR(10));

    BEGIN TRANSACTION;
    BEGIN TRY
        MERGE parques.EstadisticaVisitasPorRegion AS destino
        USING (
            SELECT
                DATEFROMPARTS(
                    CAST(PARSENAME(REPLACE(LTRIM(RTRIM(indiceTiempo)), '-', '.'), 3) AS INT),
                    CAST(PARSENAME(REPLACE(LTRIM(RTRIM(indiceTiempo)), '-', '.'), 2) AS INT),
                    1
                )                                               AS periodo,
                LOWER(LTRIM(RTRIM(regionDestino)))              AS region,
                LOWER(LTRIM(RTRIM(origenVisitantes)))           AS origenVisitante,
                CAST(NULLIF(LTRIM(RTRIM(visitas)), '') AS INT)  AS cantidadVisitas,
                NULLIF(LTRIM(RTRIM(observaciones)), '')         AS observaciones
            FROM staging.VisitasPorRegion
            WHERE indiceTiempo    IS NOT NULL
              AND regionDestino   IS NOT NULL
              AND origenVisitantes IS NOT NULL
              AND visitas IS NOT NULL
              AND visitas != ''
        ) AS origen
        ON  destino.periodo         = origen.periodo
        AND destino.region          = origen.region
        AND destino.origenVisitante = origen.origenVisitante

        WHEN MATCHED AND (
            destino.cantidadVisitas != origen.cantidadVisitas
            OR ISNULL(destino.observaciones,'') != ISNULL(origen.observaciones,'')
        ) THEN
            UPDATE SET
                destino.cantidadVisitas = origen.cantidadVisitas,
                destino.observaciones   = origen.observaciones

        WHEN NOT MATCHED BY TARGET THEN
            INSERT (periodo, region, origenVisitante, cantidadVisitas, observaciones)
            VALUES (origen.periodo, origen.region, origen.origenVisitante,
                    origen.cantidadVisitas, origen.observaciones)

        OUTPUT $action INTO #vMergeOutput (accion);

        SELECT
            @vInsertadas   = SUM(CASE WHEN accion = 'INSERT' THEN 1 ELSE 0 END),
            @vActualizadas = SUM(CASE WHEN accion = 'UPDATE' THEN 1 ELSE 0 END)
        FROM #vMergeOutput;

        DROP TABLE #vMergeOutput;

        COMMIT TRANSACTION;

        PRINT 'Importacion por region completada exitosamente.';
        PRINT 'Filas procesadas desde CSV: ' + CAST(@vFilas AS VARCHAR);
        PRINT 'Filas insertadas: '    + CAST(ISNULL(@vInsertadas, 0)   AS VARCHAR);
        PRINT 'Filas actualizadas: '  + CAST(ISNULL(@vActualizadas, 0) AS VARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#vMergeOutput') IS NOT NULL
            DROP TABLE #vMergeOutput;
        THROW;
    END CATCH;
END
GO

-- NOTA DE USO:
-- EXEC parques.sp_ImportarVisitasPorRegion
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\visitas-residentes-y-no-residentes-por-region.csv';
PRINT 'SP parques.sp_ImportarVisitasPorRegion creado correctamente.';
GO

GO


-- ============================================================
-- IMPORTACION - Distribucion anual APN (CSV)
-- ============================================================

--           Administracion de Parques Nacionales (APN)
--               SP sp_ImportarVisitasAnual hace UPSERT en parques.EstadisticaVisitasAnual

GO

-- SP: sp_ImportarVisitasAnual
-- Carga el CSV de porcentajes anuales en staging y hace UPSERT
-- en la tabla final parques.EstadisticaVisitasAnual.
-- Parametro: @vRutaArchivo = ruta completa al CSV en el servidor
CREATE OR ALTER PROCEDURE parques.sp_ImportarVisitasAnual
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql        NVARCHAR(MAX);
    DECLARE @vFilas      INT;
    DECLARE @vInsertadas   INT = 0;
    DECLARE @vActualizadas INT = 0;

    -- --------------------------------------------------------
    -- Paso 1: Limpiar staging
    -- --------------------------------------------------------
    TRUNCATE TABLE staging.VisitasPorcentajeAnual;

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT
    -- Separador: ;   Campos entre comillas: si (FORMAT = 'CSV')
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT staging.VisitasPorcentajeAnual
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FORMAT           = ''CSV'',
            FIELDTERMINATOR  = '';'',
            ROWTERMINATOR    = ''\n'',
            FIRSTROW         = 2,
            CODEPAGE         = ''65001'',
            TABLOCK
        );
    ';
    EXEC sp_executesql @vSql;

    SELECT @vFilas = COUNT(*) FROM staging.VisitasPorcentajeAnual;
    PRINT 'Filas cargadas en staging: ' + CAST(@vFilas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: UPSERT hacia tabla final
    -- --------------------------------------------------------
    CREATE TABLE #vMergeOutput (accion NVARCHAR(10));

    BEGIN TRANSACTION;
    BEGIN TRY
        MERGE parques.EstadisticaVisitasAnual AS destino
        USING (
            SELECT
                CAST(LTRIM(RTRIM(anio))                   AS INT)          AS anio,
                CAST(LTRIM(RTRIM(residentesPorcentaje))   AS DECIMAL(5,2)) AS residentesPorcentaje,
                CAST(LTRIM(RTRIM(noResidentesPorcentaje)) AS DECIMAL(5,2)) AS noResidentesPorcentaje
            FROM staging.VisitasPorcentajeAnual
            WHERE anio IS NOT NULL
              AND residentesPorcentaje IS NOT NULL
              AND noResidentesPorcentaje IS NOT NULL
        ) AS origen
        ON destino.anio = origen.anio

        WHEN MATCHED AND (
            destino.residentesPorcentaje   != origen.residentesPorcentaje
            OR destino.noResidentesPorcentaje != origen.noResidentesPorcentaje
        ) THEN
            UPDATE SET
                destino.residentesPorcentaje   = origen.residentesPorcentaje,
                destino.noResidentesPorcentaje = origen.noResidentesPorcentaje

        WHEN NOT MATCHED BY TARGET THEN
            INSERT (anio, residentesPorcentaje, noResidentesPorcentaje)
            VALUES (origen.anio, origen.residentesPorcentaje, origen.noResidentesPorcentaje)

        OUTPUT $action INTO #vMergeOutput (accion);

        SELECT
            @vInsertadas   = SUM(CASE WHEN accion = 'INSERT' THEN 1 ELSE 0 END),
            @vActualizadas = SUM(CASE WHEN accion = 'UPDATE' THEN 1 ELSE 0 END)
        FROM #vMergeOutput;

        DROP TABLE #vMergeOutput;

        COMMIT TRANSACTION;

        PRINT 'Importacion de estadisticas anuales completada.';
        PRINT 'Filas procesadas: '    + CAST(@vFilas               AS VARCHAR);
        PRINT 'Registros insertados: ' + CAST(ISNULL(@vInsertadas,   0) AS VARCHAR);
        PRINT 'Registros actualizados: '+ CAST(ISNULL(@vActualizadas, 0) AS VARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#vMergeOutput') IS NOT NULL
            DROP TABLE #vMergeOutput;
        THROW;
    END CATCH;
END
GO

-- NOTA DE USO:
-- EXEC parques.sp_ImportarVisitasAnual
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\aprn_i_visitas_porc_2024.csv';
--
-- Verificacion:
--   SELECT anio, residentesPorcentaje, noResidentesPorcentaje
--   FROM parques.EstadisticaVisitasAnual
--   ORDER BY anio;
PRINT 'SP parques.sp_ImportarVisitasAnual creado correctamente.';
GO

GO


-- ============================================================
-- IMPORTACION - Areas protegidas APN (CSV)
-- ============================================================

--           Administracion de Parques Nacionales (APN)
--   Superficie: en hectareas (unidad oficial APN)
--               SP sp_ImportarAreasProtegidas hace UPSERT en:
--                 parques.TipoParque  (deriva tipo del prefijo del nombre)
--                 parques.Ubicacion   (usa centroide aproximado por region)
--                 parques.Parque      (nombre oficial + superficie en hectareas)
--
--   NOTA sobre coordenadas: el CSV no incluye GPS. Se asignan coordenadas
--   aproximadas (centroide de cada region) como punto de inicio.
--   Pueden actualizarse manualmente o mediante un dataset geografico posterior.
--

GO

-- SP: sp_ImportarAreasProtegidas
-- Carga el CSV de areas protegidas en staging y hace UPSERT
-- en TipoParque, Ubicacion y Parque.
-- Parametro: @vRutaArchivo = ruta completa al CSV en el servidor
CREATE OR ALTER PROCEDURE parques.sp_ImportarAreasProtegidas
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql        NVARCHAR(MAX);
    DECLARE @vFilas      INT;
    DECLARE @vInsertadas   INT = 0;
    DECLARE @vActualizadas INT = 0;

    -- --------------------------------------------------------
    -- Paso 1: Limpiar staging
    -- --------------------------------------------------------
    TRUNCATE TABLE staging.AreasProtegidas;

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT
    -- Separador: ;   Campos entre comillas: si (FORMAT = 'CSV')
    -- Requiere SQL Server 2017+ para FORMAT = 'CSV'
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT staging.AreasProtegidas
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FORMAT           = ''CSV'',
            FIELDTERMINATOR  = '';'',
            ROWTERMINATOR    = ''\n'',
            FIRSTROW         = 2,
            CODEPAGE         = ''65001'',
            TABLOCK
        );
    ';
    EXEC sp_executesql @vSql;

    SELECT @vFilas = COUNT(*) FROM staging.AreasProtegidas;
    PRINT 'Filas cargadas en staging: ' + CAST(@vFilas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: Poblar parques.TipoParque
    -- Deriva el tipo del prefijo del nombre del area protegida.
    -- --------------------------------------------------------
    MERGE parques.TipoParque AS destino
    USING (
        SELECT DISTINCT
            CASE
                WHEN areaProtegida LIKE 'Parque Nacional%'              THEN 'Parque Nacional'
                WHEN areaProtegida LIKE 'Parque Interjurisdiccional%'   THEN 'Parque Interjurisdiccional'
                WHEN areaProtegida LIKE 'Reserva Nacional%'             THEN 'Reserva Nacional'
                WHEN areaProtegida LIKE 'Reserva Natural%'              THEN 'Reserva Natural'
                WHEN areaProtegida LIKE 'Monumento Natural%'            THEN 'Monumento Natural'
                ELSE 'Otra Area Protegida'
            END AS descripcion
        FROM staging.AreasProtegidas
        WHERE areaProtegida IS NOT NULL
    ) AS origen
    ON destino.descripcion = origen.descripcion
    WHEN NOT MATCHED THEN
        INSERT (descripcion) VALUES (origen.descripcion);

    PRINT 'TipoParque actualizado.';

    -- --------------------------------------------------------
    -- Paso 4: Poblar parques.Ubicacion
    -- Una ubicacion por area protegida, usando coordenadas
    -- aproximadas del centroide de cada region de la APN.
    -- Mapa de regiones -> (latitud, longitud) centroide aprox.:
    --   Centro            -> (-31.00, -67.50)   San Juan / Mendoza / Cordoba
    --   Centro este       -> (-32.00, -60.50)   Entre Rios / Santa Fe
    --   Nea               -> (-27.00, -57.00)   Corrientes / Misiones / Chaco
    --   Noa               -> (-24.00, -65.00)   Salta / Jujuy / Tucuman
    --   Patagonia norte   -> (-41.00, -71.00)   Neuquen / Rio Negro / Chubut norte
    --   Patagonia austral -> (-50.00, -70.00)   Santa Cruz / Tierra del Fuego
    --   Mar Argentino     -> (-50.00, -58.00)   Offshore Atlantico Sur
    -- --------------------------------------------------------
    MERGE parques.Ubicacion AS destino
    USING (
        SELECT
            areaProtegida                      AS direccion,
            LOWER(LTRIM(RTRIM(region)))        AS provincia,  -- usamos region como provincia
            CASE LOWER(LTRIM(RTRIM(region)))
                WHEN 'centro'             THEN CAST(-31.00 AS DECIMAL(9,6))
                WHEN 'centro este'        THEN CAST(-32.00 AS DECIMAL(9,6))
                WHEN 'nea'                THEN CAST(-27.00 AS DECIMAL(9,6))
                WHEN 'noa'                THEN CAST(-24.00 AS DECIMAL(9,6))
                WHEN 'patagonia norte'    THEN CAST(-41.00 AS DECIMAL(9,6))
                WHEN 'patagonia austral'  THEN CAST(-50.00 AS DECIMAL(9,6))
                WHEN 'mar argentino'      THEN CAST(-50.00 AS DECIMAL(9,6))
                ELSE                           CAST(-35.00 AS DECIMAL(9,6))  -- centroide ARG
            END AS latitud,
            CASE LOWER(LTRIM(RTRIM(region)))
                WHEN 'centro'             THEN CAST(-67.50 AS DECIMAL(9,6))
                WHEN 'centro este'        THEN CAST(-60.50 AS DECIMAL(9,6))
                WHEN 'nea'                THEN CAST(-57.00 AS DECIMAL(9,6))
                WHEN 'noa'                THEN CAST(-65.00 AS DECIMAL(9,6))
                WHEN 'patagonia norte'    THEN CAST(-71.00 AS DECIMAL(9,6))
                WHEN 'patagonia austral'  THEN CAST(-70.00 AS DECIMAL(9,6))
                WHEN 'mar argentino'      THEN CAST(-58.00 AS DECIMAL(9,6))
                ELSE                           CAST(-65.00 AS DECIMAL(9,6))  -- centroide ARG
            END AS longitud
        FROM staging.AreasProtegidas
        WHERE areaProtegida IS NOT NULL
          AND region IS NOT NULL
    ) AS origen
    ON destino.direccion = origen.direccion
    WHEN NOT MATCHED THEN
        INSERT (direccion, provincia, latitud, longitud)
        VALUES (origen.direccion, origen.provincia, origen.latitud, origen.longitud)
    WHEN MATCHED THEN
        UPDATE SET
            destino.provincia = origen.provincia;

    PRINT 'Ubicaciones actualizadas.';

    -- --------------------------------------------------------
    -- Paso 5: UPSERT en parques.Parque
    -- --------------------------------------------------------
    CREATE TABLE #vMergeOutput (accion NVARCHAR(10));

    BEGIN TRANSACTION;
    BEGIN TRY
        MERGE parques.Parque AS destino
        USING (
            SELECT
                s.areaProtegida                         AS nombre,
                TRY_CAST(
                    REPLACE(LTRIM(RTRIM(s.hectareas)), '.', '')
                    AS DECIMAL(18,2)
                )                                       AS superficie,  -- en hectareas
                tp.idTipoParque,
                u.idUbicacion
            FROM staging.AreasProtegidas s
            JOIN parques.TipoParque tp
              ON tp.descripcion = CASE
                    WHEN s.areaProtegida LIKE 'Parque Nacional%'            THEN 'Parque Nacional'
                    WHEN s.areaProtegida LIKE 'Parque Interjurisdiccional%' THEN 'Parque Interjurisdiccional'
                    WHEN s.areaProtegida LIKE 'Reserva Nacional%'           THEN 'Reserva Nacional'
                    WHEN s.areaProtegida LIKE 'Reserva Natural%'            THEN 'Reserva Natural'
                    WHEN s.areaProtegida LIKE 'Monumento Natural%'          THEN 'Monumento Natural'
                    ELSE 'Otra Area Protegida'
                 END
            JOIN parques.Ubicacion u
              ON u.direccion = s.areaProtegida
            WHERE s.areaProtegida IS NOT NULL
              AND s.hectareas IS NOT NULL
        ) AS origen
        ON destino.nombre = origen.nombre

        WHEN MATCHED AND destino.superficie != origen.superficie THEN
            UPDATE SET destino.superficie = origen.superficie

        WHEN NOT MATCHED BY TARGET THEN
            INSERT (nombre, superficie, idTipoParque, idUbicacion)
            VALUES (origen.nombre, origen.superficie, origen.idTipoParque, origen.idUbicacion)

        OUTPUT $action INTO #vMergeOutput (accion);

        SELECT
            @vInsertadas   = SUM(CASE WHEN accion = 'INSERT' THEN 1 ELSE 0 END),
            @vActualizadas = SUM(CASE WHEN accion = 'UPDATE' THEN 1 ELSE 0 END)
        FROM #vMergeOutput;

        DROP TABLE #vMergeOutput;

        COMMIT TRANSACTION;

        PRINT 'Importacion de areas protegidas completada.';
        PRINT 'Filas CSV procesadas: '  + CAST(@vFilas      AS VARCHAR);
        PRINT 'Parques insertados: '    + CAST(ISNULL(@vInsertadas,   0) AS VARCHAR);
        PRINT 'Parques actualizados: '  + CAST(ISNULL(@vActualizadas, 0) AS VARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#vMergeOutput') IS NOT NULL
            DROP TABLE #vMergeOutput;
        THROW;
    END CATCH;
END
GO

-- NOTA DE USO:
-- EXEC parques.sp_ImportarAreasProtegidas
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\aprn_h_ubicacion_superycatint_ha.csv';
--
-- Verificacion:
--   SELECT p.nombre, tp.descripcion AS tipo, p.superficie, u.provincia
--   FROM parques.Parque p
--   JOIN parques.TipoParque tp ON tp.idTipoParque = p.idTipoParque
--   JOIN parques.Ubicacion  u  ON u.idUbicacion   = p.idUbicacion
--   ORDER BY tp.descripcion, p.nombre;
PRINT 'SP parques.sp_ImportarAreasProtegidas creado correctamente.';
GO

GO


-- ============================================================
-- IMPORTACION - Areas protegidas WDPA (CSV)
-- ============================================================

--   GIS_AREA esta en km2 (se convierte a hectareas multiplicando x100 para
--   mantener consistencia con el resto del sistema que usa hectareas).
--   Filtra: solo areas de jurisdiccion Nacional (DESIG_TYPE = 'National')
--               UPSERT en parques.TipoParque y parques.Parque.
--               Si el parque ya existe (importado desde APN), actualiza
--               la superficie con el valor GIS mas preciso del WDPA.
--               Si no existe, lo inserta con ubicacion pendiente de asignar.
--
--       solo procesa las relevantes para el sistema.

GO

-- SP: sp_ImportarAreasWDPA
CREATE OR ALTER PROCEDURE parques.sp_ImportarAreasWDPA
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql          NVARCHAR(MAX);
    DECLARE @vTotalStaging INT;
    DECLARE @vProcesadas   INT;
    DECLARE @vDescartadas  INT;
    DECLARE @vInsertadas   INT = 0;
    DECLARE @vActualizadas INT = 0;

    -- --------------------------------------------------------
    -- Paso 1: Limpiar staging
    -- --------------------------------------------------------
    TRUNCATE TABLE staging.AreasWDPA;

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT (34 columnas, sep coma, BOM UTF-8)
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT staging.AreasWDPA
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FORMAT          = ''CSV'',
            FIELDTERMINATOR = '','',
            ROWTERMINATOR   = ''\n'',
            FIRSTROW        = 2,
            CODEPAGE        = ''65001'',
            TABLOCK
        );
    ';
    EXEC sp_executesql @vSql;

    SELECT @vTotalStaging = COUNT(*) FROM staging.AreasWDPA;
    PRINT 'Filas cargadas en staging: ' + CAST(@vTotalStaging AS VARCHAR);

    -- Contar las que seran descartadas (no nacionales o sin nombre)
    SELECT @vDescartadas = COUNT(*)
    FROM staging.AreasWDPA
    WHERE LTRIM(RTRIM(desigType)) != 'National'
       OR name IS NULL
       OR LTRIM(RTRIM(name)) = '';

    SELECT @vProcesadas = @vTotalStaging - @vDescartadas;
    PRINT 'Filas a procesar (jurisdiccion Nacional): ' + CAST(@vProcesadas   AS VARCHAR);
    PRINT 'Filas descartadas (no nacionales/sin nombre): ' + CAST(@vDescartadas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: UPSERT en parques.TipoParque
    -- Extrae el tipo del campo DESIG (nombre en espanol)
    -- --------------------------------------------------------
    MERGE parques.TipoParque AS destino
    USING (
        SELECT DISTINCT LTRIM(RTRIM(desig)) AS descripcion
        FROM staging.AreasWDPA
        WHERE LTRIM(RTRIM(desigType)) = 'National'
          AND desig IS NOT NULL
          AND LTRIM(RTRIM(desig)) != ''
    ) AS origen
    ON destino.descripcion = origen.descripcion
    WHEN NOT MATCHED THEN
        INSERT (descripcion) VALUES (origen.descripcion);

    PRINT 'TipoParque actualizado con tipos WDPA.';

    -- --------------------------------------------------------
    -- Paso 4: UPSERT en parques.Parque
    -- Filtra solo areas de jurisdiccion Nacional.
    -- GIS_AREA viene en km2 -> convertimos a hectareas (* 100).
    -- Si el parque ya existe por nombre, actualiza la superficie
    -- con el valor GIS mas preciso del WDPA.
    -- Si no existe, lo inserta; la Ubicacion queda pendiente
    -- (idUbicacion apuntara a una ubicacion generica por pais).
    -- --------------------------------------------------------

    -- Ubicacion generica de Argentina para parques sin ubicacion propia
    -- (se crea si no existe)
    IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion WHERE direccion = 'Argentina - Pendiente de asignacion')
    BEGIN
        INSERT INTO parques.Ubicacion (direccion, provincia, latitud, longitud)
        VALUES ('Argentina - Pendiente de asignacion', 'Sin definir', -38.00, -65.00);
    END

    DECLARE @vIdUbicacionGenerica INT =
        (SELECT idUbicacion FROM parques.Ubicacion
         WHERE direccion = 'Argentina - Pendiente de asignacion');

    CREATE TABLE #vMergeOutput (accion NVARCHAR(10));

    BEGIN TRANSACTION;
    BEGIN TRY
        MERGE parques.Parque AS destino
        USING (
            -- Deduplicar por nombre: el WDPA puede tener Polygon + Point del mismo area.
            -- Se toma el registro con mayor superficie (MAX gisArea).
            SELECT
                LTRIM(RTRIM(s.name))  AS nombre,
                MAX(TRY_CAST(
                    REPLACE(LTRIM(RTRIM(s.gisArea)), ',', '.')
                    AS DECIMAL(18,2)
                )) * 100              AS superficieHa,
                MAX(tp.idTipoParque)  AS idTipoParque,
                @vIdUbicacionGenerica AS idUbicacion
            FROM staging.AreasWDPA s
            JOIN parques.TipoParque tp
              ON tp.descripcion = LTRIM(RTRIM(s.desig))
            WHERE LTRIM(RTRIM(s.desigType)) = 'National'
              AND s.name IS NOT NULL
              AND LTRIM(RTRIM(s.name)) != ''
              AND TRY_CAST(
                    REPLACE(LTRIM(RTRIM(s.gisArea)), ',', '.')
                    AS DECIMAL(18,2)
                  ) IS NOT NULL
            GROUP BY LTRIM(RTRIM(s.name))
        ) AS origen
        ON destino.nombre = origen.nombre

        -- Si ya existe, actualizar superficie con el dato GIS mas preciso
        WHEN MATCHED AND destino.superficie != origen.superficieHa THEN
            UPDATE SET destino.superficie = origen.superficieHa

        -- Si no existe, insertar con ubicacion generica
        WHEN NOT MATCHED BY TARGET THEN
            INSERT (nombre, superficie, idTipoParque, idUbicacion)
            VALUES (origen.nombre, origen.superficieHa,
                    origen.idTipoParque, origen.idUbicacion)

        OUTPUT $action INTO #vMergeOutput (accion);

        SELECT
            @vInsertadas   = SUM(CASE WHEN accion = 'INSERT' THEN 1 ELSE 0 END),
            @vActualizadas = SUM(CASE WHEN accion = 'UPDATE' THEN 1 ELSE 0 END)
        FROM #vMergeOutput;

        DROP TABLE #vMergeOutput;
        COMMIT TRANSACTION;

        PRINT '----------------------------------------------';
        PRINT 'Importacion WDPA completada exitosamente.';
        PRINT 'Total filas en CSV:          ' + CAST(@vTotalStaging  AS VARCHAR);
        PRINT 'Procesadas (nacionales):     ' + CAST(@vProcesadas    AS VARCHAR);
        PRINT 'Descartadas (no nacionales): ' + CAST(@vDescartadas   AS VARCHAR);
        PRINT 'Parques insertados:          ' + CAST(ISNULL(@vInsertadas,   0) AS VARCHAR);
        PRINT 'Parques actualizados:        ' + CAST(ISNULL(@vActualizadas, 0) AS VARCHAR);
        PRINT '----------------------------------------------';

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#vMergeOutput') IS NOT NULL
            DROP TABLE #vMergeOutput;
        THROW;
    END CATCH;
END
GO

-- NOTA DE USO:
-- EXEC parques.sp_ImportarAreasWDPA
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\WDPA_WDOECM_Jun2026_Public_ARG_csv.csv';
--
-- Verificacion post-importacion:
--   SELECT p.nombre, tp.descripcion AS tipo, p.superficie, u.provincia
--   FROM parques.Parque p
--   JOIN parques.TipoParque tp ON tp.idTipoParque = p.idTipoParque
--   JOIN parques.Ubicacion  u  ON u.idUbicacion   = p.idUbicacion
--   ORDER BY tp.descripcion, p.nombre;
PRINT 'SP parques.sp_ImportarAreasWDPA creado correctamente.';
GO

GO


-- ============================================================
-- IMPORTACION - Feriados nacionales (API REST)
-- ============================================================

--   Respuesta JSON (array): [{"fecha":"YYYY-MM-DD","tipo":"...","nombre":"..."}]
--   Tipos conocidos: inamovible, trasladable, puente, nolaborable
--               parseo manual del JSON -> UPSERT en parques.Feriado
--
--     EXEC sp_configure 'Ole Automation Procedures', 1;
--     RECONFIGURE;
--   (requiere permisos de sysadmin)
--

GO

-- SP: sp_ImportarFeriados
-- Llama a la API de ArgentinaDatos para un año dado,
-- parsea el JSON recibido y hace UPSERT en parques.Feriado.
-- Parametro: @vAnio = año a importar (ej. 2025)
CREATE OR ALTER PROCEDURE parques.sp_ImportarFeriados
    @vAnio INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Validacion del parametro
    IF @vAnio < 2000 OR @vAnio > 2100
    BEGIN
        RAISERROR('- El anio indicado no es valido. Debe estar entre 2000 y 2100.', 16, 1);
        RETURN;
    END

    DECLARE @vUrl          NVARCHAR(200);
    DECLARE @vObjHttp      INT;
    DECLARE @vHrResult     INT;
    DECLARE @vRespuesta    NVARCHAR(MAX);
    DECLARE @vChunk        NVARCHAR(MAX);
    DECLARE @vInsertadas   INT = 0;
    DECLARE @vActualizadas INT = 0;

    SET @vUrl = 'https://argentinadatos.com/v1/feriados/' + CAST(@vAnio AS VARCHAR(4));
    PRINT 'Consultando: ' + @vUrl;

    -- --------------------------------------------------------
    -- Paso 1: Llamada HTTP GET via OLE Automation
    -- --------------------------------------------------------
    EXEC @vHrResult = sp_OACreate 'MSXML2.ServerXMLHTTP', @vObjHttp OUT;
    IF @vHrResult <> 0
    BEGIN
        RAISERROR('- Error al crear objeto HTTP (sp_OACreate). Verificar que Ole Automation este habilitado.', 16, 1);
        RETURN;
    END

    EXEC @vHrResult = sp_OAMethod @vObjHttp, 'open', NULL, 'GET', @vUrl, false;
    IF @vHrResult <> 0
    BEGIN
        EXEC sp_OADestroy @vObjHttp;
        RAISERROR('- Error al abrir conexion HTTP.', 16, 1);
        RETURN;
    END

    EXEC @vHrResult = sp_OAMethod @vObjHttp, 'setRequestHeader', NULL, 'Accept', 'application/json';
    EXEC @vHrResult = sp_OAMethod @vObjHttp, 'send';
    IF @vHrResult <> 0
    BEGIN
        EXEC sp_OADestroy @vObjHttp;
        RAISERROR('- Error al enviar peticion HTTP.', 16, 1);
        RETURN;
    END

    -- Leer la respuesta
    EXEC @vHrResult = sp_OAGetProperty @vObjHttp, 'responseText', @vRespuesta OUT;
    EXEC sp_OADestroy @vObjHttp;

    IF @vRespuesta IS NULL OR LEN(@vRespuesta) < 5
    BEGIN
        RAISERROR('- La API no devolvio datos. Verificar conectividad o el anio consultado.', 16, 1);
        RETURN;
    END

    PRINT 'Respuesta recibida (' + CAST(LEN(@vRespuesta) AS VARCHAR) + ' caracteres).';

    -- --------------------------------------------------------
    -- Paso 2: Cargar el JSON en staging
    -- SQL Server 2016+ soporta OPENJSON nativo
    -- --------------------------------------------------------
    TRUNCATE TABLE staging.Feriados;

    INSERT INTO staging.Feriados (fecha, tipo, nombre)
    SELECT
        JSON_VALUE(value, '$.fecha'),
        JSON_VALUE(value, '$.tipo'),
        JSON_VALUE(value, '$.nombre')
    FROM OPENJSON(@vRespuesta);

    DECLARE @vFilas INT;
    SELECT @vFilas = COUNT(*) FROM staging.Feriados;
    PRINT 'Feriados cargados en staging: ' + CAST(@vFilas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: UPSERT hacia tabla final
    -- --------------------------------------------------------
    CREATE TABLE #vMergeOutput (accion NVARCHAR(10));

    BEGIN TRANSACTION;
    BEGIN TRY
        MERGE parques.Feriado AS destino
        USING (
            SELECT
                CAST(fecha AS DATE)       AS fecha,
                LTRIM(RTRIM(tipo))        AS tipo,
                LTRIM(RTRIM(nombre))      AS nombre
            FROM staging.Feriados
            WHERE fecha IS NOT NULL
              AND nombre IS NOT NULL
        ) AS origen
        ON destino.fecha = origen.fecha

        WHEN MATCHED AND (
            ISNULL(destino.tipo,'') != ISNULL(origen.tipo,'')
            OR destino.nombre       != origen.nombre
        ) THEN
            UPDATE SET
                destino.tipo   = origen.tipo,
                destino.nombre = origen.nombre

        WHEN NOT MATCHED BY TARGET THEN
            INSERT (fecha, tipo, nombre)
            VALUES (origen.fecha, origen.tipo, origen.nombre)

        OUTPUT $action INTO #vMergeOutput (accion);

        SELECT
            @vInsertadas   = SUM(CASE WHEN accion = 'INSERT' THEN 1 ELSE 0 END),
            @vActualizadas = SUM(CASE WHEN accion = 'UPDATE' THEN 1 ELSE 0 END)
        FROM #vMergeOutput;

        DROP TABLE #vMergeOutput;

        COMMIT TRANSACTION;

        PRINT 'Importacion de feriados ' + CAST(@vAnio AS VARCHAR) + ' completada.';
        PRINT 'Feriados insertados: '    + CAST(ISNULL(@vInsertadas, 0)   AS VARCHAR);
        PRINT 'Feriados actualizados: '  + CAST(ISNULL(@vActualizadas, 0) AS VARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#vMergeOutput') IS NOT NULL
            DROP TABLE #vMergeOutput;
        THROW;
    END CATCH;
END
GO

-- NOTA DE USO:
-- Habilitar OLE Automation en SQL Server (una sola vez, requiere sysadmin):
--   EXEC sp_configure 'Ole Automation Procedures', 1;
--   RECONFIGURE;
--
-- Importar feriados de un año:
--   EXEC parques.sp_ImportarFeriados @vAnio = 2025;
--   EXEC parques.sp_ImportarFeriados @vAnio = 2026;
--
-- Verificar resultado:
--   SELECT * FROM parques.Feriado ORDER BY fecha;
PRINT 'SP parques.sp_ImportarFeriados creado correctamente.';
GO

GO


-- ============================================================
-- IMPORTACION - Tipo de cambio USD/ARS (API REST)
-- ============================================================

--   Endpoints disponibles:
--     /v1/dolares/oficial   -> dolar oficial Banco Nacion
--     /v1/dolares/blue      -> dolar blue (mercado informal)
--     /v1/dolares/tarjeta   -> dolar tarjeta (compras con tarjeta en el exterior)
--   Formato respuesta JSON: {"moneda":"USD","casa":"oficial","nombre":"Oficial",
--                             "compra":1100.50,"venta":1120.50,
--                             "fechaActualizacion":"2026-06-15T12:00:00.000Z"}
--   Reporte 2 - Ingresos en moneda extranjera).
--
--     EXEC sp_configure 'Ole Automation Procedures', 1;
--     RECONFIGURE;
--

GO

-- SP: sp_ImportarTipoCambio
-- Consulta la API dolarapi.com para el tipo indicado y guarda
-- el valor en parques.TipoCambio con logica de Upsert.
-- Parametro: @vTipo = 'oficial' | 'blue' | 'tarjeta'
--            (default: 'oficial')
CREATE OR ALTER PROCEDURE parques.sp_ImportarTipoCambio
    @vTipo VARCHAR(20) = 'oficial'
AS
BEGIN
    SET NOCOUNT ON;

    -- Validacion del parametro
    IF @vTipo NOT IN ('oficial', 'blue', 'tarjeta', 'mayorista', 'bolsa', 'cripto')
    BEGIN
        RAISERROR('- Tipo de cambio invalido. Valores validos: oficial, blue, tarjeta, mayorista, bolsa, cripto.', 16, 1);
        RETURN;
    END

    DECLARE @vUrl        NVARCHAR(200);
    DECLARE @vObjHttp    INT;
    DECLARE @vHrResult   INT;
    DECLARE @vRespuesta  NVARCHAR(MAX);
    DECLARE @vCompra     DECIMAL(10,2);
    DECLARE @vVenta      DECIMAL(10,2);
    DECLARE @vFecha      DATE = CAST(GETDATE() AS DATE);

    SET @vUrl = 'https://dolarapi.com/v1/dolares/' + @vTipo;
    PRINT 'Consultando: ' + @vUrl;

    -- --------------------------------------------------------
    -- Paso 1: HTTP GET via OLE Automation
    -- --------------------------------------------------------
    EXEC @vHrResult = sp_OACreate 'MSXML2.ServerXMLHTTP', @vObjHttp OUT;
    IF @vHrResult <> 0
    BEGIN
        RAISERROR('- Error al crear objeto HTTP. Verificar que Ole Automation este habilitado.', 16, 1);
        RETURN;
    END

    EXEC @vHrResult = sp_OAMethod @vObjHttp, 'open', NULL, 'GET', @vUrl, false;
    IF @vHrResult <> 0
    BEGIN
        EXEC sp_OADestroy @vObjHttp;
        RAISERROR('- Error al abrir conexion HTTP con dolarapi.com.', 16, 1);
        RETURN;
    END

    EXEC sp_OAMethod @vObjHttp, 'setRequestHeader', NULL, 'Accept', 'application/json';
    EXEC @vHrResult = sp_OAMethod @vObjHttp, 'send';
    IF @vHrResult <> 0
    BEGIN
        EXEC sp_OADestroy @vObjHttp;
        RAISERROR('- Error al enviar peticion HTTP.', 16, 1);
        RETURN;
    END

    EXEC sp_OAGetProperty @vObjHttp, 'responseText', @vRespuesta OUT;
    EXEC sp_OADestroy @vObjHttp;

    IF @vRespuesta IS NULL OR LEN(@vRespuesta) < 10
    BEGIN
        RAISERROR('- La API no devolvio datos. Verificar conectividad a dolarapi.com.', 16, 1);
        RETURN;
    END

    PRINT 'Respuesta recibida: ' + @vRespuesta;

    -- --------------------------------------------------------
    -- Paso 2: Parsear JSON con OPENJSON (SQL Server 2016+)
    -- Respuesta: {"moneda":"USD","casa":"oficial","nombre":"Oficial",
    --             "compra":1100.50,"venta":1120.50,"fechaActualizacion":"..."}
    -- --------------------------------------------------------
    SELECT
        @vCompra = TRY_CAST(JSON_VALUE(@vRespuesta, '$.compra') AS DECIMAL(10,2)),
        @vVenta  = TRY_CAST(JSON_VALUE(@vRespuesta, '$.venta')  AS DECIMAL(10,2));

    IF @vCompra IS NULL OR @vVenta IS NULL
    BEGIN
        RAISERROR('- No se pudieron parsear los valores de compra/venta del JSON.', 16, 1);
        RETURN;
    END

    IF @vCompra <= 0 OR @vVenta < @vCompra
    BEGIN
        RAISERROR('- Valores de tipo de cambio invalidos recibidos de la API.', 16, 1);
        RETURN;
    END

    -- --------------------------------------------------------
    -- Paso 3: UPSERT en parques.TipoCambio
    -- Si ya existe el tipo para hoy, actualiza; sino inserta.
    -- --------------------------------------------------------
    BEGIN TRANSACTION;
    BEGIN TRY
        MERGE parques.TipoCambio AS destino
        USING (
            SELECT @vFecha AS fecha, @vTipo AS tipo,
                   @vCompra AS compra, @vVenta AS venta
        ) AS origen
        ON destino.fecha = origen.fecha
        AND destino.tipo  = origen.tipo

        WHEN MATCHED THEN
            UPDATE SET
                destino.compra = origen.compra,
                destino.venta  = origen.venta

        WHEN NOT MATCHED THEN
            INSERT (fecha, tipo, compra, venta)
            VALUES (origen.fecha, origen.tipo, origen.compra, origen.venta);

        COMMIT TRANSACTION;

        PRINT '----------------------------------------------';
        PRINT 'Tipo de cambio registrado correctamente.';
        PRINT 'Tipo:   ' + @vTipo;
        PRINT 'Fecha:  ' + CONVERT(VARCHAR(10), @vFecha, 103);
        PRINT 'Compra: $ ' + CAST(@vCompra AS VARCHAR);
        PRINT 'Venta:  $ ' + CAST(@vVenta  AS VARCHAR);
        PRINT '----------------------------------------------';

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

-- SP auxiliar: sp_ObtenerTipoCambioVigente
-- Retorna el tipo de cambio mas reciente para un tipo dado.
-- Uso: llamarlo desde otros SPs que necesiten convertir precios.
CREATE OR ALTER PROCEDURE parques.sp_ObtenerTipoCambioVigente
    @vTipo   VARCHAR(20) = 'oficial',
    @vVenta  DECIMAL(10,2) OUTPUT,
    @vCompra DECIMAL(10,2) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        @vVenta  = venta,
        @vCompra = compra
    FROM parques.TipoCambio
    WHERE tipo = @vTipo
    ORDER BY fecha DESC;

    IF @vVenta IS NULL
    BEGIN
        RAISERROR('- No hay tipo de cambio registrado para el tipo indicado. Ejecute sp_ImportarTipoCambio primero.', 16, 1);
        RETURN;
    END
END
GO

-- NOTA DE USO:
-- Habilitar OLE Automation (una sola vez, requiere sysadmin):
--   EXEC sp_configure 'Ole Automation Procedures', 1;
--   RECONFIGURE;
--
-- Importar tipo de cambio actual:
--   EXEC parques.sp_ImportarTipoCambio @vTipo = 'oficial';
--   EXEC parques.sp_ImportarTipoCambio @vTipo = 'blue';
--   EXEC parques.sp_ImportarTipoCambio @vTipo = 'tarjeta';
--
-- Consultar historial:
--   SELECT * FROM parques.TipoCambio ORDER BY fecha DESC, tipo;
--
-- Usar en otro SP para convertir un precio en pesos a dolares:
--   DECLARE @vVenta DECIMAL(10,2), @vCompra DECIMAL(10,2);
--   EXEC parques.sp_ObtenerTipoCambioVigente
--       @vTipo = 'oficial', @vVenta = @vVenta OUTPUT, @vCompra = @vCompra OUTPUT;
--   SELECT @vPrecioARS / @vVenta AS precioUSD;
PRINT 'SPs parques.sp_ImportarTipoCambio y sp_ObtenerTipoCambioVigente creados correctamente.';
GO

GO
