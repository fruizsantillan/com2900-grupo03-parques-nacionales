-- =============================================
-- Descripción: SPs de lógica de negocio - Guías, Tours y Atracciones
-- =============================================

USE ParquesNacionales;
GO

-- ==========================================
-- SP NEGOCIO: Asignar guía a tour
-- Valida: vigencia, superposición de fechas
-- ==========================================
CREATE OR ALTER PROCEDURE parques.sp_AsignarGuiaATour
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
    IF NOT EXISTS (SELECT 1 FROM parques.Tour WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- El tour especificado no existe.' + CHAR(13);

    -- Validar que el guía existe
    IF NOT EXISTS (SELECT 1 FROM parques.Guia WHERE dni = @dniGuia)
        SET @vErrores = @vErrores + '- El guía especificado no existe.' + CHAR(13);

    -- Validar fechas
    IF @fechaFin < @fechaInicio
        SET @vErrores = @vErrores + '- La fecha de fin no puede ser anterior a la fecha de inicio.' + CHAR(13);

    -- Validar vigencia de autorización del guía
    SELECT @vVigencia = vigenciaAutorizacion FROM parques.Guia WHERE dni = @dniGuia;
    IF @vVigencia < @fechaFin
        SET @vErrores = @vErrores + '- La autorización del guía vence antes de que finalice la asignación.' + CHAR(13);

    -- Validar superposición de fechas para ese guía
    IF EXISTS (
        SELECT 1 FROM parques.AsignacionGuia
        WHERE dniGuia = @dniGuia
          AND @fechaInicio <= fechaFin
          AND @fechaFin >= fechaInicio
    )
        SET @vErrores = @vErrores + '- El guía ya tiene una asignación en ese período de fechas.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO parques.AsignacionGuia (idTour, dniGuia, fechaInicio, fechaFin)
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
CREATE OR ALTER PROCEDURE parques.sp_RegistrarAtraccion
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
        SET @vErrores = @vErrores + '- El nombre de la atracción es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores = @vErrores + '- La duración debe ser mayor a 0 minutos.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores = @vErrores + '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio < 0
        SET @vErrores = @vErrores + '- El precio no puede ser negativo.' + CHAR(13);
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores = @vErrores + '- El parque especificado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO parques.Atraccion (nombre, descripcion, tipo, precio, duracion, cupoMaximo, idParque)
        VALUES (@nombre, @descripcion, @tipo, @precio, @duracion, @cupoMaximo, @idParque);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO