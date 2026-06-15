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

PRINT '=== TEST: TipoDeConsesion ===';

-- [EXITOSO] Alta de tipos
PRINT '-- Alta exitosa';
EXEC concesiones.sp_TipoConsesion_Insertar @descripcion = 'Gastronomia';
EXEC concesiones.sp_TipoConsesion_Insertar @descripcion = 'Turismo aventura';
EXEC concesiones.sp_TipoConsesion_Insertar @descripcion = 'Comercio minorista';

-- Evidencia
SELECT * FROM concesiones.TipoDeConsesion;

-- [FALLIDO] Descripcion vacia
PRINT '-- Fallo: descripcion vacia';
BEGIN TRY
    EXEC concesiones.sp_TipoConsesion_Insertar @descripcion = '';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Descripcion duplicada
PRINT '-- Fallo: descripcion duplicada';
BEGIN TRY
    EXEC concesiones.sp_TipoConsesion_Insertar @descripcion = 'Gastronomia';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [EXITOSO] Actualizacion
PRINT '-- Actualizacion exitosa';
EXEC concesiones.sp_TipoConsesion_Actualizar @idTipoConcesion = 3, @descripcion = 'Comercio y souvenirs';
SELECT * FROM concesiones.TipoDeConsesion WHERE idTipoConcesion = 3;

-- [FALLIDO] Actualizar ID inexistente
PRINT '-- Fallo: ID inexistente';
BEGIN TRY
    EXEC concesiones.sp_TipoConsesion_Actualizar @idTipoConcesion = 999, @descripcion = 'Test';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- ============================================================
-- TESTING: sp_Empresa_Insertar / Eliminar / Actualizar
-- ============================================================

PRINT '=== TEST: Empresa ===';

-- [EXITOSO] Alta de empresas
PRINT '-- Alta exitosa';
EXEC concesiones.sp_Empresa_Insertar
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @contacto    = 'Carlos Fernandez',
    @email       = 'contacto@cabanabosque.com',
    @telefono    = '011-4523-9876';

EXEC concesiones.sp_Empresa_Insertar
    @razonSocial = 'Aventura Patagonica S.A.',
    @cuit        = '30798765432',
    @email       = 'info@aventurapatag.com';

-- Evidencia
SELECT * FROM concesiones.Empresa;

-- [FALLIDO] CUIT duplicado
PRINT '-- Fallo: CUIT duplicado';
BEGIN TRY
    EXEC concesiones.sp_Empresa_Insertar
        @razonSocial = 'Empresa Copia',
        @cuit        = '30712345678';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Multiples errores simultaneos
PRINT '-- Fallo: multiples errores simultaneos';
BEGIN TRY
    EXEC concesiones.sp_Empresa_Insertar
        @razonSocial = '',
        @cuit        = '123',
        @email       = 'emailinvalido';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [EXITOSO] Actualizacion
PRINT '-- Actualizacion exitosa';
EXEC concesiones.sp_Empresa_Actualizar
    @idEmpresa   = 1,
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @telefono    = '011-4523-0000';
SELECT * FROM concesiones.Empresa WHERE idEmpresa = 1;

-- ============================================================
-- TESTING: sp_Concesion_Insertar / Eliminar / Actualizar
-- (Requiere idParque valido de parques.Parque)
-- ============================================================

PRINT '=== TEST: Concesion ===';

-- [EXITOSO] Alta de concesiones
PRINT '-- Alta exitosa';
EXEC concesiones.sp_Concesion_Insertar
    @descripcion     = 'Restaurante principal - Parque Nahuel Huapi',
    @idTipoConcesion = 1,
    @idParque        = 1,
    @idEmpresa       = 1,
    @fechaInicio     = '2025-01-01',
    @fechaFin        = '2026-12-31',
    @canonMensual    = 150000.00;

EXEC concesiones.sp_Concesion_Insertar
    @descripcion     = 'Excursiones de trekking - Parque Los Glaciares',
    @idTipoConcesion = 2,
    @idParque        = 2,
    @idEmpresa       = 2,
    @fechaInicio     = '2025-03-01',
    @fechaFin        = '2027-02-28',
    @canonMensual    = 80000.00;

-- Evidencia
SELECT * FROM concesiones.Concesion;

-- [FALLIDO] Fecha fin anterior a inicio
PRINT '-- Fallo: fecha fin <= fecha inicio';
BEGIN TRY
    EXEC concesiones.sp_Concesion_Insertar
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
    EXEC concesiones.sp_Concesion_Insertar
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
    EXEC concesiones.sp_Concesion_Insertar
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
    EXEC concesiones.sp_TipoConsesion_Eliminar @idTipoConcesion = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [EXITOSO] Baja de concesion sin pagos
PRINT '-- Baja exitosa (concesion sin pagos)';
EXEC concesiones.sp_Concesion_Insertar
    @descripcion     = 'Concesion temporal para borrar',
    @idTipoConcesion = 3,
    @idParque        = 1,
    @idEmpresa       = 2,
    @fechaInicio     = '2025-01-01',
    @fechaFin        = '2025-06-30',
    @canonMensual    = 10000.00;

DECLARE @vIdTemp INT = (SELECT MAX(idConcesion) FROM concesiones.Concesion);
EXEC concesiones.sp_Concesion_Eliminar @idConcesion = @vIdTemp;
SELECT * FROM concesiones.Concesion;

-- ============================================================
-- TESTING: sp_PagoConcesion_Insertar / Eliminar / Actualizar
-- ============================================================

PRINT '=== TEST: PagoConcesion ===';

-- [EXITOSO] Alta de pagos
PRINT '-- Alta exitosa';
EXEC concesiones.sp_PagoConcesion_Insertar
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-02-05',
    @periodoAnio = 2025,
    @periodoMes  = 1;

EXEC concesiones.sp_PagoConcesion_Insertar
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-03-03',
    @periodoAnio = 2025,
    @periodoMes  = 2;

-- Evidencia
SELECT * FROM concesiones.PagoConcesion;

-- [FALLIDO] Pago duplicado mismo periodo
PRINT '-- Fallo: periodo duplicado';
BEGIN TRY
    EXEC concesiones.sp_PagoConcesion_Insertar
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
    EXEC concesiones.sp_PagoConcesion_Insertar
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
    EXEC concesiones.sp_PagoConcesion_Insertar
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
EXEC concesiones.sp_PagoConcesion_Actualizar
    @idPagoConcesion = 1,
    @monto           = 155000.00,
    @fechaPago       = '2025-02-05';
SELECT * FROM concesiones.PagoConcesion WHERE idPagoConcesion = 1;

-- [EXITOSO] Baja
PRINT '-- Baja exitosa';
EXEC concesiones.sp_PagoConcesion_Eliminar @idPagoConcesion = 2;
SELECT * FROM concesiones.PagoConcesion;

-- [FALLIDO] Baja ID inexistente
PRINT '-- Fallo: baja ID inexistente';
BEGIN TRY
    EXEC concesiones.sp_PagoConcesion_Eliminar @idPagoConcesion = 999;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Ahora si: baja de concesion con pagos
PRINT '-- Fallo: baja concesion con pagos';
BEGIN TRY
    EXEC concesiones.sp_Concesion_Eliminar @idConcesion = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH
GO
