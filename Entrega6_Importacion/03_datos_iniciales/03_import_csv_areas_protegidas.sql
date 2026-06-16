-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Importacion de areas protegidas nacionales desde CSV oficial de APN.
--   Fuente: aprn_h_ubicacion_superycatint_ha.csv
--   Origen: https://datos.gob.ar/dataset/ambiente-areas-protegidas-nacionales
--           Administracion de Parques Nacionales (APN)
--   Formato: CSV UTF-8, separador punto y coma (;), campos entre comillas dobles
--   Columnas: region, area_protegida, hectareas, categoria_internacional
--   Superficie: en hectareas (unidad oficial APN)
--   Estrategia: BULK INSERT en staging.AreasProtegidas ->
--               SP sp_ImportarAreasProtegidas hace UPSERT en:
--                 parques.TipoParque  (deriva tipo del prefijo del nombre)
--                 parques.Ubicacion   (usa centroide aproximado por region)
--                 parques.Parque      (nombre oficial + superficie en hectareas)
--
--   NOTA sobre coordenadas: el CSV no incluye GPS. Se asignan coordenadas
--   aproximadas (centroide de cada region) como punto de inicio.
--   Pueden actualizarse manualmente o mediante un dataset geografico posterior.
--
-- Prerequisito: Ejecutar 01_tablas_staging.sql y los scripts de tablas del modulo parques.
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: sp_ImportarAreasProtegidas
-- Carga el CSV de areas protegidas en staging y hace UPSERT
-- en TipoParque, Ubicacion y Parque.
-- Parametro: @vRutaArchivo = ruta completa al CSV en el servidor
-- ============================================================
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
    -- Nota: no actualizamos lat/lon para preservar coordenadas precisas si ya existen

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

-- ============================================================
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
-- ============================================================
PRINT 'SP parques.sp_ImportarAreasProtegidas creado correctamente.';
GO
