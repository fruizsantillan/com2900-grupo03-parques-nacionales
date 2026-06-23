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
--   Estrategia: sp_OACreate (OLE Automation) para HTTP GET ->
--               OPENJSON -> tabla temporal #Feriados -> UPSERT en parques.Feriado
--
--   REQUISITO PREVIO en SQL Server:
--     EXEC sp_configure 'Ole Automation Procedures', 1;
--     RECONFIGURE;
--   (requiere permisos de sysadmin)
--
-- Prerequisito: Ejecutar 01_tablas_staging.sql
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: sp_ImportarFeriados
-- Llama a la API de ArgentinaDatos para un año dado,
-- parsea el JSON recibido y hace UPSERT en parques.Feriado.
-- Parametro: @vAnio = año a importar (ej. 2025)
-- ============================================================
CREATE OR ALTER PROCEDURE parques.sp_ImportarFeriados
    @vAnio INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @vAnio < 2000 OR @vAnio > 2100
    BEGIN
        RAISERROR('- El anio indicado no es valido. Debe estar entre 2000 y 2100.', 16, 1);
        RETURN;
    END

    DECLARE @vUrl          NVARCHAR(200);
    DECLARE @vObjHttp      INT;
    DECLARE @vHrResult     INT;
    DECLARE @vRespuesta    NVARCHAR(MAX);
    DECLARE @vFilas        INT = 0;
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
        INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
        VALUES ('parques.sp_ImportarFeriados', @vUrl, 0, 0, 0, 1);
        RAISERROR('- Error al crear objeto HTTP (sp_OACreate). Verificar que Ole Automation este habilitado.', 16, 1);
        RETURN;
    END

    EXEC @vHrResult = sp_OAMethod @vObjHttp, 'open', NULL, 'GET', @vUrl, false;
    IF @vHrResult <> 0
    BEGIN
        EXEC sp_OADestroy @vObjHttp;
        INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
        VALUES ('parques.sp_ImportarFeriados', @vUrl, 0, 0, 0, 1);
        RAISERROR('- Error al abrir conexion HTTP.', 16, 1);
        RETURN;
    END

    EXEC @vHrResult = sp_OAMethod @vObjHttp, 'setRequestHeader', NULL, 'Accept', 'application/json';
    EXEC @vHrResult = sp_OAMethod @vObjHttp, 'send';
    IF @vHrResult <> 0
    BEGIN
        EXEC sp_OADestroy @vObjHttp;
        INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
        VALUES ('parques.sp_ImportarFeriados', @vUrl, 0, 0, 0, 1);
        RAISERROR('- Error al enviar peticion HTTP.', 16, 1);
        RETURN;
    END

    EXEC @vHrResult = sp_OAGetProperty @vObjHttp, 'responseText', @vRespuesta OUT;
    EXEC sp_OADestroy @vObjHttp;

    IF @vRespuesta IS NULL OR LEN(@vRespuesta) < 5
    BEGIN
        INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
        VALUES ('parques.sp_ImportarFeriados', @vUrl, 0, 0, 0, 1);
        RAISERROR('- La API no devolvio datos. Verificar conectividad o el anio consultado.', 16, 1);
        RETURN;
    END

    PRINT 'Respuesta recibida (' + CAST(LEN(@vRespuesta) AS VARCHAR) + ' caracteres).';

    -- --------------------------------------------------------
    -- Paso 2: Parsear JSON en tabla temporal
    -- --------------------------------------------------------
    CREATE TABLE #Feriados (
        fecha  VARCHAR(20)   NULL,
        tipo   VARCHAR(50)   NULL,
        nombre VARCHAR(200)  NULL
    );

    INSERT INTO #Feriados (fecha, tipo, nombre)
    SELECT
        JSON_VALUE(value, '$.fecha'),
        JSON_VALUE(value, '$.tipo'),
        JSON_VALUE(value, '$.nombre')
    FROM OPENJSON(@vRespuesta);

    SELECT @vFilas = COUNT(*) FROM #Feriados;
    PRINT 'Feriados cargados en staging temporal: ' + CAST(@vFilas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: UPSERT hacia tabla final
    -- --------------------------------------------------------
    CREATE TABLE #vMergeOutput (accion NVARCHAR(10));

    BEGIN TRANSACTION;
    BEGIN TRY
        MERGE parques.Feriado AS destino
        USING (
            SELECT
                CAST(fecha AS DATE)   AS fecha,
                LTRIM(RTRIM(tipo))    AS tipo,
                LTRIM(RTRIM(nombre))  AS nombre
            FROM #Feriados
            WHERE fecha  IS NOT NULL
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
        PRINT 'Feriados insertados:    ' + CAST(ISNULL(@vInsertadas,   0) AS VARCHAR);
        PRINT 'Feriados actualizados:  ' + CAST(ISNULL(@vActualizadas, 0) AS VARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        IF OBJECT_ID('tempdb..#vMergeOutput') IS NOT NULL DROP TABLE #vMergeOutput;
        INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
        VALUES ('parques.sp_ImportarFeriados', @vUrl, ISNULL(@vFilas,0), 0, 0, 1);
        THROW;
    END CATCH;

    INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
    VALUES ('parques.sp_ImportarFeriados', @vUrl, @vFilas,
            ISNULL(@vInsertadas,0), ISNULL(@vActualizadas,0), 0);
END
GO

-- ============================================================
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
-- ============================================================
PRINT 'SP parques.sp_ImportarFeriados creado correctamente.';
GO
