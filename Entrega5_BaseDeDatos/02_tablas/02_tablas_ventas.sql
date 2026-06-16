-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Creacion de tablas del modulo Ventas y Precios.
--              Tablas: TipoVisitante, PrecioEntrada, TicketVenta, LineaVenta
-- Dependencias: Schema 'ventas' creado por script 01_database.sql
--               Tabla parques.Parque creada por modulo Parques
--               Tabla parques.Tour creada por modulo Guias, Tours y Atracciones
--               Tabla parques.Atraccion creada por modulo Guias, Tours y Atracciones
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- TABLA: TipoVisitante
-- Lookup de tipos de visitante
-- Ejemplos: Residente, Extranjero, Jubilado, Estudiante
-- ============================================================
CREATE TABLE ventas.TipoVisitante (
    idTipoVisitante  INT          IDENTITY(1,1)  NOT NULL,
    descripcion      VARCHAR(100)                NOT NULL,
    CONSTRAINT PK_TipoVisitante             PRIMARY KEY (idTipoVisitante),
    CONSTRAINT UQ_TipoVisitante_descripcion UNIQUE      (descripcion)
);
GO

-- ============================================================
-- TABLA: PrecioEntrada
-- Catalogo historico de precios de entrada por parque y tipo de visitante
-- fechaHasta NULL indica precio vigente
-- ============================================================
CREATE TABLE ventas.PrecioEntrada (
    idPrecio           INT           IDENTITY(1,1)  NOT NULL,
    fechaActualizacion DATE                         NOT NULL,
    valor              DECIMAL(18,2)                NOT NULL,
    idParque           INT                          NOT NULL,
    idTipoVisitante    INT                          NOT NULL,
    fechaHasta         DATE                         NULL,
    CONSTRAINT PK_PrecioEntrada               PRIMARY KEY (idPrecio),
    CONSTRAINT FK_PrecioEntrada_Parque        FOREIGN KEY (idParque)        REFERENCES parques.Parque(idParque),
    CONSTRAINT FK_PrecioEntrada_TipoVisitante FOREIGN KEY (idTipoVisitante) REFERENCES ventas.TipoVisitante(idTipoVisitante),
    CONSTRAINT CHK_PrecioEntrada_valor        CHECK (valor >= 0)
);
GO

-- ============================================================
-- TABLA: TicketVenta
-- Cabecera del ticket de venta
-- ============================================================
CREATE TABLE ventas.TicketVenta (
    idTicket      INT IDENTITY(1,1) NOT NULL,
    fechaHora     DATETIME      NOT NULL,
    total         DECIMAL(18,2) NOT NULL,
    puntoDeVenta  INT           NOT NULL,
    nroTicket     INT           NOT NULL,
    formaPago     VARCHAR(50)   NOT NULL,
    idParque      INT           NULL,
    CONSTRAINT PK_TicketVenta        PRIMARY KEY (idTicket),
    CONSTRAINT FK_TicketVenta_Parque FOREIGN KEY (idParque) REFERENCES parques.Parque(idParque),
    CONSTRAINT CHK_TicketVenta_total CHECK (total >= 0)
);
GO

-- ============================================================
-- TABLA: LineaVenta
-- Detalle o renglon del ticket de venta
-- Puede representar una entrada, un tour o una atraccion
-- ============================================================
CREATE TABLE ventas.LineaVenta (
    idLineaVenta    INT IDENTITY(1,1) NOT NULL,
    ticketAsociado  INT           NOT NULL,
    descripcion     VARCHAR(50)   NOT NULL,
    subtotal        DECIMAL(18,2) NOT NULL,
    cantidad        INT           NOT NULL,
    precioUnitario  DECIMAL(18,2) NOT NULL,
    idPrecioEntrada INT           NULL,
    idTour          INT           NULL,
    idAtraccion     INT           NULL,
    CONSTRAINT PK_LineaVenta                 PRIMARY KEY (idLineaVenta),
    CONSTRAINT FK_LineaVenta_PrecioEntrada   FOREIGN KEY (idPrecioEntrada) REFERENCES ventas.PrecioEntrada(idPrecio),
    CONSTRAINT FK_LineaVenta_TicketVenta     FOREIGN KEY (ticketAsociado) REFERENCES ventas.TicketVenta(idTicket),
    CONSTRAINT FK_LineaVenta_Tour            FOREIGN KEY (idTour) REFERENCES parques.Tour(idTour),
    CONSTRAINT FK_LineaVenta_Atraccion       FOREIGN KEY (idAtraccion) REFERENCES parques.Atraccion(idAtraccion),
    CONSTRAINT CHK_LineaVenta_cantidad       CHECK (cantidad > 0),
    CONSTRAINT CHK_LineaVenta_precioUnitario CHECK (precioUnitario >= 0),
    CONSTRAINT CHK_LineaVenta_subtotal       CHECK (subtotal >= 0),
    CONSTRAINT CHK_LineaVenta_UnSoloItem CHECK (
        (CASE WHEN idPrecioEntrada IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN idTour IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN idAtraccion IS NOT NULL THEN 1 ELSE 0 END) = 1
    )
);
GO