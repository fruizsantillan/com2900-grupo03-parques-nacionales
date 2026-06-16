-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Importacion de areas protegidas desde la base de datos mundial WDPA.
--   Fuente: WDPA_WDOECM_Jun2026_Public_ARG_csv.csv
--   Origen: https://www.protectedplanet.net (UNEP-WCMC / IUCN)
--   Formato: CSV UTF-8 con BOM, separador coma, 34 columnas
--   Columnas usadas: NAME, DESIG, DESIG_TYPE, IUCN_CAT, GIS_AREA, STATUS_YR, MANG_AUTH
--   GIS_AREA esta en km2 (se convierte a hectareas multiplicando x100 para
--   mantener consistencia con el resto del sistema que usa hectareas).
--   Filtra: solo areas de jurisdiccion Nacional (DESIG_TYPE = 'National')
--   Estrategia: BULK INSERT en staging.AreasWDPA ->
--               UPSERT en parques.TipoParque y parques.Parque.
--               Si el parque ya existe (importado desde APN), actualiza
--               la superficie con el valor GIS mas preciso del WDPA.
--               Si no existe, lo inserta con ubicacion pendiente de asignar.
--
-- NOTA: El CSV tiene 34 columnas. BULK INSERT carga todas; el SP
--       solo procesa las relevantes para el sistema.
-- Prerequisito: Ejecutar 01_tablas_staging.sql y scripts de tablas de parques.
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: sp_ImportarAreasWDPA
-- ============================================================
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

-- ============================================================
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
-- ============================================================
PRINT 'SP parques.sp_ImportarAreasWDPA creado correctamente.';
GO
