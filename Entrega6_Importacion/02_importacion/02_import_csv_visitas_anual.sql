-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Importacion de distribucion anual de visitas desde CSV oficial de APN.
--   Fuente: aprn_i_visitas_porc_2024.csv
--   Origen: https://datos.gob.ar/dataset/ambiente-areas-protegidas-nacionales
--           Administracion de Parques Nacionales (APN)
--   Formato: CSV UTF-8, separador punto y coma (;), campos entre comillas dobles
--   Columnas: anio, residentes_en_porcentaje, no_residentes_en_porcentaje
--   Rango: 2008-2025 (18 registros anuales)
--   Estrategia: BULK INSERT en staging.VisitasPorcentajeAnual ->
--               SP sp_ImportarVisitasAnual hace UPSERT en parques.EstadisticaVisitasAnual
-- Prerequisito: Ejecutar 01_tablas_staging.sql
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: sp_ImportarVisitasAnual
-- Carga el CSV de porcentajes anuales en staging y hace UPSERT
-- en la tabla final parques.EstadisticaVisitasAnual.
-- Parametro: @vRutaArchivo = ruta completa al CSV en el servidor
-- ============================================================
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

-- ============================================================
-- NOTA DE USO:
-- EXEC parques.sp_ImportarVisitasAnual
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\aprn_i_visitas_porc_2024.csv';
--
-- Verificacion:
--   SELECT anio, residentesPorcentaje, noResidentesPorcentaje
--   FROM parques.EstadisticaVisitasAnual
--   ORDER BY anio;
-- ============================================================
PRINT 'SP parques.sp_ImportarVisitasAnual creado correctamente.';
GO
