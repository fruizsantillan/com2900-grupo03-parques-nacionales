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

PRINT '===== TEST 1 (OK): insertar guia valido =====';
-- Resultado esperado: 1 fila insertada, sin error
EXEC personal.Guia_Insertar
    @dni                  = 30000001,
    @apyn                 = 'Carlos Pérez',
    @especialidad         = 'Flora patagónica',
    @titulo               = 'Lic. en Biología',
    @vigenciaAutorizacion = '2027-12-31';
SELECT * FROM personal.Guia WHERE dni = 30000001;

PRINT '===== TEST 2 (OK): asignar guia a tour sin superposicion =====';
PRINT '===== SETUP: carga de datos base =====';
-- Declaramos variables para guardar los IDs reales que genere la base de datos
DECLARE @vIdTipo INT, @vIdUbic INT, @vIdParque INT, @vIdTour INT;

-- 1. Insertar un Tipo de Parque (solo si no existe) y guardar su ID
IF NOT EXISTS (SELECT 1 FROM parques.TipoParque WHERE descripcion = 'Parque Nacional Test')
    EXEC parques.TipoParque_Insertar @descripcion = 'Parque Nacional Test';
SELECT @vIdTipo = idTipoParque FROM parques.TipoParque WHERE descripcion = 'Parque Nacional Test';

-- 2. Insertar Ubicacion (solo si no existe) y guardar su ID
IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion WHERE direccion = 'Ruta Test 1')
    EXEC parques.Ubicacion_Insertar @direccion = 'Ruta Test 1', @provincia = 'Misiones', @latitud = -25.0, @longitud = -54.0;
SELECT @vIdUbic = idUbicacion FROM parques.Ubicacion WHERE direccion = 'Ruta Test 1';

-- 3. Insertar el Parque usando las variables anteriores y guardar su ID
IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE nombre = 'Iguazu Test')
    EXEC parques.Parque_Insertar @nombre = 'Iguazu Test', @superficie = 1000, @idTipoParque = @vIdTipo, @idUbicacion = @vIdUbic;
SELECT @vIdParque = idParque FROM parques.Parque WHERE nombre = 'Iguazu Test';

-- 4. Insertar el Tour usando el ID del Parque y guardar su ID
IF NOT EXISTS (SELECT 1 FROM actividades.Tour WHERE nombre = 'Tour Cataratas Test')
    EXEC actividades.Tour_Insertar @nombre = 'Tour Cataratas Test', @duracion = 120, @cupoMaximo = 20, @precio = 5000, @idParque = @vIdParque;
SELECT @vIdTour = idTour FROM actividades.Tour WHERE nombre = 'Tour Cataratas Test';


-- Resultado esperado: asignación creada correctamente usando el ID del tour real (@vIdTour)
EXEC personal.AsignacionGuia_Insertar    
    @idTour      = @vIdTour,
    @dniGuia     = 30000001,
    @fechaInicio = '2025-01-01',
    @fechaFin    = '2025-06-30';

SELECT * FROM personal.AsignacionGuia WHERE dniGuia = 30000001;

PRINT '===== TEST 3 (OK): registrar atraccion valida =====';
-- Resultado esperado: atracción insertada
EXEC actividades.Atraccion_Insertar
    @nombre      = 'Senderismo Lago Verde',
    @tipo        = 'Outdoor',
    @precio      = 0,
    @duracion    = 120,
    @cupoMaximo  = 20,
    @idParque    = 1;
SELECT * FROM actividades.Atraccion WHERE nombre = 'Senderismo Lago Verde';

-- =====================
-- TESTS DE VALIDACIONES (ERRORES ESPERADOS)
-- =====================

PRINT '===== TEST 4 (ERROR): insertar guia con DNI duplicado =====';
-- Esperado: error "Ya existe un guia registrado con ese DNI"
BEGIN TRY
    EXEC personal.Guia_Insertar
        @dni                  = 30000001,
        @apyn                 = 'Otro Guia',
        @vigenciaAutorizacion = '2026-01-01';
    PRINT 'FALLO LA PRUEBA: se esperaba error de DNI duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 5 (ERROR): asignar guia con autorizacion vencida antes del fin del tour =====';
-- Esperado: error "La autorizacion del guia vence antes de la fecha de finalizacion del tour"
BEGIN TRY
    EXEC personal.AsignacionGuia_Insertar
        @idTour      = 1,
        @dniGuia     = 30000001,
        @fechaInicio = '2025-01-01',
        @fechaFin    = '2030-01-01'; -- fecha posterior a la vigencia (2027-12-31)
    PRINT 'FALLO LA PRUEBA: se esperaba error de autorizacion vencida.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 6 (ERROR): asignar guia con superposicion de fechas =====';
-- Esperado: error "El guia ya cuenta con un tour asignado en el rango de fechas solicitado"
BEGIN TRY
    EXEC personal.AsignacionGuia_Insertar
        @idTour      = 2,
        @dniGuia     = 30000001,
        @fechaInicio = '2025-03-01', -- se superpone con el test 2 (Ene-Jun 2025)
        @fechaFin    = '2025-09-01';
    PRINT 'FALLO LA PRUEBA: se esperaba error de superposicion de fechas.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 7 (ERROR): registrar atraccion con cupo 0 =====';
-- Esperado: error "El cupo maximo debe ser mayor a 0"
BEGIN TRY
    EXEC actividades.Atraccion_Insertar
        @nombre     = 'Atraccion invalida',
        @precio     = 0,
        @duracion   = 60,
        @cupoMaximo = 0,
        @idParque   = 1;
    PRINT 'FALLO LA PRUEBA: se esperaba error de cupo maximo invalido.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH
GO
