-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Script de testing unificado Entrega 5.
-- =============================================

-- ============================================================
-- 05_testing_parque_guardaparque.sql
-- ============================================================

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 16/06/2026
-- Descripcion: Testing del ABM del modulo Parques (02_abm_parques.sql).
--              Mezcla casos exitosos y casos que deben disparar validaciones.
--              Los casos de error se capturan con TRY/CATCH e imprimen el
--              mensaje esperado, para que el script no se interrumpa.
-- Pre-requisito: ejecutar 01_tablas_parques.sql y 02_abm_parques.sql.
-- =============================================

USE ParquesNacionales;
GO

SET NOCOUNT ON;

DECLARE @idTipo INT, @idUbic INT, @idParque INT;

PRINT '===== TEST 1 (OK): alta de TipoParque =====';
-- Esperado: se crea y muestra 'Tipo de parque creado con ID: X'.
EXEC parques.TipoParque_Insertar @descripcion = 'Parque Nacional';
SELECT @idTipo = idTipoParque FROM parques.TipoParque WHERE descripcion = 'Parque Nacional';

PRINT '===== TEST 2 (ERROR): TipoParque con descripcion duplicada =====';
-- Esperado: '- Ya existe un tipo de parque con esa descripcion.'
BEGIN TRY
    EXEC parques.TipoParque_Insertar @descripcion = 'Parque Nacional';
    PRINT 'FALLO LA PRUEBA: se esperaba error de duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 3 (ERROR): TipoParque sin descripcion =====';
-- Esperado: '- La descripcion del tipo de parque es obligatoria.'
BEGIN TRY
    EXEC parques.TipoParque_Insertar @descripcion = '';
    PRINT 'FALLO LA PRUEBA: se esperaba error de obligatoriedad.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 4 (OK): alta de Ubicacion =====';
EXEC parques.Ubicacion_Insertar
     @direccion = 'Av. San Martin 100',
     @provincia = 'Neuquen',
     @latitud   = -40.123456,
     @longitud  = -71.654321;
SELECT @idUbic = idUbicacion FROM parques.Ubicacion WHERE direccion = 'Av. San Martin 100';

PRINT '===== TEST 5 (ERROR): Ubicacion con latitud fuera de rango =====';
-- Esperado: '- La latitud debe estar entre -90 y 90.'
BEGIN TRY
    EXEC parques.Ubicacion_Insertar
         @direccion = 'Calle Falsa 123',
         @provincia = 'Rio Negro',
         @latitud   = 200,
         @longitud  = -71;
    PRINT 'FALLO LA PRUEBA: se esperaba error de latitud.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 6 (OK): alta de Parque =====';
EXEC parques.Parque_Insertar
     @nombre       = 'Nahuel Huapi',
     @superficie   = 7050.50,
     @idTipoParque = @idTipo,
     @idUbicacion  = @idUbic;
SELECT @idParque = idParque FROM parques.Parque WHERE nombre = 'Nahuel Huapi';
-- Evidencia de los datos cargados:
SELECT idParque, nombre, superficie, idTipoParque, idUbicacion
FROM parques.Parque WHERE idParque = @idParque;

PRINT '===== TEST 7 (ERROR): Parque con varios errores a la vez =====';
-- Esperado: UN solo mensaje que junta superficie<=0 y tipo inexistente.
BEGIN TRY
    EXEC parques.Parque_Insertar
         @nombre       = 'Parque Invalido',
         @superficie   = -5,
         @idTipoParque = 99999,
         @idUbicacion  = @idUbic;
    PRINT 'FALLO LA PRUEBA: se esperaban errores combinados.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 8 (OK): alta de Guardaparque =====';
EXEC personal.Guardaparque_Insertar
     @dni   = 30111222,
     @apyn  = 'Perez, Juan',
     @email = 'juan.perez@parques.gob.ar';
SELECT dni, apyn, email FROM personal.Guardaparque WHERE dni = 30111222;

PRINT '===== TEST 9 (ERROR): Guardaparque con dni invalido y email mal formado =====';
-- Esperado: UN solo mensaje con dni<=0 y email invalido.
BEGIN TRY
    EXEC personal.Guardaparque_Insertar
         @dni   = -1,
         @apyn  = 'Test',
         @email = 'no-es-un-email';
    PRINT 'FALLO LA PRUEBA: se esperaban errores combinados.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 10 (ERROR): eliminar un TipoParque en uso =====';
-- Esperado: '- No se puede eliminar: existen parques asociados a este tipo.'
BEGIN TRY
    EXEC parques.TipoParque_Eliminar @idTipoParque = @idTipo;
    PRINT 'FALLO LA PRUEBA: se esperaba bloqueo por dependencia.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 11 (OK): obtener Parque por ID =====';
EXEC parques.Parque_ObtenerPorId @idParque = @idParque;
GO


-- ============================================================
-- 05_testing_negocio_parque_guardaparque.sql
-- ============================================================

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 16/06/2026
-- Descripcion: Testing de la logica de negocio del modulo Parques
--              (03_negocio_parques.sql). Recorre el ciclo de vida de un
--              guardaparque (alta, reasignacion, egreso) y el alta de parque,
--              con casos exitosos y casos que disparan validaciones.
-- Pre-requisito: ejecutar 01_tablas_parques.sql, 02_abm_parques.sql y
--                03_negocio_parques.sql.
-- =============================================

USE ParquesNacionales;
GO

SET NOCOUNT ON;

DECLARE @idTipo INT, @idParqueA INT, @idParqueB INT;

PRINT '===== SETUP: tipo de parque para las pruebas =====';
IF NOT EXISTS (SELECT 1 FROM parques.TipoParque WHERE descripcion = 'Reserva Natural')
    EXEC parques.TipoParque_Insertar @descripcion = 'Reserva Natural';
SELECT @idTipo = idTipoParque FROM parques.TipoParque WHERE descripcion = 'Reserva Natural';

PRINT '===== TEST 1 (OK): registrar parque (Ubicacion + Parque en una transaccion) =====';
EXEC parques.RegistrarParque
     @nombre       = 'Los Alerces',
     @superficie   = 2630.00,
     @idTipoParque = @idTipo,
     @direccion    = 'Ruta 71 s/n',
     @provincia    = 'Chubut',
     @latitud      = -42.800000,
     @longitud     = -71.900000;
SELECT @idParqueA = idParque FROM parques.Parque WHERE nombre = 'Los Alerces';
-- Evidencia: parque y ubicacion quedaron enlazados.
SELECT p.idParque, p.nombre, u.direccion, u.provincia
FROM parques.Parque p
JOIN parques.Ubicacion u ON u.idUbicacion = p.idUbicacion
WHERE p.idParque = @idParqueA;

PRINT '===== TEST 2 (ERROR): registrar parque con datos invalidos =====';
-- Esperado: UN solo mensaje con superficie<=0, tipo inexistente y latitud fuera de rango.
BEGIN TRY
    EXEC parques.RegistrarParque
         @nombre       = 'Parque Roto',
         @superficie   = 0,
         @idTipoParque = 99999,
         @direccion    = 'Direccion X',
         @provincia    = 'Provincia X',
         @latitud      = 999,
         @longitud     = -71;
    PRINT 'FALLO LA PRUEBA: se esperaban errores combinados.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH
-- Evidencia: no debe haber quedado ninguna ubicacion suelta de este intento.
SELECT COUNT(*) AS ubicaciones_huerfanas
FROM parques.Ubicacion WHERE direccion = 'Direccion X';

PRINT '===== TEST 3 (OK): registrar guardaparque con su asignacion inicial =====';
EXEC personal.RegistrarGuardaparque
     @dni         = 28999888,
     @apyn        = 'Gomez, Ana',
     @idParque    = @idParqueA,
     @fechaInicio = '2025-01-10';
-- Evidencia: queda una asignacion vigente (fechaFin NULL).
SELECT idAsignacion, dni, idParque, fechaInicio, fechaFin
FROM personal.AsignacionGuardaparque WHERE dni = 28999888;

PRINT '===== TEST 4 (ERROR): registrar guardaparque con dni ya existente =====';
-- Esperado: '- Ya existe un guardaparque registrado con ese DNI.'
BEGIN TRY
    EXEC personal.RegistrarGuardaparque
         @dni         = 28999888,
         @apyn        = 'Otro Nombre',
         @idParque    = @idParqueA,
         @fechaInicio = '2025-02-01';
    PRINT 'FALLO LA PRUEBA: se esperaba error de dni duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== SETUP: segundo parque para la reasignacion =====';
EXEC parques.RegistrarParque
     @nombre       = 'Lanin',
     @superficie   = 4120.00,
     @idTipoParque = @idTipo,
     @direccion    = 'Ruta 40 km 2000',
     @provincia    = 'Neuquen',
     @latitud      = -39.600000,
     @longitud     = -71.500000;
SELECT @idParqueB = idParque FROM parques.Parque WHERE nombre = 'Lanin';

PRINT '===== TEST 5 (OK): reasignar el guardaparque al segundo parque =====';
EXEC personal.ReasignarGuardaparque
     @dni               = 28999888,
     @idParqueDestino   = @idParqueB,
     @fechaReasignacion = '2025-06-01';
-- Evidencia: 2 filas. La 1ra cerrada (fechaFin=2025-06-01, motivo 'Reasignacion')
-- y la 2da vigente (fechaFin NULL) en el parque B.
SELECT idAsignacion, idParque, fechaInicio, fechaFin, motivoEgreso
FROM personal.AsignacionGuardaparque
WHERE dni = 28999888
ORDER BY fechaInicio;

PRINT '===== TEST 6 (ERROR): reasignar al mismo parque en el que ya esta =====';
-- Esperado: '- El parque destino es el mismo que el parque actual.'
BEGIN TRY
    EXEC personal.ReasignarGuardaparque
         @dni               = 28999888,
         @idParqueDestino   = @idParqueB,
         @fechaReasignacion = '2025-07-01';
    PRINT 'FALLO LA PRUEBA: se esperaba error de destino igual al actual.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 7 (OK): registrar el egreso del guardaparque =====';
EXEC personal.RegistrarEgresoGuardaparque
     @dni          = 28999888,
     @fechaEgreso  = '2025-12-31',
     @motivoEgreso = 'Renuncia';
-- Evidencia: ya no debe quedar ninguna asignacion vigente.
SELECT COUNT(*) AS asignaciones_vigentes
FROM personal.AsignacionGuardaparque
WHERE dni = 28999888 AND fechaFin IS NULL;

PRINT '===== TEST 8 (ERROR): registrar egreso sin asignacion vigente =====';
-- Esperado: '- El guardaparque no tiene una asignacion vigente...'
BEGIN TRY
    EXEC personal.RegistrarEgresoGuardaparque
         @dni          = 28999888,
         @fechaEgreso  = '2026-01-15',
         @motivoEgreso = 'Renuncia';
    PRINT 'FALLO LA PRUEBA: se esperaba error de sin asignacion vigente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH
GO


-- ============================================================
-- 05_testing_guias_tour_atracciones.sql
-- ============================================================

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


-- ============================================================
-- 05_testing_abm_concesiones.sql
-- ============================================================

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Scripts de testing para SPs de ABM - modulo Concesiones.
--              Cubre casos exitosos con evidencia (SELECT) y casos fallidos
--              que demuestran el comportamiento de las validaciones.
-- Prerequisito: Ejecutar 02_tablas_concesiones.sql y 03_abm_concesiones.sql
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- TESTING: TipoConsesion_Insertar / Eliminar / Actualizar
-- ============================================================

PRINT '===== TEST 1 (OK): alta de TipoDeConsesion =====';
EXEC concesiones.TipoConsesion_Insertar @descripcion = 'Gastronomia';
EXEC concesiones.TipoConsesion_Insertar @descripcion = 'Turismo aventura';
EXEC concesiones.TipoConsesion_Insertar @descripcion = 'Comercio minorista';
SELECT * FROM concesiones.TipoDeConsesion;

PRINT '===== TEST 2 (ERROR): descripcion vacia =====';
BEGIN TRY
    EXEC concesiones.TipoConsesion_Insertar @descripcion = '';
    PRINT 'FALLO LA PRUEBA: se esperaba error de descripcion obligatoria.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 3 (ERROR): descripcion duplicada =====';
BEGIN TRY
    EXEC concesiones.TipoConsesion_Insertar @descripcion = 'Gastronomia';
    PRINT 'FALLO LA PRUEBA: se esperaba error de descripcion duplicada.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 4 (OK): actualizacion de TipoDeConsesion =====';
EXEC concesiones.TipoConsesion_Actualizar @idTipoConcesion = 3, @descripcion = 'Comercio y souvenirs';
SELECT * FROM concesiones.TipoDeConsesion WHERE idTipoConcesion = 3;

PRINT '===== TEST 5 (ERROR): actualizar ID inexistente =====';
BEGIN TRY
    EXEC concesiones.TipoConsesion_Actualizar @idTipoConcesion = 999, @descripcion = 'Test';
    PRINT 'FALLO LA PRUEBA: se esperaba error de ID inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

-- ============================================================
-- TESTING: Empresa_Insertar / Eliminar / Actualizar
-- ============================================================

PRINT '===== TEST 6 (OK): alta de Empresa =====';
EXEC concesiones.Empresa_Insertar
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @contacto    = 'Carlos Fernandez',
    @email       = 'contacto@cabanabosque.com',
    @telefono    = '011-4523-9876';

EXEC concesiones.Empresa_Insertar
    @razonSocial = 'Aventura Patagonica S.A.',
    @cuit        = '30798765432',
    @email       = 'info@aventurapatag.com';

SELECT * FROM concesiones.Empresa;

PRINT '===== TEST 7 (ERROR): CUIT duplicado =====';
BEGIN TRY
    EXEC concesiones.Empresa_Insertar
        @razonSocial = 'Empresa Copia',
        @cuit        = '30712345678';
    PRINT 'FALLO LA PRUEBA: se esperaba error de CUIT duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 8 (ERROR): multiples errores simultaneos en Empresa =====';
BEGIN TRY
    EXEC concesiones.Empresa_Insertar
        @razonSocial = '',
        @cuit        = '123',
        @email       = 'emailinvalido';
    PRINT 'FALLO LA PRUEBA: se esperaban errores de razon social, CUIT y email invalidos.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 9 (OK): actualizacion de Empresa =====';
EXEC concesiones.Empresa_Actualizar
    @idEmpresa   = 1,
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @telefono    = '011-4523-0000';
SELECT * FROM concesiones.Empresa WHERE idEmpresa = 1;

-- ============================================================
-- TESTING: Concesion_Insertar / Eliminar / Actualizar
-- (Requiere idParque valido de parques.Parque)
-- ============================================================

PRINT '===== TEST 10 (OK): alta de Concesion =====';
EXEC concesiones.Concesion_Insertar
    @descripcion     = 'Restaurante principal - Parque Nahuel Huapi',
    @idTipoConcesion = 1,
    @idParque        = 1,
    @idEmpresa       = 1,
    @fechaInicio     = '2025-01-01',
    @fechaFin        = '2026-12-31',
    @canonMensual    = 150000.00;

EXEC concesiones.Concesion_Insertar
    @descripcion     = 'Excursiones de trekking - Parque Los Glaciares',
    @idTipoConcesion = 2,
    @idParque        = 2,
    @idEmpresa       = 2,
    @fechaInicio     = '2025-03-01',
    @fechaFin        = '2027-02-28',
    @canonMensual    = 80000.00;

SELECT * FROM concesiones.Concesion;

PRINT '===== TEST 11 (ERROR): fecha fin anterior a inicio =====';
BEGIN TRY
    EXEC concesiones.Concesion_Insertar
        @descripcion     = 'Concesion invalida',
        @idTipoConcesion = 1,
        @idParque        = 1,
        @idEmpresa       = 1,
        @fechaInicio     = '2026-01-01',
        @fechaFin        = '2025-01-01',
        @canonMensual    = 50000.00;
    PRINT 'FALLO LA PRUEBA: se esperaba error de fechas invalidas.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 12 (ERROR): empresa inexistente =====';
BEGIN TRY
    EXEC concesiones.Concesion_Insertar
        @descripcion     = 'Concesion empresa fantasma',
        @idTipoConcesion = 1,
        @idParque        = 1,
        @idEmpresa       = 999,
        @fechaInicio     = '2025-01-01',
        @fechaFin        = '2026-12-31',
        @canonMensual    = 50000.00;
    PRINT 'FALLO LA PRUEBA: se esperaba error de empresa inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 13 (ERROR): canon igual a cero =====';
BEGIN TRY
    EXEC concesiones.Concesion_Insertar
        @descripcion     = 'Concesion canon cero',
        @idTipoConcesion = 1,
        @idParque        = 1,
        @idEmpresa       = 1,
        @fechaInicio     = '2025-01-01',
        @fechaFin        = '2026-12-31',
        @canonMensual    = 0;
    PRINT 'FALLO LA PRUEBA: se esperaba error de canon invalido.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 14 (ERROR): baja de tipo con concesiones asociadas =====';
BEGIN TRY
    EXEC concesiones.TipoConsesion_Eliminar @idTipoConcesion = 1;
    PRINT 'FALLO LA PRUEBA: se esperaba bloqueo por dependencia.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 15 (OK): baja de concesion sin pagos =====';
EXEC concesiones.Concesion_Insertar
    @descripcion     = 'Concesion temporal para borrar',
    @idTipoConcesion = 3,
    @idParque        = 1,
    @idEmpresa       = 2,
    @fechaInicio     = '2025-01-01',
    @fechaFin        = '2025-06-30',
    @canonMensual    = 10000.00;

DECLARE @vIdTemp INT = (SELECT MAX(idConcesion) FROM concesiones.Concesion);
EXEC concesiones.Concesion_Eliminar @idConcesion = @vIdTemp;
SELECT * FROM concesiones.Concesion;

-- ============================================================
-- TESTING: PagoConcesion_Insertar / Eliminar / Actualizar
-- ============================================================

PRINT '===== TEST 16 (OK): alta de pagos de canon =====';
EXEC concesiones.PagoConcesion_Insertar
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-02-05',
    @periodoAnio = 2025,
    @periodoMes  = 1;

EXEC concesiones.PagoConcesion_Insertar
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-03-03',
    @periodoAnio = 2025,
    @periodoMes  = 2;

SELECT * FROM concesiones.PagoConcesion;

PRINT '===== TEST 17 (ERROR): pago duplicado para el mismo periodo =====';
BEGIN TRY
    EXEC concesiones.PagoConcesion_Insertar
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2025-02-10',
        @periodoAnio = 2025,
        @periodoMes  = 1;
    PRINT 'FALLO LA PRUEBA: se esperaba error de periodo duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 18 (ERROR): mes fuera de rango =====';
BEGIN TRY
    EXEC concesiones.PagoConcesion_Insertar
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2025-01-05',
        @periodoAnio = 2025,
        @periodoMes  = 13;
    PRINT 'FALLO LA PRUEBA: se esperaba error de mes invalido.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 19 (ERROR): monto negativo =====';
BEGIN TRY
    EXEC concesiones.PagoConcesion_Insertar
        @idConcesion = 1,
        @monto       = -500.00,
        @fechaPago   = '2025-04-05',
        @periodoAnio = 2025,
        @periodoMes  = 3;
    PRINT 'FALLO LA PRUEBA: se esperaba error de monto invalido.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 20 (OK): actualizacion de monto de pago =====';
EXEC concesiones.PagoConcesion_Actualizar
    @idPagoConcesion = 1,
    @monto           = 155000.00,
    @fechaPago       = '2025-02-05';
SELECT * FROM concesiones.PagoConcesion WHERE idPagoConcesion = 1;

PRINT '===== TEST 21 (OK): baja de pago =====';
EXEC concesiones.PagoConcesion_Eliminar @idPagoConcesion = 2;
SELECT * FROM concesiones.PagoConcesion;

PRINT '===== TEST 22 (ERROR): baja de pago con ID inexistente =====';
BEGIN TRY
    EXEC concesiones.PagoConcesion_Eliminar @idPagoConcesion = 999;
    PRINT 'FALLO LA PRUEBA: se esperaba error de pago inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 23 (ERROR): baja de concesion con pagos registrados =====';
BEGIN TRY
    EXEC concesiones.Concesion_Eliminar @idConcesion = 1;
    PRINT 'FALLO LA PRUEBA: se esperaba bloqueo por pagos asociados.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH
GO


-- ============================================================
-- 05_testing_negocio_concesiones.sql
-- ============================================================

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Scripts de testing para SPs de logica de negocio - modulo Concesiones.
--              Cubre casos exitosos con evidencia (SELECT) y casos fallidos
--              que demuestran el comportamiento de las validaciones.
-- Prerequisito: Ejecutar 02_tablas_concesiones.sql, 03_abm_concesiones.sql
--               y 04_negocio_concesiones.sql
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- DATOS BASE para los tests
-- (Si ya existen de los tests ABM, comentar este bloque)
-- ============================================================

EXEC concesiones.TipoConsesion_Insertar @descripcion = 'Gastronomia';
EXEC concesiones.TipoConsesion_Insertar @descripcion = 'Turismo aventura';

EXEC concesiones.Empresa_Insertar
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @email       = 'contacto@cabanabosque.com';

EXEC concesiones.Empresa_Insertar
    @razonSocial = 'Aventura Patagonica S.A.',
    @cuit        = '30798765432',
    @email       = 'info@aventurapatag.com';

-- ============================================================
-- TESTING: AltaConcesionCompleta
-- ============================================================

PRINT '===== TEST 1 (OK): alta de concesion valida sin solapamiento =====';
EXEC concesiones.AltaConcesionCompleta
    @descripcion     = 'Restaurante principal - Parque Nahuel Huapi',
    @idTipoConcesion = 1,
    @idParque        = 1,
    @idEmpresa       = 1,
    @fechaInicio     = '2025-01-01',
    @fechaFin        = '2026-12-31',
    @canonMensual    = 150000.00;
-- Evidencia
SELECT
    c.idConcesion,
    c.descripcion,
    t.descripcion        AS tipoConcesion,
    e.razonSocial        AS empresa,
    c.fechaInicio,
    c.fechaFin,
    c.canonMensual
FROM concesiones.Concesion c
JOIN concesiones.TipoDeConsesion t ON t.idTipoConcesion = c.idTipoConcesion
JOIN concesiones.Empresa e         ON e.idEmpresa       = c.idEmpresa;

PRINT '===== TEST 2 (ERROR): empresa inexistente =====';
BEGIN TRY
    EXEC concesiones.AltaConcesionCompleta
        @descripcion     = 'Concesion empresa fantasma',
        @idTipoConcesion = 1,
        @idParque        = 1,
        @idEmpresa       = 999,
        @fechaInicio     = '2025-01-01',
        @fechaFin        = '2026-12-31',
        @canonMensual    = 50000.00;
    PRINT 'FALLO LA PRUEBA: se esperaba error de empresa inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 3 (ERROR): parque inexistente =====';
BEGIN TRY
    EXEC concesiones.AltaConcesionCompleta
        @descripcion     = 'Concesion parque fantasma',
        @idTipoConcesion = 1,
        @idParque        = 999,
        @idEmpresa       = 1,
        @fechaInicio     = '2025-01-01',
        @fechaFin        = '2026-12-31',
        @canonMensual    = 50000.00;
    PRINT 'FALLO LA PRUEBA: se esperaba error de parque inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 4 (ERROR): solapamiento con concesion vigente misma empresa/parque/tipo =====';
BEGIN TRY
    EXEC concesiones.AltaConcesionCompleta
        @descripcion     = 'Segunda concesion gastronomica misma empresa',
        @idTipoConcesion = 1,
        @idParque        = 1,
        @idEmpresa       = 1,
        @fechaInicio     = '2026-01-01',
        @fechaFin        = '2027-12-31',
        @canonMensual    = 160000.00;
    PRINT 'FALLO LA PRUEBA: se esperaba bloqueo por solapamiento de concesion vigente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 5 (ERROR): multiples errores simultaneos =====';
BEGIN TRY
    EXEC concesiones.AltaConcesionCompleta
        @descripcion     = '',
        @idTipoConcesion = 999,
        @idParque        = 999,
        @idEmpresa       = 999,
        @fechaInicio     = '2026-01-01',
        @fechaFin        = '2025-01-01',
        @canonMensual    = 0;
    PRINT 'FALLO LA PRUEBA: se esperaban errores combinados de descripcion, IDs y fechas.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 6 (OK): misma empresa, mismo parque, diferente tipo =====';
EXEC concesiones.AltaConcesionCompleta
    @descripcion     = 'Excursiones de trekking - Parque Nahuel Huapi',
    @idTipoConcesion = 2,
    @idParque        = 1,
    @idEmpresa       = 1,
    @fechaInicio     = '2025-06-01',
    @fechaFin        = '2027-05-31',
    @canonMensual    = 95000.00;
SELECT * FROM concesiones.Concesion;

-- ============================================================
-- TESTING: RegistrarPagoCanon
-- ============================================================

PRINT '===== TEST 7 (OK): primer pago de canon =====';
EXEC concesiones.RegistrarPagoCanon
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-02-05',
    @periodoAnio = 2025,
    @periodoMes  = 1;

PRINT '===== TEST 8 (OK): segundo pago de canon =====';
EXEC concesiones.RegistrarPagoCanon
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-03-03',
    @periodoAnio = 2025,
    @periodoMes  = 2;
-- Evidencia
SELECT
    p.idPagoConcesion,
    c.descripcion AS concesion,
    p.periodoMes,
    p.periodoAnio,
    p.monto,
    p.fechaPago
FROM concesiones.PagoConcesion p
JOIN concesiones.Concesion c ON c.idConcesion = p.idConcesion
ORDER BY p.periodoAnio, p.periodoMes;

PRINT '===== TEST 9 (ERROR): pago duplicado para el mismo periodo =====';
BEGIN TRY
    EXEC concesiones.RegistrarPagoCanon
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2025-02-10',
        @periodoAnio = 2025,
        @periodoMes  = 1;
    PRINT 'FALLO LA PRUEBA: se esperaba error de periodo duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 10 (ERROR): concesion inexistente =====';
BEGIN TRY
    EXEC concesiones.RegistrarPagoCanon
        @idConcesion = 999,
        @monto       = 50000.00,
        @fechaPago   = '2025-02-05',
        @periodoAnio = 2025,
        @periodoMes  = 1;
    PRINT 'FALLO LA PRUEBA: se esperaba error de concesion inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 11 (ERROR): periodo anterior al inicio de la concesion =====';
BEGIN TRY
    EXEC concesiones.RegistrarPagoCanon
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2024-12-05',
        @periodoAnio = 2024,
        @periodoMes  = 12;
    PRINT 'FALLO LA PRUEBA: se esperaba error de periodo fuera del rango de la concesion.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 12 (ERROR): periodo posterior al vencimiento de la concesion =====';
BEGIN TRY
    EXEC concesiones.RegistrarPagoCanon
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2027-01-05',
        @periodoAnio = 2027,
        @periodoMes  = 1;
    PRINT 'FALLO LA PRUEBA: se esperaba error de periodo posterior al vencimiento.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 13 (ERROR): mes invalido (0) =====';
BEGIN TRY
    EXEC concesiones.RegistrarPagoCanon
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2025-01-05',
        @periodoAnio = 2025,
        @periodoMes  = 0;
    PRINT 'FALLO LA PRUEBA: se esperaba error de mes fuera de rango.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 14 (ERROR): monto negativo y mes invalido (multiples errores) =====';
BEGIN TRY
    EXEC concesiones.RegistrarPagoCanon
        @idConcesion = 1,
        @monto       = -1000.00,
        @fechaPago   = '2025-01-05',
        @periodoAnio = 2019,
        @periodoMes  = 13;
    PRINT 'FALLO LA PRUEBA: se esperaban errores combinados de monto, anio y mes.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

-- Evidencia final: todos los pagos registrados
PRINT '===== Estado final de pagos =====';
SELECT
    p.idPagoConcesion,
    c.descripcion AS concesion,
    p.periodoMes,
    p.periodoAnio,
    p.monto,
    p.fechaPago
FROM concesiones.PagoConcesion p
JOIN concesiones.Concesion c ON c.idConcesion = p.idConcesion
ORDER BY p.periodoAnio, p.periodoMes;

-- Reporte: concesiones con pagos atrasados (mes anterior sin pago)
PRINT '===== Reporte: concesiones con pagos atrasados =====';
SELECT
    c.idConcesion,
    c.descripcion,
    e.razonSocial,
    c.canonMensual,
    c.fechaFin
FROM concesiones.Concesion c
JOIN concesiones.Empresa e ON e.idEmpresa = c.idEmpresa
WHERE c.fechaFin >= CAST(GETDATE() AS DATE)
  AND NOT EXISTS (
      SELECT 1 FROM concesiones.PagoConcesion p
      WHERE p.idConcesion = c.idConcesion
        AND p.periodoAnio = YEAR(DATEADD(MONTH, -1, GETDATE()))
        AND p.periodoMes  = MONTH(DATEADD(MONTH, -1, GETDATE()))
  );
GO


-- ============================================================
-- 05_testing_abm_ventas.sql
-- ============================================================

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 16/06/2026
-- Descripcion: Testing del ABM del modulo Ventas y Precios.
--              Mezcla casos exitosos y casos que deben disparar validaciones.
--              Los casos de error se capturan con TRY/CATCH para que el script no se interrumpa.
-- Pre-requisito: ejecutar Reset database.sql, 01_tablas_necesarias.sql,
--                02_tablas_ventas.sql y 03_abm_ventas.sql.
-- =============================================

USE ParquesNacionales;
GO

SET NOCOUNT ON;

DECLARE
    @idTipoParque INT,
    @idUbicacion INT,
    @idParque INT,
    @idTour INT,
    @idAtraccion INT,
    @idTipoVisitanteResidente INT,
    @idTipoVisitanteExtranjero INT,
    @idTipoVisitanteTemporal INT,
    @idPrecioResidente INT,
    @idPrecioExtranjero INT,
    @idTicket INT,
    @idTicketEliminar INT,
    @idLineaVenta INT;

-- ============================================================
-- SETUP: DATOS BASE NECESARIOS
-- ============================================================

PRINT '===== SETUP: carga de datos base =====';

INSERT INTO parques.TipoParque (descripcion)
VALUES ('Parque Nacional');

SET @idTipoParque = SCOPE_IDENTITY();

INSERT INTO parques.Ubicacion (direccion, provincia, latitud, longitud)
VALUES ('Ruta Nacional 12', 'Misiones', -25.695278, -54.436667);

SET @idUbicacion = SCOPE_IDENTITY();

INSERT INTO parques.Parque (nombre, superficie, idTipoParque, idUbicacion)
VALUES ('Parque Nacional Iguazu', 67200.00, @idTipoParque, @idUbicacion);

SET @idParque = SCOPE_IDENTITY();

INSERT INTO actividades.Tour (nombre, descripcion, duracion, cupoMaximo, precio, idParque)
VALUES ('Tour Cataratas', 'Recorrido por las cataratas', 120, 30, 5000.00, @idParque);

SET @idTour = SCOPE_IDENTITY();

INSERT INTO actividades.Atraccion (nombre, descripcion, tipo, precio, duracion, cupoMaximo, idParque)
VALUES ('Garganta del Diablo', 'Atraccion principal', 'Natural', 3000.00, 90, 50, @idParque);

SET @idAtraccion = SCOPE_IDENTITY();

-- ============================================================
-- TIPO VISITANTE
-- ============================================================

PRINT '===== TEST 1 (OK): insertar TipoVisitante =====';

EXEC ventas.TipoVisitante_Insertar @descripcion = 'Residente';
EXEC ventas.TipoVisitante_Insertar @descripcion = 'Extranjero';
EXEC ventas.TipoVisitante_Insertar @descripcion = 'Temporal';

SELECT @idTipoVisitanteResidente = idTipoVisitante
FROM ventas.TipoVisitante
WHERE descripcion = 'Residente';

SELECT @idTipoVisitanteExtranjero = idTipoVisitante
FROM ventas.TipoVisitante
WHERE descripcion = 'Extranjero';

SELECT @idTipoVisitanteTemporal = idTipoVisitante
FROM ventas.TipoVisitante
WHERE descripcion = 'Temporal';

SELECT * FROM ventas.TipoVisitante;

PRINT '===== TEST 2 (ERROR): insertar TipoVisitante duplicado =====';
BEGIN TRY
    EXEC ventas.TipoVisitante_Insertar @descripcion = 'Residente';
    PRINT 'FALLO LA PRUEBA: se esperaba error de duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 3 (ERROR): insertar TipoVisitante sin descripcion =====';
BEGIN TRY
    EXEC ventas.TipoVisitante_Insertar @descripcion = '';
    PRINT 'FALLO LA PRUEBA: se esperaba error de descripcion obligatoria.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 4 (OK): actualizar TipoVisitante =====';

EXEC ventas.TipoVisitante_Actualizar
    @idTipoVisitante = @idTipoVisitanteResidente,
    @descripcion = 'Residente Nacional';

SELECT * FROM ventas.TipoVisitante;

PRINT '===== TEST 5 (ERROR): actualizar TipoVisitante con descripcion duplicada =====';
BEGIN TRY
    EXEC ventas.TipoVisitante_Actualizar
        @idTipoVisitante = @idTipoVisitanteTemporal,
        @descripcion = 'Extranjero';
    PRINT 'FALLO LA PRUEBA: se esperaba error de descripcion duplicada.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 6 (OK): eliminar TipoVisitante temporal =====';

EXEC ventas.TipoVisitante_Eliminar
    @idTipoVisitante = @idTipoVisitanteTemporal;

SELECT * FROM ventas.TipoVisitante;

-- ============================================================
-- PRECIO ENTRADA
-- ============================================================

PRINT '===== TEST 7 (OK): insertar PrecioEntrada vigente =====';

EXEC ventas.PrecioEntrada_Insertar
    @valor = 2500.00,
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente;

EXEC ventas.PrecioEntrada_Insertar
    @valor = 6000.00,
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteExtranjero;

SELECT @idPrecioResidente = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteResidente
  AND fechaHasta IS NULL;

SELECT @idPrecioExtranjero = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteExtranjero
  AND fechaHasta IS NULL;

SELECT * FROM ventas.PrecioEntrada;

PRINT '===== TEST 8 (ERROR): insertar PrecioEntrada con valor negativo =====';
BEGIN TRY
    EXEC ventas.PrecioEntrada_Insertar
        @valor = -100.00,
        @idParque = @idParque,
        @idTipoVisitante = @idTipoVisitanteResidente;
    PRINT 'FALLO LA PRUEBA: se esperaba error de valor negativo.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 9 (ERROR): insertar PrecioEntrada con parque inexistente =====';
BEGIN TRY
    EXEC ventas.PrecioEntrada_Insertar
        @valor = 1000.00,
        @idParque = 99999,
        @idTipoVisitante = @idTipoVisitanteResidente;
    PRINT 'FALLO LA PRUEBA: se esperaba error de parque inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 10 (ERROR): insertar PrecioEntrada vigente duplicado =====';
BEGIN TRY
    EXEC ventas.PrecioEntrada_Insertar
        @valor = 3000.00,
        @idParque = @idParque,
        @idTipoVisitante = @idTipoVisitanteResidente;
    PRINT 'FALLO LA PRUEBA: se esperaba error de precio vigente duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 11 (OK): actualizar PrecioEntrada versionando precio =====';

EXEC ventas.PrecioEntrada_Actualizar
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente,
    @nuevoValor = 3500.00;

SELECT *
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteResidente
ORDER BY idPrecio;

SELECT @idPrecioResidente = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteResidente
  AND fechaHasta IS NULL;

PRINT '===== TEST 12 (ERROR): actualizar PrecioEntrada con tipo visitante inexistente =====';
BEGIN TRY
    EXEC ventas.PrecioEntrada_Actualizar
        @idParque = @idParque,
        @idTipoVisitante = 99999,
        @nuevoValor = 4000.00;
    PRINT 'FALLO LA PRUEBA: se esperaba error de tipo visitante inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 13 (OK): baja logica de PrecioEntrada =====';

EXEC ventas.PrecioEntrada_Eliminar
    @idPrecio = @idPrecioExtranjero;

SELECT *
FROM ventas.PrecioEntrada
WHERE idPrecio = @idPrecioExtranjero;

PRINT '===== TEST 14 (ERROR): baja logica de PrecioEntrada ya dado de baja =====';
BEGIN TRY
    EXEC ventas.PrecioEntrada_Eliminar
        @idPrecio = @idPrecioExtranjero;
    PRINT 'FALLO LA PRUEBA: se esperaba error de precio ya dado de baja.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

-- Volvemos a crear precio extranjero vigente para usarlo luego
EXEC ventas.PrecioEntrada_Insertar
    @valor = 6500.00,
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteExtranjero;

SELECT @idPrecioExtranjero = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteExtranjero
  AND fechaHasta IS NULL;

-- ============================================================
-- TICKET VENTA
-- ============================================================

PRINT '===== TEST 15 (OK): insertar TicketVenta =====';

EXEC ventas.TicketVenta_Insertar
    @puntoDeVenta = 1,
    @formaPago = 'Efectivo',
    @idParque = @idParque;

SELECT @idTicket = MAX(idTicket)
FROM ventas.TicketVenta
WHERE puntoDeVenta = 1;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 16 (ERROR): insertar TicketVenta sin formaPago =====';
BEGIN TRY
    EXEC ventas.TicketVenta_Insertar
        @puntoDeVenta = 1,
        @formaPago = '',
        @idParque = @idParque;
    PRINT 'FALLO LA PRUEBA: se esperaba error de forma de pago.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 17 (ERROR): insertar TicketVenta con parque inexistente =====';
BEGIN TRY
    EXEC ventas.TicketVenta_Insertar
        @puntoDeVenta = 1,
        @formaPago = 'Tarjeta',
        @idParque = 99999;
    PRINT 'FALLO LA PRUEBA: se esperaba error de parque inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 18 (OK): actualizar TicketVenta solo formaPago =====';

EXEC ventas.TicketVenta_Actualizar
    @idTicket = @idTicket,
    @formaPago = 'Tarjeta';

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 19 (ERROR): actualizar TicketVenta inexistente =====';
BEGIN TRY
    EXEC ventas.TicketVenta_Actualizar
        @idTicket = 99999,
        @formaPago = 'Efectivo';
    PRINT 'FALLO LA PRUEBA: se esperaba error de ticket inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

-- ============================================================
-- LINEA VENTA
-- ============================================================

PRINT '===== TEST 20 (OK): insertar LineaVenta de entrada =====';

EXEC ventas.LineaVenta_Insertar
    @ticketAsociado = @idTicket,
    @cantidad = 2,
    @idPrecioEntrada = @idPrecioResidente,
    @idTour = NULL,
    @idAtraccion = NULL;

SELECT @idLineaVenta = MAX(idLineaVenta)
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 21 (OK): insertar LineaVenta de tour =====';

EXEC ventas.LineaVenta_Insertar
    @ticketAsociado = @idTicket,
    @cantidad = 1,
    @idPrecioEntrada = NULL,
    @idTour = @idTour,
    @idAtraccion = NULL;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 22 (ERROR): insertar LineaVenta con mas de un item asociado =====';
BEGIN TRY
    EXEC ventas.LineaVenta_Insertar
        @ticketAsociado = @idTicket,
        @cantidad = 1,
        @idPrecioEntrada = @idPrecioResidente,
        @idTour = @idTour,
        @idAtraccion = NULL;
    PRINT 'FALLO LA PRUEBA: se esperaba error por mas de un item asociado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 23 (ERROR): insertar LineaVenta con cantidad invalida =====';
BEGIN TRY
    EXEC ventas.LineaVenta_Insertar
        @ticketAsociado = @idTicket,
        @cantidad = 0,
        @idPrecioEntrada = @idPrecioResidente,
        @idTour = NULL,
        @idAtraccion = NULL;
    PRINT 'FALLO LA PRUEBA: se esperaba error por cantidad invalida.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 24 (ERROR): insertar LineaVenta con ticket inexistente =====';
BEGIN TRY
    EXEC ventas.LineaVenta_Insertar
        @ticketAsociado = 99999,
        @cantidad = 1,
        @idPrecioEntrada = @idPrecioResidente,
        @idTour = NULL,
        @idAtraccion = NULL;
    PRINT 'FALLO LA PRUEBA: se esperaba error por ticket inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 25 (OK): actualizar LineaVenta a atraccion =====';

EXEC ventas.LineaVenta_Actualizar
    @idLineaVenta = @idLineaVenta,
    @cantidad = 3,
    @idPrecioEntrada = NULL,
    @idTour = NULL,
    @idAtraccion = @idAtraccion;

SELECT *
FROM ventas.LineaVenta
WHERE idLineaVenta = @idLineaVenta;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 26 (ERROR): actualizar LineaVenta inexistente =====';
BEGIN TRY
    EXEC ventas.LineaVenta_Actualizar
        @idLineaVenta = 99999,
        @cantidad = 1,
        @idPrecioEntrada = NULL,
        @idTour = @idTour,
        @idAtraccion = NULL;
    PRINT 'FALLO LA PRUEBA: se esperaba error de linea inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 27 (OK): eliminar LineaVenta y recalcular total =====';

EXEC ventas.LineaVenta_Eliminar
    @idLineaVenta = @idLineaVenta;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

PRINT '===== TEST 28 (ERROR): eliminar LineaVenta inexistente =====';
BEGIN TRY
    EXEC ventas.LineaVenta_Eliminar
        @idLineaVenta = 99999;
    PRINT 'FALLO LA PRUEBA: se esperaba error de linea inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

-- ============================================================
-- TICKET VENTA - ELIMINACION CON LINEAS
-- ============================================================

PRINT '===== TEST 29 (OK): eliminar TicketVenta con lineas asociadas =====';

EXEC ventas.TicketVenta_Insertar
    @puntoDeVenta = 2,
    @formaPago = 'Efectivo',
    @idParque = @idParque;

SELECT @idTicketEliminar = MAX(idTicket)
FROM ventas.TicketVenta
WHERE puntoDeVenta = 2;

EXEC ventas.LineaVenta_Insertar
    @ticketAsociado = @idTicketEliminar,
    @cantidad = 1,
    @idPrecioEntrada = @idPrecioResidente,
    @idTour = NULL,
    @idAtraccion = NULL;

EXEC ventas.TicketVenta_Eliminar
    @idTicket = @idTicketEliminar;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicketEliminar;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicketEliminar;

PRINT '===== TEST 30 (ERROR): eliminar TicketVenta inexistente =====';
BEGIN TRY
    EXEC ventas.TicketVenta_Eliminar
        @idTicket = 99999;
    PRINT 'FALLO LA PRUEBA: se esperaba error de ticket inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- 05_testing_negocio_ventas.sql
-- ============================================================

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 16/06/2026
-- Descripcion: Testing de SPs de negocio del modulo Ventas y Precios.
--              Prueba registrarVentaEntrada y actualizarPrecioEntrada.
--              Mezcla casos exitosos y casos que deben disparar validaciones.
-- Pre-requisito: ejecutar Reset database.sql, 01_tablas_necesarias.sql,
--                02_tablas_ventas.sql, 03_abm_ventas.sql y 04_negocio_ventas.sql.
-- =============================================

USE ParquesNacionales;
GO

SET NOCOUNT ON;

DECLARE
    @idTipoParque INT,
    @idUbicacion INT,
    @idParque INT,
    @idTipoVisitanteResidente INT,
    @idTipoVisitanteExtranjero INT,
    @idTicket INT,
    @idPrecioVigente INT;

-- ============================================================
-- SETUP: DATOS BASE
-- ============================================================

PRINT '===== SETUP: carga de datos base =====';

INSERT INTO parques.TipoParque (descripcion)
VALUES ('Parque Nacional');

SET @idTipoParque = SCOPE_IDENTITY();

INSERT INTO parques.Ubicacion (direccion, provincia, latitud, longitud)
VALUES ('Ruta Nacional 12', 'Misiones', -25.695278, -54.436667);

SET @idUbicacion = SCOPE_IDENTITY();

INSERT INTO parques.Parque (nombre, superficie, idTipoParque, idUbicacion)
VALUES ('Parque Nacional Iguazu', 67200.00, @idTipoParque, @idUbicacion);

SET @idParque = SCOPE_IDENTITY();

EXEC ventas.TipoVisitante_Insertar
    @descripcion = 'Residente';

SELECT @idTipoVisitanteResidente = idTipoVisitante
FROM ventas.TipoVisitante
WHERE descripcion = 'Residente';

EXEC ventas.TipoVisitante_Insertar
    @descripcion = 'Extranjero';

SELECT @idTipoVisitanteExtranjero = idTipoVisitante
FROM ventas.TipoVisitante
WHERE descripcion = 'Extranjero';

EXEC ventas.PrecioEntrada_Insertar
    @valor = 2500.00,
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente;

EXEC ventas.PrecioEntrada_Insertar
    @valor = 6000.00,
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteExtranjero;

SELECT 'TipoVisitante' AS tabla, * FROM ventas.TipoVisitante;
SELECT 'PrecioEntrada' AS tabla, * FROM ventas.PrecioEntrada;

-- ============================================================
-- TEST registrarVentaEntrada
-- ============================================================

PRINT '===== TEST 1 (OK): registrarVentaEntrada crea nuevo ticket =====';

EXEC ventas.RegistrarVentaEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente,
    @cantidad = 2,
    @puntoDeVenta = 1,
    @formaPago = 'Efectivo',
    @nuevoTkt = 1;

SELECT @idTicket = MAX(idTicket)
FROM ventas.TicketVenta
WHERE puntoDeVenta = 1;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

PRINT '===== TEST 2 (OK): registrarVentaEntrada agrega linea al ultimo ticket =====';

EXEC ventas.RegistrarVentaEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteExtranjero,
    @cantidad = 1,
    @puntoDeVenta = 1,
    @formaPago = 'Efectivo',
    @nuevoTkt = 0;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

PRINT '===== TEST 3 (OK): registrarVentaEntrada crea otro ticket en el mismo punto de venta =====';

EXEC ventas.RegistrarVentaEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente,
    @cantidad = 1,
    @puntoDeVenta = 1,
    @formaPago = 'Tarjeta',
    @nuevoTkt = 1;

SELECT *
FROM ventas.TicketVenta
WHERE puntoDeVenta = 1
ORDER BY nroTicket;

PRINT '===== TEST 4 (ERROR): registrarVentaEntrada con cantidad invalida =====';

BEGIN TRY
    EXEC ventas.RegistrarVentaEntrada
        @idParque = @idParque,
        @idTipoVisitante = @idTipoVisitanteResidente,
        @cantidad = 0,
        @puntoDeVenta = 1,
        @formaPago = 'Efectivo',
        @nuevoTkt = 1;

    PRINT 'FALLO LA PRUEBA: se esperaba error por cantidad invalida.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 5 (ERROR): registrarVentaEntrada con parque inexistente =====';

BEGIN TRY
    EXEC ventas.RegistrarVentaEntrada
        @idParque = 99999,
        @idTipoVisitante = @idTipoVisitanteResidente,
        @cantidad = 1,
        @puntoDeVenta = 1,
        @formaPago = 'Efectivo',
        @nuevoTkt = 1;

    PRINT 'FALLO LA PRUEBA: se esperaba error por parque inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 6 (ERROR): registrarVentaEntrada con tipo visitante inexistente =====';

BEGIN TRY
    EXEC ventas.RegistrarVentaEntrada
        @idParque = @idParque,
        @idTipoVisitante = 99999,
        @cantidad = 1,
        @puntoDeVenta = 1,
        @formaPago = 'Efectivo',
        @nuevoTkt = 1;

    PRINT 'FALLO LA PRUEBA: se esperaba error por tipo visitante inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 7 (ERROR): registrarVentaEntrada sin formaPago =====';

BEGIN TRY
    EXEC ventas.RegistrarVentaEntrada
        @idParque = @idParque,
        @idTipoVisitante = @idTipoVisitanteResidente,
        @cantidad = 1,
        @puntoDeVenta = 1,
        @formaPago = '',
        @nuevoTkt = 1;

    PRINT 'FALLO LA PRUEBA: se esperaba error por forma de pago obligatoria.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

-- ============================================================
-- TEST actualizarPrecioEntrada
-- ============================================================

PRINT '===== TEST 8 (OK): actualizarPrecioEntrada versiona precio vigente =====';

SELECT @idPrecioVigente = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteResidente
  AND fechaHasta IS NULL;

EXEC ventas.ActualizarPrecioEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente,
    @nuevoValor = 3500.00;

SELECT *
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteResidente
ORDER BY idPrecio;

PRINT '===== TEST 9 (OK): registrarVentaEntrada usa el nuevo precio vigente =====';

EXEC ventas.RegistrarVentaEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteResidente,
    @cantidad = 1,
    @puntoDeVenta = 2,
    @formaPago = 'Efectivo',
    @nuevoTkt = 1;

SELECT @idTicket = MAX(idTicket)
FROM ventas.TicketVenta
WHERE puntoDeVenta = 2;

SELECT *
FROM ventas.TicketVenta
WHERE idTicket = @idTicket;

SELECT *
FROM ventas.LineaVenta
WHERE ticketAsociado = @idTicket;

PRINT '===== TEST 10 (OK): actualizarPrecioEntrada crea precio si no existe vigente =====';

-- Damos de baja el precio extranjero vigente para forzar que no haya vigente.
SELECT @idPrecioVigente = idPrecio
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteExtranjero
  AND fechaHasta IS NULL;

EXEC ventas.PrecioEntrada_Eliminar
    @idPrecio = @idPrecioVigente;

EXEC ventas.ActualizarPrecioEntrada
    @idParque = @idParque,
    @idTipoVisitante = @idTipoVisitanteExtranjero,
    @nuevoValor = 7000.00;

SELECT *
FROM ventas.PrecioEntrada
WHERE idParque = @idParque
  AND idTipoVisitante = @idTipoVisitanteExtranjero
ORDER BY idPrecio;

PRINT '===== TEST 11 (ERROR): actualizarPrecioEntrada con valor negativo =====';

BEGIN TRY
    EXEC ventas.ActualizarPrecioEntrada
        @idParque = @idParque,
        @idTipoVisitante = @idTipoVisitanteResidente,
        @nuevoValor = -500.00;

    PRINT 'FALLO LA PRUEBA: se esperaba error por valor negativo.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 12 (ERROR): actualizarPrecioEntrada con parque inexistente =====';

BEGIN TRY
    EXEC ventas.ActualizarPrecioEntrada
        @idParque = 99999,
        @idTipoVisitante = @idTipoVisitanteResidente,
        @nuevoValor = 4000.00;

    PRINT 'FALLO LA PRUEBA: se esperaba error por parque inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 13 (ERROR): actualizarPrecioEntrada con tipo visitante inexistente =====';

BEGIN TRY
    EXEC ventas.ActualizarPrecioEntrada
        @idParque = @idParque,
        @idTipoVisitante = 99999,
        @nuevoValor = 4000.00;

    PRINT 'FALLO LA PRUEBA: se esperaba error por tipo visitante inexistente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== FIN TESTING SPs NEGOCIO VENTAS Y PRECIOS =====';
GO
