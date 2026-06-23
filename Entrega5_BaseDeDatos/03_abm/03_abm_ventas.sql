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
-- Notas:
--   TipoVisitante:
--     - Insertar: registra un nuevo tipo de visitante.
--     - Actualizar: modifica la descripcion.
--     - Eliminar: elimina solo si no tiene precios asociados.
--
--   PrecioEntrada:
--     - Insertar: registra un precio vigente nuevo con fechaActualizacion = fecha actual.
--       Si ya existe uno vigente, informa que debe actualizarse o darse de baja primero.
--     - Actualizar: versiona el precio; cierra el precio vigente con fechaHasta = fecha actual
--       e inserta un nuevo precio vigente.
--     - Eliminar: no borra fisicamente; realiza baja logica seteando fechaHasta = fecha actual.
--
--   TicketVenta:
--     - Insertar: crea la cabecera del ticket con fecha actual, total = 0 y nroTicket automatico
--       por punto de venta.
--     - Actualizar: solo permite modificar la forma de pago.
--     - Eliminar: elimina primero las lineas asociadas y luego el ticket, dentro de una transaccion.
--
--   LineaVenta:
--     - Insertar: agrega una linea a un ticket existente, calcula descripcion, precioUnitario
--       y subtotal segun el item vendido, y recalcula el total del ticket.
--     - Actualizar: modifica cantidad/item, recalcula subtotal y total del ticket.
--     - Eliminar: elimina la linea y recalcula el total del ticket.
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
    @valor           DECIMAL(18,2),
    @idParque        INT,
    @idTipoVisitante INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores NVARCHAR(MAX) = '';
    DECLARE @vFechaHoy DATE = CAST(GETDATE() AS DATE);

    IF @valor IS NULL OR @valor < 0
        SET @vErrores += '- El valor debe ser mayor o igual a cero.' + CHAR(13);

    IF NOT EXISTS (
        SELECT 1
        FROM parques.Parque
        WHERE idParque = @idParque
    )
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (
        SELECT 1
        FROM ventas.TipoVisitante
        WHERE idTipoVisitante = @idTipoVisitante
    )
        SET @vErrores += '- El tipo de visitante indicado no existe.' + CHAR(13);

    IF EXISTS (
        SELECT 1
        FROM ventas.PrecioEntrada
        WHERE idParque = @idParque
          AND idTipoVisitante = @idTipoVisitante
          AND fechaHasta IS NULL
    )
        SET @vErrores += '- Ya existe un precio vigente para ese parque y tipo de visitante. Utilice el procedimiento de actualizacion de precios o primero de baja el precio vigente y luego registre uno nuevo.' + CHAR(13);

    IF @vErrores <> ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO ventas.PrecioEntrada
        (fechaActualizacion, valor, idParque, idTipoVisitante, fechaHasta)
    VALUES
        (@vFechaHoy, @valor, @idParque, @idTipoVisitante, NULL);

    PRINT 'Precio de entrada creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

----------------------------
CREATE OR ALTER PROCEDURE ventas.PrecioEntrada_Eliminar
    @idPrecio INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores NVARCHAR(MAX) = '';
    DECLARE @vFechaHoy DATE = CAST(GETDATE() AS DATE);

    IF NOT EXISTS (
        SELECT 1
        FROM ventas.PrecioEntrada
        WHERE idPrecio = @idPrecio
    )
        SET @vErrores += '- No existe un precio de entrada con el ID indicado.' + CHAR(13);

    IF EXISTS (
        SELECT 1
        FROM ventas.PrecioEntrada
        WHERE idPrecio = @idPrecio
          AND fechaHasta IS NOT NULL
    )
        SET @vErrores += '- El precio de entrada ya se encuentra dado de baja.' + CHAR(13);

    IF @vErrores <> ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE ventas.PrecioEntrada
    SET fechaHasta = @vFechaHoy
    WHERE idPrecio = @idPrecio;

    PRINT 'Precio de entrada dado de baja correctamente.';
END
GO

CREATE OR ALTER PROCEDURE ventas.PrecioEntrada_Actualizar
    @idParque        INT,
    @idTipoVisitante INT,
    @nuevoValor      DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores NVARCHAR(MAX) = '';
    DECLARE @vFechaHoy DATE = CAST(GETDATE() AS DATE);
    DECLARE @vIdPrecioVigente INT;

    -- Validación 1: valor válido
    IF @nuevoValor IS NULL OR @nuevoValor < 0
        SET @vErrores += '- El nuevo valor debe ser mayor o igual a cero.' + CHAR(13);

    -- Validación 2: parque existe
    IF NOT EXISTS (
        SELECT 1
        FROM parques.Parque
        WHERE idParque = @idParque
    )
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    -- Validación 3: tipo visitante existe
    IF NOT EXISTS (
        SELECT 1
        FROM ventas.TipoVisitante
        WHERE idTipoVisitante = @idTipoVisitante
    )
        SET @vErrores += '- El tipo de visitante indicado no existe.' + CHAR(13);

    -- Buscar precio vigente
    SELECT @vIdPrecioVigente = idPrecio
    FROM ventas.PrecioEntrada
    WHERE idParque = @idParque
      AND idTipoVisitante = @idTipoVisitante
      AND fechaHasta IS NULL;

    -- Validación 4: debe existir un precio vigente
    IF @vIdPrecioVigente IS NULL
        SET @vErrores += '- No existe un precio vigente para ese parque y tipo de visitante.' + CHAR(13);

    IF @vErrores <> ''
    BEGIN
        RAISERROR(@vErrores,16,1);
        RETURN;
    END

    BEGIN TRANSACTION;

    BEGIN TRY

        -- Cerrar precio vigente
        UPDATE ventas.PrecioEntrada
        SET fechaHasta = @vFechaHoy
        WHERE idPrecio = @vIdPrecioVigente;

        -- Crear nueva versión
        INSERT INTO ventas.PrecioEntrada
            (fechaActualizacion, valor, idParque, idTipoVisitante, fechaHasta)
        VALUES
            (@vFechaHoy, @nuevoValor, @idParque, @idTipoVisitante, NULL);

        COMMIT TRANSACTION;

        PRINT 'Precio actualizado correctamente. Nuevo ID: '
              + CAST(SCOPE_IDENTITY() AS VARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

-- ============================================================
-- TICKET VENTA
-- ============================================================
CREATE OR ALTER PROCEDURE ventas.TicketVenta_Insertar
    @puntoDeVenta INT,
    @formaPago    VARCHAR(50),
    @idParque     INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores NVARCHAR(MAX) = '';
    DECLARE @vFechaHora DATETIME = GETDATE();
    DECLARE @vNroTicket INT;

    IF @puntoDeVenta IS NULL
        SET @vErrores += '- El punto de venta es obligatorio.' + CHAR(13);

    IF @formaPago IS NULL OR LTRIM(RTRIM(@formaPago)) = ''
        SET @vErrores += '- La forma de pago es obligatoria.' + CHAR(13);

    IF NOT EXISTS (
        SELECT 1
        FROM parques.Parque
        WHERE idParque = @idParque
    )
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    SELECT @vNroTicket = ISNULL(MAX(nroTicket), 0) + 1
    FROM ventas.TicketVenta
    WHERE puntoDeVenta = @puntoDeVenta;

    INSERT INTO ventas.TicketVenta
        (fechaHora, total, puntoDeVenta, nroTicket, formaPago, idParque)
    VALUES
        (@vFechaHora, 0, @puntoDeVenta, @vNroTicket, LTRIM(RTRIM(@formaPago)), @idParque);

    PRINT 'Ticket de venta creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR)
        + ' y numero: ' + CAST(@vNroTicket AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE ventas.TicketVenta_Eliminar
    @idTicket INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (
        SELECT 1
        FROM ventas.TicketVenta
        WHERE idTicket = @idTicket
    )
        SET @vErrores += '- No existe un ticket con el ID indicado.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY

        DELETE FROM ventas.LineaVenta
        WHERE ticketAsociado = @idTicket;

        DELETE FROM ventas.TicketVenta
        WHERE idTicket = @idTicket;

        COMMIT TRANSACTION;

        PRINT 'Ticket de venta eliminado junto con sus lineas asociadas.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE ventas.TicketVenta_Actualizar
    @idTicket  INT,
    @formaPago VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (
        SELECT 1
        FROM ventas.TicketVenta
        WHERE idTicket = @idTicket
    )
        SET @vErrores += '- No existe un ticket con el ID indicado.' + CHAR(13);

    IF @formaPago IS NULL OR LTRIM(RTRIM(@formaPago)) = ''
        SET @vErrores += '- La forma de pago es obligatoria.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE ventas.TicketVenta
    SET formaPago = LTRIM(RTRIM(@formaPago))
    WHERE idTicket = @idTicket;

    PRINT 'Ticket de venta actualizado.';
END
GO

-- ============================================================
-- LINEA VENTA
-- ============================================================

CREATE OR ALTER PROCEDURE ventas.LineaVenta_Insertar
    @ticketAsociado  INT,
    @cantidad        INT,
    @idPrecioEntrada INT = NULL,
    @idTour          INT = NULL,
    @idAtraccion     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores NVARCHAR(MAX) = '';
    DECLARE @vDescripcion VARCHAR(50);
    DECLARE @vPrecioUnitario DECIMAL(18,2);
    DECLARE @vSubtotal DECIMAL(18,2);

    IF NOT EXISTS (SELECT 1 FROM ventas.TicketVenta WHERE idTicket = @ticketAsociado)
        SET @vErrores += '- El ticket asociado no existe.' + CHAR(13);

    IF @cantidad IS NULL OR @cantidad <= 0
        SET @vErrores += '- La cantidad debe ser mayor a cero.' + CHAR(13);

    IF (
        CASE WHEN @idPrecioEntrada IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN @idTour IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN @idAtraccion IS NOT NULL THEN 1 ELSE 0 END
    ) <> 1
        SET @vErrores += '- La linea debe tener exactamente un item asociado: PrecioEntrada, Tour o Atraccion.' + CHAR(13);

    IF @idPrecioEntrada IS NOT NULL
    BEGIN
        SELECT 
            @vPrecioUnitario = pe.valor,
            @vDescripcion = 'Entrada ' + tv.descripcion
        FROM ventas.PrecioEntrada pe
        INNER JOIN ventas.TipoVisitante tv
            ON tv.idTipoVisitante = pe.idTipoVisitante
        WHERE pe.idPrecio = @idPrecioEntrada
          AND pe.fechaHasta IS NULL;

        IF @vPrecioUnitario IS NULL
            SET @vErrores += '- El precio de entrada indicado no existe o no esta vigente.' + CHAR(13);
    END

    IF @idTour IS NOT NULL
    BEGIN
        SELECT 
            @vPrecioUnitario = precio,
            @vDescripcion = nombre
        FROM parques.Tour
        WHERE idTour = @idTour;

        IF @vPrecioUnitario IS NULL
            SET @vErrores += '- El tour indicado no existe.' + CHAR(13);
    END

    IF @idAtraccion IS NOT NULL
    BEGIN
        SELECT 
            @vPrecioUnitario = precio,
            @vDescripcion = nombre
        FROM parques.Atraccion
        WHERE idAtraccion = @idAtraccion;

        IF @vPrecioUnitario IS NULL
            SET @vErrores += '- La atraccion indicada no existe.' + CHAR(13);
    END

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    SET @vSubtotal = @cantidad * @vPrecioUnitario;

    BEGIN TRANSACTION;
    BEGIN TRY

        INSERT INTO ventas.LineaVenta
            (ticketAsociado, descripcion, subtotal, cantidad, precioUnitario,
             idPrecioEntrada, idTour, idAtraccion)
        VALUES
            (@ticketAsociado, @vDescripcion, @vSubtotal, @cantidad, @vPrecioUnitario,
             @idPrecioEntrada, @idTour, @idAtraccion);

        UPDATE ventas.TicketVenta
        SET total = (
            SELECT ISNULL(SUM(subtotal), 0)
            FROM ventas.LineaVenta
            WHERE ticketAsociado = @ticketAsociado
        )
        WHERE idTicket = @ticketAsociado;

        COMMIT TRANSACTION;

        PRINT 'Linea de venta creada con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE ventas.LineaVenta_Eliminar
    @idLineaVenta INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores NVARCHAR(MAX) = '';
    DECLARE @vIdTicket INT;

    SELECT @vIdTicket = ticketAsociado
    FROM ventas.LineaVenta
    WHERE idLineaVenta = @idLineaVenta;

    IF @vIdTicket IS NULL
        SET @vErrores += '- No existe una linea de venta con el ID indicado.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY

        DELETE FROM ventas.LineaVenta
        WHERE idLineaVenta = @idLineaVenta;

        UPDATE ventas.TicketVenta
        SET total = (
            SELECT ISNULL(SUM(subtotal), 0)
            FROM ventas.LineaVenta
            WHERE ticketAsociado = @vIdTicket
        )
        WHERE idTicket = @vIdTicket;

        COMMIT TRANSACTION;

        PRINT 'Linea de venta eliminada.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE ventas.LineaVenta_Actualizar
    @idLineaVenta    INT,
    @cantidad        INT,
    @idPrecioEntrada INT = NULL,
    @idTour          INT = NULL,
    @idAtraccion     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores NVARCHAR(MAX) = '';
    DECLARE @vIdTicket INT;
    DECLARE @vDescripcion VARCHAR(50);
    DECLARE @vPrecioUnitario DECIMAL(18,2);
    DECLARE @vSubtotal DECIMAL(18,2);

    SELECT @vIdTicket = ticketAsociado
    FROM ventas.LineaVenta
    WHERE idLineaVenta = @idLineaVenta;

    IF @vIdTicket IS NULL
        SET @vErrores += '- No existe una linea de venta con el ID indicado.' + CHAR(13);

    IF @cantidad IS NULL OR @cantidad <= 0
        SET @vErrores += '- La cantidad debe ser mayor a cero.' + CHAR(13);

    IF (
        CASE WHEN @idPrecioEntrada IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN @idTour IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN @idAtraccion IS NOT NULL THEN 1 ELSE 0 END
    ) <> 1
        SET @vErrores += '- La linea debe tener exactamente un item asociado: PrecioEntrada, Tour o Atraccion.' + CHAR(13);

    IF @idPrecioEntrada IS NOT NULL
    BEGIN
        SELECT 
            @vPrecioUnitario = pe.valor,
            @vDescripcion = 'Entrada ' + tv.descripcion
        FROM ventas.PrecioEntrada pe
        INNER JOIN ventas.TipoVisitante tv
            ON tv.idTipoVisitante = pe.idTipoVisitante
        WHERE pe.idPrecio = @idPrecioEntrada
          AND pe.fechaHasta IS NULL;

        IF @vPrecioUnitario IS NULL
            SET @vErrores += '- El precio de entrada indicado no existe o no esta vigente.' + CHAR(13);
    END

    IF @idTour IS NOT NULL
    BEGIN
        SELECT 
            @vPrecioUnitario = precio,
            @vDescripcion = nombre
        FROM parques.Tour
        WHERE idTour = @idTour;

        IF @vPrecioUnitario IS NULL
            SET @vErrores += '- El tour indicado no existe.' + CHAR(13);
    END

    IF @idAtraccion IS NOT NULL
    BEGIN
        SELECT 
            @vPrecioUnitario = precio,
            @vDescripcion = nombre
        FROM parques.Atraccion
        WHERE idAtraccion = @idAtraccion;

        IF @vPrecioUnitario IS NULL
            SET @vErrores += '- La atraccion indicada no existe.' + CHAR(13);
    END

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    SET @vSubtotal = @cantidad * @vPrecioUnitario;

    BEGIN TRANSACTION;
    BEGIN TRY

        UPDATE ventas.LineaVenta
        SET descripcion     = @vDescripcion,
            subtotal        = @vSubtotal,
            cantidad        = @cantidad,
            precioUnitario  = @vPrecioUnitario,
            idPrecioEntrada = @idPrecioEntrada,
            idTour          = @idTour,
            idAtraccion     = @idAtraccion
        WHERE idLineaVenta = @idLineaVenta;

        UPDATE ventas.TicketVenta
        SET total = (
            SELECT ISNULL(SUM(subtotal), 0)
            FROM ventas.LineaVenta
            WHERE ticketAsociado = @vIdTicket
        )
        WHERE idTicket = @vIdTicket;

        COMMIT TRANSACTION;

        PRINT 'Linea de venta actualizada.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO