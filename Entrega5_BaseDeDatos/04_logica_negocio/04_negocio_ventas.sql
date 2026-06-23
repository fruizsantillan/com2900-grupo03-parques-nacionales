-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Stored Procedures de logica de negocio - modulo Ventas y Precios.
--   SP 1: sp_RegistrarVentaEntrada
--         Registra una venta de entrada validando parque, tipo de visitante,
--         precio existente, ticket y linea de venta. Si el ticket no existe,
--         lo crea. Si existe, agrega la linea y recalcula el total.
--   SP 2: sp_ActualizarPrecioEntrada
--         Actualiza el precio de entrada para un parque y tipo de visitante,
--         modificando el valor y la fecha de actualizacion.
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: sp_RegistrarVentaEntrada
-- Logica de negocio: venta completa de entrada
-- Validaciones:
--   1. Parque debe existir
--   2. Tipo de visitante debe existir
--   3. Debe existir precio de entrada para ese parque y tipo de visitante
--   4. Cantidad debe ser mayor a cero
--   5. Punto de venta obligatorio
--   6. Numero de ticket obligatorio
--   7. Forma de pago obligatoria
-- ============================================================
CREATE OR ALTER PROCEDURE ventas.RegistrarVentaEntrada
    @idParque        INT,
    @idTipoVisitante INT,
    @cantidad        INT,
    @puntoDeVenta    INT,
    @nroTicket       INT,
    @formaPago       VARCHAR(50),
    @fechaHora       DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores         NVARCHAR(MAX) = '';
    DECLARE @vIdTicket        INT;
    DECLARE @vIdPrecioEntrada INT;
    DECLARE @vPrecioUnitario  DECIMAL(18,2);
    DECLARE @vSubtotal        DECIMAL(18,2);
    DECLARE @vDescripcion     VARCHAR(50);

    IF @fechaHora IS NULL
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

    -- Validacion 5: Numero de ticket obligatorio
    IF @nroTicket IS NULL
        SET @vErrores += '- El numero de ticket es obligatorio.' + CHAR(13);

    -- Validacion 6: Forma de pago obligatoria
    IF @formaPago IS NULL OR LTRIM(RTRIM(@formaPago)) = ''
        SET @vErrores += '- La forma de pago es obligatoria.' + CHAR(13);

    -- Obtener precio de entrada
    SELECT
        @vIdPrecioEntrada = idPrecio,
        @vPrecioUnitario  = valor
    FROM ventas.PrecioEntrada
    WHERE idParque = @idParque
      AND idTipoVisitante = @idTipoVisitante;

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

        SELECT @vIdTicket = idTicket
        FROM ventas.TicketVenta
        WHERE puntoDeVenta = @puntoDeVenta
          AND nroTicket = @nroTicket;

        IF @vIdTicket IS NULL
        BEGIN
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
-- SP: sp_ActualizarPrecioEntrada
-- Logica de negocio: actualizacion de precio de entrada
-- Validaciones:
--   1. Parque debe existir
--   2. Tipo de visitante debe existir
--   3. Debe existir precio para ese parque y tipo de visitante
--   4. Nuevo valor debe ser mayor o igual a cero
--   5. Fecha de actualizacion obligatoria
-- ============================================================
CREATE OR ALTER PROCEDURE ventas.ActualizarPrecioEntrada
    @idParque           INT,
    @idTipoVisitante    INT,
    @nuevoValor         DECIMAL(18,2),
    @fechaActualizacion DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores  NVARCHAR(MAX) = '';
    DECLARE @vIdPrecio INT;

    -- Validacion 1: Parque existe
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    -- Validacion 2: Tipo de visitante existe
    IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- El tipo de visitante indicado no existe.' + CHAR(13);

    -- Validacion 3: Nuevo valor valido
    IF @nuevoValor IS NULL OR @nuevoValor < 0
        SET @vErrores += '- El nuevo valor debe ser mayor o igual a cero.' + CHAR(13);

    -- Validacion 4: Fecha obligatoria
    IF @fechaActualizacion IS NULL
        SET @vErrores += '- La fecha de actualizacion es obligatoria.' + CHAR(13);

    -- Obtener precio existente
    SELECT @vIdPrecio = idPrecio
    FROM ventas.PrecioEntrada
    WHERE idParque = @idParque
      AND idTipoVisitante = @idTipoVisitante;

    -- Validacion 5: Precio existente
    IF @vIdPrecio IS NULL
        SET @vErrores += '- No existe un precio de entrada para ese parque y tipo de visitante.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY

        UPDATE ventas.PrecioEntrada
        SET valor = @nuevoValor,
            fechaActualizacion = @fechaActualizacion
        WHERE idPrecio = @vIdPrecio;

        COMMIT TRANSACTION;

        PRINT 'Precio de entrada actualizado correctamente. ID: ' + CAST(@vIdPrecio AS VARCHAR);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO