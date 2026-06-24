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
-- TESTING: sp_TipoConsesion_Insertar / Eliminar / Actualizar
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
-- TESTING: sp_Empresa_Insertar / Eliminar / Actualizar
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
-- TESTING: sp_Concesion_Insertar / Eliminar / Actualizar
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
-- TESTING: sp_PagoConcesion_Insertar / Eliminar / Actualizar
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
