-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 27/06/2026
-- Descripcion: Entrega 9 - Vistas para alimentar el dashboard de Power BI.
--   Cada vista expone datos ya procesados desde la base SQL para que
--   Power BI los consuma por conexion directa (DirectQuery o Import).
--   Vistas:
--     vw_VisitasPorParque        -> visitantes por parque y periodo
--     vw_IngresosPorParque       -> ingresos (entradas, tours, atracciones, concesiones)
--     vw_ActividadesMasDemandadas-> ranking de tours y atracciones
--     vw_ParquesGeo              -> parques con lat/long para el mapa
--     vw_ConcesionesEstado       -> concesiones vigentes/vencidas y deuda
-- Prerequisito: Tablas y datos cargados (Entregas 5, 6 y seed).
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- VISTA 1: Visitas por parque y periodo
-- Cuenta visitantes (suma de cantidad en lineas de entrada)
-- con desglose temporal para que Power BI agrupe por año/mes/semana.
-- ============================================================
CREATE OR ALTER VIEW ventas.vw_VisitasPorParque
AS
SELECT
    p.idParque,
    p.nombre                          AS Parque,
    tp.descripcion                    AS TipoParque,
    u.provincia                       AS Provincia,
    tv.fechaHora                      AS FechaHora,
    CAST(tv.fechaHora AS DATE)        AS Fecha,
    YEAR(tv.fechaHora)                AS Anio,
    MONTH(tv.fechaHora)               AS Mes,
    DATENAME(MONTH, tv.fechaHora)     AS NombreMes,
    DATEPART(WEEK, tv.fechaHora)      AS Semana,
    lv.cantidad                       AS Visitantes,
    tvis.descripcion                  AS TipoVisitante
FROM ventas.LineaVenta lv
INNER JOIN ventas.TicketVenta tv   ON tv.idTicket = lv.ticketAsociado
INNER JOIN parques.Parque p        ON p.idParque = tv.idParque
INNER JOIN parques.TipoParque tp   ON tp.idTipoParque = p.idTipoParque
INNER JOIN parques.Ubicacion u     ON u.idUbicacion = p.idUbicacion
INNER JOIN ventas.PrecioEntrada pe ON pe.idPrecio = lv.idPrecioEntrada
INNER JOIN ventas.TipoVisitante tvis ON tvis.idTipoVisitante = pe.idTipoVisitante
WHERE lv.idPrecioEntrada IS NOT NULL;
GO

-- Esta vista es lo mismo que el reporte de visitas por periodo pero power bi trabaja con vistas.
