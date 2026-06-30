-- =============================================
-- Un monton de datos para que cuando se muestre el reporte haya algo que ver.
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- PARTE 1: DATOS BASE (via SPs de la Entrega 5)
-- ============================================================
PRINT '=== PARTE 1: Cargando datos base ===';
GO

-- ---- Tipos de parque ----
IF NOT EXISTS (SELECT 1 FROM parques.TipoParque WHERE descripcion = 'Parque Nacional')
    EXEC parques.TipoParque_Insertar @descripcion = 'Parque Nacional';
IF NOT EXISTS (SELECT 1 FROM parques.TipoParque WHERE descripcion = 'Reserva Natural')
    EXEC parques.TipoParque_Insertar @descripcion = 'Reserva Natural';
IF NOT EXISTS (SELECT 1 FROM parques.TipoParque WHERE descripcion = 'Monumento Natural')
    EXEC parques.TipoParque_Insertar @descripcion = 'Monumento Natural';
GO

-- ---- Parques (via SP de negocio: crea Ubicacion + Parque juntos) ----
-- Se usan variables para el idTipoParque para no depender de IDs fijos.
DECLARE @idPN INT = (SELECT idTipoParque FROM parques.TipoParque WHERE descripcion = 'Parque Nacional');

IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE nombre = 'Parque Nacional Nahuel Huapi')
    EXEC parques.RegistrarParque
        @nombre='Parque Nacional Nahuel Huapi', @superficie=717261,
        @idTipoParque=@idPN, @direccion='San Carlos de Bariloche',
        @provincia='Rio Negro', @latitud=-41.050000, @longitud=-71.416667;

IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE nombre = 'Parque Nacional Iguazu')
    EXEC parques.RegistrarParque
        @nombre='Parque Nacional Iguazu', @superficie=67698,
        @idTipoParque=@idPN, @direccion='Puerto Iguazu',
        @provincia='Misiones', @latitud=-25.686944, @longitud=-54.444167;

IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE nombre = 'Parque Nacional Los Glaciares')
    EXEC parques.RegistrarParque
        @nombre='Parque Nacional Los Glaciares', @superficie=731932,
        @idTipoParque=@idPN, @direccion='El Calafate',
        @provincia='Santa Cruz', @latitud=-50.366667, @longitud=-72.883333;

IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE nombre = 'Parque Nacional Quebrada del Condorito')
    EXEC parques.RegistrarParque
        @nombre='Parque Nacional Quebrada del Condorito', @superficie=35396,
        @idTipoParque=@idPN, @direccion='Pampa de Achala',
        @provincia='Cordoba', @latitud=-31.800000, @longitud=-64.700000;
GO

-- ---- Tipos de visitante ----
IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante WHERE descripcion = 'Residente')
    EXEC ventas.TipoVisitante_Insertar @descripcion = 'Residente';
IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante WHERE descripcion = 'No Residente')
    EXEC ventas.TipoVisitante_Insertar @descripcion = 'No Residente';
IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante WHERE descripcion = 'Estudiante')
    EXEC ventas.TipoVisitante_Insertar @descripcion = 'Estudiante';
IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante WHERE descripcion = 'Jubilado')
    EXEC ventas.TipoVisitante_Insertar @descripcion = 'Jubilado';
GO

-- ---- Precios de entrada (via SP, solo si no hay precio vigente) ----
DECLARE @idParque INT, @idTV INT, @valor DECIMAL(18,2);
DECLARE @i INT;

DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT p.idParque, tv.idTipoVisitante,
           CASE tv.descripcion
               WHEN 'Residente'    THEN 10000
               WHEN 'No Residente' THEN 28000
               WHEN 'Estudiante'   THEN 5000
               WHEN 'Jubilado'     THEN 4000
           END
    FROM parques.Parque p
    CROSS JOIN ventas.TipoVisitante tv;

OPEN cur;
FETCH NEXT FROM cur INTO @idParque, @idTV, @valor;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ventas.PrecioEntrada
                   WHERE idParque=@idParque AND idTipoVisitante=@idTV AND fechaHasta IS NULL)
    BEGIN
        BEGIN TRY
            EXEC ventas.PrecioEntrada_Insertar @valor=@valor, @idParque=@idParque, @idTipoVisitante=@idTV;
        END TRY
        BEGIN CATCH
            PRINT 'Aviso precio: ' + ERROR_MESSAGE();
        END CATCH
    END
    FETCH NEXT FROM cur INTO @idParque, @idTV, @valor;
END
CLOSE cur; DEALLOCATE cur;
GO

-- ---- Tours ----
DECLARE @p1 INT = (SELECT idParque FROM parques.Parque WHERE nombre='Parque Nacional Nahuel Huapi');
DECLARE @p2 INT = (SELECT idParque FROM parques.Parque WHERE nombre='Parque Nacional Iguazu');
DECLARE @p3 INT = (SELECT idParque FROM parques.Parque WHERE nombre='Parque Nacional Los Glaciares');

IF NOT EXISTS (SELECT 1 FROM actividades.Tour WHERE nombre='Travesia Cerro Catedral')
    EXEC actividades.Tour_Insertar @nombre='Travesia Cerro Catedral', @descripcion='Caminata guiada',
        @duracion=240, @cupoMaximo=20, @precio=18000, @idParque=@p1;
IF NOT EXISTS (SELECT 1 FROM actividades.Tour WHERE nombre='Garganta del Diablo')
    EXEC actividades.Tour_Insertar @nombre='Garganta del Diablo', @descripcion='Pasarelas superiores',
        @duracion=120, @cupoMaximo=30, @precio=9000, @idParque=@p2;
IF NOT EXISTS (SELECT 1 FROM actividades.Tour WHERE nombre='Minitrekking Perito Moreno')
    EXEC actividades.Tour_Insertar @nombre='Minitrekking Perito Moreno', @descripcion='Caminata sobre glaciar',
        @duracion=300, @cupoMaximo=15, @precio=45000, @idParque=@p3;
GO

-- ---- Atracciones ----
DECLARE @p1 INT = (SELECT idParque FROM parques.Parque WHERE nombre='Parque Nacional Iguazu');
IF NOT EXISTS (SELECT 1 FROM actividades.Atraccion WHERE nombre='Paseo en lancha Isla San Martin')
    EXEC actividades.Atraccion_Insertar @nombre='Paseo en lancha Isla San Martin', @descripcion='Navegacion',
        @tipo='Nautica', @precio=14000, @duracion=60, @cupoMaximo=40, @idParque=@p1;
GO

PRINT '=== Datos base cargados ===';
GO

-- ============================================================
-- PARTE 2: VENTAS HISTORICAS (fechas distribuidas en 12 meses)
-- Insercion directa para poder fijar la fecha (los SPs usan GETDATE).
-- Se replica la logica de los SPs: nroTicket por PV, subtotal y total.
-- ============================================================
PRINT '=== PARTE 2: Generando ventas historicas ===';
GO

-- Limpieza de ventas previas (para poder re-ejecutar sin duplicar)
DELETE FROM ventas.LineaVenta;
DELETE FROM ventas.TicketVenta;
DBCC CHECKIDENT ('ventas.LineaVenta', RESEED, 0);
DBCC CHECKIDENT ('ventas.TicketVenta', RESEED, 0);
GO

SET NOCOUNT ON;

DECLARE @hoy DATE = CAST(GETDATE() AS DATE);
DECLARE @mesOffset INT = 11;   -- arranca 11 meses atras y avanza hasta el mes actual
DECLARE @nroTicketPV INT;       -- nro de ticket por punto de venta (PV unico = 1)
DECLARE @idTicket INT;
DECLARE @fechaTicket DATETIME;
DECLARE @idParque INT;
DECLARE @idPrecio INT;
DECLARE @valor DECIMAL(18,2);
DECLARE @cant INT;
DECLARE @ventasDelMes INT;
DECLARE @v INT;
DECLARE @semilla INT;

-- Para variar el volumen por parque y darle forma a la tendencia
-- (mas visitas en meses de verano: dic, ene, feb; menos en invierno)
DECLARE @nroTicketGlobal INT = 0;

WHILE @mesOffset >= 0
BEGIN
    -- Primer dia del mes objetivo
    DECLARE @primerDiaMes DATE = DATEFROMPARTS(
        YEAR(DATEADD(MONTH, -@mesOffset, @hoy)),
        MONTH(DATEADD(MONTH, -@mesOffset, @hoy)),
        1);
    DECLARE @mesNum INT = MONTH(@primerDiaMes);

    -- Factor estacional: verano (12,1,2) mas alto, invierno (6,7,8) mas bajo
    DECLARE @factor INT =
        CASE
            WHEN @mesNum IN (12, 1, 2) THEN 8   -- verano: alta temporada
            WHEN @mesNum IN (3, 4, 11) THEN 5   -- media
            WHEN @mesNum IN (5, 9, 10) THEN 4
            WHEN @mesNum IN (6, 7, 8)  THEN 6   -- invierno: vacaciones de julio sube algo
            ELSE 4
        END;

    -- Recorrer cada parque
    DECLARE curP CURSOR LOCAL FAST_FORWARD FOR
        SELECT idParque FROM parques.Parque ORDER BY idParque;
    OPEN curP;
    FETCH NEXT FROM curP INTO @idParque;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Cantidad de tickets de venta de este parque en este mes
        SET @ventasDelMes = @factor + (@idParque % 3);  -- algo de variacion por parque

        SET @v = 1;
        WHILE @v <= @ventasDelMes
        BEGIN
            -- Fecha del ticket: dia pseudo-aleatorio dentro del mes
            SET @fechaTicket = DATEADD(
                DAY,
                ((@v * 7 + @idParque * 3) % 27),   -- dia 0..27
                CAST(@primerDiaMes AS DATETIME));
            -- Hora variada
            SET @fechaTicket = DATEADD(HOUR, (9 + (@v % 8)), @fechaTicket);

            SET @nroTicketGlobal = @nroTicketGlobal + 1;

            -- Crear el ticket (punto de venta 1 para todos, nro incremental)
            INSERT INTO ventas.TicketVenta
                (fechaHora, total, puntoDeVenta, nroTicket, formaPago, idParque)
            VALUES
                (@fechaTicket, 0, 1, @nroTicketGlobal,
                 CASE (@v % 3) WHEN 0 THEN 'Efectivo' WHEN 1 THEN 'Tarjeta de credito' ELSE 'QR' END,
                 @idParque);
            SET @idTicket = SCOPE_IDENTITY();

            -- Agregar 1 a 3 lineas de entrada (distintos tipos de visitante)
            DECLARE @lineas INT = 1 + (@v % 3);
            DECLARE @l INT = 1;
            WHILE @l <= @lineas
            BEGIN
                -- Elegir un precio vigente del parque (rotando tipo de visitante)
                SELECT TOP 1 @idPrecio = pe.idPrecio, @valor = pe.valor
                FROM ventas.PrecioEntrada pe
                WHERE pe.idParque = @idParque AND pe.fechaHasta IS NULL
                ORDER BY (pe.idTipoVisitante + @l + @v) % 4, pe.idPrecio;

                IF @idPrecio IS NOT NULL
                BEGIN
                    SET @cant = 1 + ((@v + @l) % 5);  -- entre 1 y 5 entradas
                    INSERT INTO ventas.LineaVenta
                        (ticketAsociado, descripcion, subtotal, cantidad, precioUnitario,
                         idPrecioEntrada, idTour, idAtraccion)
                    VALUES
                        (@idTicket, 'Entrada', @cant * @valor, @cant, @valor,
                         @idPrecio, NULL, NULL);
                END
                SET @l = @l + 1;
            END

            -- Recalcular total del ticket (como hace el SP)
            UPDATE ventas.TicketVenta
            SET total = (SELECT ISNULL(SUM(subtotal),0)
                         FROM ventas.LineaVenta WHERE ticketAsociado = @idTicket)
            WHERE idTicket = @idTicket;

            SET @v = @v + 1;
        END

        FETCH NEXT FROM curP INTO @idParque;
    END
    CLOSE curP; DEALLOCATE curP;

    SET @mesOffset = @mesOffset - 1;
END
GO

PRINT '=== Ventas historicas generadas ===';
GO

-- ============================================================
-- VERIFICACION: ver la distribucion temporal generada
-- ============================================================
PRINT '--- Tickets por mes ---';
SELECT
    YEAR(fechaHora)  AS anio,
    MONTH(fechaHora) AS mes,
    COUNT(*)         AS cantidadTickets,
    SUM(total)       AS ingresoTotal
FROM ventas.TicketVenta
GROUP BY YEAR(fechaHora), MONTH(fechaHora)
ORDER BY anio, mes;
GO

PRINT '--- Visitas por parque y mes (igual que el reporte) ---';
SELECT
    p.nombre                AS parque,
    YEAR(tv.fechaHora)      AS anio,
    MONTH(tv.fechaHora)     AS mes,
    SUM(lv.cantidad)        AS visitantes
FROM ventas.LineaVenta lv
INNER JOIN ventas.TicketVenta tv ON tv.idTicket = lv.ticketAsociado
INNER JOIN parques.Parque p      ON p.idParque = tv.idParque
WHERE lv.idPrecioEntrada IS NOT NULL
GROUP BY p.nombre, YEAR(tv.fechaHora), MONTH(tv.fechaHora)
ORDER BY p.nombre, anio, mes;
GO

PRINT '=== Listo. Ejecuta el reporte o refresca Power BI. ===';
GO
