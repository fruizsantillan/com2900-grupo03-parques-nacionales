-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 16/06/2026
-- Descripcion: Testing del ABM del modulo Ventas y Precios.
--              Mezcla casos exitosos y casos que deben disparar validaciones.
--              Los casos de error se capturan con TRY/CATCH para que el script no se interrumpa.
-- Pre-requisito: ejecutar Reset database.sql, 01_tablas_necesarias.sql,
--                02_tablas_ventas.sql y 03_abm_ventas.sql.
-- =============================================

USE ParquesNacionales;
GO

SET NOCOUNT ON;

DECLARE
    @idTipoParque INT,
    @idUbicacion INT,
    @idParque INT,
    @idTour INT,
    @idAtraccion INT,
    @idTipoVisitanteResidente INT,
    @idTipoVisitanteExtranjero INT,
    @idTipoVisitanteTemporal INT,
    @idPrecioResidente INT,
    @idPrecioExtranjero INT,
    @idTicket INT,
    @idTicketEliminar INT,
    @idLineaVenta INT;

-- ============================================================
-- SETUP: DATOS BASE NECESARIOS
-- ============================================================

PRINT '===== SETUP: carga de datos base =====';

INSERT INTO parques.TipoParque (descripcion)
VALUES ('Parque Nacional');

SET @idTipoParque = SCOPE_IDENTITY();

INSERT INTO parques.Ubicacion (direccion, provincia, latitud, longitud)
VALUES ('Ruta Nacional 12', 'Misiones', -25.695278, -54.436667);

SET @idUbicacion = SCOPE_IDENTITY();

INSERT INTO parques.Parque (nombre, superficie, idTipoParque, idUbicacion)
VALUES ('Parque Nacional Iguazu', 67200.00, @idTipoParque, @idUbicacion);

SET @idParque = SCOPE_IDENTITY();

INSERT INTO actividades.Tour (nombre, descripcion, duracion, cupoMaximo, precio, idParque)
VALUES ('Tour Cataratas', 'Recorrido por las cataratas', 120, 30, 5000.00, @idParque);

SET @idTour = SCOPE_IDENTITY();

INSERT INTO actividades.Atraccion (nombre, descripcion, tipo, precio, duracion, cupoMaximo, idParque)
VALUES ('Garganta del Diablo', 'Atraccion principal', 'Natural', 3000.00, 90, 50, @idParque);

SET @idAtraccion = SCOPE_IDENTITY();

-- ============================================================
-- TIPO VISITANTE
-- ============================================================

PRINT '===== TEST 1 (OK): insertar TipoVisitante =====';

EXEC ventas.TipoVisitante_Insertar @descripcion = 'Residente';
EXEC ventas.TipoVisitante_Insertar @descripcion = 'Extranjero';
EXEC ventas.TipoVisitante_Insertar @descripcion = 'Temporal';

SELECT @idTipoVisitanteResidente = idTipoVisitante
FROM ventas.TipoVisitante
WHERE descripcion = 'Residente';

SELECT @idTipoVisitanteExtranjero = idTipoVisitante
FROM ventas.TipoVisitante
WHERE descripcion = 'Extranjero';

SELECT @idTipoVisitanteTemporal = idTipoVisitante
FROM ventas.TipoVisitante
WHERE descripcion = 'Temporal';

SELECT * FROM ventas.TipoVisitante;

PRINT '===== TEST 2 (ERROR): insertar TipoVisitante duplicado =====';
BEGIN TRY
    EXEC ventas.TipoVisitante_Insertar @descripcion = 'Residente';
    PRINT 'FALLO LA PRUEBA: se esperaba error de duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 3 (ERROR): insertar TipoVisitante sin descripcion =====';
BEGIN TRY
    EXEC ventas.TipoVisitante_Insertar @descripcion = '';
    PRINT 'FALLO LA PRUEBA: se esperaba error de descripcion obligatoria.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 4 (OK): actualizar TipoVisitante =====';

EXEC ventas.TipoVisitante_Actualizar
    @idTipoVisitante = @idTipoVisitanteResidente,
    @descripcion = 'Residente Nacional';

SELECT * FROM ventas.TipoVisitante;

PRINT '===== TEST 5 (ERROR): actualizar TipoVisitante con descripcion duplicada =====';
BEGIN TRY
    EXEC ventas.TipoVisitante_Actualizar
        @idTipoVisitante = @idTipoVisitanteTemporal,
        @descripcion = 'Extranjero';
    PRINT 'FALLO LA PRUEBA: se esperaba error de descripcion duplicada.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 6 (OK): eliminar TipoVisitante temporal =====';

EXEC ventas.TipoVisitante_Eliminar
    @idTipoVisitante = @idTipoVisitanteTemporal;

SELECT * FROM ventas.TipoVisitante;

-- ============================================================
-- PRECIO ENTRADA
-- ============================================================

PRINT '===== TEST 7 (OK): insertar PrecioEntrada vigente =====';

EXEC ventas.PrecioEntrada_Insertar
    @valor = 2500.00,
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente;

EXEC ventas.PrecioEntrada_Insertar
    @valor = 6000.00,
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteExtranjero;

SELECT @idPrecioResidente = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteResidente
  AND fechaHasta IS NULL;

SELECT @idPrecioExtranjero = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteExtranjero
  AND fechaHasta IS NULL;

SELECT * FROM ventas.PrecioEntrada;

PRINT '===== TEST 8 (ERROR): insertar PrecioEntrada con valor negativo =====';
BEGIN TRY
    EXEC ventas.PrecioEntrada_Insertar
        @valor = -100.00,
        @idParque = @idParque,
        @idTipoVisitante = @idTipoVisitanteResidente;
    PRINT 'FALLO LA PRUEBA: se esperaba error de valor negativo.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 9 (ERROR): insertar PrecioEntrada con parque inexistente =====';
BEGIN TRY
    EXEC ventas.PrecioEntrada_Insertar
        @valor = 1000.00,
        @idParque = 99999,
        @idTipoVisitante = @idTipoVisitanteResidente;
    PRINT 'FALLO LA PRUEBA: se esperaba error de parque inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 10 (ERROR): insertar PrecioEntrada vigente duplicado =====';
BEGIN TRY
    EXEC ventas.PrecioEntrada_Insertar
        @valor = 3000.00,
        @idParque = @idParque,
        @idTipoVisitante = @idTipoVisitanteResidente;
    PRINT 'FALLO LA PRUEBA: se esperaba error de precio vigente duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 11 (OK): actualizar PrecioEntrada versionando precio =====';

EXEC ventas.PrecioEntrada_Actualizar
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente,
    @nuevoValor = 3500.00;

SELECT *
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteResidente
ORDER BY idPrecio;

SELECT @idPrecioResidente = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteResidente
  AND fechaHasta IS NULL;

PRINT '===== TEST 12 (ERROR): actualizar PrecioEntrada con tipo visitante inexistente =====';
BEGIN TRY
    EXEC ventas.PrecioEntrada_Actualizar
        @idParque = @idParque,
        @idTipoVisitante = 99999,
        @nuevoValor = 4000.00;
    PRINT 'FALLO LA PRUEBA: se esperaba error de tipo visitante inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 13 (OK): baja logica de PrecioEntrada =====';

EXEC ventas.PrecioEntrada_Eliminar
    @idPrecio = @idPrecioExtranjero;

SELECT *
FROM ventas.PrecioEntrada
WHERE idPrecio = @idPrecioExtranjero;

PRINT '===== TEST 14 (ERROR): baja logica de PrecioEntrada ya dado de baja =====';
BEGIN TRY
    EXEC ventas.PrecioEntrada_Eliminar
        @idPrecio = @idPrecioExtranjero;
    PRINT 'FALLO LA PRUEBA: se esperaba error de precio ya dado de baja.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

-- Volvemos a crear precio extranjero vigente para usarlo luego
EXEC ventas.PrecioEntrada_Insertar
    @valor = 6500.00,
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteExtranjero;

SELECT @idPrecioExtranjero = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteExtranjero
  AND fechaHasta IS NULL;

-- ============================================================
-- TICKET VENTA
-- ============================================================

PRINT '===== TEST 15 (OK): insertar TicketVenta =====';

EXEC ventas.TicketVenta_Insertar
    @puntoDeVenta = 1,
    @formaPago = 'Efectivo',
    @idParque = @idParque;

SELECT @idTicket = MAX(idTicket)
FROM ventas.TicketVenta
WHERE puntoDeVenta = 1;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 16 (ERROR): insertar TicketVenta sin formaPago =====';
BEGIN TRY
    EXEC ventas.TicketVenta_Insertar
        @puntoDeVenta = 1,
        @formaPago = '',
        @idParque = @idParque;
    PRINT 'FALLO LA PRUEBA: se esperaba error de forma de pago.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 17 (ERROR): insertar TicketVenta con parque inexistente =====';
BEGIN TRY
    EXEC ventas.TicketVenta_Insertar
        @puntoDeVenta = 1,
        @formaPago = 'Tarjeta',
        @idParque = 99999;
    PRINT 'FALLO LA PRUEBA: se esperaba error de parque inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 18 (OK): actualizar TicketVenta solo formaPago =====';

EXEC ventas.TicketVenta_Actualizar
    @idTicket = @idTicket,
    @formaPago = 'Tarjeta';

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 19 (ERROR): actualizar TicketVenta inexistente =====';
BEGIN TRY
    EXEC ventas.TicketVenta_Actualizar
        @idTicket = 99999,
        @formaPago = 'Efectivo';
    PRINT 'FALLO LA PRUEBA: se esperaba error de ticket inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

-- ============================================================
-- LINEA VENTA
-- ============================================================

PRINT '===== TEST 20 (OK): insertar LineaVenta de entrada =====';

EXEC ventas.LineaVenta_Insertar
    @ticketAsociado = @idTicket,
    @cantidad = 2,
    @idPrecioEntrada = @idPrecioResidente,
    @idTour = NULL,
    @idAtraccion = NULL;

SELECT @idLineaVenta = MAX(idLineaVenta)
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 21 (OK): insertar LineaVenta de tour =====';

EXEC ventas.LineaVenta_Insertar
    @ticketAsociado = @idTicket,
    @cantidad = 1,
    @idPrecioEntrada = NULL,
    @idTour = @idTour,
    @idAtraccion = NULL;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 22 (ERROR): insertar LineaVenta con mas de un item asociado =====';
BEGIN TRY
    EXEC ventas.LineaVenta_Insertar
        @ticketAsociado = @idTicket,
        @cantidad = 1,
        @idPrecioEntrada = @idPrecioResidente,
        @idTour = @idTour,
        @idAtraccion = NULL;
    PRINT 'FALLO LA PRUEBA: se esperaba error por mas de un item asociado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 23 (ERROR): insertar LineaVenta con cantidad invalida =====';
BEGIN TRY
    EXEC ventas.LineaVenta_Insertar
        @ticketAsociado = @idTicket,
        @cantidad = 0,
        @idPrecioEntrada = @idPrecioResidente,
        @idTour = NULL,
        @idAtraccion = NULL;
    PRINT 'FALLO LA PRUEBA: se esperaba error por cantidad invalida.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 24 (ERROR): insertar LineaVenta con ticket inexistente =====';
BEGIN TRY
    EXEC ventas.LineaVenta_Insertar
        @ticketAsociado = 99999,
        @cantidad = 1,
        @idPrecioEntrada = @idPrecioResidente,
        @idTour = NULL,
        @idAtraccion = NULL;
    PRINT 'FALLO LA PRUEBA: se esperaba error por ticket inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 25 (OK): actualizar LineaVenta a atraccion =====';

EXEC ventas.LineaVenta_Actualizar
    @idLineaVenta = @idLineaVenta,
    @cantidad = 3,
    @idPrecioEntrada = NULL,
    @idTour = NULL,
    @idAtraccion = @idAtraccion;

SELECT *
FROM ventas.LineaVenta
WHERE idLineaVenta = @idLineaVenta;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 26 (ERROR): actualizar LineaVenta inexistente =====';
BEGIN TRY
    EXEC ventas.LineaVenta_Actualizar
        @idLineaVenta = 99999,
        @cantidad = 1,
        @idPrecioEntrada = NULL,
        @idTour = @idTour,
        @idAtraccion = NULL;
    PRINT 'FALLO LA PRUEBA: se esperaba error de linea inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 27 (OK): eliminar LineaVenta y recalcular total =====';

EXEC ventas.LineaVenta_Eliminar
    @idLineaVenta = @idLineaVenta;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 28 (ERROR): eliminar LineaVenta inexistente =====';
BEGIN TRY
    EXEC ventas.LineaVenta_Eliminar
        @idLineaVenta = 99999;
    PRINT 'FALLO LA PRUEBA: se esperaba error de linea inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

-- ============================================================
-- TICKET VENTA - ELIMINACION CON LINEAS
-- ============================================================

PRINT '===== TEST 29 (OK): eliminar TicketVenta con lineas asociadas =====';

EXEC ventas.TicketVenta_Insertar
    @puntoDeVenta = 2,
    @formaPago = 'Efectivo',
    @idParque = @idParque;

SELECT @idTicketEliminar = MAX(idTicket)
FROM ventas.TicketVenta
WHERE puntoDeVenta = 2;

EXEC ventas.LineaVenta_Insertar
    @ticketAsociado = @idTicketEliminar,
    @cantidad = 1,
    @idPrecioEntrada = @idPrecioResidente,
    @idTour = NULL,
    @idAtraccion = NULL;

EXEC ventas.TicketVenta_Eliminar
    @idTicket = @idTicketEliminar;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicketEliminar;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicketEliminar;

PRINT '===== TEST 30 (ERROR): eliminar TicketVenta inexistente =====';
BEGIN TRY
    EXEC ventas.TicketVenta_Eliminar
        @idTicket = 99999;
    PRINT 'FALLO LA PRUEBA: se esperaba error de ticket inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH
GO