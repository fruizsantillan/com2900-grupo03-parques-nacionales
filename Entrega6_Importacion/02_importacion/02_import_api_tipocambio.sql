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
--   Estrategia: sp_OACreate (HTTP GET) -> OPENJSON -> UPSERT en parques.TipoCambio
--
--   REQUISITO PREVIO en SQL Server:
--     EXEC sp_configure 'Ole Automation Procedures', 1;
--     RECONFIGURE;
--
-- Prerequisito: Ejecutar 01_tablas_staging.sql
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: sp_ImportarTipoCambio
-- Consulta la API dolarapi.com para el tipo indicado y guarda
-- el valor en parques.TipoCambio con logica de Upsert.
-- Parametro: @vTipo = 'oficial' | 'blue' | 'tarjeta'
--            (default: 'oficial')
-- ============================================================
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

-- ============================================================
-- SP auxiliar: sp_ObtenerTipoCambioVigente
-- Retorna el tipo de cambio mas reciente para un tipo dado.
-- Uso: llamarlo desde otros SPs que necesiten convertir precios.
-- ============================================================
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

-- ============================================================
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
-- ============================================================
PRINT 'SPs parques.sp_ImportarTipoCambio y sp_ObtenerTipoCambioVigente creados correctamente.';
GO
