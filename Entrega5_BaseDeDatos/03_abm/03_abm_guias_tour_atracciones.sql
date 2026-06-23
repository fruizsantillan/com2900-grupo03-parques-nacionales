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