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

-- ============================================================
-- VISTA 2: Ingresos por parque y periodo
-- Desglosa los ingresos por concepto: entradas, tours, atracciones.
-- Una fila por linea de venta, para que Power BI sume por concepto.
-- ============================================================
CREATE OR ALTER VIEW ventas.vw_IngresosPorParque
AS
SELECT
    p.idParque,
    p.nombre                       AS Parque,
    u.provincia                    AS Provincia,
    CAST(tv.fechaHora AS DATE)     AS Fecha,
    YEAR(tv.fechaHora)             AS Anio,
    MONTH(tv.fechaHora)            AS Mes,
    DATENAME(MONTH, tv.fechaHora)  AS NombreMes,
    DATEPART(WEEK, tv.fechaHora)   AS Semana,
    CASE
        WHEN lv.idPrecioEntrada IS NOT NULL THEN 'Entrada'
        WHEN lv.idTour          IS NOT NULL THEN 'Tour'
        WHEN lv.idAtraccion     IS NOT NULL THEN 'Atraccion'
        ELSE 'Otro'
    END                            AS Concepto,
    lv.descripcion                 AS Detalle,
    lv.cantidad                    AS Cantidad,
    lv.subtotal                    AS Ingreso
FROM ventas.LineaVenta lv
INNER JOIN ventas.TicketVenta tv ON tv.idTicket = lv.ticketAsociado
INNER JOIN parques.Parque p      ON p.idParque = tv.idParque
INNER JOIN parques.Ubicacion u   ON u.idUbicacion = p.idUbicacion;
GO

-- ============================================================
-- VISTA 3: Actividades mas demandadas
-- Ranking de tours y atracciones por cantidad vendida e ingreso.
-- ============================================================
CREATE OR ALTER VIEW actividades.vw_ActividadesMasDemandadas
AS
SELECT
    'Tour'             AS TipoActividad,
    t.nombre           AS Actividad,
    p.nombre           AS Parque,
    SUM(lv.cantidad)   AS UnidadesVendidas,
    SUM(lv.subtotal)   AS IngresoTotal
FROM ventas.LineaVenta lv
INNER JOIN actividades.Tour t ON t.idTour = lv.idTour
INNER JOIN parques.Parque p   ON p.idParque = t.idParque
WHERE lv.idTour IS NOT NULL
GROUP BY t.nombre, p.nombre

UNION ALL

SELECT
    'Atraccion'        AS TipoActividad,
    a.nombre           AS Actividad,
    p.nombre           AS Parque,
    SUM(lv.cantidad)   AS UnidadesVendidas,
    SUM(lv.subtotal)   AS IngresoTotal
FROM ventas.LineaVenta lv
INNER JOIN actividades.Atraccion a ON a.idAtraccion = lv.idAtraccion
INNER JOIN parques.Parque p        ON p.idParque = a.idParque
WHERE lv.idAtraccion IS NOT NULL
GROUP BY a.nombre, p.nombre;
GO

-- ============================================================
-- VISTA 4: Parques con geolocalizacion (para el mapa de Power BI)
-- Incluye lat/long y metricas agregadas por parque.
-- ============================================================
CREATE OR ALTER VIEW parques.vw_ParquesGeo
AS
SELECT
    p.idParque,
    p.nombre                                  AS Parque,
    tp.descripcion                            AS TipoParque,
    p.superficie                              AS SuperficieHa,
    u.provincia                               AS Provincia,
    u.direccion                               AS Direccion,
    u.latitud                                 AS Latitud,
    u.longitud                                AS Longitud,
    ISNULL(v.TotalVisitantes, 0)              AS TotalVisitantes,
    ISNULL(i.TotalIngresos, 0)                AS TotalIngresos
FROM parques.Parque p
INNER JOIN parques.TipoParque tp ON tp.idTipoParque = p.idTipoParque
INNER JOIN parques.Ubicacion u   ON u.idUbicacion = p.idUbicacion
LEFT JOIN (
    SELECT tv.idParque, SUM(lv.cantidad) AS TotalVisitantes
    FROM ventas.LineaVenta lv
    INNER JOIN ventas.TicketVenta tv ON tv.idTicket = lv.ticketAsociado
    WHERE lv.idPrecioEntrada IS NOT NULL
    GROUP BY tv.idParque
) v ON v.idParque = p.idParque
LEFT JOIN (
    SELECT tv.idParque, SUM(lv.subtotal) AS TotalIngresos
    FROM ventas.LineaVenta lv
    INNER JOIN ventas.TicketVenta tv ON tv.idTicket = lv.ticketAsociado
    GROUP BY tv.idParque
) i ON i.idParque = p.idParque;
GO

-- ============================================================
-- VISTA 5: Estado de concesiones (vigentes/vencidas y deuda)
-- ============================================================
CREATE OR ALTER VIEW concesiones.vw_ConcesionesEstado
AS
SELECT
    c.idConcesion,
    p.nombre                                  AS Parque,
    e.razonSocial                             AS Empresa,
    tc.descripcion                            AS TipoConcesion,
    c.descripcion                             AS Concesion,
    c.fechaInicio                             AS FechaInicio,
    c.fechaFin                                AS FechaFin,
    c.canonMensual                            AS CanonMensual,
    CASE
        WHEN c.fechaFin >= CAST(GETDATE() AS DATE) THEN 'Vigente'
        ELSE 'Vencida'
    END                                       AS Estado,
    ISNULL(pg.PagosRealizados, 0)             AS PagosRealizados,
    ISNULL(pg.TotalCobrado, 0)                AS TotalCobrado,
    DATEDIFF(
        MONTH, c.fechaInicio,
        CASE WHEN c.fechaFin < CAST(GETDATE() AS DATE)
             THEN c.fechaFin ELSE CAST(GETDATE() AS DATE) END
    )                                         AS MesesTranscurridos
FROM concesiones.Concesion c
INNER JOIN parques.Parque p           ON p.idParque = c.idParque
INNER JOIN concesiones.Empresa e      ON e.idEmpresa = c.idEmpresa
INNER JOIN concesiones.TipoDeConsesion tc ON tc.idTipoConcesion = c.idTipoConcesion
LEFT JOIN (
    SELECT idConcesion,
           COUNT(*)      AS PagosRealizados,
           SUM(monto)    AS TotalCobrado
    FROM concesiones.PagoConcesion
    GROUP BY idConcesion
) pg ON pg.idConcesion = c.idConcesion;
GO

PRINT 'Vistas para Power BI creadas correctamente.';
GO

-- ============================================================
-- VERIFICACION (probar que devuelven datos)
-- ============================================================
SELECT TOP 5 * FROM ventas.vw_VisitasPorParque;
SELECT TOP 5 * FROM ventas.vw_IngresosPorParque;
SELECT TOP 5 * FROM actividades.vw_ActividadesMasDemandadas ORDER BY UnidadesVendidas DESC;
SELECT * FROM parques.vw_ParquesGeo;
SELECT * FROM concesiones.vw_ConcesionesEstado;
GO
