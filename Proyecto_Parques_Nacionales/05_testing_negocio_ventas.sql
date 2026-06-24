-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 16/06/2026
-- Descripcion: Testing de SPs de negocio del modulo Ventas y Precios.
--              Prueba registrarVentaEntrada y actualizarPrecioEntrada.
--              Mezcla casos exitosos y casos que deben disparar validaciones.
-- Pre-requisito: ejecutar Reset database.sql, 01_tablas_necesarias.sql,
--                02_tablas_ventas.sql, 03_abm_ventas.sql y 04_negocio_ventas.sql.
-- =============================================

USE ParquesNacionales;
GO

SET NOCOUNT ON;

DECLARE
    @idTipoParque INT,
    @idUbicacion INT,
    @idParque INT,
    @idTipoVisitanteResidente INT,
    @idTipoVisitanteExtranjero INT,
    @idTicket INT,
    @idPrecioVigente INT;

-- ============================================================
-- SETUP: DATOS BASE
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

EXEC ventas.TipoVisitante_Insertar
    @descripcion = 'Residente';

SELECT @idTipoVisitanteResidente = idTipoVisitante
FROM ventas.TipoVisitante
WHERE descripcion = 'Residente';

EXEC ventas.TipoVisitante_Insertar
    @descripcion = 'Extranjero';

SELECT @idTipoVisitanteExtranjero = idTipoVisitante
FROM ventas.TipoVisitante
WHERE descripcion = 'Extranjero';

EXEC ventas.PrecioEntrada_Insertar
    @valor = 2500.00,
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente;

EXEC ventas.PrecioEntrada_Insertar
    @valor = 6000.00,
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteExtranjero;

SELECT 'TipoVisitante' AS tabla, * FROM ventas.TipoVisitante;
SELECT 'PrecioEntrada' AS tabla, * FROM ventas.PrecioEntrada;

-- ============================================================
-- TEST registrarVentaEntrada
-- ============================================================

PRINT '===== TEST 1 (OK): registrarVentaEntrada crea nuevo ticket =====';

EXEC ventas.RegistrarVentaEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente,
    @cantidad = 2,
    @puntoDeVenta = 1,
    @formaPago = 'Efectivo',
    @nuevoTkt = 1;

SELECT @idTicket = MAX(idTicket)
FROM ventas.TicketVenta
WHERE puntoDeVenta = 1;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

PRINT '===== TEST 2 (OK): registrarVentaEntrada agrega linea al ultimo ticket =====';

EXEC ventas.RegistrarVentaEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteExtranjero,
    @cantidad = 1,
    @puntoDeVenta = 1,
    @formaPago = 'Efectivo',
    @nuevoTkt = 0;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

PRINT '===== TEST 3 (OK): registrarVentaEntrada crea otro ticket en el mismo punto de venta =====';

EXEC ventas.RegistrarVentaEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente,
    @cantidad = 1,
    @puntoDeVenta = 1,
    @formaPago = 'Tarjeta',
    @nuevoTkt = 1;

SELECT *
FROM ventas.TicketVenta
WHERE puntoDeVenta = 1
ORDER BY nroTicket;

PRINT '===== TEST 4 (ERROR): registrarVentaEntrada con cantidad invalida =====';

BEGIN TRY
    EXEC ventas.RegistrarVentaEntrada
        @idParque = @idParque,
        @idTipoVisitante = @idTipoVisitanteResidente,
        @cantidad = 0,
        @puntoDeVenta = 1,
        @formaPago = 'Efectivo',
        @nuevoTkt = 1;

    PRINT 'FALLO LA PRUEBA: se esperaba error por cantidad invalida.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 5 (ERROR): registrarVentaEntrada con parque inexistente =====';

BEGIN TRY
    EXEC ventas.RegistrarVentaEntrada
        @idParque = 99999,
        @idTipoVisitante = @idTipoVisitanteResidente,
        @cantidad = 1,
        @puntoDeVenta = 1,
        @formaPago = 'Efectivo',
        @nuevoTkt = 1;

    PRINT 'FALLO LA PRUEBA: se esperaba error por parque inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 6 (ERROR): registrarVentaEntrada con tipo visitante inexistente =====';

BEGIN TRY
    EXEC ventas.RegistrarVentaEntrada
        @idParque = @idParque,
        @idTipoVisitante = 99999,
        @cantidad = 1,
        @puntoDeVenta = 1,
        @formaPago = 'Efectivo',
        @nuevoTkt = 1;

    PRINT 'FALLO LA PRUEBA: se esperaba error por tipo visitante inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 7 (ERROR): registrarVentaEntrada sin formaPago =====';

BEGIN TRY
    EXEC ventas.RegistrarVentaEntrada
        @idParque = @idParque,
        @idTipoVisitante = @idTipoVisitanteResidente,
        @cantidad = 1,
        @puntoDeVenta = 1,
        @formaPago = '',
        @nuevoTkt = 1;

    PRINT 'FALLO LA PRUEBA: se esperaba error por forma de pago obligatoria.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

-- ============================================================
-- TEST actualizarPrecioEntrada
-- ============================================================

PRINT '===== TEST 8 (OK): actualizarPrecioEntrada versiona precio vigente =====';

SELECT @idPrecioVigente = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteResidente
  AND fechaHasta IS NULL;

EXEC ventas.ActualizarPrecioEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente,
    @nuevoValor = 3500.00;

SELECT *
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteResidente
ORDER BY idPrecio;

PRINT '===== TEST 9 (OK): registrarVentaEntrada usa el nuevo precio vigente =====';

EXEC ventas.RegistrarVentaEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente,
    @cantidad = 1,
    @puntoDeVenta = 2,
    @formaPago = 'Efectivo',
    @nuevoTkt = 1;

SELECT @idTicket = MAX(idTicket)
FROM ventas.TicketVenta
WHERE puntoDeVenta = 2;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

PRINT '===== TEST 10 (OK): actualizarPrecioEntrada crea precio si no existe vigente =====';

-- Damos de baja el precio extranjero vigente para forzar que no haya vigente.
SELECT @idPrecioVigente = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteExtranjero
  AND fechaHasta IS NULL;

EXEC ventas.PrecioEntrada_Eliminar
    @idPrecio = @idPrecioVigente;

EXEC ventas.ActualizarPrecioEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteExtranjero,
    @nuevoValor = 7000.00;

SELECT *
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteExtranjero
ORDER BY idPrecio;

PRINT '===== TEST 11 (ERROR): actualizarPrecioEntrada con valor negativo =====';

BEGIN TRY
    EXEC ventas.ActualizarPrecioEntrada
        @idParque = @idParque,
        @idTipoVisitante = @idTipoVisitanteResidente,
        @nuevoValor = -500.00;

    PRINT 'FALLO LA PRUEBA: se esperaba error por valor negativo.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 12 (ERROR): actualizarPrecioEntrada con parque inexistente =====';

BEGIN TRY
    EXEC ventas.ActualizarPrecioEntrada
        @idParque = 99999,
        @idTipoVisitante = @idTipoVisitanteResidente,
        @nuevoValor = 4000.00;

    PRINT 'FALLO LA PRUEBA: se esperaba error por parque inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 13 (ERROR): actualizarPrecioEntrada con tipo visitante inexistente =====';

BEGIN TRY
    EXEC ventas.ActualizarPrecioEntrada
        @idParque = @idParque,
        @idTipoVisitante = 99999,
        @nuevoValor = 4000.00;

    PRINT 'FALLO LA PRUEBA: se esperaba error por tipo visitante inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== FIN TESTING SPs NEGOCIO VENTAS Y PRECIOS =====';
GO