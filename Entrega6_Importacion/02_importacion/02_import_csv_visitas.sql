-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Importacion de visitas nacionales desde CSV.
--   Fuente: visitas-residentes-y-no-residentes.csv
--   Origen: https://datos.yvera.gob.ar (Ministerio de Turismo y Deporte)
--   Formato: CSV UTF-8 con BOM, separador coma
--   Columnas: indice_tiempo, origen_visitantes, visitas, observaciones
--   Nota: indice_tiempo viene como YYYY-M-DD (ej. 2008-1-01). Se convierte
--         a DATE usando DATEFROMPARTS para garantizar el primer dia del mes.
--   Estrategia: BULK INSERT en staging.VisitasNacionales ->
--               SP sp_ImportarVisitasNacionales hace UPSERT en parques.EstadisticaVisitas
-- Prerequisito: Ejecutar 01_tablas_staging.sql
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: sp_ImportarVisitasNacionales
-- Carga el CSV de visitas nacionales en la tabla de staging y
-- luego ejecuta el upsert hacia la tabla final.
-- Parametro: @vRutaArchivo = ruta completa al CSV en el servidor
-- ============================================================
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

-- ============================================================
-- NOTA DE USO:
-- Ajustar la ruta al CSV segun el servidor SQL Server.
-- Ejemplo ejecucion:
--
-- EXEC parques.sp_ImportarVisitasNacionales
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\visitas-residentes-y-no-residentes.csv';
--
-- Si SQL Server esta en el mismo equipo, usar ruta local.
-- Si es remoto, el archivo debe estar accesible desde el servidor.
-- ============================================================
PRINT 'SP parques.sp_ImportarVisitasNacionales creado correctamente.';
GO
