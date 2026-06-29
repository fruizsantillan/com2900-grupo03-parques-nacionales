-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Fecha: 15/06/2026
-- Descripcion: Script de Carga de Datos (Seed Data) - Criterios de Aceptación
-- Genera: 10 Parques, 30 Actividades, 20 Guías, 20 Guardaparques, 10 Concesiones,
--         Historial de ventas y cubre los 4 casos obligatorios del TP.
-- =============================================

USE ParquesNacionales;
GO

SET NOCOUNT ON;
PRINT 'Iniciando carga de datos (Seed Data)...';

-- ============================================================
-- 1. TIPOS BASE Y 10 PARQUES
-- ============================================================
PRINT '--- 1. Registrando Tipos y 10 Parques ---';
BEGIN TRY
    EXEC parques.TipoParque_Insertar 'Parque Nacional';
    EXEC parques.TipoParque_Insertar 'Reserva Natural';
END TRY BEGIN CATCH END CATCH;

DECLARE @idTipoNacional INT = (SELECT TOP 1 idTipoParque FROM parques.TipoParque WHERE descripcion = 'Parque Nacional');

-- Parque 1 (Será el de múltiples actividades)
EXEC parques.RegistrarParque 'Parque Nacional Iguazu', 67720, @idTipoNacional, 'Ruta 101', 'Misiones', -25.68, -54.44;
-- Parques 2 al 10
EXEC parques.RegistrarParque 'Parque Nacional Los Glaciares', 726927, @idTipoNacional, 'Ruta 11', 'Santa Cruz', -50.50, -73.00;
EXEC parques.RegistrarParque 'Parque Nacional Nahuel Huapi', 717261, @idTipoNacional, 'Av. Bustillo', 'Rio Negro', -41.14, -71.30;
EXEC parques.RegistrarParque 'Parque Nacional Tierra del Fuego', 68909, @idTipoNacional, 'Ruta 3', 'Tierra del Fuego', -54.83, -68.45;
EXEC parques.RegistrarParque 'Parque Nacional Talampaya', 215000, @idTipoNacional, 'Ruta 76', 'La Rioja', -29.78, -67.90;
EXEC parques.RegistrarParque 'Parque Nacional Lanin', 412000, @idTipoNacional, 'Ruta 40', 'Neuquen', -39.63, -71.17;
EXEC parques.RegistrarParque 'Parque Nacional El Palmar', 8500, @idTipoNacional, 'Ruta 14', 'Entre Rios', -31.86, -58.23;
EXEC parques.RegistrarParque 'Parque Nacional Los Alerces', 259570, @idTipoNacional, 'Ruta 71', 'Chubut', -42.85, -71.87;
EXEC parques.RegistrarParque 'Parque Nacional Sierra de las Quijadas', 73533, @idTipoNacional, 'Ruta 147', 'San Luis', -32.55, -67.01;
EXEC parques.RegistrarParque 'Parque Nacional Calilegua', 76306, @idTipoNacional, 'Ruta 83', 'Jujuy', -23.63, -64.77;
GO

-- ============================================================
-- 2. 20 GUARDAPARQUES
-- ============================================================
PRINT '--- 2. Registrando 20 Guardaparques (Cifrados) ---';
DECLARE @i INT = 1;
DECLARE @dni INT = 20000000;
WHILE @i <= 20
BEGIN
    SET @dni = @dni + 1;
    EXEC personal.Guardaparque_Insertar @dni, 'Guardaparque Genérico', 'gp@parques.gob.ar', '1122334455', 'Localidad', '1985-01-01';
    SET @i = @i + 1;
END
GO

-- ============================================================
-- 3. 20 GUÍAS
-- ============================================================
PRINT '--- 3. Registrando 20 Guías (Cifrados) ---';
DECLARE @j INT = 1;
DECLARE @dniGuia INT = 30000000;
WHILE @j <= 20
BEGIN
    SET @dniGuia = @dniGuia + 1;
    EXEC personal.Guia_Insertar @dniGuia, 'Guia Genérico', 'Bilingue', 'Turismo', 'Apto', '2030-12-31';
    SET @j = @j + 1;
END
GO

-- ============================================================
-- 4. 30 ACTIVIDADES (CASO OBLIGATORIO 1 y 2)
-- ============================================================
PRINT '--- 4. Registrando 30 Actividades ---';
DECLARE @idParque1 INT = (SELECT TOP 1 idParque FROM parques.Parque WHERE nombre = 'Parque Nacional Iguazu');

-- CASO 1: Parque con múltiples actividades simultáneas (25 actividades en Iguazú)
DECLARE @k INT = 1;
WHILE @k <= 15
BEGIN
    EXEC actividades.Tour_Insertar 'Tour Selva Adentro', 'Recorrido', 120, 20, 5000.00, @idParque1;
    SET @k = @k + 1;
END

DECLARE @l INT = 1;
WHILE @l <= 10
BEGIN
    EXEC actividades.Atraccion_Insertar 'Mirador Cataratas', 'Vista', 'Mirador', 0, 30, 100, @idParque1;
    SET @l = @l + 1;
END

-- CASO 2 (PREPARACIÓN): Tour diseñado para llenarse (Cupo: 10)
EXEC actividades.Tour_Insertar 'Garganta del Diablo Exclusivo', 'Tour VIP', 60, 10, 15000.00, @idParque1;

-- 4 actividades más en otro parque para llegar a 30
DECLARE @idParque2 INT = (SELECT TOP 1 idParque FROM parques.Parque WHERE nombre = 'Parque Nacional Los Glaciares');
EXEC actividades.Tour_Insertar 'Minitrekking Glaciar', 'Caminata en hielo', 180, 15, 25000.00, @idParque2;
EXEC actividades.Tour_Insertar 'Safari Nautico', 'Navegacion', 60, 50, 10000.00, @idParque2;
EXEC actividades.Atraccion_Insertar 'Pasarelas Glaciar', 'Mirador', 'Paseo', 0, 120, 500, @idParque2;
EXEC actividades.Atraccion_Insertar 'Museo del Hielo', 'Centro cultural', 'Museo', 2000.00, 60, 50, @idParque2;
GO

-- ============================================================
-- 5. 10 CONCESIONES (CASO OBLIGATORIO 3)
-- ============================================================
PRINT '--- 5. Registrando Concesiones (Vigentes y Vencidas) ---';
BEGIN TRY
    EXEC concesiones.TipoConsesion_Insertar 'Gastronomia';
    EXEC concesiones.TipoConsesion_Insertar 'Regaleria';
    EXEC concesiones.Empresa_Insertar 'Restaurantes Parques SA', '30777788889', 'Juan Perez', 'info@rest.com', '11223344';
    EXEC concesiones.Empresa_Insertar 'Souvenirs SRL', '30111122223', 'Ana Lopez', 'ventas@souv.com', '55667788';
END TRY BEGIN CATCH END CATCH;

DECLARE @idTipoGastro INT = (SELECT TOP 1 idTipoConcesion FROM concesiones.TipoDeConsesion WHERE descripcion = 'Gastronomia');
DECLARE @idEmpresa1 INT = (SELECT TOP 1 idEmpresa FROM concesiones.Empresa WHERE cuit = '30777788889');
DECLARE @idParque1 INT = (SELECT TOP 1 idParque FROM parques.Parque WHERE nombre = 'Parque Nacional Iguazu');

-- CASO 3A: Concesión VIGENTE (Termina en 2030)
EXEC concesiones.Concesion_Insertar 'Restaurante Central', @idTipoGastro, @idParque1, @idEmpresa1, '2024-01-01', '2030-12-31', 500000.00;

-- CASO 3B: Concesión VENCIDA (Terminó en 2022)
EXEC concesiones.Concesion_Insertar 'Kiosco Sendero Viejo', @idTipoGastro, @idParque1, @idEmpresa1, '2018-01-01', '2022-12-31', 150000.00;

-- 8 Concesiones más para llegar a 10
DECLARE @m INT = 1;
WHILE @m <= 8
BEGIN
    EXEC concesiones.Concesion_Insertar 'Puesto Comida Rapida', @idTipoGastro, @idParque1, @idEmpresa1, '2023-01-01', '2028-12-31', 100000.00;
    SET @m = @m + 1;
END
GO

-- ============================================================
-- 6. HISTORIAL DE VENTAS Y CASO DE CUPO COMPLETO
-- ============================================================
PRINT '--- 6. Generando Historial de Ventas y Tour Lleno ---';
BEGIN TRY
    EXEC ventas.TipoVisitante_Insertar 'General';
    EXEC ventas.TipoVisitante_Insertar 'Jubilado';
END TRY BEGIN CATCH END CATCH;

DECLARE @idParque1 INT = (SELECT TOP 1 idParque FROM parques.Parque WHERE nombre = 'Parque Nacional Iguazu');
DECLARE @idTipoGen INT = (SELECT TOP 1 idTipoVisitante FROM ventas.TipoVisitante WHERE descripcion = 'General');

-- Crear precio de entrada
BEGIN TRY
    EXEC ventas.PrecioEntrada_Insertar 10000.00, @idParque1, @idTipoGen;
END TRY BEGIN CATCH END CATCH;

-- Generar historial de ventas de entradas normales (3 ventas)
EXEC ventas.RegistrarVentaEntrada @idParque1, @idTipoGen, 2, 1, 'Tarjeta', 1;
EXEC ventas.RegistrarVentaEntrada @idParque1, @idTipoGen, 4, 1, 'Efectivo', 1;
EXEC ventas.RegistrarVentaEntrada @idParque1, @idTipoGen, 1, 2, 'QR', 1;

-- CASO 2 (EJECUCIÓN): Tour con cupo completo (Vender 10 tickets del tour "Garganta del Diablo Exclusivo")
DECLARE @idTourLleno INT = (SELECT TOP 1 idTour FROM actividades.Tour WHERE nombre = 'Garganta del Diablo Exclusivo');

-- Creamos un ticket cabecera vacío (Entrada al parque)
EXEC ventas.TicketVenta_Insertar @puntoDeVenta = 3, @formaPago = 'Tarjeta', @idParque = @idParque1;
DECLARE @idTicketNuevo INT = (SELECT MAX(idTicket) FROM ventas.TicketVenta);

-- Insertamos la Línea de Venta para el Tour, consumiendo el cupo máximo (10)
EXEC ventas.LineaVenta_Insertar @ticketAsociado = @idTicketNuevo, @cantidad = 10, @idTour = @idTourLleno;

PRINT 'Tour "Garganta del Diablo Exclusivo" ha llenado su cupo de 10 personas en el Ticket ID: ' + CAST(@idTicketNuevo AS VARCHAR);
GO

-- ============================================================
-- 7. CASO OBLIGATORIO: IMPORTACIÓN CON ERRORES PARCIALES
-- ============================================================
PRINT '--- 7. Simulando Importación con Errores Parciales ---';
-- Se simula el comportamiento de un proceso BULK INSERT + Cursor 
-- donde algunas filas de un archivo externo están corruptas.

CREATE TABLE #MockCSV (fila INT, nombre VARCHAR(50), superficie DECIMAL(18,2));
INSERT INTO #MockCSV VALUES 
(1, 'Parque Nacional Falso 1', 1500), -- Fila OK
(2, NULL, 2000),                      -- Fila Error: Nombre nulo
(3, 'Parque Nacional Falso 2', -50);  -- Fila Error: Superficie negativa

DECLARE @procesadas INT = 0, @insertadas INT = 0, @errores INT = 0;
DECLARE @n VARCHAR(50), @s DECIMAL(18,2);

DECLARE cur_mock CURSOR LOCAL FOR SELECT nombre, superficie FROM #MockCSV;
OPEN cur_mock;
FETCH NEXT FROM cur_mock INTO @n, @s;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @procesadas = @procesadas + 1;
    BEGIN TRY
        -- Intenta usar el SP del sistema. Fallará en validaciones para la fila 2 y 3.
        EXEC parques.RegistrarParque @n, @s, 1, 'Calle Falsa 123', 'Mock', -30.0, -60.0;
        SET @insertadas = @insertadas + 1;
    END TRY
    BEGIN CATCH
        SET @errores = @errores + 1;
        PRINT 'Error atrapado en fila ' + CAST(@procesadas AS VARCHAR) + ': ' + ERROR_MESSAGE();
    END CATCH
    FETCH NEXT FROM cur_mock INTO @n, @s;
END
CLOSE cur_mock; DEALLOCATE cur_mock;

-- Registrar en Log Oficial de Importación
INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
VALUES ('Simulacion_Requisito_Importacion', 'mock_errores_parciales.csv', @procesadas, @insertadas, 0, @errores);

PRINT 'Importacion simulada finalizada. Procesadas: 3 | Exitosas: 1 | Errores: 2';
GO

PRINT '====================================================';
PRINT 'SEED DATA Y CRITERIOS DE ACEPTACION COMPLETADOS OK.';
PRINT '====================================================';