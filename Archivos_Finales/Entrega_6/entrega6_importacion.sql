-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Script de importacion Entrega 6 - solo SPs (sin tablas).
--   Ejecutar despues de entrega6_unificado.sql o despues de que las tablas ya existan.
-- =============================================

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

CREATE OR ALTER PROCEDURE parques.ImportarVisitasNacionales
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
        indiceTiempo      NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,
        origenVisitantes  NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,
        visitas           NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,
        observaciones     NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT del CSV en la tabla temporal
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT #VisitasNacionales
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FIELDTERMINATOR  = '','',
            FIELDQUOTE      = ''"'',
            ROWTERMINATOR   = ''' + CHAR(10) + N''',
            FIRSTROW         = 2,
            KEEPNULLS,
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
            destino.cantidadVisitas <> origen.cantidadVisitas
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
        VALUES ('parques.ImportarVisitasNacionales', @vRutaArchivo, ISNULL(@vFilas,0), 0, 0, 1);
        THROW;
    END CATCH;

    -- --------------------------------------------------------
    -- Paso 4: Log de importacion
    -- --------------------------------------------------------
    INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
    VALUES ('parques.ImportarVisitasNacionales', @vRutaArchivo, @vFilas,
            ISNULL(@vInsertadas,0), ISNULL(@vActualizadas,0), 0);
END
GO

-- ============================================================
-- NOTA DE USO:
-- EXEC parques.ImportarVisitasNacionales
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\visitas-residentes-y-no-residentes.csv';
-- ============================================================
PRINT 'SP parques.ImportarVisitasNacionales creado correctamente.';
GO

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
--   Estrategia: BULK INSERT en tabla temporal #VisitasPorRegion ->
--               UPSERT en parques.EstadisticaVisitasPorRegion
-- Prerequisito: Ejecutar 01_tablas_staging.sql
-- =============================================

USE ParquesNacionales;
GO

CREATE OR ALTER PROCEDURE parques.ImportarVisitasPorRegion
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql          NVARCHAR(MAX);
    DECLARE @vFilas        INT;
    DECLARE @vInsertadas   INT = 0;
    DECLARE @vActualizadas INT = 0;

    -- --------------------------------------------------------
    -- Paso 1: Tabla temporal de staging
    -- --------------------------------------------------------
    CREATE TABLE #VisitasPorRegion (
        indiceTiempo      NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,
        regionDestino     NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,
        origenVisitantes  NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,
        visitas           NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,
        observaciones     NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT #VisitasPorRegion
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FIELDTERMINATOR  = '','',
            FIELDQUOTE      = ''"'',
            ROWTERMINATOR   = ''' + CHAR(10) + N''',
            FIRSTROW         = 2,
            KEEPNULLS,
            TABLOCK
        );
    ';
    EXEC sp_executesql @vSql;

    SELECT @vFilas = COUNT(*) FROM #VisitasPorRegion;
    PRINT 'Filas cargadas en staging temporal: ' + CAST(@vFilas AS VARCHAR);

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
            FROM #VisitasPorRegion
            WHERE indiceTiempo     IS NOT NULL
              AND regionDestino    IS NOT NULL
              AND origenVisitantes IS NOT NULL
              AND visitas IS NOT NULL
              AND visitas != ''
        ) AS origen
        ON  destino.periodo         = origen.periodo
        AND destino.region          = origen.region
        AND destino.origenVisitante = origen.origenVisitante
                
        WHEN MATCHED AND (
            destino.cantidadVisitas <> origen.cantidadVisitas
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
        PRINT 'Filas leidas del CSV:  ' + CAST(@vFilas AS VARCHAR);
        PRINT 'Filas insertadas:      ' + CAST(ISNULL(@vInsertadas,   0) AS VARCHAR);
        PRINT 'Filas actualizadas:    ' + CAST(ISNULL(@vActualizadas, 0) AS VARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#vMergeOutput') IS NOT NULL DROP TABLE #vMergeOutput;
        INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
        VALUES ('parques.ImportarVisitasPorRegion', @vRutaArchivo, ISNULL(@vFilas,0), 0, 0, 1);
        THROW;
    END CATCH;

    INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
    VALUES ('parques.ImportarVisitasPorRegion', @vRutaArchivo, @vFilas,
            ISNULL(@vInsertadas,0), ISNULL(@vActualizadas,0), 0);
END
GO

-- ============================================================
-- NOTA DE USO:
-- EXEC parques.ImportarVisitasPorRegion
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\visitas-residentes-y-no-residentes-por-region.csv';
-- ============================================================
PRINT 'SP parques.ImportarVisitasPorRegion creado correctamente.';
GO

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Importacion de distribucion anual de visitas desde CSV oficial de APN.
--   Fuente: aprn_i_visitas_porc_2024.csv
--   Origen: https://datos.gob.ar/dataset/ambiente-areas-protegidas-nacionales (APN)
--   Formato: CSV UTF-8, separador punto y coma (;), campos entre comillas dobles
--   Columnas: anio, residentes_en_porcentaje, no_residentes_en_porcentaje
--   Estrategia: BULK INSERT en tabla temporal #VisitasPorcentajeAnual ->
--               UPSERT en parques.EstadisticaVisitasAnual
-- Prerequisito: Ejecutar 01_tablas_staging.sql
-- =============================================

USE ParquesNacionales;
GO

CREATE OR ALTER PROCEDURE parques.ImportarVisitasAnual
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql          NVARCHAR(MAX);
    DECLARE @vFilas        INT;
    DECLARE @vInsertadas   INT = 0;
    DECLARE @vActualizadas INT = 0;

    -- --------------------------------------------------------
    -- Paso 1: Tabla temporal de staging
    -- --------------------------------------------------------
    CREATE TABLE #VisitasPorcentajeAnual (
        anio                    NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,
        residentesPorcentaje    NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,
        noResidentesPorcentaje  NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT (separador ;, campos entre comillas)
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT #VisitasPorcentajeAnual
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FIELDTERMINATOR  = '';'',
            FIELDQUOTE      = ''"'',
            ROWTERMINATOR   = ''' + CHAR(10) + N''',
            FIRSTROW         = 2,
            KEEPNULLS,
            TABLOCK
        );
    ';
    EXEC sp_executesql @vSql;

    SELECT @vFilas = COUNT(*) FROM #VisitasPorcentajeAnual;
    PRINT 'Filas cargadas en staging temporal: ' + CAST(@vFilas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: UPSERT hacia tabla final
    -- --------------------------------------------------------
    CREATE TABLE #vMergeOutput (accion NVARCHAR(10));

    BEGIN TRANSACTION;
    BEGIN TRY
        MERGE parques.EstadisticaVisitasAnual AS destino
        USING (
            SELECT
                CAST(LTRIM(RTRIM(REPLACE(REPLACE(anio, '"', ''), CHAR(13), ''))) AS INT) AS anio,
                CAST(REPLACE(REPLACE(LTRIM(RTRIM(residentesPorcentaje)), '"', ''), ',', '.')   AS DECIMAL(5,2)) AS residentesPorcentaje,
                CAST(REPLACE(REPLACE(LTRIM(RTRIM(noResidentesPorcentaje)), '"', ''), ',', '.') AS DECIMAL(5,2)) AS noResidentesPorcentaje
            FROM #VisitasPorcentajeAnual
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
        PRINT 'Filas leidas del CSV:    ' + CAST(@vFilas AS VARCHAR);
        PRINT 'Registros insertados:    ' + CAST(ISNULL(@vInsertadas,   0) AS VARCHAR);
        PRINT 'Registros actualizados:  ' + CAST(ISNULL(@vActualizadas, 0) AS VARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#vMergeOutput') IS NOT NULL DROP TABLE #vMergeOutput;
        INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
        VALUES ('parques.ImportarVisitasAnual', @vRutaArchivo, ISNULL(@vFilas,0), 0, 0, 1);
        THROW;
    END CATCH;

    INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
    VALUES ('parques.ImportarVisitasAnual', @vRutaArchivo, @vFilas,
            ISNULL(@vInsertadas,0), ISNULL(@vActualizadas,0), 0);
END
GO

-- ============================================================
-- NOTA DE USO:
-- EXEC parques.ImportarVisitasAnual
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\aprn_i_visitas_porc_2024.csv';
-- ============================================================
PRINT 'SP parques.ImportarVisitasAnual creado correctamente.';
GO

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Importacion de feriados nacionales desde API REST (formato JSON).
--   Fuente: https://argentinadatos.com/v1/feriados/{anio}
--   Formato: JSON - segundo formato de datos del modulo de importacion
--   Respuesta JSON (array): [{"fecha":"YYYY-MM-DD","tipo":"...","nombre":"..."}]
--   Tipos conocidos: inamovible, trasladable, puente, nolaborable
--   Estrategia: OACreate (OLE Automation) para HTTP GET ->
--               OPENJSON -> tabla temporal #Feriados -> UPSERT en parques.Feriado
--
--   REQUISITO PREVIO en SQL Server:
--     EXEC configure 'Ole Automation Procedures', 1;
--     RECONFIGURE;
--   (requiere permisos de sysadmin)
--
-- Prerequisito: Ejecutar 01_tablas_staging.sql
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: ImportarFeriados
-- Llama a la API de ArgentinaDatos para un año dado,
-- parsea el JSON recibido y hace UPSERT en parques.Feriado.
-- Parametro: @vAnio = año a importar (ej. 2025)
-- ============================================================
CREATE OR ALTER PROCEDURE parques.ImportarFeriados
    @vAnio INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @vAnio < 2000 OR @vAnio > 2100
    BEGIN
        RAISERROR('- El anio indicado no es valido. Debe estar entre 2000 y 2100.', 16, 1);
        RETURN;
    END

    DECLARE @vUrl NVARCHAR(200) = 'https://argentinadatos.com/v1/feriados/' + CAST(@vAnio AS VARCHAR(4));
    DECLARE @vObjHttp INT, @vHrResult INT;
    DECLARE @vRespuesta VARCHAR(8000); -- <--- LA MAGIA: NO usar MAX
    DECLARE @vFilas INT = 0, @vInsertadas INT = 0, @vActualizadas INT = 0;

    CREATE TABLE #Feriados (fecha NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, tipo NVARCHAR(MAX) COLLATE DATABASE_DEFAULT, nombre NVARCHAR(MAX) COLLATE DATABASE_DEFAULT);
    
    EXEC @vHrResult = sp_OACreate 'WinHttp.WinHttpRequest.5.1', @vObjHttp OUT;
    IF @vHrResult = 0 EXEC @vHrResult = sp_OAMethod @vObjHttp, 'open', NULL, 'GET', @vUrl, false;
    IF @vHrResult = 0 EXEC sp_OASetProperty @vObjHttp, 'Option', 2048, 9; -- FORZAR TLS 1.2
    IF @vHrResult = 0 EXEC @vHrResult = sp_OAMethod @vObjHttp, 'send';
    IF @vHrResult = 0 EXEC sp_OAGetProperty @vObjHttp, 'responseText', @vRespuesta OUT;
    EXEC sp_OADestroy @vObjHttp;

    IF @vRespuesta IS NULL OR LEN(@vRespuesta) < 10
    BEGIN
        PRINT 'AVISO: API inalcanzable. Usando datos de respaldo (Mock).';
        INSERT INTO #Feriados (fecha, tipo, nombre) VALUES 
        (CAST(@vAnio AS VARCHAR)+'-01-01', 'inamovible', 'Año Nuevo'),
        (CAST(@vAnio AS VARCHAR)+'-05-01', 'inamovible', 'Día del Trabajador');
    END
    ELSE
    BEGIN
        PRINT '>> API OK: Feriados obtenidos en vivo desde la red.';
        INSERT INTO #Feriados (fecha, tipo, nombre)
        SELECT JSON_VALUE(value, '$.fecha'), JSON_VALUE(value, '$.tipo'), JSON_VALUE(value, '$.nombre') FROM OPENJSON(@vRespuesta);
    END

    SELECT @vFilas = COUNT(*) FROM #Feriados;
    
    MERGE parques.Feriado AS destino
    USING (SELECT CAST(fecha AS DATE) AS fecha, LTRIM(RTRIM(tipo)) AS tipo, LTRIM(RTRIM(nombre)) AS nombre FROM #Feriados) AS origen
    ON destino.fecha = origen.fecha
    WHEN MATCHED THEN UPDATE SET destino.tipo = origen.tipo, destino.nombre = origen.nombre
    WHEN NOT MATCHED THEN INSERT (fecha, tipo, nombre) VALUES (origen.fecha, origen.tipo, origen.nombre);

    PRINT 'Importacion de feriados completada.';
END
GO

-- ============================================================
-- NOTA DE USO:
-- Habilitar OLE Automation en SQL Server (una sola vez, requiere sysadmin):
--   EXEC configure 'Ole Automation Procedures', 1;
--   RECONFIGURE;
--
-- Importar feriados de un año:
--   EXEC parques.ImportarFeriados @vAnio = 2025;
--   EXEC parques.ImportarFeriados @vAnio = 2026;
--
-- Verificar resultado:
--   SELECT * FROM parques.Feriado ORDER BY fecha;
-- ============================================================
PRINT 'SP parques.ImportarFeriados creado correctamente.';
GO

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Importacion del tipo de cambio USD/ARS desde API REST (formato JSON).
--   Fuente: https://dolarapi.com (API publica argentina, sin autenticacion)
--   Endpoints disponibles:
--     /v1/dolares/oficial   -> dolar oficial Banco Nacion
--     /v1/dolares/blue      -> dolar blue (mercado informal)
--     /v1/dolares/tarjeta   -> dolar tarjeta (compras con tarjeta en el exterior)
--   Formato respuesta JSON: {"moneda":"USD","casa":"oficial","nombre":"Oficial",
--                             "compra":1100.50,"venta":1120.50,
--                             "fechaActualizacion":"2026-06-15T12:00:00.000Z"}
--   Uso en el sistema: calcular el valor de entradas en dolares (Entrega 7,
--   Reporte 2 - Ingresos en moneda extranjera).
--   Estrategia: OACreate (HTTP GET) -> OPENJSON -> UPSERT en parques.TipoCambio
--
--   REQUISITO PREVIO en SQL Server:
--     EXEC configure 'Ole Automation Procedures', 1;
--     RECONFIGURE;
--
-- Prerequisito: Ejecutar 01_tablas_staging.sql
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: ImportarTipoCambio
-- Consulta la API dolarapi.com para el tipo indicado y guarda
-- el valor en parques.TipoCambio con logica de Upsert.
-- Parametro: @vTipo = 'oficial' | 'blue' | 'tarjeta'
--            (default: 'oficial')
-- ============================================================
USE ParquesNacionales;
GO
CREATE OR ALTER PROCEDURE parques.ImportarTipoCambio
    @vTipo VARCHAR(20) = 'oficial'
AS
BEGIN
    SET NOCOUNT ON;
    IF @vTipo NOT IN ('oficial', 'blue', 'tarjeta', 'mayorista', 'bolsa', 'cripto')
    BEGIN
        RAISERROR('- Tipo de cambio invalido. Valores validos: oficial, blue, tarjeta, mayorista, bolsa, cripto.', 16, 1);
        RETURN;
    END

    DECLARE @vUrl NVARCHAR(200) = 'https://api.bluelytics.com.ar/v2/latest';
    DECLARE @vObjHttp INT, @vHrResult INT;
    DECLARE @vRespuesta VARCHAR(8000); -- <--- LA MAGIA: NO usar MAX
    DECLARE @vCompra DECIMAL(10,2), @vVenta DECIMAL(10,2);
    DECLARE @vFecha DATE = CAST(GETDATE() AS DATE);

    EXEC @vHrResult = sp_OACreate 'WinHttp.WinHttpRequest.5.1', @vObjHttp OUT;
    IF @vHrResult = 0 EXEC @vHrResult = sp_OAMethod @vObjHttp, 'open', NULL, 'GET', @vUrl, false;
    IF @vHrResult = 0 EXEC sp_OASetProperty @vObjHttp, 'Option', 2048, 9; -- FORZAR TLS 1.2
    IF @vHrResult = 0 EXEC @vHrResult = sp_OAMethod @vObjHttp, 'send';
    IF @vHrResult = 0 EXEC sp_OAGetProperty @vObjHttp, 'responseText', @vRespuesta OUT;
    EXEC sp_OADestroy @vObjHttp;

    IF @vRespuesta IS NULL OR LEN(@vRespuesta) < 10
    BEGIN
        PRINT 'AVISO: API de cotizaciones inalcanzable. Usando valores de respaldo (Mock).';
        IF @vTipo = 'blue' BEGIN SET @vCompra = 1445.00; SET @vVenta = 1495.00; END
        ELSE IF @vTipo = 'tarjeta' BEGIN SET @vCompra = 1445.00 * 1.6; SET @vVenta = 1495.00 * 1.6; END
        ELSE BEGIN SET @vCompra = 900.00; SET @vVenta = 950.00; END 
    END
    ELSE
    BEGIN
        PRINT '>> API OK: Datos obtenidos en vivo desde la red.';
        DECLARE @vNodo VARCHAR(20) = CASE WHEN @vTipo = 'blue' THEN 'blue' ELSE 'oficial' END;
        SELECT @vCompra = TRY_CAST(JSON_VALUE(@vRespuesta, '$.' + @vNodo + '.value_buy') AS DECIMAL(10,2)),
               @vVenta  = TRY_CAST(JSON_VALUE(@vRespuesta, '$.' + @vNodo + '.value_sell')  AS DECIMAL(10,2));
        IF @vTipo = 'tarjeta' BEGIN SET @vCompra = @vCompra * 1.60; SET @vVenta = @vVenta * 1.60; END
    END

    MERGE parques.TipoCambio AS destino
    USING (SELECT @vFecha AS fecha, @vTipo AS tipo, @vCompra AS compra, @vVenta AS venta) AS origen
    ON destino.fecha = origen.fecha AND destino.tipo COLLATE DATABASE_DEFAULT = origen.tipo COLLATE DATABASE_DEFAULT
    WHEN MATCHED THEN UPDATE SET destino.compra = origen.compra, destino.venta = origen.venta
    WHEN NOT MATCHED THEN INSERT (fecha, tipo, compra, venta) VALUES (origen.fecha, origen.tipo, origen.compra, origen.venta);

    PRINT 'Tipo de cambio (' + @vTipo + ') procesado -> Compra: $' + CAST(@vCompra AS VARCHAR);
END
GO

-- ============================================================
-- SP auxiliar: ObtenerTipoCambioVigente
-- Retorna el tipo de cambio mas reciente para un tipo dado.
-- Uso: llamarlo desde otros SPs que necesiten convertir precios.
-- ============================================================
CREATE OR ALTER PROCEDURE parques.ObtenerTipoCambioVigente
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
        RAISERROR('- No hay tipo de cambio registrado para el tipo indicado. Ejecute ImportarTipoCambio primero.', 16, 1);
        RETURN;
    END
END
GO

-- ============================================================
-- NOTA DE USO:
-- Habilitar OLE Automation (una sola vez, requiere sysadmin):
--   EXEC configure 'Ole Automation Procedures', 1;
--   RECONFIGURE;
--
-- Importar tipo de cambio actual:
--   EXEC parques.ImportarTipoCambio @vTipo = 'oficial';
--   EXEC parques.ImportarTipoCambio @vTipo = 'blue';
--   EXEC parques.ImportarTipoCambio @vTipo = 'tarjeta';
--
-- Consultar historial:
--   SELECT * FROM parques.TipoCambio ORDER BY fecha DESC, tipo;
--
-- Usar en otro SP para convertir un precio en pesos a dolares:
--   DECLARE @vVenta DECIMAL(10,2), @vCompra DECIMAL(10,2);
--   EXEC parques.ObtenerTipoCambioVigente
--       @vTipo = 'oficial', @vVenta = @vVenta OUTPUT, @vCompra = @vCompra OUTPUT;
--   SELECT @vPrecioARS / @vVenta AS precioUSD;
-- ============================================================
PRINT 'SPs parques.ImportarTipoCambio y ObtenerTipoCambioVigente creados correctamente.';
GO

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
--   Columnas usadas: NAME, DESIG, DESIG_TYPE, GIS_AREA
--   GIS_AREA en km2 -> se convierte a hectareas (* 100).
--   Filtra: solo DESIG_TYPE = 'National'
--   Estrategia: BULK INSERT en tabla temporal #AreasWDPA ->
--               CURSOR -> parques.TipoParque_Insertar (si el tipo no existe) ->
--               CURSOR -> parques.RegistrarParque (nuevo) o parques.Parque_Actualizar (existente)
--
-- NOTA: La tabla temporal tiene todas las columnas del CSV WDPA para que
--       BULK INSERT las pueda cargar sin FORMAT FILE. Solo se usan las relevantes.
-- Prerequisito: Ejecutar 01_tablas_staging.sql y scripts de tablas de parques (E5).
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: ImportarAreasWDPA
-- ============================================================
CREATE OR ALTER PROCEDURE parques.ImportarAreasWDPA
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql              NVARCHAR(MAX);
    DECLARE @vTotalStaging     INT = 0;
    DECLARE @vProcesadas       INT = 0;
    DECLARE @vDescartadas      INT = 0;
    DECLARE @vInsertadas       INT = 0;
    DECLARE @vActualizadas     INT = 0;

    -- Cursor variables
    DECLARE @vNombre           VARCHAR(200);
    DECLARE @vDesig            VARCHAR(200);
    DECLARE @vDesigType        VARCHAR(50);
    DECLARE @vGisArea          VARCHAR(30);
    DECLARE @vDescripcionTipo  VARCHAR(200);
    DECLARE @vSuperficieHa     DECIMAL(18,2);
    DECLARE @vIdTipoParque     INT;
    DECLARE @vIdParque         INT;
    DECLARE @vIdUbicacion      INT;

    -- --------------------------------------------------------
    -- Paso 1: Tabla temporal de staging (34 columnas del CSV WDPA)
    -- Orden segun el CSV estandar WDPA Public v7
    -- --------------------------------------------------------
    CREATE TABLE #AreasWDPA (
        wdpaId          NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 1  WDPAID
        wdpaPid         NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 2  WDPA_PID
        paDef           NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 3  PA_DEF
        name            NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 4  NAME
        origName        NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 5  ORIG_NAME
        desig           NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 6  DESIG
        desigEng        NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 7  DESIG_ENG
        desigType       NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 8  DESIG_TYPE
        iucnCat         NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 9  IUCN_CAT
        intCrit         NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 10 INT_CRIT
        marine          NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 11 MARINE
        repMArea        NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 12 REP_M_AREA
        gisMArea        NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 13 GIS_M_AREA
        repArea         NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 14 REP_AREA
        gisArea         NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 15 GIS_AREA
        noTake          NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 16 NO_TAKE
        noTkArea        NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 17 NO_TK_AREA
        status          NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 18 STATUS
        statusYr        NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 19 STATUS_YR
        govType         NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 20 GOV_TYPE
        ownType         NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 21 OWN_TYPE
        mangAuth        NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 22 MANG_AUTH
        mangPlan        NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 23 MANG_PLAN
        verif           NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 24 VERIF
        metadataId      NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 25 METADATAID
        subLoc          NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 26 SUB_LOC
        parentIso3      NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 27 PARENT_ISO3
        iso3            NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 28 ISO3
        suppInfo        NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 29 SUPP_INFO
        consObj         NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 30 CONS_OBJ
        mangPlanRef     NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL,  -- 31 MANG_PLAN_REF
        impId           NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 32 IMP_ID
        impDate         NVARCHAR(MAX)   COLLATE DATABASE_DEFAULT NULL,  -- 33 IMP_DATE
        col34           NVARCHAR(MAX)  COLLATE DATABASE_DEFAULT NULL   -- 34 (additional field if present)
    );

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT #AreasWDPA
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FIELDTERMINATOR = '','',
            FIELDQUOTE      = ''"'',
            ROWTERMINATOR   = ''' + CHAR(10) + N''',
            FIRSTROW        = 2,
            KEEPNULLS,
            TABLOCK
        );
    ';
    EXEC sp_executesql @vSql;

    SELECT @vTotalStaging = COUNT(*) FROM #AreasWDPA;
    PRINT 'Filas cargadas en staging temporal: ' + CAST(@vTotalStaging AS VARCHAR);

    SELECT @vDescartadas = COUNT(*)
    FROM #AreasWDPA
    WHERE LTRIM(RTRIM(desigType)) != 'National'
       OR name IS NULL
       OR LTRIM(RTRIM(name)) = '';

    SET @vProcesadas = @vTotalStaging - @vDescartadas;
    PRINT 'A procesar (jurisdiccion Nacional): ' + CAST(@vProcesadas AS VARCHAR);
    PRINT 'Descartadas (no nacionales/sin nombre): ' + CAST(@vDescartadas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: Insertar TipoParque (si no existe) via SP de E5
    -- --------------------------------------------------------
    DECLARE tipo_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT LTRIM(RTRIM(desig))
        FROM #AreasWDPA
        WHERE LTRIM(RTRIM(desigType)) = 'National'
          AND desig IS NOT NULL
          AND LTRIM(RTRIM(desig)) != '';

    OPEN tipo_cursor;
    FETCH NEXT FROM tipo_cursor INTO @vDescripcionTipo;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM parques.TipoParque WHERE descripcion = @vDescripcionTipo)
        BEGIN
            BEGIN TRY
                EXEC parques.TipoParque_Insertar @descripcion = @vDescripcionTipo;
            END TRY
            BEGIN CATCH
                PRINT 'Aviso: no se pudo insertar TipoParque "' + @vDescripcionTipo + '": ' + ERROR_MESSAGE();
            END CATCH
        END
        FETCH NEXT FROM tipo_cursor INTO @vDescripcionTipo;
    END
    CLOSE tipo_cursor;
    DEALLOCATE tipo_cursor;
    PRINT 'TipoParque actualizado con tipos WDPA.';

    -- --------------------------------------------------------
    -- Paso 4: Insertar / actualizar Parques via SPs de E5
    -- WDPA puede tener duplicados (Polygon + Point del mismo area).
    -- El cursor usa MAX(gisArea) por nombre para tomar la mayor superficie.
    -- Si el parque no existe: llama parques.RegistrarParque (con ubicacion generica).
    -- Si ya existe: llama parques.Parque_Actualizar para actualizar superficie.
    -- --------------------------------------------------------

    -- Crear ubicacion generica si no existe
    IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion WHERE direccion = 'Argentina - Pendiente de asignacion')
    BEGIN
        INSERT INTO parques.Ubicacion (direccion, provincia, latitud, longitud)
        VALUES ('Argentina - Pendiente de asignacion', 'Sin definir', -38.00, -65.00);
    END

    DECLARE wdpa_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            LTRIM(RTRIM(s.name)),
            LTRIM(RTRIM(s.desig)),
            MAX(TRY_CAST(REPLACE(LTRIM(RTRIM(s.gisArea)), ',', '.') AS DECIMAL(18,2))) * 100
        FROM #AreasWDPA s
        WHERE LTRIM(RTRIM(s.desigType)) = 'National'
          AND s.name IS NOT NULL
          AND LTRIM(RTRIM(s.name)) != ''
          AND TRY_CAST(REPLACE(LTRIM(RTRIM(s.gisArea)), ',', '.') AS DECIMAL(18,2)) IS NOT NULL
        GROUP BY LTRIM(RTRIM(s.name)), LTRIM(RTRIM(s.desig));

    OPEN wdpa_cursor;
    FETCH NEXT FROM wdpa_cursor INTO @vNombre, @vDescripcionTipo, @vSuperficieHa;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @vIdTipoParque = idTipoParque
        FROM parques.TipoParque
        WHERE descripcion = @vDescripcionTipo;

        IF @vIdTipoParque IS NOT NULL AND @vSuperficieHa IS NOT NULL AND @vSuperficieHa > 0
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE nombre = @vNombre)
            BEGIN
                BEGIN TRY
                    EXEC parques.RegistrarParque
                        @nombre       = @vNombre,
                        @superficie   = @vSuperficieHa,
                        @idTipoParque = @vIdTipoParque,
                        @direccion    = 'Argentina - Pendiente de asignacion',
                        @provincia    = 'Sin definir',
                        @latitud      = -38.00,
                        @longitud     = -65.00;
                    SET @vInsertadas += 1;
                END TRY
                BEGIN CATCH
                    PRINT 'Error al insertar parque WDPA "' + @vNombre + '": ' + ERROR_MESSAGE();
                END CATCH
            END
            ELSE
            BEGIN
                SELECT @vIdParque    = idParque,
                       @vIdUbicacion = idUbicacion,
                       @vIdTipoParque = idTipoParque
                FROM parques.Parque
                WHERE nombre = @vNombre;

                BEGIN TRY
                    EXEC parques.Parque_Actualizar
                        @idParque     = @vIdParque,
                        @nombre       = @vNombre,
                        @superficie   = @vSuperficieHa,
                        @idTipoParque = @vIdTipoParque,
                        @idUbicacion  = @vIdUbicacion;
                    SET @vActualizadas += 1;
                END TRY
                BEGIN CATCH
                    PRINT 'Error al actualizar parque WDPA "' + @vNombre + '": ' + ERROR_MESSAGE();
                END CATCH
            END
        END

        FETCH NEXT FROM wdpa_cursor INTO @vNombre, @vDescripcionTipo, @vSuperficieHa;
    END
    CLOSE wdpa_cursor;
    DEALLOCATE wdpa_cursor;

    PRINT '----------------------------------------------';
    PRINT 'Importacion WDPA completada exitosamente.';
    PRINT 'Total filas en CSV:          ' + CAST(@vTotalStaging AS VARCHAR);
    PRINT 'Procesadas (nacionales):     ' + CAST(@vProcesadas   AS VARCHAR);
    PRINT 'Descartadas:                 ' + CAST(@vDescartadas  AS VARCHAR);
    PRINT 'Parques insertados:          ' + CAST(@vInsertadas   AS VARCHAR);
    PRINT 'Parques actualizados:        ' + CAST(@vActualizadas AS VARCHAR);
    PRINT '----------------------------------------------';

    INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
    VALUES ('parques.ImportarAreasWDPA', @vRutaArchivo, @vTotalStaging,
            @vInsertadas, @vActualizadas, 0);
END
GO

-- ============================================================
-- NOTA DE USO:
-- EXEC parques.ImportarAreasWDPA
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\WDPA_WDOECM_Jun2026_Public_ARG_csv.csv';
--
-- Verificacion post-importacion:
--   SELECT p.nombre, tp.descripcion AS tipo, p.superficie, u.provincia
--   FROM parques.Parque p
--   JOIN parques.TipoParque tp ON tp.idTipoParque = p.idTipoParque
--   JOIN parques.Ubicacion  u  ON u.idUbicacion   = p.idUbicacion
--   ORDER BY tp.descripcion, p.nombre;
-- ============================================================
PRINT 'SP parques.ImportarAreasWDPA creado correctamente.';
GO

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
--   Estrategia: BULK INSERT en tabla temporal #AreasProtegidas ->
--               CURSOR -> parques.TipoParque_Insertar (si el tipo no existe) ->
--               CURSOR -> parques.RegistrarParque (nuevo) o parques.Parque_Actualizar (existente)
--
--   NOTA sobre coordenadas: el CSV no incluye GPS. Se asignan coordenadas
--   aproximadas (centroide de cada region) como punto de inicio.
--
-- Prerequisito: Ejecutar 01_tablas_staging.sql y los scripts de tablas del modulo parques (E5).
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: ImportarAreasProtegidas
-- ============================================================
CREATE OR ALTER PROCEDURE parques.ImportarAreasProtegidas
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql              NVARCHAR(MAX);
    DECLARE @vFilas            INT = 0;
    DECLARE @vInsertadas       INT = 0;
    DECLARE @vActualizadas     INT = 0;

    -- Cursor variables
    DECLARE @vRegion           VARCHAR(100);
    DECLARE @vAreaProtegida    VARCHAR(200);
    DECLARE @vHectareas        VARCHAR(30);
    DECLARE @vDescripcionTipo  VARCHAR(100);
    DECLARE @vSuperficie       DECIMAL(18,2);
    DECLARE @vLat              DECIMAL(9,6);
    DECLARE @vLon              DECIMAL(9,6);
    DECLARE @vIdTipoParque     INT;
    DECLARE @vIdParque         INT;
    DECLARE @vIdUbicacion      INT;

    -- --------------------------------------------------------
    -- Paso 1: Tabla temporal de staging
    -- --------------------------------------------------------
    CREATE TABLE #AreasProtegidas (
        region                 VARCHAR(100)  COLLATE DATABASE_DEFAULT NULL,
        areaProtegida          VARCHAR(200)  COLLATE DATABASE_DEFAULT NULL,
        hectareas              VARCHAR(30)   COLLATE DATABASE_DEFAULT NULL,
        categoriaInternacional VARCHAR(100)  COLLATE DATABASE_DEFAULT NULL
    );

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT #AreasProtegidas
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FIELDTERMINATOR  = '';'',
            FIELDQUOTE      = ''"'',
            ROWTERMINATOR   = ''' + CHAR(10) + N''',
            FIRSTROW         = 2,
            KEEPNULLS,
            TABLOCK
        );
    ';
    EXEC sp_executesql @vSql;

    SELECT @vFilas = COUNT(*) FROM #AreasProtegidas;
    PRINT 'Filas cargadas en staging temporal: ' + CAST(@vFilas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: Insertar TipoParque (si no existe) via SP de E5
    -- --------------------------------------------------------
    DECLARE tipo_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT
            CASE
                WHEN areaProtegida LIKE 'Parque Nacional%'              THEN 'Parque Nacional'
                WHEN areaProtegida LIKE 'Parque Interjurisdiccional%'   THEN 'Parque Interjurisdiccional'
                WHEN areaProtegida LIKE 'Reserva Nacional%'             THEN 'Reserva Nacional'
                WHEN areaProtegida LIKE 'Reserva Natural%'              THEN 'Reserva Natural'
                WHEN areaProtegida LIKE 'Monumento Natural%'            THEN 'Monumento Natural'
                ELSE 'Otra Area Protegida'
            END
        FROM #AreasProtegidas
        WHERE areaProtegida IS NOT NULL;

    OPEN tipo_cursor;
    FETCH NEXT FROM tipo_cursor INTO @vDescripcionTipo;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM parques.TipoParque WHERE descripcion = @vDescripcionTipo)
        BEGIN
            BEGIN TRY
                EXEC parques.TipoParque_Insertar @descripcion = @vDescripcionTipo;
            END TRY
            BEGIN CATCH
                PRINT 'Aviso: no se pudo insertar TipoParque "' + @vDescripcionTipo + '": ' + ERROR_MESSAGE();
            END CATCH
        END
        FETCH NEXT FROM tipo_cursor INTO @vDescripcionTipo;
    END
    CLOSE tipo_cursor;
    DEALLOCATE tipo_cursor;
    PRINT 'TipoParque actualizado.';

    -- --------------------------------------------------------
    -- Paso 4: Insertar / actualizar Parques via SPs de E5
    -- Usa parques.RegistrarParque (nuevo) o parques.Parque_Actualizar (existente).
    -- Coordenadas aproximadas por region (centroide APN).
    -- --------------------------------------------------------
    DECLARE parque_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT region, areaProtegida, hectareas
        FROM #AreasProtegidas
        WHERE areaProtegida IS NOT NULL
          AND hectareas IS NOT NULL
          AND LTRIM(RTRIM(hectareas)) != '';

    OPEN parque_cursor;
    FETCH NEXT FROM parque_cursor INTO @vRegion, @vAreaProtegida, @vHectareas;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Calcular superficie
        SET @vSuperficie = TRY_CAST(
            REPLACE(LTRIM(RTRIM(@vHectareas)), '.', '')
            AS DECIMAL(18,2)
        );

        -- Derivar tipo del nombre
        SET @vDescripcionTipo = CASE
            WHEN @vAreaProtegida LIKE 'Parque Nacional%'              THEN 'Parque Nacional'
            WHEN @vAreaProtegida LIKE 'Parque Interjurisdiccional%'   THEN 'Parque Interjurisdiccional'
            WHEN @vAreaProtegida LIKE 'Reserva Nacional%'             THEN 'Reserva Nacional'
            WHEN @vAreaProtegida LIKE 'Reserva Natural%'              THEN 'Reserva Natural'
            WHEN @vAreaProtegida LIKE 'Monumento Natural%'            THEN 'Monumento Natural'
            ELSE 'Otra Area Protegida'
        END;

        SELECT @vIdTipoParque = idTipoParque
        FROM parques.TipoParque
        WHERE descripcion = @vDescripcionTipo;

        -- Coordenadas aproximadas por region APN
        SET @vLat = CASE LOWER(LTRIM(RTRIM(@vRegion)))
            WHEN 'centro'             THEN CAST(-31.00 AS DECIMAL(9,6))
            WHEN 'centro este'        THEN CAST(-32.00 AS DECIMAL(9,6))
            WHEN 'nea'                THEN CAST(-27.00 AS DECIMAL(9,6))
            WHEN 'noa'                THEN CAST(-24.00 AS DECIMAL(9,6))
            WHEN 'patagonia norte'    THEN CAST(-41.00 AS DECIMAL(9,6))
            WHEN 'patagonia austral'  THEN CAST(-50.00 AS DECIMAL(9,6))
            WHEN 'mar argentino'      THEN CAST(-50.00 AS DECIMAL(9,6))
            ELSE                           CAST(-35.00 AS DECIMAL(9,6))
        END;

        SET @vLon = CASE LOWER(LTRIM(RTRIM(@vRegion)))
            WHEN 'centro'             THEN CAST(-67.50 AS DECIMAL(9,6))
            WHEN 'centro este'        THEN CAST(-60.50 AS DECIMAL(9,6))
            WHEN 'nea'                THEN CAST(-57.00 AS DECIMAL(9,6))
            WHEN 'noa'                THEN CAST(-65.00 AS DECIMAL(9,6))
            WHEN 'patagonia norte'    THEN CAST(-71.00 AS DECIMAL(9,6))
            WHEN 'patagonia austral'  THEN CAST(-70.00 AS DECIMAL(9,6))
            WHEN 'mar argentino'      THEN CAST(-58.00 AS DECIMAL(9,6))
            ELSE                           CAST(-65.00 AS DECIMAL(9,6))
        END;

        IF @vSuperficie IS NOT NULL AND @vSuperficie > 0 AND @vIdTipoParque IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE nombre = @vAreaProtegida)
            BEGIN
                -- Parque nuevo: usar SP de negocio (crea Ubicacion + Parque)
                BEGIN TRY
                    EXEC parques.RegistrarParque
                        @nombre       = @vAreaProtegida,
                        @superficie   = @vSuperficie,
                        @idTipoParque = @vIdTipoParque,
                        @direccion    = @vAreaProtegida,
                        @provincia    = @vRegion,
                        @latitud      = @vLat,
                        @longitud     = @vLon;
                    SET @vInsertadas += 1;
                END TRY
                BEGIN CATCH
                    PRINT 'Error al insertar parque "' + @vAreaProtegida + '": ' + ERROR_MESSAGE();
                END CATCH
            END
            ELSE
            BEGIN
                -- Parque existente: actualizar solo superficie si cambio
                SELECT @vIdParque    = idParque,
                       @vIdUbicacion = idUbicacion,
                       @vIdTipoParque = idTipoParque
                FROM parques.Parque
                WHERE nombre = @vAreaProtegida;

                BEGIN TRY
                    EXEC parques.Parque_Actualizar
                        @idParque     = @vIdParque,
                        @nombre       = @vAreaProtegida,
                        @superficie   = @vSuperficie,
                        @idTipoParque = @vIdTipoParque,
                        @idUbicacion  = @vIdUbicacion;
                    SET @vActualizadas += 1;
                END TRY
                BEGIN CATCH
                    PRINT 'Error al actualizar parque "' + @vAreaProtegida + '": ' + ERROR_MESSAGE();
                END CATCH
            END
        END

        FETCH NEXT FROM parque_cursor INTO @vRegion, @vAreaProtegida, @vHectareas;
    END
    CLOSE parque_cursor;
    DEALLOCATE parque_cursor;

    PRINT 'Importacion de areas protegidas completada.';
    PRINT 'Filas CSV procesadas: '  + CAST(@vFilas         AS VARCHAR);
    PRINT 'Parques insertados:   '  + CAST(@vInsertadas    AS VARCHAR);
    PRINT 'Parques actualizados: '  + CAST(@vActualizadas  AS VARCHAR);

    INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
    VALUES ('parques.ImportarAreasProtegidas', @vRutaArchivo, @vFilas,
            @vInsertadas, @vActualizadas, 0);
END
GO

-- ============================================================
-- NOTA DE USO:
-- EXEC parques.ImportarAreasProtegidas
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\aprn_h_ubicacion_superycatint_ha.csv';
--
-- Verificacion:
--   SELECT p.nombre, tp.descripcion AS tipo, p.superficie, u.provincia
--   FROM parques.Parque p
--   JOIN parques.TipoParque tp ON tp.idTipoParque = p.idTipoParque
--   JOIN parques.Ubicacion  u  ON u.idUbicacion   = p.idUbicacion
--   ORDER BY tp.descripcion, p.nombre;
-- ============================================================
PRINT 'SP parques.ImportarAreasProtegidas creado correctamente.';
GO
