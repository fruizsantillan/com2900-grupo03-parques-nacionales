-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Stored Procedures de logica de negocio - modulo Concesiones.
--   SP 1: sp_AltaConcesionCompleta
--         Registra una nueva concesion validando integridad entre
--         empresa, parque, tipo y solapamiento de vigencias.
--   SP 2: sp_RegistrarPagoCanon
--         Registra el pago mensual del canon validando que la
--         concesion este vigente y que no exista pago duplicado
--         para el mismo periodo.
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: sp_AltaConcesionCompleta
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
-- SP: sp_RegistrarPagoCanon
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
