-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Importacion de visitas por region desde CSV.
--   Fuente: visitas-residentes-y-no-residentes-por-region.csv
--   Origen: https://datos.yvera.gob.ar (Ministerio de Turismo y Deporte)
--   Formato: CSV UTF-8 con BOM, separador coma
--   Columnas: indice_tiempo, region_de_destino, origen_visitantes, visitas, observaciones
--   Regiones: buenos aires, cordoba, cuyo, litoral, norte, patagonia
--   Nota: indice_tiempo viene como YYYY-M-DD (ej. 2008-1-01). Se convierte
--         a DATE usando DATEFROMPARTS para garantizar el primer dia del mes.
--   Estrategia: BULK INSERT en staging.VisitasPorRegion ->
--               SP sp_ImportarVisitasPorRegion hace UPSERT en parques.EstadisticaVisitasPorRegion
-- Prerequisito: Ejecutar 01_tablas_staging.sql
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: sp_ImportarVisitasPorRegion
-- Carga el CSV de visitas por region en staging y luego
-- hace el upsert hacia la tabla final.
-- Parametro: @vRutaArchivo = ruta completa al CSV en el servidor
-- ============================================================
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

-- ============================================================
-- NOTA DE USO:
-- EXEC parques.sp_ImportarVisitasPorRegion
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\visitas-residentes-y-no-residentes-por-region.csv';
-- ============================================================
PRINT 'SP parques.sp_ImportarVisitasPorRegion creado correctamente.';
GO
