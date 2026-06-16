-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Ejecucion de los SPs de importacion - Entrega 6.
--              Ajustar @vBasePath con la ruta local al repositorio.
-- Prerequisito: Ejecutar entrega6_unificado.sql primero.
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- CONFIGURACION: ajustar esta ruta antes de ejecutar
-- ============================================================
-- Ejemplo Windows:
--   C:\ruta\al\repo\Entrega6_Importacion\datasets\
-- Ejemplo Mac/Linux con Docker:
--   /datasets/

-- ============================================================
-- CSV 1: Visitas nacionales mensuales
-- Fuente: datos.yvera.gob.ar | ~660 filas
-- ============================================================
EXEC parques.sp_ImportarVisitasNacionales
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\datos-gob-ar\visitas-residentes-y-no-residentes.csv';
GO

-- ============================================================
-- CSV 2: Visitas por region
-- Fuente: datos.yvera.gob.ar | ~3960 filas
-- ============================================================
EXEC parques.sp_ImportarVisitasPorRegion
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\datos-gob-ar\visitas-residentes-y-no-residentes-por-region.csv';
GO

-- ============================================================
-- CSV 3: Distribucion anual de visitas APN
-- Fuente: datos.gob.ar APN | 18 filas (2008-2025)
-- ============================================================
EXEC parques.sp_ImportarVisitasAnual
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\datos-gob-ar\aprn_i_visitas_porc_2024.csv';
GO

-- ============================================================
-- CSV 4: Areas protegidas APN con ubicacion y superficie
-- Fuente: datos.gob.ar APN | 50 filas
-- ============================================================
EXEC parques.sp_ImportarAreasProtegidas
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\datos-gob-ar\aprn_h_ubicacion_superycatint_ha.csv';
GO

-- ============================================================
-- CSV 5: Areas protegidas WDPA / Protected Planet
-- Fuente: protectedplanet.net (UNEP-WCMC / IUCN) | 479 filas
-- ============================================================
EXEC parques.sp_ImportarAreasWDPA
    @vRutaArchivo = 'C:\TP_ParquesNacionales\Entrega6_Importacion\datasets\protected-planet\WDPA_WDOECM_Jun2026_Public_ARG_csv\WDPA_WDOECM_Jun2026_Public_ARG_csv.csv';
GO

-- ============================================================
-- API 1: Feriados nacionales argentinos
-- Fuente: argentinadatos.com | Requiere OLE Automation + internet
-- Habilitar una sola vez (requiere sysadmin):
--   EXEC sp_configure 'Ole Automation Procedures', 1; RECONFIGURE;
-- ============================================================
EXEC parques.sp_ImportarFeriados @vAnio = 2024;
EXEC parques.sp_ImportarFeriados @vAnio = 2025;
EXEC parques.sp_ImportarFeriados @vAnio = 2026;
GO

-- ============================================================
-- API 2: Tipo de cambio USD/ARS
-- Fuente: dolarapi.com | Requiere OLE Automation + internet
-- ============================================================
EXEC parques.sp_ImportarTipoCambio @vTipo = 'oficial';
EXEC parques.sp_ImportarTipoCambio @vTipo = 'blue';
EXEC parques.sp_ImportarTipoCambio @vTipo = 'tarjeta';
GO

-- ============================================================
-- VERIFICACION POST-IMPORTACION
-- ============================================================
SELECT 'EstadisticaVisitas'         AS tabla, COUNT(*) AS filas FROM parques.EstadisticaVisitas
UNION ALL
SELECT 'EstadisticaVisitasPorRegion',           COUNT(*) FROM parques.EstadisticaVisitasPorRegion
UNION ALL
SELECT 'EstadisticaVisitasAnual',               COUNT(*) FROM parques.EstadisticaVisitasAnual
UNION ALL
SELECT 'Parque',                                COUNT(*) FROM parques.Parque
UNION ALL
SELECT 'TipoParque',                            COUNT(*) FROM parques.TipoParque
UNION ALL
SELECT 'Ubicacion',                             COUNT(*) FROM parques.Ubicacion
UNION ALL
SELECT 'Feriado',                               COUNT(*) FROM parques.Feriado
UNION ALL
SELECT 'TipoCambio',                            COUNT(*) FROM parques.TipoCambio
ORDER BY tabla;
GO
