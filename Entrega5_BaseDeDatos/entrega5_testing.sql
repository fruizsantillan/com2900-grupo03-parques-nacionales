-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Script de testing Entrega 5 - Requiere ejecutar entrega5_unificado.sql primero.
-- =============================================

USE ParquesNacionales;
GO


-- ============================================================
-- TESTING - ABM Parques y Guardaparques
-- ============================================================

--              Mezcla casos exitosos y casos que deben disparar validaciones.
--              Los casos de error se capturan con TRY/CATCH e imprimen el
--              mensaje esperado, para que el script no se interrumpa.
-- Pre-requisito: ejecutar 01_tablas_parques.sql y 02_abm_parques.sql.

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

GO


-- ============================================================
-- TESTING - NEGOCIO Parques y Guardaparques
-- ============================================================

--              (03_negocio_parques.sql). Recorre el ciclo de vida de un
--              guardaparque (alta, reasignacion, egreso) y el alta de parque,
--              con casos exitosos y casos que disparan validaciones.
-- Pre-requisito: ejecutar 01_tablas_parques.sql, 02_abm_parques.sql y
--                03_negocio_parques.sql.

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

GO


-- ============================================================
-- TESTING - ABM Concesiones
-- ============================================================

--              Cubre casos exitosos con evidencia (SELECT) y casos fallidos
--              que demuestran el comportamiento de las validaciones.

GO

-- TESTING: sp_TipoConsesion_Insertar / Eliminar / Actualizar

PRINT '=== TEST: TipoDeConsesion ===';

-- [EXITOSO] Alta de tipos
PRINT '-- Alta exitosa';
EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Gastronomia';
EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Turismo aventura';
EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Comercio minorista';

-- Evidencia
SELECT * FROM parques.TipoDeConsesion;

-- [FALLIDO] Descripcion vacia
PRINT '-- Fallo: descripcion vacia';
BEGIN TRY
    EXEC parques.sp_TipoConsesion_Insertar @descripcion = '';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Descripcion duplicada
PRINT '-- Fallo: descripcion duplicada';
BEGIN TRY
    EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Gastronomia';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [EXITOSO] Actualizacion
PRINT '-- Actualizacion exitosa';
EXEC parques.sp_TipoConsesion_Actualizar @idTipoConcesion = 3, @descripcion = 'Comercio y souvenirs';
SELECT * FROM parques.TipoDeConsesion WHERE idTipoConcesion = 3;

-- [FALLIDO] Actualizar ID inexistente
PRINT '-- Fallo: ID inexistente';
BEGIN TRY
    EXEC parques.sp_TipoConsesion_Actualizar @idTipoConcesion = 999, @descripcion = 'Test';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- TESTING: sp_Empresa_Insertar / Eliminar / Actualizar

PRINT '=== TEST: Empresa ===';

-- [EXITOSO] Alta de empresas
PRINT '-- Alta exitosa';
EXEC parques.sp_Empresa_Insertar
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @contacto    = 'Carlos Fernandez',
    @email       = 'contacto@cabanabosque.com',
    @telefono    = '011-4523-9876';

EXEC parques.sp_Empresa_Insertar
    @razonSocial = 'Aventura Patagonica S.A.',
    @cuit        = '30798765432',
    @email       = 'info@aventurapatag.com';

-- Evidencia
SELECT * FROM parques.Empresa;

-- [FALLIDO] CUIT duplicado
PRINT '-- Fallo: CUIT duplicado';
BEGIN TRY
    EXEC parques.sp_Empresa_Insertar
        @razonSocial = 'Empresa Copia',
        @cuit        = '30712345678';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Multiples errores simultaneos
PRINT '-- Fallo: multiples errores simultaneos';
BEGIN TRY
    EXEC parques.sp_Empresa_Insertar
        @razonSocial = '',
        @cuit        = '123',
        @email       = 'emailinvalido';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [EXITOSO] Actualizacion
PRINT '-- Actualizacion exitosa';
EXEC parques.sp_Empresa_Actualizar
    @idEmpresa   = 1,
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @telefono    = '011-4523-0000';
SELECT * FROM parques.Empresa WHERE idEmpresa = 1;

-- TESTING: sp_Concesion_Insertar / Eliminar / Actualizar
-- (Requiere idParque valido de parques.Parque)

PRINT '=== TEST: Concesion ===';

-- [EXITOSO] Alta de concesiones
PRINT '-- Alta exitosa';
EXEC parques.sp_Concesion_Insertar
    @descripcion     = 'Restaurante principal - Parque Nahuel Huapi',
    @idTipoConcesion = 1,
    @idParque        = 1,
    @idEmpresa       = 1,
    @fechaInicio     = '2025-01-01',
    @fechaFin        = '2026-12-31',
    @canonMensual    = 150000.00;

EXEC parques.sp_Concesion_Insertar
    @descripcion     = 'Excursiones de trekking - Parque Los Glaciares',
    @idTipoConcesion = 2,
    @idParque        = 2,
    @idEmpresa       = 2,
    @fechaInicio     = '2025-03-01',
    @fechaFin        = '2027-02-28',
    @canonMensual    = 80000.00;

-- Evidencia
SELECT * FROM parques.Concesion;

-- [FALLIDO] Fecha fin anterior a inicio
PRINT '-- Fallo: fecha fin <= fecha inicio';
BEGIN TRY
    EXEC parques.sp_Concesion_Insertar
        @descripcion     = 'Concesion invalida',
        @idTipoConcesion = 1,
        @idParque        = 1,
        @idEmpresa       = 1,
        @fechaInicio     = '2026-01-01',
        @fechaFin        = '2025-01-01',
        @canonMensual    = 50000.00;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Empresa inexistente
PRINT '-- Fallo: empresa no existe';
BEGIN TRY
    EXEC parques.sp_Concesion_Insertar
        @descripcion     = 'Concesion empresa fantasma',
        @idTipoConcesion = 1,
        @idParque        = 1,
        @idEmpresa       = 999,
        @fechaInicio     = '2025-01-01',
        @fechaFin        = '2026-12-31',
        @canonMensual    = 50000.00;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Canon cero
PRINT '-- Fallo: canon = 0';
BEGIN TRY
    EXEC parques.sp_Concesion_Insertar
        @descripcion     = 'Concesion canon cero',
        @idTipoConcesion = 1,
        @idParque        = 1,
        @idEmpresa       = 1,
        @fechaInicio     = '2025-01-01',
        @fechaFin        = '2026-12-31',
        @canonMensual    = 0;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Baja de tipo con concesiones asociadas
PRINT '-- Fallo: baja de tipo con concesiones asociadas';
BEGIN TRY
    EXEC parques.sp_TipoConsesion_Eliminar @idTipoConcesion = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [EXITOSO] Baja de concesion sin pagos
PRINT '-- Baja exitosa (concesion sin pagos)';
EXEC parques.sp_Concesion_Insertar
    @descripcion     = 'Concesion temporal para borrar',
    @idTipoConcesion = 3,
    @idParque        = 1,
    @idEmpresa       = 2,
    @fechaInicio     = '2025-01-01',
    @fechaFin        = '2025-06-30',
    @canonMensual    = 10000.00;

DECLARE @vIdTemp INT = (SELECT MAX(idConcesion) FROM parques.Concesion);
EXEC parques.sp_Concesion_Eliminar @idConcesion = @vIdTemp;
SELECT * FROM parques.Concesion;

-- TESTING: sp_PagoConcesion_Insertar / Eliminar / Actualizar

PRINT '=== TEST: PagoConcesion ===';

-- [EXITOSO] Alta de pagos
PRINT '-- Alta exitosa';
EXEC parques.sp_PagoConcesion_Insertar
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-02-05',
    @periodoAnio = 2025,
    @periodoMes  = 1;

EXEC parques.sp_PagoConcesion_Insertar
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-03-03',
    @periodoAnio = 2025,
    @periodoMes  = 2;

-- Evidencia
SELECT * FROM parques.PagoConcesion;

-- [FALLIDO] Pago duplicado mismo periodo
PRINT '-- Fallo: periodo duplicado';
BEGIN TRY
    EXEC parques.sp_PagoConcesion_Insertar
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2025-02-10',
        @periodoAnio = 2025,
        @periodoMes  = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Mes invalido
PRINT '-- Fallo: mes fuera de rango';
BEGIN TRY
    EXEC parques.sp_PagoConcesion_Insertar
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2025-01-05',
        @periodoAnio = 2025,
        @periodoMes  = 13;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Monto negativo
PRINT '-- Fallo: monto negativo';
BEGIN TRY
    EXEC parques.sp_PagoConcesion_Insertar
        @idConcesion = 1,
        @monto       = -500.00,
        @fechaPago   = '2025-04-05',
        @periodoAnio = 2025,
        @periodoMes  = 3;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [EXITOSO] Actualizacion de monto
PRINT '-- Actualizacion exitosa';
EXEC parques.sp_PagoConcesion_Actualizar
    @idPagoConcesion = 1,
    @monto           = 155000.00,
    @fechaPago       = '2025-02-05';
SELECT * FROM parques.PagoConcesion WHERE idPagoConcesion = 1;

-- [EXITOSO] Baja
PRINT '-- Baja exitosa';
EXEC parques.sp_PagoConcesion_Eliminar @idPagoConcesion = 2;
SELECT * FROM parques.PagoConcesion;

-- [FALLIDO] Baja ID inexistente
PRINT '-- Fallo: baja ID inexistente';
BEGIN TRY
    EXEC parques.sp_PagoConcesion_Eliminar @idPagoConcesion = 999;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Ahora si: baja de concesion con pagos
PRINT '-- Fallo: baja concesion con pagos';
BEGIN TRY
    EXEC parques.sp_Concesion_Eliminar @idConcesion = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH
GO

GO


-- ============================================================
-- TESTING - NEGOCIO Concesiones
-- ============================================================

--              Cubre casos exitosos con evidencia (SELECT) y casos fallidos
--              que demuestran el comportamiento de las validaciones.
--               y 04_negocio_parques.sql

GO

-- DATOS BASE para los tests
-- (Si ya existen de los tests ABM, comentar este bloque)

EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Gastronomia';
EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Turismo aventura';

EXEC parques.sp_Empresa_Insertar
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @email       = 'contacto@cabanabosque.com';

EXEC parques.sp_Empresa_Insertar
    @razonSocial = 'Aventura Patagonica S.A.',
    @cuit        = '30798765432',
    @email       = 'info@aventurapatag.com';

-- TESTING: sp_AltaConcesionCompleta

PRINT '=== TEST: sp_AltaConcesionCompleta ===';

-- [EXITOSO] Alta de concesion valida
PRINT '-- Caso exitoso: concesion nueva sin solapamiento';
EXEC parques.sp_AltaConcesionCompleta
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
FROM parques.Concesion c
JOIN parques.TipoDeConsesion t ON t.idTipoConcesion = c.idTipoConcesion
JOIN parques.Empresa e         ON e.idEmpresa       = c.idEmpresa;

-- [FALLIDO] Empresa inexistente
PRINT '-- Fallo: empresa no existe';
BEGIN TRY
    EXEC parques.sp_AltaConcesionCompleta
        @descripcion     = 'Concesion empresa fantasma',
        @idTipoConcesion = 1,
        @idParque        = 1,
        @idEmpresa       = 999,
        @fechaInicio     = '2025-01-01',
        @fechaFin        = '2026-12-31',
        @canonMensual    = 50000.00;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Parque inexistente
PRINT '-- Fallo: parque no existe';
BEGIN TRY
    EXEC parques.sp_AltaConcesionCompleta
        @descripcion     = 'Concesion parque fantasma',
        @idTipoConcesion = 1,
        @idParque        = 999,
        @idEmpresa       = 1,
        @fechaInicio     = '2025-01-01',
        @fechaFin        = '2026-12-31',
        @canonMensual    = 50000.00;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Solapamiento de concesion vigente (misma empresa + parque + tipo)
PRINT '-- Fallo: ya existe concesion vigente para empresa/parque/tipo';
BEGIN TRY
    EXEC parques.sp_AltaConcesionCompleta
        @descripcion     = 'Segunda concesion gastronomica misma empresa',
        @idTipoConcesion = 1,
        @idParque        = 1,
        @idEmpresa       = 1,
        @fechaInicio     = '2026-01-01',
        @fechaFin        = '2027-12-31',
        @canonMensual    = 160000.00;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Multiples errores simultaneos
PRINT '-- Fallo: multiples errores simultaneos';
BEGIN TRY
    EXEC parques.sp_AltaConcesionCompleta
        @descripcion     = '',
        @idTipoConcesion = 999,
        @idParque        = 999,
        @idEmpresa       = 999,
        @fechaInicio     = '2026-01-01',
        @fechaFin        = '2025-01-01',
        @canonMensual    = 0;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [EXITOSO] Segunda concesion valida (diferente tipo)
PRINT '-- Caso exitoso: misma empresa, mismo parque, diferente tipo';
EXEC parques.sp_AltaConcesionCompleta
    @descripcion     = 'Excursiones de trekking - Parque Nahuel Huapi',
    @idTipoConcesion = 2,
    @idParque        = 1,
    @idEmpresa       = 1,
    @fechaInicio     = '2025-06-01',
    @fechaFin        = '2027-05-31',
    @canonMensual    = 95000.00;

SELECT * FROM parques.Concesion;

-- TESTING: sp_RegistrarPagoCanon

PRINT '=== TEST: sp_RegistrarPagoCanon ===';

-- [EXITOSO] Pago del canon del mes 1/2025
PRINT '-- Caso exitoso: primer pago';
EXEC parques.sp_RegistrarPagoCanon
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-02-05',
    @periodoAnio = 2025,
    @periodoMes  = 1;

-- [EXITOSO] Pago del mes 2/2025
PRINT '-- Caso exitoso: segundo pago';
EXEC parques.sp_RegistrarPagoCanon
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
FROM parques.PagoConcesion p
JOIN parques.Concesion c ON c.idConcesion = p.idConcesion
ORDER BY p.periodoAnio, p.periodoMes;

-- [FALLIDO] Periodo duplicado
PRINT '-- Fallo: pago duplicado para el mismo periodo';
BEGIN TRY
    EXEC parques.sp_RegistrarPagoCanon
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2025-02-10',
        @periodoAnio = 2025,
        @periodoMes  = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Concesion inexistente
PRINT '-- Fallo: concesion no existe';
BEGIN TRY
    EXEC parques.sp_RegistrarPagoCanon
        @idConcesion = 999,
        @monto       = 50000.00,
        @fechaPago   = '2025-02-05',
        @periodoAnio = 2025,
        @periodoMes  = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Periodo anterior al inicio de la concesion
PRINT '-- Fallo: periodo anterior al inicio de la concesion';
BEGIN TRY
    EXEC parques.sp_RegistrarPagoCanon
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2024-12-05',
        @periodoAnio = 2024,
        @periodoMes  = 12;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Periodo posterior al vencimiento de la concesion
PRINT '-- Fallo: periodo posterior al vencimiento';
BEGIN TRY
    EXEC parques.sp_RegistrarPagoCanon
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2027-01-05',
        @periodoAnio = 2027,
        @periodoMes  = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Mes invalido
PRINT '-- Fallo: mes invalido (0)';
BEGIN TRY
    EXEC parques.sp_RegistrarPagoCanon
        @idConcesion = 1,
        @monto       = 150000.00,
        @fechaPago   = '2025-01-05',
        @periodoAnio = 2025,
        @periodoMes  = 0;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Monto negativo y mes invalido (multiples errores)
PRINT '-- Fallo: multiples errores simultaneos';
BEGIN TRY
    EXEC parques.sp_RegistrarPagoCanon
        @idConcesion = 1,
        @monto       = -1000.00,
        @fechaPago   = '2025-01-05',
        @periodoAnio = 2019,
        @periodoMes  = 13;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- Evidencia final: todos los pagos registrados
PRINT '-- Estado final de pagos:';
SELECT
    p.idPagoConcesion,
    c.descripcion AS concesion,
    p.periodoMes,
    p.periodoAnio,
    p.monto,
    p.fechaPago
FROM parques.PagoConcesion p
JOIN parques.Concesion c ON c.idConcesion = p.idConcesion
ORDER BY p.periodoAnio, p.periodoMes;

-- Reporte: concesiones con pagos atrasados (mes anterior sin pago)
PRINT '-- Reporte: concesiones con pagos atrasados (mes anterior sin pago)';
SELECT
    c.idConcesion,
    c.descripcion,
    e.razonSocial,
    c.canonMensual,
    c.fechaFin
FROM parques.Concesion c
JOIN parques.Empresa e ON e.idEmpresa = c.idEmpresa
WHERE c.fechaFin >= CAST(GETDATE() AS DATE)
  AND NOT EXISTS (
      SELECT 1 FROM parques.PagoConcesion p
      WHERE p.idConcesion = c.idConcesion
        AND p.periodoAnio = YEAR(DATEADD(MONTH, -1, GETDATE()))
        AND p.periodoMes  = MONTH(DATEADD(MONTH, -1, GETDATE()))
  );
GO

GO


-- ============================================================
-- TESTING - Guías, Tours y Atracciones
-- ============================================================


GO

-- TESTS EXITOSOS

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


-- TESTS DE VALIDACIONES (ERRORES ESPERADOS)

PRINT '--- TEST 4: Insertar guía con DNI duplicado ---';
-- Resultado esperado: error "Ya existe un guía registrado con ese DNI"
BEGIN TRY
    EXEC parques.sp_Guia_Insertar
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

GO
