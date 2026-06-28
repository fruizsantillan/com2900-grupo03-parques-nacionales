-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 27/06/2026
-- Descripcion: Entrega 5 (3/3) - Stored Procedures de LOGICA DE NEGOCIO.
--   Operaciones que afectan varias tablas, encapsuladas en transacciones
--   que garantizan la integridad de los datos.
--   Incluye: RegistrarParque, RegistrarGuardaparque, ReasignarGuardaparque,
--            RegistrarEgresoGuardaparque, AltaConcesionCompleta,
--            RegistrarPagoCanon, RegistrarVentaEntrada, ActualizarPrecioEntrada,
--            AsignarGuiaATour, RegistrarAtraccion.
-- Prerequisito: Ejecutar 01_tablas_y_schemas.sql y 02_sp_abm.sql.
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- REGISTRAR PARQUE
-- Da de alta la Ubicacion y el Parque en una sola transaccion,
-- evitando que quede un parque sin ubicacion o una ubicacion huerfana.
-- ============================================================
CREATE OR ALTER PROCEDURE parques.RegistrarParque
    @nombre       VARCHAR(100),
    @superficie   DECIMAL(18,2),
    @idTipoParque INT,
    @direccion    VARCHAR(100),
    @provincia    VARCHAR(50),
    @latitud      DECIMAL(9,6),
    @longitud     DECIMAL(9,6)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @vErrores     NVARCHAR(MAX) = '';
    DECLARE @vIdUbicacion INT;
    DECLARE @vIdParque    INT;

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores += '- El nombre del parque es obligatorio.' + CHAR(13);
    ELSE IF EXISTS (SELECT 1 FROM parques.Parque WHERE nombre = LTRIM(RTRIM(@nombre)))
        SET @vErrores += '- Ya existe un parque con ese nombre.' + CHAR(13);

    IF @superficie IS NULL OR @superficie <= 0
        SET @vErrores += '- La superficie debe ser mayor a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TipoParque WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- El tipo de parque indicado no existe.' + CHAR(13);

    IF @direccion IS NULL OR LTRIM(RTRIM(@direccion)) = ''
        SET @vErrores += '- La direccion es obligatoria.' + CHAR(13);

    IF @provincia IS NULL OR LTRIM(RTRIM(@provincia)) = ''
        SET @vErrores += '- La provincia es obligatoria.' + CHAR(13);

    IF @latitud IS NULL OR @latitud NOT BETWEEN -90 AND 90
        SET @vErrores += '- La latitud debe estar entre -90 y 90.' + CHAR(13);

    IF @longitud IS NULL OR @longitud NOT BETWEEN -180 AND 180
        SET @vErrores += '- La longitud debe estar entre -180 y 180.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO parques.Ubicacion (direccion, provincia, latitud, longitud)
        VALUES (LTRIM(RTRIM(@direccion)), LTRIM(RTRIM(@provincia)), @latitud, @longitud);

        SET @vIdUbicacion = SCOPE_IDENTITY();

        INSERT INTO parques.Parque (nombre, superficie, idTipoParque, idUbicacion)
        VALUES (LTRIM(RTRIM(@nombre)), @superficie, @idTipoParque, @vIdUbicacion);

        SET @vIdParque = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        PRINT 'Parque registrado con ID: ' + CAST(@vIdParque AS VARCHAR)
            + ' (Ubicacion ID: ' + CAST(@vIdUbicacion AS VARCHAR) + ').';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ============================================================
-- REGISTRAR GUARDAPARQUE
-- Alta completa: crea el Guardaparque y su primera asignacion
-- (parque + fecha de ingreso) en una transaccion, para que no
-- quede personal sin parque asignado.
-- ============================================================
CREATE OR ALTER PROCEDURE personal.RegistrarGuardaparque
    @dni             INT,
    @apyn            VARCHAR(50),
    @idParque        INT,
    @fechaInicio     DATE,
    @email           VARCHAR(100) = NULL,
    @telefono        VARCHAR(50)  = NULL,
    @localidad       VARCHAR(50)  = NULL,
    @fechaNacimiento DATETIME     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @dni IS NULL OR @dni <= 0
        SET @vErrores += '- El DNI es obligatorio y debe ser mayor a 0.' + CHAR(13);
    ELSE IF EXISTS (SELECT 1 FROM personal.Guardaparque WHERE dni = @dni)
        SET @vErrores += '- Ya existe un guardaparque registrado con ese DNI.' + CHAR(13);

    IF @apyn IS NULL OR LTRIM(RTRIM(@apyn)) = ''
        SET @vErrores += '- El apellido y nombre es obligatorio.' + CHAR(13);

    IF @email IS NOT NULL AND @email NOT LIKE '%@%.%'
        SET @vErrores += '- El formato del email no es valido.' + CHAR(13);

    IF @fechaNacimiento IS NOT NULL AND @fechaNacimiento > GETDATE()
        SET @vErrores += '- La fecha de nacimiento no puede ser futura.' + CHAR(13);

    IF @fechaInicio IS NULL
        SET @vErrores += '- La fecha de ingreso es obligatoria.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO personal.Guardaparque (dni, apyn, email, telefono, localidad, fechaNacimiento)
        VALUES (@dni, LTRIM(RTRIM(@apyn)), @email, @telefono, @localidad, @fechaNacimiento);

        INSERT INTO personal.AsignacionGuardaparque (fechaInicio, fechaFin, motivoEgreso, idParque, dni)
        VALUES (@fechaInicio, NULL, NULL, @idParque, @dni);

        COMMIT TRANSACTION;

        PRINT 'Guardaparque ' + CAST(@dni AS VARCHAR)
            + ' registrado y asignado al parque ' + CAST(@idParque AS VARCHAR) + '.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ============================================================
-- REASIGNAR GUARDAPARQUE
-- Cierra la asignacion vigente (le pone fechaFin y motivo) y abre
-- una nueva en el parque destino, en una sola transaccion. Asi el
-- guardaparque nunca queda sin asignacion ni con dos vigentes.
-- ============================================================
CREATE OR ALTER PROCEDURE personal.ReasignarGuardaparque
    @dni               INT,
    @idParqueDestino   INT,
    @fechaReasignacion DATE,
    @motivoEgreso      VARCHAR(255) = 'Reasignacion'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @vErrores            NVARCHAR(MAX) = '';
    DECLARE @vIdAsignacionActual INT;
    DECLARE @vIdParqueActual     INT;
    DECLARE @vFechaInicioActual  DATE;

    -- Datos de la asignacion vigente (fechaFin NULL)
    SELECT @vIdAsignacionActual = idAsignacion,
           @vIdParqueActual     = idParque,
           @vFechaInicioActual  = fechaInicio
    FROM personal.AsignacionGuardaparque
    WHERE dni = @dni AND fechaFin IS NULL;

    IF NOT EXISTS (SELECT 1 FROM personal.Guardaparque WHERE dni = @dni)
        SET @vErrores += '- El guardaparque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParqueDestino)
        SET @vErrores += '- El parque destino indicado no existe.' + CHAR(13);

    IF @fechaReasignacion IS NULL
        SET @vErrores += '- La fecha de reasignacion es obligatoria.' + CHAR(13);

    IF @vIdAsignacionActual IS NULL
        SET @vErrores += '- El guardaparque no tiene una asignacion vigente para reasignar.' + CHAR(13);
    ELSE
    BEGIN
        IF @idParqueDestino = @vIdParqueActual
            SET @vErrores += '- El parque destino es el mismo que el parque actual.' + CHAR(13);

        IF @fechaReasignacion < @vFechaInicioActual
            SET @vErrores += '- La fecha de reasignacion no puede ser anterior al inicio de la asignacion vigente.' + CHAR(13);
    END

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Cierra la asignacion vigente (antes de abrir la nueva,
        --    para no violar el indice unico de asignacion activa).
        UPDATE personal.AsignacionGuardaparque
        SET fechaFin     = @fechaReasignacion,
            motivoEgreso = @motivoEgreso
        WHERE idAsignacion = @vIdAsignacionActual;

        -- 2. Abre la nueva asignacion en el parque destino.
        INSERT INTO personal.AsignacionGuardaparque (fechaInicio, fechaFin, motivoEgreso, idParque, dni)
        VALUES (@fechaReasignacion, NULL, NULL, @idParqueDestino, @dni);

        COMMIT TRANSACTION;

        PRINT 'Guardaparque ' + CAST(@dni AS VARCHAR) + ' reasignado del parque '
            + CAST(@vIdParqueActual AS VARCHAR) + ' al parque '
            + CAST(@idParqueDestino AS VARCHAR) + '.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ============================================================
-- REGISTRAR EGRESO DE GUARDAPARQUE
-- Cierra la asignacion vigente con fecha y motivo de egreso,
-- sin abrir una nueva (baja definitiva del parque).
-- ============================================================
CREATE OR ALTER PROCEDURE personal.RegistrarEgresoGuardaparque
    @dni          INT,
    @fechaEgreso  DATE,
    @motivoEgreso VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @vErrores            NVARCHAR(MAX) = '';
    DECLARE @vIdAsignacionActual INT;
    DECLARE @vFechaInicioActual  DATE;

    SELECT @vIdAsignacionActual = idAsignacion,
           @vFechaInicioActual  = fechaInicio
    FROM personal.AsignacionGuardaparque
    WHERE dni = @dni AND fechaFin IS NULL;

    IF NOT EXISTS (SELECT 1 FROM personal.Guardaparque WHERE dni = @dni)
        SET @vErrores += '- El guardaparque indicado no existe.' + CHAR(13);

    IF @fechaEgreso IS NULL
        SET @vErrores += '- La fecha de egreso es obligatoria.' + CHAR(13);

    IF @motivoEgreso IS NULL OR LTRIM(RTRIM(@motivoEgreso)) = ''
        SET @vErrores += '- El motivo de egreso es obligatorio.' + CHAR(13);

    IF @vIdAsignacionActual IS NULL
        SET @vErrores += '- El guardaparque no tiene una asignacion vigente (ya egreso o nunca fue asignado).' + CHAR(13);
    ELSE IF @fechaEgreso < @vFechaInicioActual
        SET @vErrores += '- La fecha de egreso no puede ser anterior al inicio de la asignacion vigente.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE personal.AsignacionGuardaparque
        SET fechaFin     = @fechaEgreso,
            motivoEgreso = LTRIM(RTRIM(@motivoEgreso))
        WHERE idAsignacion = @vIdAsignacionActual;

        COMMIT TRANSACTION;

        PRINT 'Egreso registrado para el guardaparque ' + CAST(@dni AS VARCHAR) + '.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ============================================================
-- 04 - NEGOCIO: Concesiones
-- ============================================================

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Stored Procedures de logica de negocio - modulo Concesiones.
--   SP 1: AltaConcesionCompleta
--         Registra una nueva concesion validando integridad entre
--         empresa, parque, tipo y solapamiento de vigencias.
--   SP 2: RegistrarPagoCanon
--         Registra el pago mensual del canon validando que la
--         concesion este vigente y que no exista pago duplicado
--         para el mismo periodo.
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: AltaConcesionCompleta
-- Logica de negocio: alta de concesion con validaciones cruzadas
-- Validaciones:
--   1. Descripcion obligatoria
--   2. Empresa debe existir en el sistema
--   3. Parque debe existir en el sistema
--   4. Tipo de concesion debe existir
--   5. fechaFin debe ser posterior a fechaInicio
--   6. canonMensual debe ser mayor a cero
--   7. No puede existir otra concesion vigente para la misma
--      combinacion empresa + parque + tipo de actividad
-- ============================================================
CREATE OR ALTER PROCEDURE concesiones.AltaConcesionCompleta
    @descripcion     VARCHAR(100),
    @idTipoConcesion INT,
    @idParque        INT,
    @idEmpresa       INT,
    @fechaInicio     DATE,
    @fechaFin        DATE,
    @canonMensual    DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    -- Validacion 1: Descripcion obligatoria
    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion de la concesion es obligatoria.' + CHAR(13);

    -- Validacion 2: Empresa existe
    IF NOT EXISTS (SELECT 1 FROM concesiones.Empresa WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- La empresa indicada no existe en el sistema.' + CHAR(13);

    -- Validacion 3: Parque existe
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe en el sistema.' + CHAR(13);

    -- Validacion 4: Tipo de concesion existe
    IF NOT EXISTS (SELECT 1 FROM concesiones.TipoDeConsesion WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- El tipo de concesion indicado no existe.' + CHAR(13);

    -- Validacion 5: Rango de fechas valido
    IF @fechaFin <= @fechaInicio
        SET @vErrores += '- La fecha de fin debe ser posterior a la fecha de inicio.' + CHAR(13);

    -- Validacion 6: Canon valido
    IF @canonMensual <= 0
        SET @vErrores += '- El canon mensual debe ser mayor a cero.' + CHAR(13);

    -- Validacion 7: Solapamiento de concesion vigente
    IF EXISTS (
        SELECT 1 FROM concesiones.Concesion
        WHERE idEmpresa       = @idEmpresa
          AND idParque        = @idParque
          AND idTipoConcesion = @idTipoConcesion
          AND fechaFin        >= CAST(GETDATE() AS DATE)
    )
        SET @vErrores += '- Ya existe una concesion vigente para esa empresa, parque y tipo de actividad. '
                       + 'Debe vencer la anterior antes de registrar una nueva.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO concesiones.Concesion
            (descripcion, idTipoConcesion, idParque, idEmpresa, fechaInicio, fechaFin, canonMensual)
        VALUES
            (LTRIM(RTRIM(@descripcion)), @idTipoConcesion, @idParque, @idEmpresa,
             @fechaInicio, @fechaFin, @canonMensual);

        DECLARE @vIdNuevo INT = SCOPE_IDENTITY();
        COMMIT TRANSACTION;

        PRINT 'Concesion registrada exitosamente con ID: ' + CAST(@vIdNuevo AS VARCHAR);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

-- ============================================================
-- SP: RegistrarPagoCanon
-- Logica de negocio: pago mensual del canon de una concesion
-- Validaciones:
--   1. La concesion debe existir
--   2. La concesion no debe estar vencida (fechaFin >= hoy)
--   3. El periodo de pago debe estar dentro del rango de la concesion
--   4. No debe existir pago previo para el mismo periodo
--   5. El monto debe ser mayor a cero
--   6. El mes del periodo debe estar entre 1 y 12
--   7. El anio del periodo no puede ser anterior a 2020
-- ============================================================
CREATE OR ALTER PROCEDURE concesiones.RegistrarPagoCanon
    @idConcesion INT,
    @monto       DECIMAL(18,2),
    @fechaPago   DATE,
    @periodoAnio INT,
    @periodoMes  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores     NVARCHAR(MAX) = '';
    DECLARE @vFechaInicio DATE;
    DECLARE @vFechaFin    DATE;

    -- Obtener datos de la concesion
    SELECT @vFechaInicio = fechaInicio,
           @vFechaFin    = fechaFin
    FROM concesiones.Concesion
    WHERE idConcesion = @idConcesion;

    -- Validacion 1: La concesion existe
    IF @vFechaInicio IS NULL
    BEGIN
        RAISERROR('- No existe una concesion con el ID indicado.', 16, 1);
        RETURN;
    END

    -- Validacion 2: La concesion no esta vencida
    IF @vFechaFin < CAST(GETDATE() AS DATE)
        SET @vErrores += '- La concesion esta vencida (fecha de fin: '
                       + CONVERT(VARCHAR(10), @vFechaFin, 103)
                       + '). No se pueden registrar nuevos pagos.' + CHAR(13);

    -- Validacion 3: El periodo esta dentro del rango de la concesion
    IF @periodoMes BETWEEN 1 AND 12 AND @periodoAnio >= 2020
    BEGIN
        DECLARE @vFechaPeriodo DATE = DATEFROMPARTS(@periodoAnio, @periodoMes, 1);

        IF @vFechaPeriodo < DATEFROMPARTS(YEAR(@vFechaInicio), MONTH(@vFechaInicio), 1)
            SET @vErrores += '- El periodo indicado es anterior al inicio de la concesion ('
                           + CONVERT(VARCHAR(7), @vFechaInicio, 120) + ').' + CHAR(13);

        IF @vFechaPeriodo > DATEFROMPARTS(YEAR(@vFechaFin), MONTH(@vFechaFin), 1)
            SET @vErrores += '- El periodo indicado es posterior al vencimiento de la concesion ('
                           + CONVERT(VARCHAR(7), @vFechaFin, 120) + ').' + CHAR(13);
    END

    -- Validacion 4: Pago duplicado para el mismo periodo
    IF EXISTS (
        SELECT 1 FROM concesiones.PagoConcesion
        WHERE idConcesion = @idConcesion
          AND periodoAnio = @periodoAnio
          AND periodoMes  = @periodoMes
    )
        SET @vErrores += '- Ya existe un pago registrado para esta concesion en el periodo '
                       + CAST(@periodoMes AS VARCHAR) + '/' + CAST(@periodoAnio AS VARCHAR) + '.' + CHAR(13);

    -- Validacion 5: Monto valido
    IF @monto <= 0
        SET @vErrores += '- El monto debe ser mayor a cero.' + CHAR(13);

    -- Validacion 6: Mes valido
    IF @periodoMes NOT BETWEEN 1 AND 12
        SET @vErrores += '- El mes del periodo debe estar entre 1 y 12.' + CHAR(13);

    -- Validacion 7: Anio valido
    IF @periodoAnio < 2020
        SET @vErrores += '- El anio del periodo no puede ser anterior a 2020.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO concesiones.PagoConcesion
            (idConcesion, monto, fechaPago, periodoAnio, periodoMes)
        VALUES
            (@idConcesion, @monto, @fechaPago, @periodoAnio, @periodoMes);

        COMMIT TRANSACTION;
        PRINT 'Pago de canon registrado correctamente. ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

-- ============================================================
-- 04 - NEGOCIO: Ventas
-- ============================================================

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
CREATE OR ALTER PROCEDURE ventas.RegistrarVentaEntrada
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
CREATE OR ALTER PROCEDURE ventas.ActualizarPrecioEntrada
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
-- ============================================================
-- 04 - NEGOCIO: Guias, Tours y Atracciones
-- ============================================================

-- =============================================
-- Universidad: Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Comisión: 01-2900 | Grupo 03
-- Integrantes: Del Vecchio Fabrizio, Ocampos Horacio,
--              Ruiz Santillán Facundo, Lago Franco Nehuen
-- Fecha: 15/06/2026
-- Descripción: SPs de lógica de negocio - Guías, Tours y Atracciones
-- =============================================

USE ParquesNacionales;
GO

-- ==========================================
-- SP NEGOCIO: Asignar guía a tour
-- Valida: vigencia, superposición de fechas
-- ==========================================
CREATE OR ALTER PROCEDURE personal.AsignarGuiaATour
    @idTour      INT,
    @dniGuia     INT,
    @fechaInicio DATE,
    @fechaFin    DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';
    DECLARE @vVigencia DATE;

    -- Validar que el tour existe
    IF NOT EXISTS (SELECT 1 FROM actividades.Tour WHERE idTour = @idTour)
        SET @vErrores += '- El tour especificado no existe.' + CHAR(13);

    -- Validar que el guía existe
    IF NOT EXISTS (SELECT 1 FROM personal.Guia WHERE dni = @dniGuia)
        SET @vErrores += '- El guía especificado no existe.' + CHAR(13);

    -- Validar fechas
    IF @fechaInicio IS NULL OR @fechaFin IS NULL
        SET @vErrores += '- Las fechas de inicio y fin son obligatorias.' + CHAR(13);
    IF @fechaInicio IS NOT NULL AND @fechaFin IS NOT NULL AND @fechaFin < @fechaInicio
        SET @vErrores += '- La fecha de fin no puede ser anterior a la fecha de inicio.' + CHAR(13);

    -- Validar vigencia de autorización del guía
    SELECT @vVigencia = vigenciaAutorizacion FROM personal.Guia WHERE dni = @dniGuia;
    IF @vVigencia IS NOT NULL AND @fechaFin IS NOT NULL AND @vVigencia < @fechaFin
        SET @vErrores += '- La autorización del guía vence antes de que finalice la asignación.' + CHAR(13);

    -- Validar superposición de fechas para ese guía
    IF @dniGuia IS NOT NULL AND @fechaInicio IS NOT NULL AND @fechaFin IS NOT NULL AND EXISTS (
        SELECT 1 FROM personal.AsignacionGuia
        WHERE dniGuia = @dniGuia
          AND @fechaInicio <= fechaFin
          AND @fechaFin >= fechaInicio
    )
        SET @vErrores += '- El guía ya tiene una asignación en ese período de fechas.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO personal.AsignacionGuia (idTour, dniGuia, fechaInicio, fechaFin)
        VALUES (@idTour, @dniGuia, @fechaInicio, @fechaFin);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- ==========================================
-- SP NEGOCIO: Registrar atracción en un parque
-- ==========================================
CREATE OR ALTER PROCEDURE actividades.RegistrarAtraccion
    @nombre         VARCHAR(100),
    @descripcion    VARCHAR(255) = NULL,
    @tipo           VARCHAR(50)  = NULL,
    @precio         DECIMAL(18,2) = 0,
    @duracion       INT,
    @cupoMaximo     INT,
    @idParque       INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores += '- El nombre de la atracción es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores += '- La duración debe ser mayor a 0 minutos.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores += '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio IS NULL OR @precio < 0
        SET @vErrores += '- El precio no puede ser negativo.' + CHAR(13);
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores += '- El parque especificado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO actividades.Atraccion (nombre, descripcion, tipo, precio, duracion, cupoMaximo, idParque)
        VALUES (@nombre, @descripcion, @tipo, @precio, @duracion, @cupoMaximo, @idParque);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
