-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Script de testing Entrega 5 - Requiere ejecutar todos los archivos unificados de la entrega 5.
-- =============================================


CREATE DATABASE ParquesNacionales;

USE ParquesNacionales;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'parques')
    EXEC('CREATE SCHEMA parques');
GO


-- ============================================================
-- TABLAS - Módulo Parques y Guardaparques
-- ============================================================

--               Tabla parques.Parque creada por modulo Parques

GO


--- Creacion del esquema parques
GO

-- TABLA: TipoParque
-- Tipos de parques
-- Ejemplo: Patagonia, Noreste, Centro

CREATE TABLE parques.TipoParque (
    idTipoParque  INT           IDENTITY(1,1) NOT NULL,
    descripcion   VARCHAR(100)  NOT NULL,
    CONSTRAINT PK_TipoParque PRIMARY KEY (idTipoParque)
);

-- TABLA: Ubicacion
-- Lugar fisico de un parque

CREATE TABLE parques.Ubicacion (
    idUbicacion  INT            IDENTITY(1,1) NOT NULL,
    direccion    VARCHAR(100)   NOT NULL,
    provincia    VARCHAR(50)    NOT NULL,
    latitud      DECIMAL(9,6)   NOT NULL,
    longitud     DECIMAL(9,6)   NOT NULL,
    CONSTRAINT PK_Ubicacion PRIMARY KEY (idUbicacion)
);

-- TABLA: Parque
-- Parques registrados

CREATE TABLE parques.Parque (
    idParque       INT            IDENTITY(1,1) NOT NULL,
    nombre         VARCHAR(100)   NOT NULL,
    superficie     DECIMAL(18,2)  NOT NULL,
    idTipoParque   INT            NOT NULL,
    idUbicacion    INT            NOT NULL,
    CONSTRAINT PK_Parque PRIMARY KEY (idParque),
    CONSTRAINT FK_Parque_TipoParque FOREIGN KEY (idTipoParque) REFERENCES parques.TipoParque (idTipoParque),
    CONSTRAINT FK_Parque_Ubicacion FOREIGN KEY (idUbicacion) REFERENCES parques.Ubicacion (idUbicacion)
);

-- TABLA: Guardaparque
-- Encargado de un area dentro de un parque

CREATE TABLE parques.Guardaparque (
    dni              INT    NOT NULL,
    apyn             VARCHAR(50)    NOT NULL,
    email            VARCHAR(100)   NULL,
    telefono         VARCHAR(50)    NULL,
    localidad        VARCHAR(50)    NULL,
    fechaNacimiento  DATETIME       NULL,
    CONSTRAINT PK_Guardaparque PRIMARY KEY (dni)
);

-- TABLA: AsignacionGuardaparque
-- Tabla de marca temporal para la asignacion de los guardaparques

CREATE TABLE parques.AsignacionGuardaparque (
    idAsignacion   INT            IDENTITY(1,1) NOT NULL,
    fechaInicio    DATE           NOT NULL,
    fechaFin       DATE           NULL,
    motivoEgreso   VARCHAR(255)   NULL,
    idParque       INT            NOT NULL,
    dni            INT    NOT NULL,
    CONSTRAINT PK_AsignacionGuardaparque PRIMARY KEY (idAsignacion),
    CONSTRAINT FK_AsignacionGuardaparque_Parque FOREIGN KEY (idParque) REFERENCES parques.Parque (idParque),
    CONSTRAINT FK_AsignacionGuardaparque_Guardaparque FOREIGN KEY (dni) REFERENCES parques.Guardaparque (dni)
);


GO


-- ============================================================
-- TABLAS - Módulo Concesiones
-- ============================================================

--               Tabla parques.Parque creada por modulo Parques

GO

GO

-- TABLA: TipoDeConsesion
-- Lookup de tipos de actividad concesionada
-- Ejemplos: Gastronomia, Turismo aventura, Comercio minorista
CREATE TABLE parques.TipoDeConsesion (
    idTipoConcesion  INT          IDENTITY(1,1)  NOT NULL,
    descripcion      VARCHAR(100)                NOT NULL,
    CONSTRAINT PK_TipoDeConsesion             PRIMARY KEY (idTipoConcesion),
    CONSTRAINT UQ_TipoDeConsesion_descripcion UNIQUE      (descripcion)
);
GO

-- TABLA: Empresa
-- Datos de la empresa concesionaria
CREATE TABLE parques.Empresa (
    idEmpresa    INT          IDENTITY(1,1)  NOT NULL,
    razonSocial  VARCHAR(200)                NOT NULL,
    cuit         VARCHAR(20)                 NOT NULL,
    contacto     VARCHAR(100)                NULL,
    email        VARCHAR(100)                NULL,
    telefono     VARCHAR(50)                 NULL,
    CONSTRAINT PK_Empresa      PRIMARY KEY (idEmpresa),
    CONSTRAINT UQ_Empresa_cuit UNIQUE      (cuit)
);
GO

-- TABLA: Concesion
-- Contrato de concesion entre una empresa y un parque
CREATE TABLE parques.Concesion (
    idConcesion      INT           IDENTITY(1,1)  NOT NULL,
    descripcion      VARCHAR(100)                 NOT NULL,
    idTipoConcesion  INT                          NOT NULL,
    idParque         INT                          NOT NULL,
    idEmpresa        INT                          NOT NULL,
    fechaInicio      DATE                         NOT NULL,
    fechaFin         DATE                         NOT NULL,
    canonMensual     DECIMAL(18,2)                NOT NULL,
    CONSTRAINT PK_Concesion                 PRIMARY KEY (idConcesion),
    CONSTRAINT FK_Concesion_TipoDeConsesion FOREIGN KEY (idTipoConcesion) REFERENCES parques.TipoDeConsesion(idTipoConcesion),
    CONSTRAINT FK_Concesion_Empresa         FOREIGN KEY (idEmpresa)       REFERENCES parques.Empresa(idEmpresa),
    CONSTRAINT FK_Concesion_Parque          FOREIGN KEY (idParque)        REFERENCES parques.Parque(idParque),
    CONSTRAINT CHK_Concesion_fechas         CHECK (fechaFin > fechaInicio),
    CONSTRAINT CHK_Concesion_canonMensual   CHECK (canonMensual > 0)
);
GO

-- TABLA: PagoConcesion
-- Historial de pagos de canon mensual por concesion
-- La constraint UQ_PagoConcesion_periodo impide duplicados a nivel DB
-- (ademas de la validacion en el SP de negocio)
CREATE TABLE parques.PagoConcesion (
    idPagoConcesion  INT           IDENTITY(1,1)  NOT NULL,
    idConcesion      INT                          NOT NULL,
    monto            DECIMAL(18,2)                NOT NULL,
    fechaPago        DATE                         NOT NULL,
    periodoAnio      INT                          NOT NULL,
    periodoMes       INT                          NOT NULL,
    CONSTRAINT PK_PagoConcesion              PRIMARY KEY (idPagoConcesion),
    CONSTRAINT FK_PagoConcesion_Concesion    FOREIGN KEY (idConcesion) REFERENCES parques.Concesion(idConcesion),
    CONSTRAINT CHK_PagoConcesion_periodoMes  CHECK (periodoMes BETWEEN 1 AND 12),
    CONSTRAINT CHK_PagoConcesion_periodoAnio CHECK (periodoAnio >= 2020),
    CONSTRAINT CHK_PagoConcesion_monto       CHECK (monto > 0),
    CONSTRAINT UQ_PagoConcesion_periodo      UNIQUE (idConcesion, periodoAnio, periodoMes)
);
GO

GO


-- ============================================================
-- TABLAS - Módulo Guías, Tours y Atracciones
-- ============================================================

--              Ruiz Santillán Facundo, Lago Franco Nehuen

GO

-- GUIA
IF NOT EXISTS (SELECT 1 FROM sys.tables t 
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Guia' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.Guia (
        dni                    INT                NOT NULL,
        apyn                   VARCHAR(100)       NOT NULL,
        especialidad           VARCHAR(100)       NULL,
        titulo                 VARCHAR(100)       NULL,
        habilitaciones         VARCHAR(255)       NULL,
        vigenciaAutorizacion   DATE               NOT NULL,
        CONSTRAINT PK_Guia_dni PRIMARY KEY (dni)
    );
END
GO

-- TOUR
IF NOT EXISTS (SELECT 1 FROM sys.tables t 
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Tour' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.Tour (
        idTour      INT IDENTITY(1,1)   NOT NULL,
        nombre      VARCHAR(100)        NOT NULL,
        descripcion VARCHAR(255)        NULL,
        duracion    INT                 NOT NULL, -- en minutos
        cupoMaximo  INT                 NOT NULL,
        precio      DECIMAL(18,2)       NOT NULL DEFAULT 0,
        idParque    INT                 NOT NULL,
        CONSTRAINT PK_Tour              PRIMARY KEY (idTour),
        CONSTRAINT FK_Tour_Parque       FOREIGN KEY (idParque) REFERENCES parques.Parque(idParque),
        CONSTRAINT CHK_Tour_duracion    CHECK (duracion > 0),
        CONSTRAINT CHK_Tour_cupo        CHECK (cupoMaximo > 0),
        CONSTRAINT CHK_Tour_precio      CHECK (precio >= 0)
    );
END
GO

-- ATRACCION
IF NOT EXISTS (SELECT 1 FROM sys.tables t 
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Atraccion' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.Atraccion (
        idAtraccion     INT IDENTITY(1,1)   NOT NULL,
        nombre          VARCHAR(100)        NOT NULL,
        descripcion     VARCHAR(255)        NULL,
        tipo            VARCHAR(50)         NULL,
        precio          DECIMAL(18,2)       NOT NULL DEFAULT 0,
        duracion        INT                 NOT NULL, -- en minutos
        cupoMaximo      INT                 NOT NULL,
        idParque        INT                 NOT NULL,
        CONSTRAINT PK_Atraccion             PRIMARY KEY (idAtraccion),
        CONSTRAINT FK_Atraccion_Parque      FOREIGN KEY (idParque) REFERENCES parques.Parque(idParque),
        CONSTRAINT CHK_Atraccion_duracion   CHECK (duracion > 0),
        CONSTRAINT CHK_Atraccion_cupo       CHECK (cupoMaximo > 0),
        CONSTRAINT CHK_Atraccion_precio     CHECK (precio >= 0)
    );
END
GO

-- ASIGNACION GUIA
IF NOT EXISTS (SELECT 1 FROM sys.tables t 
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'AsignacionGuia' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.AsignacionGuia (
        idAsignacion    INT IDENTITY(1,1)   NOT NULL,
        idTour          INT                 NOT NULL,
        dniGuia         INT                 NOT NULL,
        fechaInicio     DATE                NOT NULL,
        fechaFin        DATE                NOT NULL,
        CONSTRAINT PK_AsignacionGuia            PRIMARY KEY (idAsignacion),
        CONSTRAINT FK_AsignacionGuia_Tour       FOREIGN KEY (idTour) REFERENCES parques.Tour(idTour),
        CONSTRAINT FK_AsignacionGuia_dniGuia       FOREIGN KEY (dniGuia) REFERENCES parques.Guia(dni),
        CONSTRAINT CHK_AsignacionGuia_fechas    CHECK (fechaFin >= fechaInicio)
    );
END
GO

GO


-- ============================================================
-- TABLAS - Módulo Ventas
-- ============================================================

--               Tabla parques.Parque creada por modulo Parques
--               Tabla parques.Tour creada por modulo Guias, Tours y Atracciones
--               Tabla parques.Atraccion creada por modulo Guias, Tours y Atracciones

GO

GO

-- TABLA: TipoVisitante
-- Lookup de tipos de visitante
-- Ejemplos: Residente, Extranjero, Jubilado, Estudiante
CREATE TABLE parques.TipoVisitante (
    idTipoVisitante  INT          IDENTITY(1,1)  NOT NULL,
    descripcion      VARCHAR(100)                NOT NULL,
    CONSTRAINT PK_TipoVisitante             PRIMARY KEY (idTipoVisitante),
    CONSTRAINT UQ_TipoVisitante_descripcion UNIQUE      (descripcion)
);
GO

-- TABLA: PrecioEntrada
-- Catalogo historico de precios de entrada por parque y tipo de visitante
-- fechaHasta NULL indica precio vigente
CREATE TABLE parques.PrecioEntrada (
    idPrecio           INT           IDENTITY(1,1)  NOT NULL,
    fechaActualizacion DATE                         NOT NULL,
    valor              DECIMAL(18,2)                NOT NULL,
    idParque           INT                          NOT NULL,
    idTipoVisitante    INT                          NOT NULL,
    fechaHasta         DATE                         NULL,
    CONSTRAINT PK_PrecioEntrada               PRIMARY KEY (idPrecio),
    CONSTRAINT FK_PrecioEntrada_Parque        FOREIGN KEY (idParque)        REFERENCES parques.Parque(idParque),
    CONSTRAINT FK_PrecioEntrada_TipoVisitante FOREIGN KEY (idTipoVisitante) REFERENCES parques.TipoVisitante(idTipoVisitante),
    CONSTRAINT CHK_PrecioEntrada_valor        CHECK (valor >= 0)
);
GO

-- TABLA: TicketVenta
-- Cabecera del ticket de venta
CREATE TABLE parques.TicketVenta (
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

-- TABLA: LineaVenta
-- Detalle o renglon del ticket de venta
-- Puede representar una entrada, un tour o una atraccion
CREATE TABLE parques.LineaVenta (
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
    CONSTRAINT FK_LineaVenta_PrecioEntrada   FOREIGN KEY (idPrecioEntrada) REFERENCES parques.PrecioEntrada(idPrecio),
    CONSTRAINT FK_LineaVenta_TicketVenta     FOREIGN KEY (ticketAsociado) REFERENCES parques.TicketVenta(idTicket),
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

GO
