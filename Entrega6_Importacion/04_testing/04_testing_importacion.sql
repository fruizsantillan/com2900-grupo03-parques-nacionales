-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Scripts de testing para el modulo de importacion (Entrega 6).
--              Prueba todos los SPs de importacion (CSV y API):
--              - Casos exitosos con evidencia (SELECT post-importacion)
--              - Casos de error con validaciones esperadas
--              - Verificacion Upsert: reimportacion sin duplicados
--              - Verificacion importacion parcial: filas invalidas descartadas
-- Prerequisito: Ejecutar 01_tablas_staging.sql, todos los scripts de 02_importacion/
--               y 03_datos_iniciales/ antes de ejecutar este archivo.
-- IMPORTANTE: Ajustar la variable @vBasePath con la ruta local a los datasets.
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- CONFIGURACION: ajustar esta ruta a la ubicacion local de los datasets
-- ============================================================
DECLARE @vBasePath NVARCHAR(500) =
    'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\';
-- Ejemplo Mac/Linux via SQL Server en Docker:
-- N'/datasets/'

PRINT '===========================================================';
PRINT ' TESTING MODULO DE IMPORTACION - ENTREGA 6';
PRINT ' Ruta base datasets: ' + @vBasePath;
PRINT '===========================================================';
GO

-- ============================================================
-- TEST 1: sp_ImportarVisitasNacionales
-- Dataset: visitas-residentes-y-no-residentes.csv
-- Esperado exitoso: ~1980 filas procesadas (660 filas x 3 tipos)
-- ============================================================

PRINT '';
PRINT '=== TEST 1: sp_ImportarVisitasNacionales ===';

-- [EXITOSO] Primera importacion
PRINT '-- Caso exitoso: primera importacion del CSV';
-- RESULTADO ESPERADO: Filas insertadas ~660 (una por periodo/tipo)
EXEC parques.sp_ImportarVisitasNacionales
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\datos-gob-ar\visitas-residentes-y-no-residentes.csv';

-- Evidencia: muestra primeras y ultimas filas importadas
SELECT TOP 5
    periodo,
    origenVisitante,
    cantidadVisitas,
    observaciones
FROM parques.EstadisticaVisitas
ORDER BY periodo ASC, origenVisitante;

SELECT TOP 5
    periodo,
    origenVisitante,
    cantidadVisitas,
    observaciones
FROM parques.EstadisticaVisitas
ORDER BY periodo DESC, origenVisitante;

SELECT
    COUNT(*)              AS totalRegistros,
    MIN(periodo)          AS periodoDesde,
    MAX(periodo)          AS periodoHasta,
    SUM(cantidadVisitas)  AS totalVisitasHistoricas
FROM parques.EstadisticaVisitas
WHERE origenVisitante = 'total';

-- [UPSERT] Segunda ejecucion sobre mismo archivo: no debe generar duplicados
PRINT '-- Caso Upsert: reimportacion del mismo archivo (no debe duplicar registros)';
-- RESULTADO ESPERADO: 0 insertadas, misma cantidad actualizada o sin cambios
DECLARE @vConteoAntes INT = (SELECT COUNT(*) FROM parques.EstadisticaVisitas);

EXEC parques.sp_ImportarVisitasNacionales
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\datos-gob-ar\visitas-residentes-y-no-residentes.csv';

DECLARE @vConteoDespues INT = (SELECT COUNT(*) FROM parques.EstadisticaVisitas);

PRINT 'Registros antes: '  + CAST(@vConteoAntes   AS VARCHAR);
PRINT 'Registros despues: ' + CAST(@vConteoDespues AS VARCHAR);
IF @vConteoAntes = @vConteoDespues
    PRINT 'UPSERT OK: sin duplicados generados.';
ELSE
    PRINT 'ADVERTENCIA: se generaron registros adicionales.';

-- [FALLIDO] Ruta de archivo inexistente
PRINT '-- Fallo esperado: archivo no encontrado';
-- RESULTADO ESPERADO: error de BULK INSERT (archivo no existe)
BEGIN TRY
    EXEC parques.sp_ImportarVisitasNacionales
        @vRutaArchivo = 'C:\ruta\inexistente\archivo.csv';
END TRY
BEGIN CATCH
    PRINT 'ERROR capturado (esperado): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- TEST 2: sp_ImportarVisitasPorRegion
-- Dataset: visitas-residentes-y-no-residentes-por-region.csv
-- Esperado exitoso: ~3960 filas (regiones x periodos x tipos)
-- ============================================================

PRINT '';
PRINT '=== TEST 2: sp_ImportarVisitasPorRegion ===';

-- [EXITOSO]
PRINT '-- Caso exitoso: importacion CSV por region';
-- RESULTADO ESPERADO: ~3960 registros, 6 regiones distintas
EXEC parques.sp_ImportarVisitasPorRegion
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\datos-gob-ar\visitas-residentes-y-no-residentes-por-region.csv';

-- Evidencia: resumen por region
SELECT
    region,
    COUNT(*)             AS periodos,
    MIN(periodo)         AS desde,
    MAX(periodo)         AS hasta,
    SUM(cantidadVisitas) AS totalVisitas
FROM parques.EstadisticaVisitasPorRegion
WHERE origenVisitante = 'total'
GROUP BY region
ORDER BY totalVisitas DESC;

-- [UPSERT] Reimportacion sin duplicados
PRINT '-- Caso Upsert: reimportacion (no debe duplicar)';
-- RESULTADO ESPERADO: conteo identico antes y despues
DECLARE @vConteoAntes2 INT = (SELECT COUNT(*) FROM parques.EstadisticaVisitasPorRegion);
EXEC parques.sp_ImportarVisitasPorRegion
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\datos-gob-ar\visitas-residentes-y-no-residentes-por-region.csv';
DECLARE @vConteoDespues2 INT = (SELECT COUNT(*) FROM parques.EstadisticaVisitasPorRegion);
IF @vConteoAntes2 = @vConteoDespues2
    PRINT 'UPSERT OK: sin duplicados. Registros: ' + CAST(@vConteoDespues2 AS VARCHAR);
ELSE
    PRINT 'ADVERTENCIA: conteo cambio de ' + CAST(@vConteoAntes2 AS VARCHAR) + ' a ' + CAST(@vConteoDespues2 AS VARCHAR);
GO

-- ============================================================
-- TEST 3: sp_ImportarVisitasAnual
-- Dataset: aprn_i_visitas_porc_2024.csv
-- Esperado exitoso: 18 registros (2008-2025)
-- ============================================================

PRINT '';
PRINT '=== TEST 3: sp_ImportarVisitasAnual ===';

-- [EXITOSO]
PRINT '-- Caso exitoso: importacion CSV porcentajes anuales';
-- RESULTADO ESPERADO: 18 filas, anios 2008 a 2025
EXEC parques.sp_ImportarVisitasAnual
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\datos-gob-ar\aprn_i_visitas_porc_2024.csv';

-- Evidencia
SELECT
    anio,
    residentesPorcentaje,
    noResidentesPorcentaje,
    residentesPorcentaje + noResidentesPorcentaje AS sumaControl
FROM parques.EstadisticaVisitasAnual
ORDER BY anio;

-- Verificar que la suma siempre sea ~100%
SELECT
    COUNT(*) AS totalAnios,
    MIN(anio) AS desde,
    MAX(anio) AS hasta,
    MIN(residentesPorcentaje + noResidentesPorcentaje) AS minSuma,
    MAX(residentesPorcentaje + noResidentesPorcentaje) AS maxSuma
FROM parques.EstadisticaVisitasAnual;

-- Caso COVID 2021: no residentes debe ser muy bajo (<5%)
PRINT '-- Verificacion especial: anio 2021 (COVID - minimo turismo extranjero)';
-- RESULTADO ESPERADO: no_residentes cerca de 1.96%
SELECT anio, residentesPorcentaje, noResidentesPorcentaje
FROM parques.EstadisticaVisitasAnual
WHERE anio = 2021;
GO

-- ============================================================
-- TEST 4: sp_ImportarAreasProtegidas
-- Dataset: aprn_h_ubicacion_superycatint_ha.csv (APN, sep ;)
-- Esperado exitoso: ~48 areas protegidas
-- ============================================================

PRINT '';
PRINT '=== TEST 4: sp_ImportarAreasProtegidas ===';

-- [EXITOSO]
PRINT '-- Caso exitoso: importacion CSV APN (separador ;)';
-- RESULTADO ESPERADO: tipos de parque creados, parques insertados con superficie en ha
EXEC parques.sp_ImportarAreasProtegidas
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\datos-gob-ar\aprn_h_ubicacion_superycatint_ha.csv';

-- Evidencia: tipos de parque generados
SELECT idTipoParque, descripcion
FROM parques.TipoParque
ORDER BY descripcion;

-- Evidencia: parques importados con su region
SELECT TOP 10
    p.nombre,
    tp.descripcion AS tipo,
    p.superficie   AS hectareas,
    u.provincia    AS region
FROM parques.Parque p
JOIN parques.TipoParque tp ON tp.idTipoParque = p.idTipoParque
JOIN parques.Ubicacion  u  ON u.idUbicacion   = p.idUbicacion
ORDER BY p.superficie DESC;

-- [UPSERT] Reimportacion: no debe duplicar parques
PRINT '-- Caso Upsert: reimportacion APN (no debe duplicar)';
-- RESULTADO ESPERADO: Parques actualizados = 0 o los mismos, Insertados = 0
DECLARE @vConteoAntes4 INT = (SELECT COUNT(*) FROM parques.Parque);
EXEC parques.sp_ImportarAreasProtegidas
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\datos-gob-ar\aprn_h_ubicacion_superycatint_ha.csv';
DECLARE @vConteoDespues4 INT = (SELECT COUNT(*) FROM parques.Parque);
IF @vConteoAntes4 = @vConteoDespues4
    PRINT 'UPSERT OK: sin duplicados. Parques en sistema: ' + CAST(@vConteoDespues4 AS VARCHAR);
ELSE
    PRINT 'ADVERTENCIA: conteo cambio de ' + CAST(@vConteoAntes4 AS VARCHAR) + ' a ' + CAST(@vConteoDespues4 AS VARCHAR);
GO

-- ============================================================
-- TEST 5: sp_ImportarAreasWDPA
-- Dataset: WDPA_WDOECM_Jun2026_Public_ARG_csv.csv (Protected Planet)
-- Esperado exitoso: ~479 filas en staging, filtra solo nacionales
-- ============================================================

PRINT '';
PRINT '=== TEST 5: sp_ImportarAreasWDPA ===';

-- [EXITOSO]
PRINT '-- Caso exitoso: importacion CSV WDPA Protected Planet';
-- RESULTADO ESPERADO: carga ~479 en staging, procesa solo las de jurisdiccion Nacional
-- Parques ya existentes (del TEST 4) tendran superficie actualizada con GIS_AREA en km2*100
-- Nuevas areas protegidas no nacionales seran descartadas e informadas
EXEC parques.sp_ImportarAreasWDPA
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\protected-planet\WDPA_WDOECM_Jun2026_Public_ARG_csv\WDPA_WDOECM_Jun2026_Public_ARG_csv.csv';

-- Evidencia: distribucion por tipo de area en staging (todas las jurisdicciones)
SELECT
    LTRIM(RTRIM(desigType)) AS jurisdiccion,
    COUNT(*)                AS cantidad
FROM staging.AreasWDPA
GROUP BY LTRIM(RTRIM(desigType))
ORDER BY cantidad DESC;

-- Evidencia: parques con superficie actualizada por WDPA
SELECT TOP 10
    p.nombre,
    tp.descripcion AS tipo,
    p.superficie   AS superficieHa
FROM parques.Parque p
JOIN parques.TipoParque tp ON tp.idTipoParque = p.idTipoParque
ORDER BY p.superficie DESC;

-- Evidencia: total de parques en sistema post-importacion combinada
SELECT
    tp.descripcion AS tipo,
    COUNT(*)       AS cantidad
FROM parques.Parque p
JOIN parques.TipoParque tp ON tp.idTipoParque = p.idTipoParque
GROUP BY tp.descripcion
ORDER BY cantidad DESC;

-- [IMPORTACION PARCIAL] Verificar que filas invalidas se descartan sin abortar la carga
PRINT '-- Verificacion importacion parcial: filas con gisArea invalido son descartadas';
-- RESULTADO ESPERADO: PRINT muestra filas descartadas > 0 (las de jurisdiccion sub-nacional)
-- El SP no falla, solo informa cuantas se descartaron

-- [UPSERT] Reimportacion sin duplicados
PRINT '-- Caso Upsert: reimportacion WDPA (no debe duplicar parques)';
-- RESULTADO ESPERADO: solo actualizaciones o sin cambios, nunca duplicados
DECLARE @vConteoAntes5 INT = (SELECT COUNT(*) FROM parques.Parque);
EXEC parques.sp_ImportarAreasWDPA
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\protected-planet\WDPA_WDOECM_Jun2026_Public_ARG_csv\WDPA_WDOECM_Jun2026_Public_ARG_csv.csv';
DECLARE @vConteoDespues5 INT = (SELECT COUNT(*) FROM parques.Parque);
IF @vConteoAntes5 = @vConteoDespues5
    PRINT 'UPSERT OK: sin duplicados.';
ELSE
    PRINT 'INFO: se agregaron ' + CAST(@vConteoDespues5 - @vConteoAntes5 AS VARCHAR) + ' nuevas areas.';
GO

-- ============================================================
-- TEST 6: sp_ImportarFeriados (API JSON - ArgentinaDatos)
-- RESULTADO ESPERADO: feriados del anio importados desde la API
-- REQUISITO: Ole Automation habilitado, conectividad a internet
-- ============================================================

PRINT '';
PRINT '=== TEST 6: sp_ImportarFeriados (API JSON) ===';

-- [EXITOSO] Importar feriados de anio vigente
PRINT '-- Caso exitoso: importar feriados 2026';
-- RESULTADO ESPERADO: feriados nacionales del 2026 insertados en parques.Feriado
EXEC parques.sp_ImportarFeriados @vAnio = 2026;

-- Evidencia
SELECT
    fecha,
    tipo,
    nombre
FROM parques.Feriado
WHERE YEAR(fecha) = 2026
ORDER BY fecha;

SELECT COUNT(*) AS totalFeriados2026
FROM parques.Feriado
WHERE YEAR(fecha) = 2026;

-- [EXITOSO] Importar otro anio
PRINT '-- Caso exitoso: importar feriados 2025';
EXEC parques.sp_ImportarFeriados @vAnio = 2025;

SELECT COUNT(*) AS totalFeriados2025
FROM parques.Feriado
WHERE YEAR(fecha) = 2025;

-- [UPSERT] Reimportacion: no debe duplicar feriados
PRINT '-- Caso Upsert: reimportacion feriados 2026 (no debe duplicar)';
-- RESULTADO ESPERADO: misma cantidad de feriados antes y despues
DECLARE @vConteoFeriados INT = (SELECT COUNT(*) FROM parques.Feriado WHERE YEAR(fecha) = 2026);
EXEC parques.sp_ImportarFeriados @vAnio = 2026;
DECLARE @vConteoFeriadosDespues INT = (SELECT COUNT(*) FROM parques.Feriado WHERE YEAR(fecha) = 2026);
IF @vConteoFeriados = @vConteoFeriadosDespues
    PRINT 'UPSERT OK: sin duplicados. Feriados 2026: ' + CAST(@vConteoFeriadosDespues AS VARCHAR);
ELSE
    PRINT 'ADVERTENCIA: conteo cambio.';

-- [FALLIDO] Anio invalido (fuera de rango)
PRINT '-- Fallo esperado: anio fuera de rango';
-- RESULTADO ESPERADO: RAISERROR con mensaje de validacion
BEGIN TRY
    EXEC parques.sp_ImportarFeriados @vAnio = 1900;
END TRY
BEGIN CATCH
    PRINT 'ERROR capturado (esperado): ' + ERROR_MESSAGE();
END CATCH

BEGIN TRY
    EXEC parques.sp_ImportarFeriados @vAnio = 2200;
END TRY
BEGIN CATCH
    PRINT 'ERROR capturado (esperado): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- TEST 7: sp_ImportarTipoCambio (API JSON - dolarapi.com)
-- RESULTADO ESPERADO: tipo de cambio del dia registrado
-- REQUISITO: Ole Automation habilitado, conectividad a internet
-- ============================================================

PRINT '';
PRINT '=== TEST 7: sp_ImportarTipoCambio (API JSON) ===';

-- [EXITOSO] Importar dolar oficial
PRINT '-- Caso exitoso: importar tipo de cambio oficial';
-- RESULTADO ESPERADO: compra y venta del dolar oficial registradas para hoy
EXEC parques.sp_ImportarTipoCambio @vTipo = 'oficial';

-- [EXITOSO] Importar dolar blue
PRINT '-- Caso exitoso: importar tipo de cambio blue';
EXEC parques.sp_ImportarTipoCambio @vTipo = 'blue';

-- [EXITOSO] Importar dolar tarjeta (relevante para visitantes extranjeros)
PRINT '-- Caso exitoso: importar tipo de cambio tarjeta';
EXEC parques.sp_ImportarTipoCambio @vTipo = 'tarjeta';

-- Evidencia: tipos de cambio del dia
SELECT
    fecha,
    tipo,
    compra,
    venta,
    venta - compra AS spread
FROM parques.TipoCambio
WHERE fecha = CAST(GETDATE() AS DATE)
ORDER BY tipo;

-- [UPSERT] Reimportacion del dia: actualiza, no duplica
PRINT '-- Caso Upsert: reimportacion del mismo tipo y fecha (actualiza, no duplica)';
-- RESULTADO ESPERADO: misma cantidad de registros, valores actualizados
DECLARE @vConteoTC INT = (SELECT COUNT(*) FROM parques.TipoCambio WHERE fecha = CAST(GETDATE() AS DATE));
EXEC parques.sp_ImportarTipoCambio @vTipo = 'oficial';
DECLARE @vConteoTCDespues INT = (SELECT COUNT(*) FROM parques.TipoCambio WHERE fecha = CAST(GETDATE() AS DATE));
IF @vConteoTC = @vConteoTCDespues
    PRINT 'UPSERT OK: sin duplicados.';
ELSE
    PRINT 'ADVERTENCIA: conteo cambio.';

-- [FALLIDO] Tipo invalido
PRINT '-- Fallo esperado: tipo de cambio invalido';
-- RESULTADO ESPERADO: RAISERROR con lista de tipos validos
BEGIN TRY
    EXEC parques.sp_ImportarTipoCambio @vTipo = 'dolarito';
END TRY
BEGIN CATCH
    PRINT 'ERROR capturado (esperado): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- TEST 8: sp_ObtenerTipoCambioVigente
-- Verifica el SP auxiliar que retorna el tipo de cambio mas reciente
-- ============================================================

PRINT '';
PRINT '=== TEST 8: sp_ObtenerTipoCambioVigente ===';

-- [EXITOSO] Obtener tipo de cambio vigente para conversion de precios
PRINT '-- Caso exitoso: obtener tipo de cambio oficial vigente';
-- RESULTADO ESPERADO: @vVenta y @vCompra con valores > 0
DECLARE @vVenta  DECIMAL(10,2);
DECLARE @vCompra DECIMAL(10,2);

EXEC parques.sp_ObtenerTipoCambioVigente
    @vTipo   = 'oficial',
    @vVenta  = @vVenta  OUTPUT,
    @vCompra = @vCompra OUTPUT;

PRINT 'Tipo de cambio oficial vigente -> Compra: $' + CAST(@vCompra AS VARCHAR)
    + ' | Venta: $' + CAST(@vVenta AS VARCHAR);

-- Simulacion de uso: calcular precio de entrada en dolares
DECLARE @vPrecioARS DECIMAL(18,2) = 5000.00;
PRINT 'Precio entrada $' + CAST(@vPrecioARS AS VARCHAR)
    + ' ARS = U$D ' + CAST(CAST(@vPrecioARS / @vVenta AS DECIMAL(10,2)) AS VARCHAR)
    + ' (al tipo oficial)';

-- [FALLIDO] Tipo sin datos registrados
PRINT '-- Fallo esperado: tipo sin cotizacion registrada';
-- RESULTADO ESPERADO: RAISERROR indicando que debe ejecutarse sp_ImportarTipoCambio
BEGIN TRY
    DECLARE @vV2 DECIMAL(10,2), @vC2 DECIMAL(10,2);
    EXEC parques.sp_ObtenerTipoCambioVigente
        @vTipo   = 'cripto',
        @vVenta  = @vV2  OUTPUT,
        @vCompra = @vC2 OUTPUT;
END TRY
BEGIN CATCH
    PRINT 'ERROR capturado (esperado): ' + ERROR_MESSAGE();
END CATCH
GO

-- ============================================================
-- RESUMEN FINAL: estado de todas las tablas del modulo
-- ============================================================
PRINT '';
PRINT '=== RESUMEN FINAL: Estado del modulo de importacion ===';

SELECT 'EstadisticaVisitas'        AS tabla, COUNT(*) AS registros FROM parques.EstadisticaVisitas
UNION ALL
SELECT 'EstadisticaVisitasPorRegion', COUNT(*) FROM parques.EstadisticaVisitasPorRegion
UNION ALL
SELECT 'EstadisticaVisitasAnual',     COUNT(*) FROM parques.EstadisticaVisitasAnual
UNION ALL
SELECT 'Feriado',                     COUNT(*) FROM parques.Feriado
UNION ALL
SELECT 'TipoCambio',                  COUNT(*) FROM parques.TipoCambio
UNION ALL
SELECT 'Parque',                      COUNT(*) FROM parques.Parque
UNION ALL
SELECT 'TipoParque',                  COUNT(*) FROM parques.TipoParque
UNION ALL
SELECT 'Ubicacion',                   COUNT(*) FROM parques.Ubicacion
ORDER BY tabla;
GO
