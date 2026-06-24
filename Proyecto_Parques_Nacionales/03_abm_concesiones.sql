-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Stored Procedures de ABM para el modulo Concesiones.
--              SPs: TipoDeConsesion (Insertar/Eliminar/Actualizar)
--                   Empresa         (Insertar/Eliminar/Actualizar)
--                   Concesion       (Insertar/Eliminar/Actualizar)
--                   PagoConcesion   (Insertar/Eliminar/Actualizar)
-- Notas: Ninguna operacion accede directamente a las tablas.
--        Cada SP reune todos los errores en un unico mensaje.
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- TIPO DE CONCESION
-- ============================================================

CREATE OR ALTER PROCEDURE concesiones.TipoConsesion_Insertar
    @descripcion VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion del tipo de concesion es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM concesiones.TipoDeConsesion
               WHERE descripcion = LTRIM(RTRIM(@descripcion)))
        SET @vErrores += '- Ya existe un tipo de concesion con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO concesiones.TipoDeConsesion (descripcion)
    VALUES (LTRIM(RTRIM(@descripcion)));

    PRINT 'Tipo de concesion creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE concesiones.TipoConsesion_Eliminar
    @idTipoConcesion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM concesiones.TipoDeConsesion
                   WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- No existe un tipo de concesion con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM concesiones.Concesion
               WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- No se puede eliminar: existen concesiones asociadas a este tipo.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM concesiones.TipoDeConsesion WHERE idTipoConcesion = @idTipoConcesion;
    PRINT 'Tipo de concesion eliminado.';
END
GO

CREATE OR ALTER PROCEDURE concesiones.TipoConsesion_Actualizar
    @idTipoConcesion INT,
    @descripcion     VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM concesiones.TipoDeConsesion
                   WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- No existe un tipo de concesion con el ID indicado.' + CHAR(13);

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM concesiones.TipoDeConsesion
               WHERE descripcion = LTRIM(RTRIM(@descripcion))
                 AND idTipoConcesion != @idTipoConcesion)
        SET @vErrores += '- Ya existe otro tipo de concesion con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE concesiones.TipoDeConsesion
    SET descripcion = LTRIM(RTRIM(@descripcion))
    WHERE idTipoConcesion = @idTipoConcesion;

    PRINT 'Tipo de concesion actualizado.';
END
GO

-- ============================================================
-- EMPRESA
-- ============================================================

CREATE OR ALTER PROCEDURE concesiones.Empresa_Insertar
    @razonSocial  VARCHAR(200),
    @cuit         VARCHAR(20),
    @contacto     VARCHAR(100) = NULL,
    @email        VARCHAR(100) = NULL,
    @telefono     VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @razonSocial IS NULL OR LTRIM(RTRIM(@razonSocial)) = ''
        SET @vErrores += '- La razon social es obligatoria.' + CHAR(13);

    IF @cuit IS NULL OR LTRIM(RTRIM(@cuit)) = ''
        SET @vErrores += '- El CUIT es obligatorio.' + CHAR(13);
    ELSE
    BEGIN
        IF LEN(LTRIM(RTRIM(@cuit))) != 11
            SET @vErrores += '- El CUIT debe tener exactamente 11 digitos.' + CHAR(13);

        IF EXISTS (SELECT 1 FROM concesiones.Empresa
                   WHERE cuit = LTRIM(RTRIM(@cuit)))
            SET @vErrores += '- Ya existe una empresa registrada con ese CUIT.' + CHAR(13);
    END

    IF @email IS NOT NULL AND @email NOT LIKE '%@%.%'
        SET @vErrores += '- El formato del email no es valido.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO concesiones.Empresa (razonSocial, cuit, contacto, email, telefono)
    VALUES (LTRIM(RTRIM(@razonSocial)), LTRIM(RTRIM(@cuit)), @contacto, @email, @telefono);

    PRINT 'Empresa registrada con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE concesiones.Empresa_Eliminar
    @idEmpresa INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM concesiones.Empresa
                   WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- No existe una empresa con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM concesiones.Concesion
               WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- No se puede eliminar la empresa: tiene concesiones registradas.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM concesiones.Empresa WHERE idEmpresa = @idEmpresa;
    PRINT 'Empresa eliminada.';
END
GO

CREATE OR ALTER PROCEDURE concesiones.Empresa_Actualizar
    @idEmpresa    INT,
    @razonSocial  VARCHAR(200),
    @cuit         VARCHAR(20),
    @contacto     VARCHAR(100) = NULL,
    @email        VARCHAR(100) = NULL,
    @telefono     VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM concesiones.Empresa
                   WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- No existe una empresa con el ID indicado.' + CHAR(13);

    IF @razonSocial IS NULL OR LTRIM(RTRIM(@razonSocial)) = ''
        SET @vErrores += '- La razon social es obligatoria.' + CHAR(13);

    IF @cuit IS NULL OR LTRIM(RTRIM(@cuit)) = ''
        SET @vErrores += '- El CUIT es obligatorio.' + CHAR(13);
    ELSE
    BEGIN
        IF LEN(LTRIM(RTRIM(@cuit))) != 11
            SET @vErrores += '- El CUIT debe tener exactamente 11 digitos.' + CHAR(13);

        IF EXISTS (SELECT 1 FROM concesiones.Empresa
                   WHERE cuit = LTRIM(RTRIM(@cuit))
                     AND idEmpresa != @idEmpresa)
            SET @vErrores += '- Ya existe otra empresa registrada con ese CUIT.' + CHAR(13);
    END

    IF @email IS NOT NULL AND @email NOT LIKE '%@%.%'
        SET @vErrores += '- El formato del email no es valido.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE concesiones.Empresa
    SET razonSocial = LTRIM(RTRIM(@razonSocial)),
        cuit        = LTRIM(RTRIM(@cuit)),
        contacto    = @contacto,
        email       = @email,
        telefono    = @telefono
    WHERE idEmpresa = @idEmpresa;

    PRINT 'Empresa actualizada.';
END
GO

-- ============================================================
-- CONCESION
-- ============================================================

CREATE OR ALTER PROCEDURE concesiones.Concesion_Insertar
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

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM concesiones.TipoDeConsesion
                   WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- El tipo de concesion indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM concesiones.Empresa
                   WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- La empresa indicada no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF @fechaFin <= @fechaInicio
        SET @vErrores += '- La fecha de fin debe ser posterior a la fecha de inicio.' + CHAR(13);

    IF @canonMensual <= 0
        SET @vErrores += '- El canon mensual debe ser mayor a cero.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO concesiones.Concesion
        (descripcion, idTipoConcesion, idParque, idEmpresa, fechaInicio, fechaFin, canonMensual)
    VALUES
        (@descripcion, @idTipoConcesion, @idParque, @idEmpresa, @fechaInicio, @fechaFin, @canonMensual);

    PRINT 'Concesion registrada con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE concesiones.Concesion_Eliminar
    @idConcesion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM concesiones.Concesion
                   WHERE idConcesion = @idConcesion)
        SET @vErrores += '- No existe una concesion con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM concesiones.PagoConcesion
               WHERE idConcesion = @idConcesion)
        SET @vErrores += '- No se puede eliminar la concesion: tiene pagos de canon registrados.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM concesiones.Concesion WHERE idConcesion = @idConcesion;
    PRINT 'Concesion eliminada.';
END
GO

CREATE OR ALTER PROCEDURE concesiones.Concesion_Actualizar
    @idConcesion     INT,
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

    IF NOT EXISTS (SELECT 1 FROM concesiones.Concesion
                   WHERE idConcesion = @idConcesion)
        SET @vErrores += '- No existe una concesion con el ID indicado.' + CHAR(13);

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM concesiones.TipoDeConsesion
                   WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- El tipo de concesion indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM concesiones.Empresa
                   WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- La empresa indicada no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF @fechaFin <= @fechaInicio
        SET @vErrores += '- La fecha de fin debe ser posterior a la fecha de inicio.' + CHAR(13);

    IF @canonMensual <= 0
        SET @vErrores += '- El canon mensual debe ser mayor a cero.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE concesiones.Concesion
    SET descripcion     = @descripcion,
        idTipoConcesion = @idTipoConcesion,
        idParque        = @idParque,
        idEmpresa       = @idEmpresa,
        fechaInicio     = @fechaInicio,
        fechaFin        = @fechaFin,
        canonMensual    = @canonMensual
    WHERE idConcesion = @idConcesion;

    PRINT 'Concesion actualizada.';
END
GO

-- ============================================================
-- PAGO DE CONCESION
-- ============================================================

CREATE OR ALTER PROCEDURE concesiones.PagoConcesion_Insertar
    @idConcesion INT,
    @monto       DECIMAL(18,2),
    @fechaPago   DATE,
    @periodoAnio INT,
    @periodoMes  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM concesiones.Concesion
                   WHERE idConcesion = @idConcesion)
        SET @vErrores += '- No existe una concesion con el ID indicado.' + CHAR(13);

    IF @monto <= 0
        SET @vErrores += '- El monto debe ser mayor a cero.' + CHAR(13);

    IF @periodoMes NOT BETWEEN 1 AND 12
        SET @vErrores += '- El mes del periodo debe estar entre 1 y 12.' + CHAR(13);

    IF @periodoAnio < 2020
        SET @vErrores += '- El anio del periodo no puede ser anterior a 2020.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM concesiones.PagoConcesion
               WHERE idConcesion = @idConcesion
                 AND periodoAnio = @periodoAnio
                 AND periodoMes  = @periodoMes)
        SET @vErrores += '- Ya existe un pago registrado para esa concesion en el periodo indicado.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO concesiones.PagoConcesion (idConcesion, monto, fechaPago, periodoAnio, periodoMes)
    VALUES (@idConcesion, @monto, @fechaPago, @periodoAnio, @periodoMes);

    PRINT 'Pago de canon registrado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE concesiones.PagoConcesion_Eliminar
    @idPagoConcesion INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM concesiones.PagoConcesion
                   WHERE idPagoConcesion = @idPagoConcesion)
    BEGIN
        RAISERROR('- No existe un pago con el ID indicado.', 16, 1);
        RETURN;
    END

    DELETE FROM concesiones.PagoConcesion WHERE idPagoConcesion = @idPagoConcesion;
    PRINT 'Pago eliminado.';
END
GO

CREATE OR ALTER PROCEDURE concesiones.PagoConcesion_Actualizar
    @idPagoConcesion INT,
    @monto           DECIMAL(18,2),
    @fechaPago       DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM concesiones.PagoConcesion
                   WHERE idPagoConcesion = @idPagoConcesion)
        SET @vErrores += '- No existe un pago con el ID indicado.' + CHAR(13);

    IF @monto <= 0
        SET @vErrores += '- El monto debe ser mayor a cero.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE concesiones.PagoConcesion
    SET monto     = @monto,
        fechaPago = @fechaPago
    WHERE idPagoConcesion = @idPagoConcesion;

    PRINT 'Pago actualizado.';
END
GO
