-- =============================================
-- Universidad: Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Comisión: 01-2900 | Grupo 03
-- Integrantes: Del Vecchio Fabrizio, Ocampos Horacio,
--              Ruiz Santillán Facundo, Lago Franco Nehuen
-- Fecha: 15/06/2026
-- Descripción: Testing del módulo Guías, Tours y Atracciones
-- =============================================

USE ParquesNacionales;
GO

-- =====================
-- TESTS EXITOSOS
-- =====================

PRINT '--- TEST 1: Insertar guía válido ---';
-- Resultado esperado: 1 fila insertada, sin error
EXEC personal.Guia_Insertar
    @dni = 30000001,
    @apyn = 'Carlos Pérez',
    @especialidad = 'Flora patagónica',
    @titulo = 'Lic. en Biología',
    @vigenciaAutorizacion = '2027-12-31';

SELECT * FROM personal.Guia WHERE dni = 30000001;
-- Verificación: debe aparecer el registro


PRINT '--- TEST 2: Asignar guía a tour sin superposición ---';
-- Resultado esperado: asignación creada correctamente
EXEC personal.AsignacionGuia_Insertar
    @idTour = 1,
    @dniGuia = 30000001,
    @fechaInicio = '2025-01-01',
    @fechaFin = '2025-06-30';

SELECT * FROM personal.AsignacionGuia WHERE dniGuia = 30000001;


PRINT '--- TEST 3: Registrar atracción válida ---';
-- Resultado esperado: atracción insertada
EXEC actividades.Atraccion_Insertar
    @nombre = 'Senderismo Lago Verde',
    @tipo = 'Outdoor',
    @precio = 0,
    @duracion = 120,
    @cupoMaximo = 20,
    @idParque = 1;

SELECT * FROM actividades.Atraccion WHERE nombre = 'Senderismo Lago Verde';


-- =====================
-- TESTS DE VALIDACIONES (ERRORES ESPERADOS)
-- =====================

PRINT '--- TEST 4: Insertar guía con DNI duplicado ---';
-- Resultado esperado: error "Ya existe un guía registrado con ese DNI"
BEGIN TRY
    EXEC personal.Guia_Insertar
        @dni = 30000001,
        @apyn = 'Otro Guia',
        @vigenciaAutorizacion = '2026-01-01';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH


PRINT '--- TEST 5: Asignar guía con autorización vencida ---';
-- Resultado esperado: error "La autorización del guía vence antes..."
BEGIN TRY
    EXEC personal.AsignacionGuia_Insertar
        @idTour = 1,
        @dniGuia = 30000001,
        @fechaInicio = '2025-01-01',
        @fechaFin = '2030-01-01'; -- fecha posterior a la vigencia (2027-12-31)
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH


PRINT '--- TEST 6: Asignar guía con superposición de fechas ---';
-- Resultado esperado: error "El guía ya cuenta con un tour asignado en el rango de fechas"
BEGIN TRY
    EXEC personal.AsignacionGuia_Insertar
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
    EXEC actividades.Atraccion_Insertar
        @nombre = 'Atraccion invalida',
        @precio = 0,
        @duracion = 60,
        @cupoMaximo = 0,
        @idParque = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH
GO