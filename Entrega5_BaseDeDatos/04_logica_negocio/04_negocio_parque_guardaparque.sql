-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 16/06/2026
-- Descripcion: Stored Procedures de LOGICA DE NEGOCIO del modulo Parques.
--              Operaciones que afectan varias tablas, encapsuladas en
--              transacciones que garantizan la integridad de los datos.
--              SPs: sp_RegistrarParque             (Ubicacion + Parque)
--                   sp_RegistrarGuardaparque       (Guardaparque + 1er Asignacion)
--                   sp_ReasignarGuardaparque       (cierra asignacion + abre nueva)
--                   sp_RegistrarEgresoGuardaparque (cierra asignacion vigente)
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
