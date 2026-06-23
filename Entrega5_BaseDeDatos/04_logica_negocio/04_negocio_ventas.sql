-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Stored Procedures de logica de negocio - modulo Ventas y Precios.
--   SP 1: registrarVentaEntrada
--         Registra una venta de entrada validando parque, tipo de visitante,
--         precio existente y linea de venta. Si el ticket no existe,
--         lo crea. Si existe, agrega la linea y recalcula el total.
--   SP 2: actualizarPrecioEntrada
--         Actualiza/versiona el precio de entrada para un parque y tipo de visitante.
--         Si existe un precio vigente, lo cierra con fechaHasta = fecha actual.
--         Luego inserta un nuevo precio vigente con fechaActualizacion = fecha actual.
--         Si no existe precio vigente, crea directamente el nuevo precio.
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: registrarVentaEntrada
-- Logica de negocio: venta completa de entrada
-- Validaciones:
--   1. Parque debe existir
--   2. Tipo de visitante debe existir
--   3. Debe existir precio de entrada para ese parque y tipo de visitante
--   4. Cantidad debe ser mayor a cero
--   5. Punto de venta obligatorio
--   6. El numero de ticket se genera automaticamente por punto de venta
--   7. Forma de pago obligatoria
-- ============================================================
CREATE OR ALTER PROCEDURE ventas.registrarVentaEntrada
    @idParque        INT,
    @idTipoVisitante INT,
    @cantidad        INT,
    @puntoDeVenta    INT,
    @formaPago       VARCHAR(50),
    @nuevoTkt        BIT 
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores         NVARCHAR(MAX) = '';
    DECLARE @vIdTicket        INT;
    DECLARE @vIdPrecioEntrada INT;
    DECLARE @vPrecioUnitario  DECIMAL(18,2);
    DECLARE @vSubtotal        DECIMAL(18,2);
    DECLARE @vDescripcion     VARCHAR(50);
    DECLARE @fechaHora        DATETIME;
    DECLARE @nroTicket        INT;

   SET @fechaHora = GETDATE();

    -- Validacion 1: Parque existe
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    -- Validacion 2: Tipo de visitante existe
    IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- El tipo de visitante indicado no existe.' + CHAR(13);

    -- Validacion 3: Cantidad valida
    IF @cantidad IS NULL OR @cantidad <= 0
        SET @vErrores += '- La cantidad debe ser mayor a cero.' + CHAR(13);

    -- Validacion 4: Punto de venta obligatorio
    IF @puntoDeVenta IS NULL
        SET @vErrores += '- El punto de venta es obligatorio.' + CHAR(13);

    -- Validacion 5: Forma de pago obligatoria
    IF @formaPago IS NULL OR LTRIM(RTRIM(@formaPago)) = ''
        SET @vErrores += '- La forma de pago es obligatoria.' + CHAR(13);

    -- Obtener precio de entrada
    SELECT
        @vIdPrecioEntrada = idPrecio,
        @vPrecioUnitario  = valor
    FROM ventas.PrecioEntrada
    WHERE idParque = @idParque
      AND idTipoVisitante = @idTipoVisitante
      AND fechaHasta IS NULL;

    -- Validacion 7: Precio existente
    IF @vIdPrecioEntrada IS NULL
        SET @vErrores += '- No existe un precio de entrada para ese parque y tipo de visitante.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    SET @vSubtotal = @cantidad * @vPrecioUnitario;

    SELECT @vDescripcion = 'Entrada ' + descripcion
    FROM ventas.TipoVisitante
    WHERE idTipoVisitante = @idTipoVisitante;

    BEGIN TRANSACTION;
    BEGIN TRY

        IF @nuevoTkt = 0 OR @nuevoTkt IS NULL
        BEGIN
            SELECT TOP 1 @vIdTicket = idTicket
            FROM ventas.TicketVenta
            WHERE puntoDeVenta = @puntoDeVenta
            ORDER BY fechaHora DESC, idTicket DESC;
        END 

        IF @vIdTicket IS NULL
        BEGIN
            SELECT @nroTicket = ISNULL(MAX(nroTicket), 0) + 1
            FROM ventas.TicketVenta
            WHERE puntoDeVenta = @puntoDeVenta;

            INSERT INTO ventas.TicketVenta
                (fechaHora, total, puntoDeVenta, nroTicket, formaPago, idParque)
            VALUES
                (@fechaHora, 0, @puntoDeVenta, @nroTicket, LTRIM(RTRIM(@formaPago)), @idParque);

            SET @vIdTicket = SCOPE_IDENTITY();
        END

        INSERT INTO ventas.LineaVenta
            (ticketAsociado, descripcion, subtotal, cantidad, precioUnitario,
             idPrecioEntrada, idTour, idAtraccion)
        VALUES
            (@vIdTicket, @vDescripcion, @vSubtotal, @cantidad, @vPrecioUnitario,
             @vIdPrecioEntrada, NULL, NULL);

        UPDATE ventas.TicketVenta
        SET total = (
            SELECT SUM(subtotal)
            FROM ventas.LineaVenta
            WHERE ticketAsociado = @vIdTicket
        )
        WHERE idTicket = @vIdTicket;

        COMMIT TRANSACTION;

        PRINT 'Venta de entrada registrada correctamente. Ticket ID: ' + CAST(@vIdTicket AS VARCHAR);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

-- ============================================================
-- SP: actualizarPrecioEntrada
-- Logica de negocio: actualizacion (versionado) de precio de entrada
-- Validaciones:
--   1. Parque debe existir
--   2. Tipo de visitante debe existir
--   3. Nuevo valor debe ser mayor o igual a cero
-- Decisiones de negocio:
--   - Si existe un precio vigente se cierra e inserta uno nuevo
--   - Si no existe precio previo se crea directamente
-- ============================================================
CREATE OR ALTER PROCEDURE ventas.actualizarPrecioEntrada
    @idParque        INT,
    @idTipoVisitante INT,
    @nuevoValor      DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores NVARCHAR(MAX) = '';
    DECLARE @vIdPrecioVigente INT;
    DECLARE @vFechaHoy DATE = CAST(GETDATE() AS DATE);

    -- Validacion 1: Parque existe
    IF NOT EXISTS (
        SELECT 1
        FROM parques.Parque
        WHERE idParque = @idParque
    )
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    -- Validacion 2: Tipo de visitante existe
    IF NOT EXISTS (
        SELECT 1
        FROM ventas.TipoVisitante
        WHERE idTipoVisitante = @idTipoVisitante
    )
        SET @vErrores += '- El tipo de visitante indicado no existe.' + CHAR(13);

    -- Validacion 3: Nuevo valor valido
    IF @nuevoValor IS NULL OR @nuevoValor < 0
        SET @vErrores += '- El nuevo valor debe ser mayor o igual a cero.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    -- Buscar precio vigente (fechaHasta IS NULL)
    SELECT @vIdPrecioVigente = idPrecio
    FROM ventas.PrecioEntrada
    WHERE idParque = @idParque
      AND idTipoVisitante = @idTipoVisitante
      AND fechaHasta IS NULL;

    BEGIN TRANSACTION;
    BEGIN TRY

        IF @vIdPrecioVigente IS NOT NULL
        BEGIN
            -- Existe precio vigente: se cierra
            UPDATE ventas.PrecioEntrada
            SET fechaHasta = @vFechaHoy
            WHERE idPrecio = @vIdPrecioVigente;
        END

        -- Se crea nuevo precio vigente
        INSERT INTO ventas.PrecioEntrada
            (fechaActualizacion, valor, idParque, idTipoVisitante, fechaHasta)
        VALUES
            (@vFechaHoy, @nuevoValor, @idParque, @idTipoVisitante, NULL);

        COMMIT TRANSACTION;

PRINT 'Precio de entrada registrado correctamente. Nuevo precio ID: '
            + CAST(SCOPE_IDENTITY() AS VARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO