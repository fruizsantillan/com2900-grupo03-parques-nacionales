-- =============================================
-- Descripción: Testing del módulo Guías, Tours y Atracciones
-- =============================================

USE ParquesNacionales;
GO

-- =====================
-- TESTS EXITOSOS
-- =====================

PRINT '--- TEST 1: Insertar guía válido ---';
-- Resultado esperado: 1 fila insertada, sin error
EXEC parques.sp_Guia_Insertar
    @dni = 30000001,
    @apyn = 'Carlos Pérez',
    @especialidad = 'Flora patagónica',
    @titulo = 'Lic. en Biología',
    @vigenciaAutorizacion = '2027-12-31';

SELECT * FROM parques.Guia WHERE dni = 30000001;
-- Verificación: debe aparecer el registro


PRINT '--- TEST 2: Asignar guía a tour sin superposición ---';
-- Resultado esperado: asignación creada correctamente
EXEC parques.sp_AsignarGuiaATour
    @idTour = 1,
    @dniGuia = 30000001,
    @fechaInicio = '2025-01-01',
    @fechaFin = '2025-06-30';

SELECT * FROM parques.AsignacionGuia WHERE dniGuia = 30000001;


PRINT '--- TEST 3: Registrar atracción válida ---';
-- Resultado esperado: atracción insertada
EXEC parques.sp_RegistrarAtraccion
    @nombre = 'Senderismo Lago Verde',
    @tipo = 'Outdoor',
    @precio = 0,
    @duracion = 120,
    @cupoMaximo = 20,
    @idParque = 1;

SELECT * FROM parques.Atraccion WHERE nombre = 'Senderismo Lago Verde';


-- =====================
-- TESTS DE VALIDACIONES (ERRORES ESPERADOS)
-- =====================

PRINT '--- TEST 4: Insertar guía con DNI duplicado ---';
-- Resultado esperado: error "Ya existe un guía registrado con ese DNI"
BEGIN TRY
    EXEC parques.sp_Guia_Insertar
        @dni = 30000001,
        @apynom = 'Otro Guia',
        @vigenciaAutorizacion = '2026-01-01';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH


PRINT '--- TEST 5: Asignar guía con autorización vencida ---';
-- Resultado esperado: error "La autorización del guía vence antes..."
BEGIN TRY
    EXEC parques.sp_AsignarGuiaATour
        @idTour = 1,
        @dniGuia = 30000001,
        @fechaInicio = '2025-01-01',
        @fechaFin = '2030-01-01'; -- fecha posterior a la vigencia (2027-12-31)
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH


PRINT '--- TEST 6: Asignar guía con superposición de fechas ---';
-- Resultado esperado: error "El guía ya tiene una asignación en ese período"
BEGIN TRY
    EXEC parques.sp_AsignarGuiaATour
        @idTour = 2,
        @dniGuia = 30000001,
        @fechaInicio = '2025-03-01', -- se superpone con el test 2 (Ene-Jun 2025)
        @fechaFin = '2025-09-01';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH


PRINT '--- TEST 7: Registrar atracción con cupo 0 ---';
-- Resultado esperado: error "El cupo máximo debe ser mayor a 0"
BEGIN TRY
    EXEC parques.sp_RegistrarAtraccion
        @nombre = 'Atraccion invalida',
        @duracion = 60,
        @cupoMaximo = 0,
        @idParque = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH
GO