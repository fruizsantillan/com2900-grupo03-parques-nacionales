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
    EXEC parques.sp_TipoParque_Insertar @descripcion = 'Reserva Natural';
SELECT @idTipo = idTipoParque FROM parques.TipoParque WHERE descripcion = 'Reserva Natural';

PRINT '===== TEST 1 (OK): registrar parque (Ubicacion + Parque en una transaccion) =====';
EXEC parques.sp_RegistrarParque
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
    EXEC parques.sp_RegistrarParque
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
EXEC parques.sp_RegistrarGuardaparque
     @dni         = 28999888,
     @apyn        = 'Gomez, Ana',
     @idParque    = @idParqueA,
     @fechaInicio = '2025-01-10';
-- Evidencia: queda una asignacion vigente (fechaFin NULL).
SELECT idAsignacion, dni, idParque, fechaInicio, fechaFin
FROM parques.AsignacionGuardaparque WHERE dni = 28999888;

PRINT '===== TEST 4 (ERROR): registrar guardaparque con dni ya existente =====';
-- Esperado: '- Ya existe un guardaparque registrado con ese DNI.'
BEGIN TRY
    EXEC parques.sp_RegistrarGuardaparque
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
EXEC parques.sp_RegistrarParque
     @nombre       = 'Lanin',
     @superficie   = 4120.00,
     @idTipoParque = @idTipo,
     @direccion    = 'Ruta 40 km 2000',
     @provincia    = 'Neuquen',
     @latitud      = -39.600000,
     @longitud     = -71.500000;
SELECT @idParqueB = idParque FROM parques.Parque WHERE nombre = 'Lanin';

PRINT '===== TEST 5 (OK): reasignar el guardaparque al segundo parque =====';
EXEC parques.sp_ReasignarGuardaparque
     @dni               = 28999888,
     @idParqueDestino   = @idParqueB,
     @fechaReasignacion = '2025-06-01';
-- Evidencia: 2 filas. La 1ra cerrada (fechaFin=2025-06-01, motivo 'Reasignacion')
-- y la 2da vigente (fechaFin NULL) en el parque B.
SELECT idAsignacion, idParque, fechaInicio, fechaFin, motivoEgreso
FROM parques.AsignacionGuardaparque
WHERE dni = 28999888
ORDER BY fechaInicio;

PRINT '===== TEST 6 (ERROR): reasignar al mismo parque en el que ya esta =====';
-- Esperado: '- El parque destino es el mismo que el parque actual.'
BEGIN TRY
    EXEC parques.sp_ReasignarGuardaparque
         @dni               = 28999888,
         @idParqueDestino   = @idParqueB,
         @fechaReasignacion = '2025-07-01';
    PRINT 'FALLO LA PRUEBA: se esperaba error de destino igual al actual.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 7 (OK): registrar el egreso del guardaparque =====';
EXEC parques.sp_RegistrarEgresoGuardaparque
     @dni          = 28999888,
     @fechaEgreso  = '2025-12-31',
     @motivoEgreso = 'Renuncia';
-- Evidencia: ya no debe quedar ninguna asignacion vigente.
SELECT COUNT(*) AS asignaciones_vigentes
FROM parques.AsignacionGuardaparque
WHERE dni = 28999888 AND fechaFin IS NULL;

PRINT '===== TEST 8 (ERROR): registrar egreso sin asignacion vigente =====';
-- Esperado: '- El guardaparque no tiene una asignacion vigente...'
BEGIN TRY
    EXEC parques.sp_RegistrarEgresoGuardaparque
         @dni          = 28999888,
         @fechaEgreso  = '2026-01-15',
         @motivoEgreso = 'Renuncia';
    PRINT 'FALLO LA PRUEBA: se esperaba error de sin asignacion vigente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH
GO
