-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 27/06/2026
-- Descripcion: Entrega 5 (2/3) - Stored Procedures de ABM (Alta/Baja/
--   Modificacion/ObtenerPorId) para todas las tablas del sistema.
--   Ninguna operacion ABM accede directamente a las tablas.
--   Modulos: Parques, Guardaparques, Guias, Tours, Atracciones,
--            Concesiones, Ventas y Precios.
-- Correccion aplicada: las referencias a parques.Tour y parques.Atraccion
--   en LineaVenta_Insertar y LineaVenta_Actualizar fueron corregidas a
--   actividades.Tour y actividades.Atraccion (schema correcto).
-- Prerequisito: Ejecutar 01_tablas_y_schemas.sql.
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

-- ============================================================
-- 03 - ABM: Guias, Tours y Atracciones
-- ============================================================

-- =============================================
-- Universidad: Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Comisión: 01-2900 | Grupo 03
-- Integrantes: Del Vecchio Fabrizio, Ocampos Horacio,
--              Ruiz Santillán Facundo, Lago Franco Nehuen
-- Fecha: 15/06/2026
-- Descripción: SPs ABM del módulo Guías, Tours y Atracciones
-- =============================================

USE ParquesNacionales;
GO

-- ==================
-- GUIA - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE personal.Guia_Insertar
    @dni                    INT,
    @apyn                   VARCHAR(100),
    @especialidad           VARCHAR(100) = NULL,
    @titulo                 VARCHAR(100) = NULL,
    @habilitaciones         VARCHAR(255) = NULL,
    @vigenciaAutorizacion   DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF @dni IS NULL OR @dni <= 0
        SET @vErrores += '- El DNI es obligatorio y debe ser mayor a 0.' + CHAR(13);
    IF @apyn IS NULL OR LTRIM(RTRIM(@apyn)) = ''
        SET @vErrores += '- El nombre y apellido es obligatorio.' + CHAR(13);
    IF @vigenciaAutorizacion IS NULL
        SET @vErrores += '- La vigencia de autorización es obligatoria.' + CHAR(13);
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM personal.Guia WHERE dni = @dni)
        SET @vErrores += '- Ya existe un guía registrado con ese DNI.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO personal.Guia (dni, apyn, especialidad, titulo, habilitaciones, vigenciaAutorizacion)
    VALUES (@dni, @apyn, @especialidad, @titulo, @habilitaciones, @vigenciaAutorizacion);
END
GO

-- ==================
-- GUIA - ACTUALIZAR
-- ==================
CREATE OR ALTER PROCEDURE personal.Guia_Actualizar
    @dni                    INT,
    @especialidad           VARCHAR(100) = NULL,
    @titulo                 VARCHAR(100) = NULL,
    @habilitaciones         VARCHAR(255) = NULL,
    @vigenciaAutorizacion   DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM personal.Guia WHERE dni = @dni)
        SET @vErrores += '- No existe un guía con ese DNI.' + CHAR(13);
    IF @vigenciaAutorizacion IS NULL
        SET @vErrores += '- La vigencia de autorización es obligatoria.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE personal.Guia
    SET especialidad = @especialidad,
        titulo = @titulo,
        habilitaciones = @habilitaciones,
        vigenciaAutorizacion = @vigenciaAutorizacion
    WHERE dni = @dni;
END
GO

-- ==================
-- GUIA - ELIMINAR
-- ==================
CREATE OR ALTER PROCEDURE personal.Guia_Eliminar
    @dni INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM personal.Guia WHERE dni = @dni)
        SET @vErrores += '- No existe un guía con ese DNI.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM personal.AsignacionGuia WHERE dniGuia = @dni)
        SET @vErrores += '- El guía tiene tours asignados y no puede eliminarse.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM personal.Guia WHERE dni = @dni;
END
GO

-- ==================
-- GUIA - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE personal.Guia_ObtenerPorId
    @dni INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM personal.Guia WHERE dni = @dni;
END
GO

-- ==================
-- TOUR - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE actividades.Tour_Insertar
    @nombre      VARCHAR(100),
    @descripcion VARCHAR(255) = NULL,
    @duracion    INT,
    @cupoMaximo  INT,
    @precio      DECIMAL(18,2),
    @idParque    INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores += '- El nombre del tour es obligatorio.' + CHAR(13);
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

    INSERT INTO actividades.Tour (nombre, descripcion, duracion, cupoMaximo, precio, idParque)
    VALUES (@nombre, @descripcion, @duracion, @cupoMaximo, @precio, @idParque);
END
GO

-- ==================
-- TOUR - ACTUALIZAR
-- ==================
CREATE OR ALTER PROCEDURE actividades.Tour_Actualizar
    @idTour      INT,
    @nombre      VARCHAR(100),
    @descripcion VARCHAR(255) = NULL,
    @duracion    INT,
    @cupoMaximo  INT,
    @precio      DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM actividades.Tour WHERE idTour = @idTour)
        SET @vErrores += '- No existe un tour con el ID especificado.' + CHAR(13);
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores += '- El nombre del tour es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores += '- La duración debe ser mayor a 0 minutos.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores += '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio IS NULL OR @precio < 0
        SET @vErrores += '- El precio no puede ser negativo.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE actividades.Tour
    SET nombre = @nombre,
        descripcion = @descripcion,
        duracion = @duracion,
        cupoMaximo = @cupoMaximo,
        precio = @precio
    WHERE idTour = @idTour;
END
GO

-- ==================
-- TOUR - ELIMINAR
-- ==================
CREATE OR ALTER PROCEDURE actividades.Tour_Eliminar
    @idTour INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM actividades.Tour WHERE idTour = @idTour)
        SET @vErrores += '- No existe el tour con el ID especificado.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM personal.AsignacionGuia WHERE idTour = @idTour)
        SET @vErrores += '- El tour tiene un historial de guías asignados y no puede eliminarse.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM ventas.LineaVenta WHERE idTour = @idTour)
        SET @vErrores += '- El tour posee registros de ventas asociadas y no puede eliminarse.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM actividades.Tour WHERE idTour = @idTour;
END
GO

-- ==================
-- TOUR - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE actividades.Tour_ObtenerPorId
    @idTour INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM actividades.Tour WHERE idTour = @idTour;
END
GO

-- ==================
-- ATRACCION - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE actividades.Atraccion_Insertar
    @nombre      VARCHAR(100),
    @descripcion VARCHAR(255) = NULL,
    @tipo        VARCHAR(50) = NULL,
    @precio      DECIMAL(18,2),
    @duracion    INT,
    @cupoMaximo  INT,
    @idParque    INT
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

    INSERT INTO actividades.Atraccion (nombre, descripcion, tipo, precio, duracion, cupoMaximo, idParque)
    VALUES (@nombre, @descripcion, @tipo, @precio, @duracion, @cupoMaximo, @idParque);
END
GO

-- ==================
-- ATRACCION - ACTUALIZAR
-- ==================
CREATE OR ALTER PROCEDURE actividades.Atraccion_Actualizar
    @idAtraccion INT,
    @nombre      VARCHAR(100),
    @descripcion VARCHAR(255) = NULL,
    @tipo        VARCHAR(50) = NULL,
    @precio      DECIMAL(18,2),
    @duracion    INT,
    @cupoMaximo  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM actividades.Atraccion WHERE idAtraccion = @idAtraccion)
        SET @vErrores += '- No existe la atracción con el ID especificado.' + CHAR(13);
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores += '- El nombre es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores += '- La duración debe ser mayor a 0.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores += '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio IS NULL OR @precio < 0
        SET @vErrores += '- El precio no puede ser negativo.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE actividades.Atraccion
    SET nombre = @nombre,
        descripcion = @descripcion,
        tipo = @tipo,
        precio = @precio,
        duracion = @duracion,
        cupoMaximo = @cupoMaximo
    WHERE idAtraccion = @idAtraccion;
END
GO

-- ==================
-- ATRACCION - ELIMINAR
-- ==================
CREATE OR ALTER PROCEDURE actividades.Atraccion_Eliminar
    @idAtraccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM actividades.Atraccion WHERE idAtraccion = @idAtraccion)
        SET @vErrores += '- No existe la atracción con el ID especificado.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM ventas.LineaVenta WHERE idAtraccion = @idAtraccion)
        SET @vErrores += '- La atracción posee registros de ventas asociadas y no puede eliminarse.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM actividades.Atraccion WHERE idAtraccion = @idAtraccion;
END
GO

-- ==================
-- ATRACCION - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE actividades.Atraccion_ObtenerPorId
    @idAtraccion INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM actividades.Atraccion WHERE idAtraccion = @idAtraccion;
END
GO

-- ==================
-- ASIGNACION GUIA - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE personal.AsignacionGuia_Insertar
    @idTour      INT,
    @dniGuia     INT,
    @fechaInicio DATE,
    @fechaFin    DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(600) = '';
    DECLARE @vVigenciaAutorizacion DATE;

    IF NOT EXISTS (SELECT 1 FROM actividades.Tour WHERE idTour = @idTour)
        SET @vErrores += '- El Tour especificado no existe.' + CHAR(13);

    SELECT @vVigenciaAutorizacion = vigenciaAutorizacion FROM personal.Guia WHERE dni = @dniGuia;
    IF @vVigenciaAutorizacion IS NULL
        SET @vErrores += '- El Guía especificado no existe.' + CHAR(13);

    IF @fechaInicio IS NULL OR @fechaFin IS NULL
        SET @vErrores += '- Las fechas de inicio y fin son obligatorias.' + CHAR(13);
    IF @fechaInicio IS NOT NULL AND @fechaFin IS NOT NULL AND @fechaInicio > @fechaFin
        SET @vErrores += '- La fecha de inicio no puede ser posterior a la fecha de fin.' + CHAR(13);

    -- Validaciones de negocio que dependen de las anteriores (se acumulan igual, sin frenar antes)
    IF @vVigenciaAutorizacion IS NOT NULL AND @fechaFin IS NOT NULL AND @vVigenciaAutorizacion < @fechaFin
        SET @vErrores += '- La autorización del guía vence antes de la fecha de finalización del tour.' + CHAR(13);

    IF @dniGuia IS NOT NULL AND @fechaInicio IS NOT NULL AND @fechaFin IS NOT NULL AND EXISTS (
        SELECT 1 FROM personal.AsignacionGuia
        WHERE dniGuia = @dniGuia
          AND @fechaInicio <= fechaFin
          AND @fechaFin >= fechaInicio
    )
        SET @vErrores += '- El guía ya cuenta con un tour asignado en el rango de fechas solicitado.' + CHAR(13);

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

-- ==================
-- ASIGNACION GUIA - ELIMINAR
-- ==================
CREATE OR ALTER PROCEDURE personal.AsignacionGuia_Eliminar
    @idAsignacion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM personal.AsignacionGuia WHERE idAsignacion = @idAsignacion)
    BEGIN
        RAISERROR('- No existe la asignación especificada.', 16, 1);
        RETURN;
    END

    DELETE FROM personal.AsignacionGuia WHERE idAsignacion = @idAsignacion;
END
GO

-- ==================
-- ASIGNACION GUIA - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE personal.AsignacionGuia_ObtenerPorId
    @idAsignacion INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM personal.AsignacionGuia WHERE idAsignacion = @idAsignacion;
END
GO
-- ============================================================
-- 03 - ABM: Concesiones
-- ============================================================

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

-- ============================================================
-- 03 - ABM: Ventas
-- ============================================================

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
        FROM actividades.Tour
        WHERE idTour = @idTour;

        IF @vPrecioUnitario IS NULL
            SET @vErrores += '- El tour indicado no existe.' + CHAR(13);
    END

    IF @idAtraccion IS NOT NULL
    BEGIN
        SELECT 
            @vPrecioUnitario = precio,
            @vDescripcion = nombre
        FROM actividades.Atraccion
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
        FROM actividades.Tour
        WHERE idTour = @idTour;

        IF @vPrecioUnitario IS NULL
            SET @vErrores += '- El tour indicado no existe.' + CHAR(13);
    END

    IF @idAtraccion IS NOT NULL
    BEGIN
        SELECT 
            @vPrecioUnitario = precio,
            @vDescripcion = nombre
        FROM actividades.Atraccion
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
-- ============================================================
