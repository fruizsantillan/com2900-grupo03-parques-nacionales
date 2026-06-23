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
--   Estrategia: BULK INSERT en tabla temporal #VisitasNacionales ->
--               UPSERT en parques.EstadisticaVisitas
-- Prerequisito: Ejecutar 01_tablas_staging.sql
-- =============================================

USE ParquesNacionales;
GO

CREATE OR ALTER PROCEDURE parques.sp_ImportarVisitasNacionales
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql          NVARCHAR(MAX);
    DECLARE @vFilas        INT;
    DECLARE @vInsertadas   INT = 0;
    DECLARE @vActualizadas INT = 0;

    -- --------------------------------------------------------
    -- Paso 1: Tabla temporal de staging (se destruye al finalizar)
    -- --------------------------------------------------------
    CREATE TABLE #VisitasNacionales (
        indiceTiempo      VARCHAR(20)   NULL,
        origenVisitantes  VARCHAR(50)   NULL,
        visitas           VARCHAR(20)   NULL,
        observaciones     VARCHAR(500)  NULL
    );

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT del CSV en la tabla temporal
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT #VisitasNacionales
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

    SELECT @vFilas = COUNT(*) FROM #VisitasNacionales;
    PRINT 'Filas cargadas en staging temporal: ' + CAST(@vFilas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: Transformacion y UPSERT hacia tabla final
    -- --------------------------------------------------------
    CREATE TABLE #vMergeOutput (accion NVARCHAR(10));

    BEGIN TRANSACTION;
    BEGIN TRY
        MERGE parques.EstadisticaVisitas AS destino
        USING (
            SELECT
                DATEFROMPARTS(
                    CAST(PARSENAME(REPLACE(LTRIM(RTRIM(indiceTiempo)), '-', '.'), 3) AS INT),
                    CAST(PARSENAME(REPLACE(LTRIM(RTRIM(indiceTiempo)), '-', '.'), 2) AS INT),
                    1
                )                                              AS periodo,
                LOWER(LTRIM(RTRIM(origenVisitantes)))          AS origenVisitante,
                CAST(NULLIF(LTRIM(RTRIM(visitas)), '') AS INT) AS cantidadVisitas,
                NULLIF(LTRIM(RTRIM(observaciones)), '')        AS observaciones
            FROM #VisitasNacionales
            WHERE indiceTiempo    IS NOT NULL
              AND origenVisitantes IS NOT NULL
              AND visitas IS NOT NULL
              AND visitas != ''
        ) AS origen
        ON  destino.periodo         = origen.periodo
        AND destino.origenVisitante = origen.origenVisitante

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

        OUTPUT $action INTO #vMergeOutput (accion);

        SELECT
            @vInsertadas   = SUM(CASE WHEN accion = 'INSERT' THEN 1 ELSE 0 END),
            @vActualizadas = SUM(CASE WHEN accion = 'UPDATE' THEN 1 ELSE 0 END)
        FROM #vMergeOutput;

        DROP TABLE #vMergeOutput;
        COMMIT TRANSACTION;

        PRINT 'Importacion completada exitosamente.';
        PRINT 'Filas leidas del CSV:  ' + CAST(@vFilas AS VARCHAR);
        PRINT 'Filas insertadas:      ' + CAST(ISNULL(@vInsertadas,   0) AS VARCHAR);
        PRINT 'Filas actualizadas:    ' + CAST(ISNULL(@vActualizadas, 0) AS VARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#vMergeOutput') IS NOT NULL DROP TABLE #vMergeOutput;
        INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
        VALUES ('parques.sp_ImportarVisitasNacionales', @vRutaArchivo, ISNULL(@vFilas,0), 0, 0, 1);
        THROW;
    END CATCH;

    -- --------------------------------------------------------
    -- Paso 4: Log de importacion
    -- --------------------------------------------------------

    -- --------------------------------------------------------
    -- Paso 4: Seed de ventas.TipoVisitante
    -- Los origenes del CSV definen los tipos de visitante del sistema.
    -- --------------------------------------------------------
    DECLARE @vTipoDesc VARCHAR(100);
    DECLARE tv_seed CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT
            CASE LOWER(LTRIM(RTRIM(origenVisitantes)))
                WHEN 'residentes'    THEN 'Residente'
                WHEN 'no residentes' THEN 'No Residente'
            END
        FROM #VisitasNacionales
        WHERE LOWER(LTRIM(RTRIM(origenVisitantes))) IN ('residentes', 'no residentes');
    OPEN tv_seed;
    FETCH NEXT FROM tv_seed INTO @vTipoDesc;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante WHERE descripcion = @vTipoDesc)
        BEGIN
            BEGIN TRY
                EXEC ventas.TipoVisitante_Insertar @descripcion = @vTipoDesc;
                PRINT 'TipoVisitante creado: ' + @vTipoDesc;
            END TRY
            BEGIN CATCH
                PRINT 'Aviso TipoVisitante "' + @vTipoDesc + '": ' + ERROR_MESSAGE();
            END CATCH
        END
        FETCH NEXT FROM tv_seed INTO @vTipoDesc;
    END
    CLOSE tv_seed; DEALLOCATE tv_seed;

    INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
    VALUES ('parques.sp_ImportarVisitasNacionales', @vRutaArchivo, @vFilas,
            ISNULL(@vInsertadas,0), ISNULL(@vActualizadas,0), 0);
END
GO

-- ============================================================
-- NOTA DE USO:
-- EXEC parques.sp_ImportarVisitasNacionales
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\visitas-residentes-y-no-residentes.csv';
-- ============================================================
PRINT 'SP parques.sp_ImportarVisitasNacionales creado correctamente.';
GO
