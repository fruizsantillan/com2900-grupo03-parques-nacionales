-- =============================================
-- Descripción: SPs ABM del módulo Guías, Tours y Atracciones
-- =============================================

USE ParquesNacionales;
GO

-- ==================
-- GUIA - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_Guia_Insertar
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

    -- Validaciones
    IF @dni IS NULL OR @dni <= 0
        SET @vErrores = @vErrores + '- El DNI es obligatorio y debe ser mayor a 0.' + CHAR(13);
    IF @apyn IS NULL OR LTRIM(RTRIM(@apyn)) = ''
        SET @vErrores = @vErrores + '- El nombre y apellido es obligatorio.' + CHAR(13);
    IF @vigenciaAutorizacion IS NULL
        SET @vErrores = @vErrores + '- La vigencia de autorización es obligatoria.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM parques.Guia WHERE dni = @dni)
        SET @vErrores = @vErrores + '- Ya existe un guía registrado con ese DNI.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Guia (dni, apyn, especialidad, titulo, habilitaciones, vigenciaAutorizacion)
    VALUES (@dni, @apyn, @especialidad, @titulo, @habilitaciones, @vigenciaAutorizacion);
END
GO

-- ==================
-- GUIA - ACTUALIZAR
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_Guia_Actualizar
    @dni                    INT,
    @especialidad           VARCHAR(100) = NULL,
    @titulo                 VARCHAR(100) = NULL,
    @habilitaciones         VARCHAR(255) = NULL,
    @vigenciaAutorizacion   DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Guia WHERE dni = @dni)
        SET @vErrores = @vErrores + '- No existe un guía con ese DNI.' + CHAR(13);
    IF @vigenciaAutorizacion IS NULL
        SET @vErrores = @vErrores + '- La vigencia de autorización es obligatoria.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Guia
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
CREATE OR ALTER PROCEDURE parques.sp_Guia_Eliminar
    @dni INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Guia WHERE dni = @dni)
        SET @vErrores = @vErrores + '- No existe un guía con ese DNI.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM parques.AsignacionGuia WHERE dni = @dni)
        SET @vErrores = @vErrores + '- El guía tiene tours asignados y no puede eliminarse.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Guia WHERE dni = @dni;
END
GO

-- ==================
-- GUIA - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_Guia_ObtenerPorId
    @dni INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM parques.Guia WHERE dni = @dni;
END
GO

-- ==================
-- TOUR - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_Tour_Insertar
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

    -- Validaciones
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores = @vErrores + '- El nombre del tour es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores = @vErrores + '- La duración debe ser mayor a 0 minutos.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores = @vErrores + '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio IS NULL OR @precio < 0
        SET @vErrores = @vErrores + '- El precio no puede ser negativo.' + CHAR(13);
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores = @vErrores + '- El parque especificado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Tour (nombre, descripcion, duracion, cupoMaximo, precio, idParque)
    VALUES (@nombre, @descripcion, @duracion, @cupoMaximo, @precio, @idParque);
END;
GO

-- ==================
-- TOUR - ACTUALIZAR
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_Tour_Actualizar
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

    IF NOT EXISTS (SELECT 1 FROM parques.Tour WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- No existe un tour con el ID especificado.' + CHAR(13);
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores = @vErrores + '- El nombre del tour es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores = @vErrores + '- La duración debe ser mayor a 0 minutos.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores = @vErrores + '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio IS NULL OR @precio < 0
        SET @vErrores = @vErrores + '- El precio no puede ser negativo.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Tour
    SET nombre = @nombre,
        descripcion = @descripcion,
        duracion = @duracion,
        cupoMaximo = @cupoMaximo,
        precio = @precio
    WHERE idTour = @idTour;
END;
GO

-- ==================
-- TOUR - ELIMINAR
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_Tour_Eliminar
    @idTour INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Tour WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- No existe el tour con el ID especificado.' + CHAR(13);
    
    -- Validar integridad si ya se vendió (Línea Venta) o si tiene guías asignados
    IF EXISTS (SELECT 1 FROM parques.AsignacionGuia WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- El tour tiene un historial de guías asignados y no puede eliminarse.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM parques.LineaVenta WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- El tour posee registros de ventas asociadas y no puede eliminarse.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Tour WHERE idTour = @idTour;
END;
GO

-- ==================
-- TOUR - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_Tour_ObtenerPorId
    @idTour INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM parques.Tour WHERE idTour = @idTour;
END;
GO

-- ==================
-- ATRACCION - INSERTAR
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_Atraccion_Insertar
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
        SET @vErrores = @vErrores + '- El nombre de la atracción es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores = @vErrores + '- La duración debe ser mayor a 0 minutos.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores = @vErrores + '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio IS NULL OR @precio < 0
        SET @vErrores = @vErrores + '- El precio no puede ser negativo.' + CHAR(13);
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores = @vErrores + '- El parque especificado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Atraccion (nombre, descripcion, tipo, precio, duracion, cupoMaximo, idParque)
    VALUES (@nombre, @descripcion, @tipo, @precio, @duracion, @cupoMaximo, @idParque);
END;
GO

-- ==================
-- ATRACCION - ACTUALIZAR
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_Atraccion_Actualizar
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

    IF NOT EXISTS (SELECT 1 FROM parques.Atraccion WHERE idAtraccion = @idAtraccion)
        SET @vErrores = @vErrores + '- No existe la atracción con el ID especificado.' + CHAR(13);
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores = @vErrores + '- El nombre es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores = @vErrores + '- La duración debe ser mayor a 0.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores = @vErrores + '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio IS NULL OR @precio < 0
        SET @vErrores = @vErrores + '- El precio no puede ser negativo.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Atraccion
    SET nombre = @nombre,
        descripcion = @descripcion,
        tipo = @tipo,
        precio = @precio,
        duracion = @duracion,
        cupoMaximo = @cupoMaximo
    WHERE idAtraccion = @idAtraccion;
END;
GO

-- ==================
-- ATRACCION - ELIMINAR
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_Atraccion_Eliminar
    @idAtraccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Atraccion WHERE idAtraccion = @idAtraccion)
        SET @vErrores = @vErrores + '- No existe la atracción con el ID especificado.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM parques.LineaVenta WHERE idAtraccion = @idAtraccion)
        SET @vErrores = @vErrores + '- La atracción posee registros de ventas asociadas y no puede eliminarse.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Atraccion WHERE idAtraccion = @idAtraccion;
END;
GO

-- ==================
-- ATRACCION - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_Atraccion_ObtenerPorId
    @idAtraccion INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM parques.Atraccion WHERE idAtraccion = @idAtraccion;
END;
GO

-- =====================================
-- ASIGNACION GUIA - INSERTAR (NEGOCIO)
-- =====================================
CREATE OR ALTER PROCEDURE parques.sp_AsignacionGuia_Insertar
    @idTour      INT,
    @dniGuia     INT,
    @fechaInicio DATE,
    @fechaFin    DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(600) = '';
    DECLARE @vVigenciaAutorizacion DATE;

    -- 1. Validaciones básicas de existencia y coherencia de fechas
    IF NOT EXISTS (SELECT 1 FROM parques.Tour WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- El Tour especificado no existe.' + CHAR(13);
    
    SELECT @vVigenciaAutorizacion = vigenciaAutorizacion FROM parques.Guia WHERE dni = @dniGuia;
    IF @vVigenciaAutorizacion IS NULL
        SET @vErrores = @vErrores + '- El Guía especificado no existe.' + CHAR(13);
        
    IF @fechaInicio IS NULL OR @fechaFin IS NULL
        SET @vErrores = @vErrores + '- Las fechas de inicio y fin son obligatorias.' + CHAR(13);
    IF @fechaInicio > @fechaFin
        SET @vErrores = @vErrores + '- La fecha de inicio no puede ser posterior a la fecha de fin.' + CHAR(13);

    -- Si las validaciones básicas fallan, frena acá para evitar errores lógicos más adelante
    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    -- 2. Regla de Negocio: Validar vigencia de autorización del guía
    -- La habilitación debe cubrir todo el rango del tour (hasta la fecha fin)
    IF @vVigenciaAutorizacion < @fechaFin
        SET @vErrores = @vErrores + '- La autorización del guía vence antes de la fecha de finalización del tour.' + CHAR(13);

    -- 3. Regla de Negocio: Validar superposición de fechas (Overlap)
    -- Hay superposición si: (InicioNuevo <= FinExistente) AND (FinNuevo >= InicioExistente)
    IF EXISTS (
        SELECT 1 FROM parques.AsignacionGuia
        WHERE dniGuia = @dniGuia
          AND @fechaInicio <= fechaFin
          AND @fechaFin >= fechaInicio
    )
    BEGIN
        SET @vErrores = @vErrores + '- El guía ya cuenta con un tour asignado en el rango de fechas solicitado.' + CHAR(13);
    END

    -- Despacho final de errores acumulados de negocio
    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    -- Si pasó todo perfectamente, inserta
    INSERT INTO parques.AsignacionGuia (idTour, dniGuia, fechaInicio, fechaFin)
    VALUES (@idTour, @dniGuia, @fechaInicio, @fechaFin);
END;
GO

-- ==================
-- ASIGNACION GUIA - ELIMINAR
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_AsignacionGuia_Eliminar
    @idAsignacion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM parques.AsignacionGuia WHERE idAsignacion = @idAsignacion)
    BEGIN
        RAISERROR('- No existe la asignación especificada.', 16, 1);
        RETURN;
    END

    DELETE FROM parques.AsignacionGuia WHERE idAsignacion = @idAsignacion;
END;
GO

-- ==================
-- ASIGNACION GUIA - OBTENER POR ID
-- ==================
CREATE OR ALTER PROCEDURE parques.sp_AsignacionGuia_ObtenerPorId
    @idAsignacion INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM parques.AsignacionGuia WHERE idAsignacion = @idAsignacion;
END;
GO