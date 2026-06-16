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

EXEC concesiones.sp_TipoConsesion_Insertar @descripcion = 'Gastronomia';
EXEC concesiones.sp_TipoConsesion_Insertar @descripcion = 'Turismo aventura';

EXEC concesiones.sp_Empresa_Insertar
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @email       = 'contacto@cabanabosque.com';

EXEC concesiones.sp_Empresa_Insertar
    @razonSocial = 'Aventura Patagonica S.A.',
    @cuit        = '30798765432',
    @email       = 'info@aventurapatag.com';

-- ============================================================
-- TESTING: sp_AltaConcesionCompleta
-- ============================================================

PRINT '=== TEST: sp_AltaConcesionCompleta ===';

-- [EXITOSO] Alta de concesion valida
PRINT '-- Caso exitoso: concesion nueva sin solapamiento';
EXEC concesiones.sp_AltaConcesionCompleta
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

-- [FALLIDO] Empresa inexistente
PRINT '-- Fallo: empresa no existe';
BEGIN TRY
    EXEC concesiones.sp_AltaConcesionCompleta
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
    EXEC concesiones.sp_AltaConcesionCompleta
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
    EXEC concesiones.sp_AltaConcesionCompleta
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
    EXEC concesiones.sp_AltaConcesionCompleta
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
EXEC concesiones.sp_AltaConcesionCompleta
    @descripcion     = 'Excursiones de trekking - Parque Nahuel Huapi',
    @idTipoConcesion = 2,
    @idParque        = 1,
    @idEmpresa       = 1,
    @fechaInicio     = '2025-06-01',
    @fechaFin        = '2027-05-31',
    @canonMensual    = 95000.00;

SELECT * FROM concesiones.Concesion;

-- ============================================================
-- TESTING: sp_RegistrarPagoCanon
-- ============================================================

PRINT '=== TEST: sp_RegistrarPagoCanon ===';

-- [EXITOSO] Pago del canon del mes 1/2025
PRINT '-- Caso exitoso: primer pago';
EXEC concesiones.sp_RegistrarPagoCanon
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-02-05',
    @periodoAnio = 2025,
    @periodoMes  = 1;

-- [EXITOSO] Pago del mes 2/2025
PRINT '-- Caso exitoso: segundo pago';
EXEC concesiones.sp_RegistrarPagoCanon
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

-- [FALLIDO] Periodo duplicado
PRINT '-- Fallo: pago duplicado para el mismo periodo';
BEGIN TRY
    EXEC concesiones.sp_RegistrarPagoCanon
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
    EXEC concesiones.sp_RegistrarPagoCanon
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
    EXEC concesiones.sp_RegistrarPagoCanon
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
    EXEC concesiones.sp_RegistrarPagoCanon
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
    EXEC concesiones.sp_RegistrarPagoCanon
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
    EXEC concesiones.sp_RegistrarPagoCanon
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
FROM concesiones.PagoConcesion p
JOIN concesiones.Concesion c ON c.idConcesion = p.idConcesion
ORDER BY p.periodoAnio, p.periodoMes;

-- Reporte: concesiones con pagos atrasados (mes anterior sin pago)
PRINT '-- Reporte: concesiones con pagos atrasados (mes anterior sin pago)';
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
