-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 27/06/2026
-- Descripcion: Stored Procedures de reportes del Sistema de Gestion
--              de Parques Nacionales.
--
--              Reporte 1: Visitas por semana, mes y año por parque.
--              Reporte 2: Ingresos por parque por semana, mes y año,
--                          incluyendo entradas, tours y concesiones.
--              Reporte 3: Concesiones con pagos adeudados.
--              Reporte 4: Matriz de visitas por mes y parque (PIVOT).
--              Reporte 5: Parques y concesiones con estructura
--                          jerarquica XML.
--
--              Los reportes 3 y 5 poseen versiones XML para cumplir
--              con el requisito de exportacion estructurada.
--
-- Prerequisito: Ejecutar los scripts de creacion de tablas,
--               ABM y logica de negocio de los modulos:
--               Parques, Ventas y Concesiones.
-- =============================================

USE ParquesNacionales;
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'reportes')
BEGIN
    EXEC('CREATE SCHEMA reportes');
END
GO

CREATE OR ALTER PROCEDURE reportes.reporteVisitasPorPeriodo
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.idParque,
        p.nombre AS parque,
        YEAR(tv.fechaHora) AS anio,
        MONTH(tv.fechaHora) AS mes,
        (DATEPART(WEEK, tv.fechaHora) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, tv.fechaHora), 0)) + 1) AS semana,
        SUM(lv.cantidad) AS cantidadVisitas
    FROM ventas.TicketVenta tv
    INNER JOIN ventas.LineaVenta lv
        ON lv.ticketAsociado = tv.idTicket
    INNER JOIN ventas.PrecioEntrada pe
        ON pe.idPrecio = lv.idPrecioEntrada
    INNER JOIN parques.Parque p
        ON p.idParque = pe.idParque
    WHERE lv.idPrecioEntrada IS NOT NULL
    GROUP BY
        p.idParque,
        p.nombre,
        YEAR(tv.fechaHora),
        MONTH(tv.fechaHora),
        (DATEPART(WEEK, tv.fechaHora) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, tv.fechaHora), 0)) + 1)
    ORDER BY
        p.nombre,
        anio,
        mes,
        semana;
END
GO


-- ============================================================
-- SP: reporteIngresosPorParque
-- Reporte 2: ingresos por parque por semana, mes y año
-- ============================================================

CREATE OR ALTER PROCEDURE reportes.reporteIngresosPorParque
AS
BEGIN
    SET NOCOUNT ON;

    WITH ingresosVentas AS (
        SELECT
            tv.idParque,
            YEAR(tv.fechaHora) AS anio,
            MONTH(tv.fechaHora) AS mes,
            (DATEPART(WEEK, tv.fechaHora) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, tv.fechaHora), 0)) + 1) AS semana,
            SUM(CASE WHEN lv.idPrecioEntrada IS NOT NULL THEN lv.cantidad ELSE 0 END) AS totalEntradas,
            SUM(CASE WHEN lv.idPrecioEntrada IS NOT NULL THEN lv.subtotal ELSE 0 END) AS ingresosEntradas,
            SUM(CASE WHEN lv.idTour IS NOT NULL THEN lv.subtotal ELSE 0 END) AS ingresosTours
        FROM ventas.TicketVenta tv
        INNER JOIN ventas.LineaVenta lv
            ON lv.ticketAsociado = tv.idTicket
        GROUP BY
            tv.idParque,
            YEAR(tv.fechaHora),
            MONTH(tv.fechaHora),
            (DATEPART(WEEK, tv.fechaHora) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, tv.fechaHora), 0)) + 1)
    ),
    ingresosConcesiones AS (
        SELECT
            c.idParque,
            YEAR(pc.fechaPago) AS anio,
            MONTH(pc.fechaPago) AS mes,
            (DATEPART(WEEK, pc.fechaPago) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, pc.fechaPago), 0)) + 1) AS semana,
            SUM(pc.monto) AS ingresosConcesiones
        FROM concesiones.Concesion c
        INNER JOIN concesiones.PagoConcesion pc
            ON pc.idConcesion = c.idConcesion
        GROUP BY
            c.idParque,
            YEAR(pc.fechaPago),
            MONTH(pc.fechaPago),
            (DATEPART(WEEK, pc.fechaPago) - DATEPART(WEEK, DATEADD(MONTH, DATEDIFF(MONTH, 0, pc.fechaPago), 0)) + 1)
    )
    SELECT
        p.idParque,
        p.nombre AS parque,
        COALESCE(v.anio, c.anio) AS anio,
        COALESCE(v.mes, c.mes) AS mes,
        COALESCE(v.semana, c.semana) AS semana,
        ISNULL(v.totalEntradas, 0) AS totalEntradas,
        ISNULL(v.ingresosEntradas, 0) AS ingresosEntradas,
        ISNULL(v.ingresosTours, 0) AS ingresosTours,
        ISNULL(c.ingresosConcesiones, 0) AS ingresosConcesiones,
        ISNULL(v.ingresosEntradas, 0)
        + ISNULL(v.ingresosTours, 0)
        + ISNULL(c.ingresosConcesiones, 0) AS ingresosTotales
    FROM ingresosVentas v
    FULL OUTER JOIN ingresosConcesiones c
        ON c.idParque = v.idParque
       AND c.anio = v.anio
       AND c.mes = v.mes
       AND c.semana = v.semana
    INNER JOIN parques.Parque p
        ON p.idParque = COALESCE(v.idParque, c.idParque)
    ORDER BY
        p.nombre,
        anio,
        mes,
        semana;
END
GO

-- ============================================================
-- SP: reporteDeudoresConcesiones
-- Reporte 3: concesiones atrasadas en pagos del año actual
-- ============================================================
CREATE OR ALTER PROCEDURE reportes.reporteDeudoresConcesiones
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vAnioActual INT = YEAR(GETDATE());
    DECLARE @vMesActual INT = MONTH(GETDATE());

    WITH meses AS (
        SELECT 1 AS mes UNION ALL
        SELECT 2 UNION ALL
        SELECT 3 UNION ALL
        SELECT 4 UNION ALL
        SELECT 5 UNION ALL
        SELECT 6 UNION ALL
        SELECT 7 UNION ALL
        SELECT 8 UNION ALL
        SELECT 9 UNION ALL
        SELECT 10 UNION ALL
        SELECT 11 UNION ALL
        SELECT 12
    )
    SELECT
        c.idConcesion,
        c.descripcion AS concesion,
        p.nombre AS parque,
        e.razonSocial AS empresa,
        @vAnioActual AS anio,
        m.mes,
        c.canonMensual AS montoAdeudado
    FROM concesiones.Concesion c
    INNER JOIN parques.Parque p
        ON p.idParque = c.idParque
    INNER JOIN concesiones.Empresa e
        ON e.idEmpresa = c.idEmpresa
    INNER JOIN meses m
        ON m.mes <= @vMesActual
    LEFT JOIN concesiones.PagoConcesion pc
        ON pc.idConcesion = c.idConcesion
       AND pc.periodoAnio = @vAnioActual
       AND pc.periodoMes = m.mes
    WHERE pc.idPagoConcesion IS NULL
      AND DATEFROMPARTS(@vAnioActual, m.mes, 1)
          BETWEEN DATEFROMPARTS(YEAR(c.fechaInicio), MONTH(c.fechaInicio), 1)
              AND DATEFROMPARTS(YEAR(c.fechaFin), MONTH(c.fechaFin), 1)
    ORDER BY
        p.nombre,
        e.razonSocial,
        m.mes;
END
GO

-- ============================================================
-- SP: reporteDeudoresConcesionesXml
-- Reporte 3.5 XML: concesiones atrasadas en pagos del año actual
-- ============================================================
CREATE OR ALTER PROCEDURE reportes.reporteDeudoresConcesionesXml
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vAnioActual INT = YEAR(GETDATE());
    DECLARE @vMesActual INT = MONTH(GETDATE());

    WITH meses AS (
        SELECT 1 AS mes UNION ALL
        SELECT 2 UNION ALL
        SELECT 3 UNION ALL
        SELECT 4 UNION ALL
        SELECT 5 UNION ALL
        SELECT 6 UNION ALL
        SELECT 7 UNION ALL
        SELECT 8 UNION ALL
        SELECT 9 UNION ALL
        SELECT 10 UNION ALL
        SELECT 11 UNION ALL
        SELECT 12
    ),
    deudas AS (
        SELECT
            c.idConcesion,
            c.descripcion AS concesion,
            p.idParque,
            p.nombre AS parque,
            e.razonSocial AS empresa,
            @vAnioActual AS anio,
            m.mes,
            c.canonMensual AS montoAdeudado
        FROM concesiones.Concesion c
        INNER JOIN parques.Parque p
            ON p.idParque = c.idParque
        INNER JOIN concesiones.Empresa e
            ON e.idEmpresa = c.idEmpresa
        INNER JOIN meses m
            ON m.mes <= @vMesActual
        LEFT JOIN concesiones.PagoConcesion pc
            ON pc.idConcesion = c.idConcesion
           AND pc.periodoAnio = @vAnioActual
           AND pc.periodoMes = m.mes
        WHERE pc.idPagoConcesion IS NULL
          AND DATEFROMPARTS(@vAnioActual, m.mes, 1)
              BETWEEN DATEFROMPARTS(YEAR(c.fechaInicio), MONTH(c.fechaInicio), 1)
                  AND DATEFROMPARTS(YEAR(c.fechaFin), MONTH(c.fechaFin), 1)
    )
    SELECT
        d.idParque AS '@idParque',
        d.parque AS '@nombre',
        (
            SELECT
                d2.idConcesion AS '@idConcesion',
                d2.concesion AS 'concesion',
                d2.empresa AS 'empresa',
                d2.anio AS 'anio',
                d2.mes AS 'mes',
                d2.montoAdeudado AS 'montoAdeudado'
            FROM deudas d2
            WHERE d2.idParque = d.idParque
            FOR XML PATH('Deuda'), TYPE
        ) AS 'Deudas'
    FROM deudas d
    GROUP BY d.idParque, d.parque
    ORDER BY d.parque
    FOR XML PATH('Parque'), ROOT('DeudoresConcesiones');
END
GO

-- ============================================================
-- SP: reporteMatrizVisitas
-- Reporte 4: tabla cruzada de visitas por mes y parque
-- ============================================================
CREATE OR ALTER PROCEDURE reportes.reporteMatrizVisitas
AS
BEGIN
    SET NOCOUNT ON;
WITH EntradasxParque(Parque, Mes, CantidadVisitas) as (
select 
    tv.idParque,
    MONTH(tv.fechaHora) as mes, 
    sum(lv.cantidad) as cantidadEntradas
    from ventas.LineaVenta lv 
inner join ventas.TicketVenta tv on lv.ticketAsociado = tv.idTicket
where lv.idPrecioEntrada IS NOT NULL and YEAR(tv.fechaHora) = YEAR(GETDATE())
group by tv.idParque, YEAR(tv.fechaHora), MONTH(tv.fechaHora)
)
    SELECT
        p.nombre AS Parque,
        ISNULL([1], 0)  AS Enero,
        ISNULL([2], 0)  AS Febrero,
        ISNULL([3], 0)  AS Marzo,
        ISNULL([4], 0)  AS Abril,
        ISNULL([5], 0)  AS Mayo,
        ISNULL([6], 0)  AS Junio,
        ISNULL([7], 0)  AS Julio,
        ISNULL([8], 0)  AS Agosto,
        ISNULL([9], 0)  AS Septiembre,
        ISNULL([10], 0) AS Octubre,
        ISNULL([11], 0) AS Noviembre,
        ISNULL([12], 0) AS Diciembre
    FROM EntradasxParque
    PIVOT (
        SUM(CantidadVisitas)
        FOR Mes IN ([1], [2], [3], [4], [5], [6],
                    [7], [8], [9], [10], [11], [12])
    ) AS pvt
    INNER JOIN parques.Parque p
        ON p.idParque = pvt.Parque
    ORDER BY p.nombre;
END
GO



-- ============================================================
-- SP: reporteParquesConcesionesXml
-- Reporte 5: parques y concesiones con vector anidado XML
-- ============================================================
CREATE OR ALTER PROCEDURE reportes.reporteParquesConcesionesXml
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.idParque AS '@idParque',
        p.nombre AS '@nombre',
        p.superficie AS '@superficie',

        (
            SELECT
                c.idConcesion AS '@idConcesion',
                c.descripcion AS 'servicioPrestado',
                tc.descripcion AS 'tipoConcesion',
                e.razonSocial AS 'titular',
                e.cuit AS 'cuit',
                c.fechaInicio AS 'fechaInicio',
                c.fechaFin AS 'fechaFin',
                c.canonMensual AS 'canonMensual'
            FROM concesiones.Concesion c
            INNER JOIN concesiones.Empresa e
                ON e.idEmpresa = c.idEmpresa
            INNER JOIN concesiones.TipoDeConsesion tc
                ON tc.idTipoConcesion = c.idTipoConcesion
            WHERE c.idParque = p.idParque
            FOR XML PATH('Concesion'), TYPE
        ) AS 'Concesiones'

    FROM parques.Parque p
    ORDER BY p.nombre
    FOR XML PATH('Parque'), ROOT('Parques');
END
GO
