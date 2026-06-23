-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Stored Procedures de ABM para el modulo Ventas y Precios.
--              SPs: TipoVisitante (Insertar/Eliminar/Actualizar)
--                   PrecioEntrada (Insertar/Eliminar/Actualizar)
--                   TicketVenta   (Insertar/Eliminar/Actualizar)
--                   LineaVenta    (Insertar/Eliminar/Actualizar)
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- TIPO VISITANTE
-- ============================================================

CREATE OR ALTER PROCEDURE ventas.TipoVisitante_Insertar
    @descripcion VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion del tipo de visitante es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM ventas.TipoVisitante
               WHERE descripcion = LTRIM(RTRIM(@descripcion)))
        SET @vErrores += '- Ya existe un tipo de visitante con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO ventas.TipoVisitante (descripcion)
    VALUES (LTRIM(RTRIM(@descripcion)));

    PRINT 'Tipo de visitante creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE ventas.TipoVisitante_Eliminar
    @idTipoVisitante INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante
                   WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- No existe un tipo de visitante con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM ventas.PrecioEntrada
               WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- No se puede eliminar: existen precios asociados a este tipo de visitante.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM ventas.TipoVisitante
    WHERE idTipoVisitante = @idTipoVisitante;

    PRINT 'Tipo de visitante eliminado.';
END
GO

CREATE OR ALTER PROCEDURE ventas.TipoVisitante_Actualizar
    @idTipoVisitante INT,
    @descripcion     VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante
                   WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- No existe un tipo de visitante con el ID indicado.' + CHAR(13);

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM ventas.TipoVisitante
               WHERE descripcion = LTRIM(RTRIM(@descripcion))
                 AND idTipoVisitante != @idTipoVisitante)
        SET @vErrores += '- Ya existe otro tipo de visitante con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE ventas.TipoVisitante
    SET descripcion = LTRIM(RTRIM(@descripcion))
    WHERE idTipoVisitante = @idTipoVisitante;

    PRINT 'Tipo de visitante actualizado.';
END
GO

-- ============================================================
-- PRECIO ENTRADA
-- ============================================================

CREATE OR ALTER PROCEDURE ventas.PrecioEntrada_Insertar
    @fechaActualizacion DATE,
    @valor              DECIMAL(18,2),
    @idParque           INT,
    @idTipoVisitante    INT,
    @fechaHasta         DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @fechaActualizacion IS NULL
        SET @vErrores += '- La fecha de actualizacion es obligatoria.' + CHAR(13);

    IF @valor IS NULL OR @valor < 0
        SET @vErrores += '- El valor debe ser mayor o igual a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante
                   WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- El tipo de visitante indicado no existe.' + CHAR(13);

    IF @fechaHasta IS NOT NULL AND @fechaHasta < @fechaActualizacion
        SET @vErrores += '- La fecha hasta no puede ser anterior a la fecha de actualizacion.' + CHAR(13);

    IF EXISTS (
           SELECT 1
           FROM ventas.PrecioEntrada
           WHERE idParque = @idParque
             AND idTipoVisitante = @idTipoVisitante
             AND fechaHasta IS NULL
       )
        SET @vErrores += '- Ya existe un precio vigente para ese parque y tipo de visitante.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO ventas.PrecioEntrada
        (fechaActualizacion, valor, idParque, idTipoVisitante, fechaHasta)
    VALUES
        (@fechaActualizacion, @valor, @idParque, @idTipoVisitante, NULL);

    PRINT 'Precio de entrada creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE ventas.PrecioEntrada_Eliminar
    @idPrecio INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM ventas.PrecioEntrada
                   WHERE idPrecio = @idPrecio)
        SET @vErrores += '- No existe un precio de entrada con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM ventas.LineaVenta
               WHERE idPrecioEntrada = @idPrecio)
        SET @vErrores += '- No se puede eliminar: existen lineas de venta asociadas a este precio.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM ventas.PrecioEntrada
    WHERE idPrecio = @idPrecio;

    PRINT 'Precio de entrada eliminado.';
END
GO

CREATE OR ALTER PROCEDURE ventas.PrecioEntrada_Actualizar
    @idPrecio           INT,
    @fechaActualizacion DATE,
    @valor              DECIMAL(18,2),
    @idParque           INT,
    @idTipoVisitante    INT,
    @fechaHasta         DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM ventas.PrecioEntrada
                   WHERE idPrecio = @idPrecio)
        SET @vErrores += '- No existe un precio de entrada con el ID indicado.' + CHAR(13);

    IF @fechaActualizacion IS NULL
        SET @vErrores += '- La fecha de actualizacion es obligatoria.' + CHAR(13);

    IF @valor IS NULL OR @valor < 0
        SET @vErrores += '- El valor debe ser mayor o igual a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante
                   WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- El tipo de visitante indicado no existe.' + CHAR(13);

    IF @fechaHasta IS NOT NULL AND @fechaHasta < @fechaActualizacion
        SET @vErrores += '- La fecha hasta no puede ser anterior a la fecha de actualizacion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE ventas.PrecioEntrada
    SET fechaActualizacion = @fechaActualizacion,
        valor              = @valor,
        idParque           = @idParque,
        idTipoVisitante    = @idTipoVisitante,
        fechaHasta         = NULL
    WHERE idPrecio = @idPrecio;

    PRINT 'Precio de entrada actualizado.';
END
GO

-- ============================================================
-- TICKET VENTA
-- ============================================================

CREATE OR ALTER PROCEDURE ventas.TicketVenta_Insertar
    @fechaHora    DATETIME,
    @total        DECIMAL(18,2),
    @puntoDeVenta INT,
    @nroTicket    INT,
    @formaPago    VARCHAR(50),
    @idParque     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @fechaHora IS NULL
        SET @vErrores += '- La fecha y hora del ticket es obligatoria.' + CHAR(13);

    IF @total IS NULL OR @total < 0
        SET @vErrores += '- El total debe ser mayor o igual a cero.' + CHAR(13);

    IF @puntoDeVenta IS NULL
        SET @vErrores += '- El punto de venta es obligatorio.' + CHAR(13);

    IF @nroTicket IS NULL
        SET @vErrores += '- El numero de ticket es obligatorio.' + CHAR(13);

    IF @formaPago IS NULL OR LTRIM(RTRIM(@formaPago)) = ''
        SET @vErrores += '- La forma de pago es obligatoria.' + CHAR(13);

    IF @idParque IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM parques.Parque
                       WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO ventas.TicketVenta
        (fechaHora, total, puntoDeVenta, nroTicket, formaPago, idParque)
    VALUES
        (@fechaHora, @total, @puntoDeVenta, @nroTicket, LTRIM(RTRIM(@formaPago)), @idParque);

    PRINT 'Ticket de venta creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE ventas.TicketVenta_Eliminar
    @idTicket INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM ventas.TicketVenta
                   WHERE idTicket = @idTicket)
        SET @vErrores += '- No existe un ticket con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM ventas.LineaVenta
               WHERE ticketAsociado = @idTicket)
        SET @vErrores += '- No se puede eliminar: existen lineas de venta asociadas a este ticket.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM ventas.TicketVenta
    WHERE idTicket = @idTicket;

    PRINT 'Ticket de venta eliminado.';
END
GO

CREATE OR ALTER PROCEDURE ventas.TicketVenta_Actualizar
    @idTicket     INT,
    @fechaHora    DATETIME,
    @total        DECIMAL(18,2),
    @puntoDeVenta INT,
    @nroTicket    INT,
    @formaPago    VARCHAR(50),
    @idParque     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM ventas.TicketVenta
                   WHERE idTicket = @idTicket)
        SET @vErrores += '- No existe un ticket con el ID indicado.' + CHAR(13);

    IF @fechaHora IS NULL
        SET @vErrores += '- La fecha y hora del ticket es obligatoria.' + CHAR(13);

    IF @total IS NULL OR @total < 0
        SET @vErrores += '- El total debe ser mayor o igual a cero.' + CHAR(13);

    IF @puntoDeVenta IS NULL
        SET @vErrores += '- El punto de venta es obligatorio.' + CHAR(13);

    IF @nroTicket IS NULL
        SET @vErrores += '- El numero de ticket es obligatorio.' + CHAR(13);

    IF @formaPago IS NULL OR LTRIM(RTRIM(@formaPago)) = ''
        SET @vErrores += '- La forma de pago es obligatoria.' + CHAR(13);

    IF @idParque IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM parques.Parque
                       WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE ventas.TicketVenta
    SET fechaHora    = @fechaHora,
        total        = @total,
        puntoDeVenta = @puntoDeVenta,
        nroTicket    = @nroTicket,
        formaPago    = LTRIM(RTRIM(@formaPago)),
        idParque     = @idParque
    WHERE idTicket = @idTicket;

    PRINT 'Ticket de venta actualizado.';
END
GO

-- ============================================================
-- LINEA VENTA
-- ============================================================

CREATE OR ALTER PROCEDURE ventas.LineaVenta_Insertar
    @idPrecioEntrada INT = NULL,
    @descripcion     VARCHAR(50),
    @subtotal        DECIMAL(18,2),
    @cantidad        INT,
    @precioUnitario  DECIMAL(18,2),
    @ticketAsociado  INT,
    @idTour          INT = NULL,
    @idAtraccion     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF @subtotal IS NULL OR @subtotal < 0
        SET @vErrores += '- El subtotal debe ser mayor o igual a cero.' + CHAR(13);

    IF @cantidad IS NULL OR @cantidad <= 0
        SET @vErrores += '- La cantidad debe ser mayor a cero.' + CHAR(13);

    IF @precioUnitario IS NULL OR @precioUnitario < 0
        SET @vErrores += '- El precio unitario debe ser mayor o igual a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM ventas.TicketVenta
                   WHERE idTicket = @ticketAsociado)
        SET @vErrores += '- El ticket asociado no existe.' + CHAR(13);

    IF (
        CASE WHEN @idPrecioEntrada IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN @idTour IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN @idAtraccion IS NOT NULL THEN 1 ELSE 0 END
        ) <> 1
    SET @vErrores += '- La linea de venta debe tener exactamente un item asociado: PrecioEntrada, Tour o Atraccion.' + CHAR(13);

    IF @idPrecioEntrada IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM ventas.PrecioEntrada
                       WHERE idPrecio = @idPrecioEntrada)
        SET @vErrores += '- El precio de entrada indicado no existe.' + CHAR(13);

    IF @idTour IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM actividades.Tour
                       WHERE idTour = @idTour)
        SET @vErrores += '- El tour indicado no existe.' + CHAR(13);

    IF @idAtraccion IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM actividades.Atraccion
                       WHERE idAtraccion = @idAtraccion)
        SET @vErrores += '- La atraccion indicada no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO ventas.LineaVenta
        (idPrecioEntrada, descripcion, subtotal, cantidad, precioUnitario,
         ticketAsociado, idTour, idAtraccion)
    VALUES
        (@idPrecioEntrada, LTRIM(RTRIM(@descripcion)), @subtotal, @cantidad,
         @precioUnitario, @ticketAsociado, @idTour, @idAtraccion);

    PRINT 'Linea de venta creada con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE ventas.LineaVenta_Eliminar
    @idLineaVenta INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM ventas.LineaVenta
                   WHERE idLineaVenta = @idLineaVenta)
    BEGIN
        RAISERROR('- No existe una linea de venta con el ID indicado.', 16, 1);
        RETURN;
    END

    DELETE FROM ventas.LineaVenta
    WHERE idLineaVenta = @idLineaVenta;

    PRINT 'Linea de venta eliminada.';
END
GO

CREATE OR ALTER PROCEDURE ventas.LineaVenta_Actualizar
    @idLineaVenta    INT,
    @idPrecioEntrada INT = NULL,
    @descripcion     VARCHAR(50),
    @subtotal        DECIMAL(18,2),
    @cantidad        INT,
    @precioUnitario  DECIMAL(18,2),
    @ticketAsociado  INT,
    @idTour          INT = NULL,
    @idAtraccion     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM ventas.LineaVenta
                   WHERE idLineaVenta = @idLineaVenta)
        SET @vErrores += '- No existe una linea de venta con el ID indicado.' + CHAR(13);

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF @subtotal IS NULL OR @subtotal < 0
        SET @vErrores += '- El subtotal debe ser mayor o igual a cero.' + CHAR(13);

    IF @cantidad IS NULL OR @cantidad <= 0
        SET @vErrores += '- La cantidad debe ser mayor a cero.' + CHAR(13);

    IF @precioUnitario IS NULL OR @precioUnitario < 0
        SET @vErrores += '- El precio unitario debe ser mayor o igual a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM ventas.TicketVenta
                   WHERE idTicket = @ticketAsociado)
        SET @vErrores += '- El ticket asociado no existe.' + CHAR(13);
    
    IF (
    CASE WHEN @idPrecioEntrada IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN @idTour IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN @idAtraccion IS NOT NULL THEN 1 ELSE 0 END
        ) <> 1
    SET @vErrores += '- La linea de venta debe tener exactamente un item asociado: PrecioEntrada, Tour o Atraccion.' + CHAR(13);

    IF @idPrecioEntrada IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM ventas.PrecioEntrada
                       WHERE idPrecio = @idPrecioEntrada)
        SET @vErrores += '- El precio de entrada indicado no existe.' + CHAR(13);

    IF @idTour IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM actividades.Tour
                       WHERE idTour = @idTour)
        SET @vErrores += '- El tour indicado no existe.' + CHAR(13);

    IF @idAtraccion IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM actividades.Atraccion
                       WHERE idAtraccion = @idAtraccion)
        SET @vErrores += '- La atraccion indicada no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE ventas.LineaVenta
    SET idPrecioEntrada = @idPrecioEntrada,
        descripcion     = LTRIM(RTRIM(@descripcion)),
        subtotal        = @subtotal,
        cantidad        = @cantidad,
        precioUnitario  = @precioUnitario,
        ticketAsociado  = @ticketAsociado,
        idTour          = @idTour,
        idAtraccion     = @idAtraccion
    WHERE idLineaVenta = @idLineaVenta;

    PRINT 'Linea de venta actualizada.';
END
GO