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
EXEC parques.sp_TipoParque_Insertar @descripcion = 'Parque Nacional';
SELECT @idTipo = idTipoParque FROM parques.TipoParque WHERE descripcion = 'Parque Nacional';

PRINT '===== TEST 2 (ERROR): TipoParque con descripcion duplicada =====';
-- Esperado: '- Ya existe un tipo de parque con esa descripcion.'
BEGIN TRY
    EXEC parques.sp_TipoParque_Insertar @descripcion = 'Parque Nacional';
    PRINT 'FALLO LA PRUEBA: se esperaba error de duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 3 (ERROR): TipoParque sin descripcion =====';
-- Esperado: '- La descripcion del tipo de parque es obligatoria.'
BEGIN TRY
    EXEC parques.sp_TipoParque_Insertar @descripcion = '';
    PRINT 'FALLO LA PRUEBA: se esperaba error de obligatoriedad.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 4 (OK): alta de Ubicacion =====';
EXEC parques.sp_Ubicacion_Insertar
     @direccion = 'Av. San Martin 100',
     @provincia = 'Neuquen',
     @latitud   = -40.123456,
     @longitud  = -71.654321;
SELECT @idUbic = idUbicacion FROM parques.Ubicacion WHERE direccion = 'Av. San Martin 100';

PRINT '===== TEST 5 (ERROR): Ubicacion con latitud fuera de rango =====';
-- Esperado: '- La latitud debe estar entre -90 y 90.'
BEGIN TRY
    EXEC parques.sp_Ubicacion_Insertar
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
EXEC parques.sp_Parque_Insertar
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
    EXEC parques.sp_Parque_Insertar
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
EXEC parques.sp_Guardaparque_Insertar
     @dni   = 30111222,
     @apyn  = 'Perez, Juan',
     @email = 'juan.perez@parques.gob.ar';
SELECT dni, apyn, email FROM parques.Guardaparque WHERE dni = 30111222;

PRINT '===== TEST 9 (ERROR): Guardaparque con dni invalido y email mal formado =====';
-- Esperado: UN solo mensaje con dni<=0 y email invalido.
BEGIN TRY
    EXEC parques.sp_Guardaparque_Insertar
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
    EXEC parques.sp_TipoParque_Eliminar @idTipoParque = @idTipo;
    PRINT 'FALLO LA PRUEBA: se esperaba bloqueo por dependencia.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 11 (OK): obtener Parque por ID =====';
EXEC parques.sp_Parque_ObtenerPorId @idParque = @idParque;
GO
