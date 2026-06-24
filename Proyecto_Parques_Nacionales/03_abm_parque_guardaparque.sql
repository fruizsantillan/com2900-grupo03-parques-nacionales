-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Stored Procedures de ABM para el modulo Parques.
--              SPs: TipoParque             (Insertar/Actualizar/Eliminar/ObtenerPorId)
--                   Ubicacion              (Insertar/Actualizar/Eliminar/ObtenerPorId)
--                   Parque                 (Insertar/Actualizar/Eliminar/ObtenerPorId)
--                   Guardaparque           (Insertar/Actualizar/Eliminar/ObtenerPorId)
--                   AsignacionGuardaparque (Insertar/Actualizar/Eliminar/ObtenerPorId)
-- =============================================

USE ParquesNacionales;
GO

-- ==================
-- TIPO DE PARQUE - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE parques.TipoParque_Insertar
    @descripcion VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion del tipo de parque es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.TipoParque
               WHERE descripcion = LTRIM(RTRIM(@descripcion)))
        SET @vErrores += '- Ya existe un tipo de parque con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.TipoParque (descripcion)
    VALUES (LTRIM(RTRIM(@descripcion)));

    PRINT 'Tipo de parque creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

-- ==================
-- TIPO DE PARQUE - ACTUALIZAR
-- ==================
CREATE OR ALTER PROCEDURE parques.TipoParque_Actualizar
    @idTipoParque INT,
    @descripcion  VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.TipoParque
                   WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- No existe un tipo de parque con el ID indicado.' + CHAR(13);

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.TipoParque
               WHERE descripcion = LTRIM(RTRIM(@descripcion))
                 AND idTipoParque != @idTipoParque)
        SET @vErrores += '- Ya existe otro tipo de parque con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.TipoParque
    SET descripcion = LTRIM(RTRIM(@descripcion))
    WHERE idTipoParque = @idTipoParque;

    PRINT 'Tipo de parque actualizado.';
END
GO

-- ==================
-- TIPO DE PARQUE - ELIMINAR
-- ==================
CREATE OR ALTER PROCEDURE parques.TipoParque_Eliminar
    @idTipoParque INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.TipoParque
                   WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- No existe un tipo de parque con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Parque
               WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- No se puede eliminar: existen parques asociados a este tipo.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.TipoParque WHERE idTipoParque = @idTipoParque;
    PRINT 'Tipo de parque eliminado.';
END
GO

-- ==================
-- TIPO DE PARQUE - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE parques.TipoParque_ObtenerPorId
    @idTipoParque INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT idTipoParque, descripcion
    FROM parques.TipoParque
    WHERE idTipoParque = @idTipoParque;
END
GO

-- ==================
-- UBICACION - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE parques.Ubicacion_Insertar
    @direccion VARCHAR(100),
    @provincia VARCHAR(50),
    @latitud   DECIMAL(9,6),
    @longitud  DECIMAL(9,6)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

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

    INSERT INTO parques.Ubicacion (direccion, provincia, latitud, longitud)
    VALUES (LTRIM(RTRIM(@direccion)), LTRIM(RTRIM(@provincia)), @latitud, @longitud);

    PRINT 'Ubicacion creada con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

-- ==================
-- UBICACION - ACTUALIZAR
-- ==================
CREATE OR ALTER PROCEDURE parques.Ubicacion_Actualizar
    @idUbicacion INT,
    @direccion   VARCHAR(100),
    @provincia   VARCHAR(50),
    @latitud     DECIMAL(9,6),
    @longitud    DECIMAL(9,6)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion
                   WHERE idUbicacion = @idUbicacion)
        SET @vErrores += '- No existe una ubicacion con el ID indicado.' + CHAR(13);

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

    UPDATE parques.Ubicacion
    SET direccion = LTRIM(RTRIM(@direccion)),
        provincia = LTRIM(RTRIM(@provincia)),
        latitud   = @latitud,
        longitud  = @longitud
    WHERE idUbicacion = @idUbicacion;

    PRINT 'Ubicacion actualizada.';
END
GO

-- ==================
-- UBICACION - ELIMINAR
-- ==================
CREATE OR ALTER PROCEDURE parques.Ubicacion_Eliminar
    @idUbicacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion
                   WHERE idUbicacion = @idUbicacion)
        SET @vErrores += '- No existe una ubicacion con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Parque
               WHERE idUbicacion = @idUbicacion)
        SET @vErrores += '- No se puede eliminar: existen parques asociados a esta ubicacion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Ubicacion WHERE idUbicacion = @idUbicacion;
    PRINT 'Ubicacion eliminada.';
END
GO

-- ==================
-- UBICACION - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE parques.Ubicacion_ObtenerPorId
    @idUbicacion INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT idUbicacion, direccion, provincia, latitud, longitud
    FROM parques.Ubicacion
    WHERE idUbicacion = @idUbicacion;
END
GO

-- ==================
-- PARQUE - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE parques.Parque_Insertar
    @nombre       VARCHAR(100),
    @superficie   DECIMAL(18,2),
    @idTipoParque INT,
    @idUbicacion  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores += '- El nombre del parque es obligatorio.' + CHAR(13);

    IF @superficie IS NULL OR @superficie <= 0
        SET @vErrores += '- La superficie debe ser mayor a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TipoParque
                   WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- El tipo de parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion
                   WHERE idUbicacion = @idUbicacion)
        SET @vErrores += '- La ubicacion indicada no existe.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Parque
               WHERE nombre = LTRIM(RTRIM(@nombre)))
        SET @vErrores += '- Ya existe un parque con ese nombre.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Parque (nombre, superficie, idTipoParque, idUbicacion)
    VALUES (LTRIM(RTRIM(@nombre)), @superficie, @idTipoParque, @idUbicacion);

    PRINT 'Parque registrado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

-- ==================
-- PARQUE - ACTUALIZAR
-- ==================
CREATE OR ALTER PROCEDURE parques.Parque_Actualizar
    @idParque     INT,
    @nombre       VARCHAR(100),
    @superficie   DECIMAL(18,2),
    @idTipoParque INT,
    @idUbicacion  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- No existe un parque con el ID indicado.' + CHAR(13);

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores += '- El nombre del parque es obligatorio.' + CHAR(13);

    IF @superficie IS NULL OR @superficie <= 0
        SET @vErrores += '- La superficie debe ser mayor a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TipoParque
                   WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- El tipo de parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion
                   WHERE idUbicacion = @idUbicacion)
        SET @vErrores += '- La ubicacion indicada no existe.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Parque
               WHERE nombre = LTRIM(RTRIM(@nombre))
                 AND idParque != @idParque)
        SET @vErrores += '- Ya existe otro parque con ese nombre.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Parque
    SET nombre       = LTRIM(RTRIM(@nombre)),
        superficie   = @superficie,
        idTipoParque = @idTipoParque,
        idUbicacion  = @idUbicacion
    WHERE idParque = @idParque;

    PRINT 'Parque actualizado.';
END
GO

-- ==================
-- PARQUE - ELIMINAR
-- ==================
-- Un parque es referenciado desde varios modulos. NO puede eliminarse si tiene:
--   actividades.Tour, actividades.Atraccion, personal.AsignacionGuardaparque
--   ventas.PrecioEntrada, ventas.TicketVenta  (esquema ventas, modulo en construccion)
--   concesiones.Concesion
    
CREATE OR ALTER PROCEDURE parques.Parque_Eliminar
    @idParque INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- No existe un parque con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM actividades.Tour
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene tours registrados.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM actividades.Atraccion
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene atracciones registradas.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM personal.AsignacionGuardaparque
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene asignaciones de guardaparques.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM ventas.PrecioEntrada
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene precios de entrada registrados.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM ventas.TicketVenta
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene ventas registradas.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM concesiones.Concesion
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene concesiones registradas.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Parque WHERE idParque = @idParque;
    PRINT 'Parque eliminado.';
END
GO

-- ==================
-- PARQUE - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE parques.Parque_ObtenerPorId
    @idParque INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT idParque, nombre, superficie, idTipoParque, idUbicacion
    FROM parques.Parque
    WHERE idParque = @idParque;
END
GO

-- ==================
-- GUARDAPARQUE - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE personal.Guardaparque_Insertar
    @dni             INT,
    @apyn            VARCHAR(50),
    @email           VARCHAR(100) = NULL,
    @telefono        VARCHAR(50)  = NULL,
    @localidad       VARCHAR(50)  = NULL,
    @fechaNacimiento DATETIME     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @dni IS NULL OR @dni <= 0
        SET @vErrores += '- El DNI es obligatorio y debe ser mayor a 0.' + CHAR(13);
    ELSE IF EXISTS (SELECT 1 FROM personal.Guardaparque
                    WHERE dni = @dni)
        SET @vErrores += '- Ya existe un guardaparque registrado con ese DNI.' + CHAR(13);

    IF @apyn IS NULL OR LTRIM(RTRIM(@apyn)) = ''
        SET @vErrores += '- El apellido y nombre es obligatorio.' + CHAR(13);

    IF @email IS NOT NULL AND @email NOT LIKE '%@%.%'
        SET @vErrores += '- El formato del email no es valido.' + CHAR(13);

    IF @fechaNacimiento IS NOT NULL AND @fechaNacimiento > GETDATE()
        SET @vErrores += '- La fecha de nacimiento no puede ser futura.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO personal.Guardaparque (dni, apyn, email, telefono, localidad, fechaNacimiento)
    VALUES (@dni, LTRIM(RTRIM(@apyn)), @email, @telefono, @localidad, @fechaNacimiento);

    PRINT 'Guardaparque registrado con DNI: ' + CAST(@dni AS VARCHAR);
END
GO

-- ==================
-- GUARDAPARQUE - ACTUALIZAR
-- ==================
CREATE OR ALTER PROCEDURE personal.Guardaparque_Actualizar
    @dni             INT,
    @apyn            VARCHAR(50),
    @email           VARCHAR(100) = NULL,
    @telefono        VARCHAR(50)  = NULL,
    @localidad       VARCHAR(50)  = NULL,
    @fechaNacimiento DATETIME     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM personal.Guardaparque
                   WHERE dni = @dni)
        SET @vErrores += '- No existe un guardaparque con el DNI indicado.' + CHAR(13);

    IF @apyn IS NULL OR LTRIM(RTRIM(@apyn)) = ''
        SET @vErrores += '- El apellido y nombre es obligatorio.' + CHAR(13);

    IF @email IS NOT NULL AND @email NOT LIKE '%@%.%'
        SET @vErrores += '- El formato del email no es valido.' + CHAR(13);

    IF @fechaNacimiento IS NOT NULL AND @fechaNacimiento > GETDATE()
        SET @vErrores += '- La fecha de nacimiento no puede ser futura.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE personal.Guardaparque
    SET apyn            = LTRIM(RTRIM(@apyn)),
        email           = @email,
        telefono        = @telefono,
        localidad       = @localidad,
        fechaNacimiento = @fechaNacimiento
    WHERE dni = @dni;

    PRINT 'Guardaparque actualizado.';
END
GO

-- ==================
-- GUARDAPARQUE - ELIMINAR
-- ==================
CREATE OR ALTER PROCEDURE personal.Guardaparque_Eliminar
    @dni INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM personal.Guardaparque
                   WHERE dni = @dni)
        SET @vErrores += '- No existe un guardaparque con el DNI indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM personal.AsignacionGuardaparque
               WHERE dni = @dni)
        SET @vErrores += '- No se puede eliminar: el guardaparque tiene asignaciones registradas.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM personal.Guardaparque WHERE dni = @dni;
    PRINT 'Guardaparque eliminado.';
END
GO

-- ==================
-- GUARDAPARQUE - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE personal.Guardaparque_ObtenerPorId
    @dni INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT dni, apyn, email, telefono, localidad, fechaNacimiento
    FROM personal.Guardaparque
    WHERE dni = @dni;
END
GO

-- ==================
-- ASIGNACION GUARDAPARQUE - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE personal.AsignacionGuardaparque_Insertar
    @fechaInicio  DATE,
    @idParque     INT,
    @dni          INT,
    @fechaFin     DATE         = NULL,
    @motivoEgreso VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @fechaInicio IS NULL
        SET @vErrores += '- La fecha de inicio es obligatoria.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM personal.Guardaparque
                   WHERE dni = @dni)
        SET @vErrores += '- El guardaparque indicado no existe.' + CHAR(13);

    IF @fechaFin IS NOT NULL AND @fechaFin < @fechaInicio
        SET @vErrores += '- La fecha de fin no puede ser anterior a la fecha de inicio.' + CHAR(13);

    IF @fechaFin IS NOT NULL AND (@motivoEgreso IS NULL OR LTRIM(RTRIM(@motivoEgreso)) = '')
        SET @vErrores += '- Si se indica fecha de fin, el motivo de egreso es obligatorio.' + CHAR(13);

    IF @fechaFin IS NULL AND EXISTS (SELECT 1 FROM personal.AsignacionGuardaparque
                                     WHERE dni = @dni AND fechaFin IS NULL)
        SET @vErrores += '- El guardaparque ya tiene una asignacion activa (sin fecha de fin).' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO personal.AsignacionGuardaparque
        (fechaInicio, fechaFin, motivoEgreso, idParque, dni)
    VALUES
        (@fechaInicio, @fechaFin, @motivoEgreso, @idParque, @dni);

    PRINT 'Asignacion registrada con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

-- ==================
-- ASIGNACION GUARDAPARQUE - ACTUALIZAR
-- ==================
CREATE OR ALTER PROCEDURE personal.AsignacionGuardaparque_Actualizar
    @idAsignacion INT,
    @fechaInicio  DATE,
    @idParque     INT,
    @dni          INT,
    @fechaFin     DATE         = NULL,
    @motivoEgreso VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM personal.AsignacionGuardaparque
                   WHERE idAsignacion = @idAsignacion)
        SET @vErrores += '- No existe una asignacion con el ID indicado.' + CHAR(13);

    IF @fechaInicio IS NULL
        SET @vErrores += '- La fecha de inicio es obligatoria.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM personal.Guardaparque
                   WHERE dni = @dni)
        SET @vErrores += '- El guardaparque indicado no existe.' + CHAR(13);

    IF @fechaFin IS NOT NULL AND @fechaFin < @fechaInicio
        SET @vErrores += '- La fecha de fin no puede ser anterior a la fecha de inicio.' + CHAR(13);

    IF @fechaFin IS NOT NULL AND (@motivoEgreso IS NULL OR LTRIM(RTRIM(@motivoEgreso)) = '')
        SET @vErrores += '- Si se indica fecha de fin, el motivo de egreso es obligatorio.' + CHAR(13);

    IF @fechaFin IS NULL AND EXISTS (SELECT 1 FROM personal.AsignacionGuardaparque
                                     WHERE dni = @dni
                                       AND fechaFin IS NULL
                                       AND idAsignacion != @idAsignacion)
        SET @vErrores += '- El guardaparque ya tiene otra asignacion activa (sin fecha de fin).' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE personal.AsignacionGuardaparque
    SET fechaInicio  = @fechaInicio,
        fechaFin     = @fechaFin,
        motivoEgreso = @motivoEgreso,
        idParque     = @idParque,
        dni          = @dni
    WHERE idAsignacion = @idAsignacion;

    PRINT 'Asignacion actualizada.';
END
GO

-- ==================
-- ASIGNACION GUARDAPARQUE - ELIMINAR
-- ==================
CREATE OR ALTER PROCEDURE personal.AsignacionGuardaparque_Eliminar
    @idAsignacion INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM personal.AsignacionGuardaparque
                   WHERE idAsignacion = @idAsignacion)
    BEGIN
        RAISERROR('- No existe una asignacion con el ID indicado.', 16, 1);
        RETURN;
    END

    DELETE FROM personal.AsignacionGuardaparque WHERE idAsignacion = @idAsignacion;
    PRINT 'Asignacion eliminada.';
END
GO

-- ==================
-- ASIGNACION GUARDAPARQUE - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE personal.AsignacionGuardaparque_ObtenerPorId
    @idAsignacion INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT idAsignacion, fechaInicio, fechaFin, motivoEgreso, idParque, dni
    FROM personal.AsignacionGuardaparque
    WHERE idAsignacion = @idAsignacion;
END
GO
