-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 27/06/2026
-- Descripcion: Entrega 5 (1/3) - Base de datos, esquemas, tablas y restricciones.
--   Contiene: CREATE DATABASE, CREATE SCHEMA y todas las tablas con sus
--   constraints (PK, FK, CHECK, UNIQUE).
--   Schemas: parques, personal, actividades, ventas, concesiones.
-- Orden de ejecucion: 1ro este script, luego ABM, luego Negocio.
-- =============================================

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Script unificado Entrega 5 - DB, schemas, tablas, ABM, negocio.
-- =============================================

-- ============================================================
-- 01 - BASE DE DATOS Y SCHEMAS
-- ============================================================

-- =============================================
-- Universidad: Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Comisión: 01-2900 | Grupo 03
-- Integrantes: Del Vecchio Fabrizio, Ocampos Horacio,
--              Ruiz Santillán Facundo, Lago Franco Nehuen
-- Fecha: 15/06/2026
-- Descripción: Creación de la base de datos y los esquemas
--              utilizados por los distintos módulos del sistema.
-- =============================================

-- ==================
-- BASE DE DATOS
-- ==================
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'ParquesNacionales')
BEGIN
    CREATE DATABASE ParquesNacionales
    COLLATE Modern_Spanish_CI_AI;
END
GO

USE ParquesNacionales;
GO

-- ==================
-- ESQUEMAS
-- ==================

-- parques: datos maestros de los parques (Parque, TipoParque, Ubicacion)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'parques')
    EXEC('CREATE SCHEMA parques');
GO

-- personal: guardaparques, guías y sus asignaciones
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'personal')
    EXEC('CREATE SCHEMA personal');
GO

-- actividades: tours y atracciones ofrecidas en cada parque
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'actividades')
    EXEC('CREATE SCHEMA actividades');
GO

-- ventas: tickets, líneas de venta, precios y tipos de visitante
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'ventas')
    EXEC('CREATE SCHEMA ventas');
GO

-- concesiones: empresas concesionarias, concesiones y pagos
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'concesiones')
    EXEC('CREATE SCHEMA concesiones');
GO
-- ============================================================
-- 02 - TABLAS: Parques y Guardaparques
-- ============================================================

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Creacion de tablas del modulo Base.
--              Tablas: TipoParque, Ubicacion, Parque (schema parques)
--                      Guardaparque, AsignacionGuardaparque (schema personal)
-- Dependencias: Schemas creados por 01_creacion_db_schemas.sql
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- TABLA: TipoParque
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'TipoParque' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.TipoParque (
        idTipoParque  INT           IDENTITY(1,1) NOT NULL,
        descripcion   VARCHAR(100)  NOT NULL,
        CONSTRAINT PK_TipoParque PRIMARY KEY (idTipoParque)
    );
END
GO

-- ============================================================
-- TABLA: Ubicacion
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Ubicacion' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.Ubicacion (
        idUbicacion  INT            IDENTITY(1,1) NOT NULL,
        direccion    VARCHAR(100)   NOT NULL,
        provincia    VARCHAR(50)    NOT NULL,
        latitud      DECIMAL(9,6)   NOT NULL,
        longitud     DECIMAL(9,6)   NOT NULL,
        CONSTRAINT PK_Ubicacion PRIMARY KEY (idUbicacion)
    );
END
GO

-- ============================================================
-- TABLA: Parque
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Parque' AND s.name = 'parques')
BEGIN
    CREATE TABLE parques.Parque (
        idParque       INT            IDENTITY(1,1) NOT NULL,
        nombre         VARCHAR(100)   NOT NULL,
        superficie     DECIMAL(18,2)  NOT NULL,
        idTipoParque   INT            NOT NULL,
        idUbicacion    INT            NOT NULL,
        CONSTRAINT PK_Parque PRIMARY KEY (idParque),
        CONSTRAINT FK_Parque_TipoParque FOREIGN KEY (idTipoParque) REFERENCES parques.TipoParque (idTipoParque),
        CONSTRAINT FK_Parque_Ubicacion  FOREIGN KEY (idUbicacion)  REFERENCES parques.Ubicacion  (idUbicacion)
    );
END
GO

-- ============================================================
-- TABLA: Guardaparque (schema personal)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Guardaparque' AND s.name = 'personal')
BEGIN
    CREATE TABLE personal.Guardaparque (
        dni              INT            NOT NULL,
        apyn             VARCHAR(50)    NOT NULL,
        email            VARCHAR(100)   NULL,
        telefono         VARCHAR(50)    NULL,
        localidad        VARCHAR(50)    NULL,
        fechaNacimiento  DATETIME       NULL,
        CONSTRAINT PK_Guardaparque PRIMARY KEY (dni)
    );
END
GO

-- ============================================================
-- TABLA: AsignacionGuardaparque (schema personal)
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'AsignacionGuardaparque' AND s.name = 'personal')
BEGIN
    CREATE TABLE personal.AsignacionGuardaparque (
        idAsignacion   INT            IDENTITY(1,1) NOT NULL,
        fechaInicio    DATE           NOT NULL,
        fechaFin       DATE           NULL,
        motivoEgreso   VARCHAR(255)   NULL,
        idParque       INT            NOT NULL,
        dni            INT            NOT NULL,
        CONSTRAINT PK_AsignacionGuardaparque PRIMARY KEY (idAsignacion),
        CONSTRAINT FK_AsignacionGuardaparque_Parque       FOREIGN KEY (idParque) REFERENCES parques.Parque          (idParque),
        CONSTRAINT FK_AsignacionGuardaparque_Guardaparque FOREIGN KEY (dni)      REFERENCES personal.Guardaparque   (dni)
    );
END
GO

-- ============================================================
-- 02 - TABLAS: Guias, Tours y Atracciones
-- ============================================================

-- =============================================
-- Universidad: Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Comisión: 01-2900 | Grupo 03
-- Integrantes: Del Vecchio Fabrizio, Ocampos Horacio,
--              Ruiz Santillán Facundo, Lago Franco Nehuen
-- Fecha: 15/06/2026
-- Descripción: Creación de tablas del módulo Guías, Tours y Atracciones
-- =============================================

USE ParquesNacionales;
GO

-- GUIA
IF NOT EXISTS (SELECT 1 FROM sys.tables t 
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Guia' AND s.name = 'personal')
BEGIN
    CREATE TABLE personal.Guia (
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
               WHERE t.name = 'Tour' AND s.name = 'actividades')
BEGIN
    CREATE TABLE actividades.Tour (
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
               WHERE t.name = 'Atraccion' AND s.name = 'actividades')
BEGIN
    CREATE TABLE actividades.Atraccion (
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
               WHERE t.name = 'AsignacionGuia' AND s.name = 'personal')
BEGIN
    CREATE TABLE personal.AsignacionGuia (
        idAsignacion    INT IDENTITY(1,1)   NOT NULL,
        idTour          INT                 NOT NULL,
        dniGuia         INT                 NOT NULL,
        fechaInicio     DATE                NOT NULL,
        fechaFin        DATE                NOT NULL,
        CONSTRAINT PK_AsignacionGuia         PRIMARY KEY (idAsignacion),
        CONSTRAINT FK_AsignacionGuia_Tour    FOREIGN KEY (idTour) REFERENCES actividades.Tour(idTour),
        CONSTRAINT FK_AsignacionGuia_dniGuia FOREIGN KEY (dniGuia) REFERENCES personal.Guia(dni),
        CONSTRAINT CHK_AsignacionGuia_fechas CHECK (fechaFin >= fechaInicio)
    );
END
GO
-- ============================================================
-- 02 - TABLAS: Concesiones
-- ============================================================

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Creacion de tablas del modulo Concesiones.
--              Tablas: TipoDeConsesion, Empresa, Concesion, PagoConcesion
-- Dependencias: Schemas creados por 01_creacion_db_schemas.sql
--               Tabla parques.Parque creada por modulo Parques
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- TABLA: TipoDeConsesion
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'TipoDeConsesion' AND s.name = 'concesiones')
BEGIN
    CREATE TABLE concesiones.TipoDeConsesion (
        idTipoConcesion  INT          IDENTITY(1,1)  NOT NULL,
        descripcion      VARCHAR(100)                NOT NULL,
        CONSTRAINT PK_TipoDeConsesion             PRIMARY KEY (idTipoConcesion),
        CONSTRAINT UQ_TipoDeConsesion_descripcion UNIQUE      (descripcion)
    );
END
GO

-- ============================================================
-- TABLA: Empresa
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Empresa' AND s.name = 'concesiones')
BEGIN
    CREATE TABLE concesiones.Empresa (
        idEmpresa    INT          IDENTITY(1,1)  NOT NULL,
        razonSocial  VARCHAR(200)                NOT NULL,
        cuit         VARCHAR(20)                 NOT NULL,
        contacto     VARCHAR(100)                NULL,
        email        VARCHAR(100)                NULL,
        telefono     VARCHAR(50)                 NULL,
        CONSTRAINT PK_Empresa      PRIMARY KEY (idEmpresa),
        CONSTRAINT UQ_Empresa_cuit UNIQUE      (cuit)
    );
END
GO

-- ============================================================
-- TABLA: Concesion
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'Concesion' AND s.name = 'concesiones')
BEGIN
    CREATE TABLE concesiones.Concesion (
        idConcesion      INT           IDENTITY(1,1)  NOT NULL,
        descripcion      VARCHAR(100)                 NOT NULL,
        idTipoConcesion  INT                          NOT NULL,
        idParque         INT                          NOT NULL,
        idEmpresa        INT                          NOT NULL,
        fechaInicio      DATE                         NOT NULL,
        fechaFin         DATE                         NOT NULL,
        canonMensual     DECIMAL(18,2)                NOT NULL,
        CONSTRAINT PK_Concesion                 PRIMARY KEY (idConcesion),
        CONSTRAINT FK_Concesion_TipoDeConsesion FOREIGN KEY (idTipoConcesion) REFERENCES concesiones.TipoDeConsesion(idTipoConcesion),
        CONSTRAINT FK_Concesion_Empresa         FOREIGN KEY (idEmpresa)       REFERENCES concesiones.Empresa(idEmpresa),
        CONSTRAINT FK_Concesion_Parque          FOREIGN KEY (idParque)        REFERENCES parques.Parque(idParque),
        CONSTRAINT CHK_Concesion_fechas         CHECK (fechaFin > fechaInicio),
        CONSTRAINT CHK_Concesion_canonMensual   CHECK (canonMensual > 0)
    );
END
GO

-- ============================================================
-- TABLA: PagoConcesion
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'PagoConcesion' AND s.name = 'concesiones')
BEGIN
    CREATE TABLE concesiones.PagoConcesion (
        idPagoConcesion  INT           IDENTITY(1,1)  NOT NULL,
        idConcesion      INT                          NOT NULL,
        monto            DECIMAL(18,2)                NOT NULL,
        fechaPago        DATE                         NOT NULL,
        periodoAnio      INT                          NOT NULL,
        periodoMes       INT                          NOT NULL,
        CONSTRAINT PK_PagoConcesion              PRIMARY KEY (idPagoConcesion),
        CONSTRAINT FK_PagoConcesion_Concesion    FOREIGN KEY (idConcesion) REFERENCES concesiones.Concesion(idConcesion),
        CONSTRAINT CHK_PagoConcesion_periodoMes  CHECK (periodoMes BETWEEN 1 AND 12),
        CONSTRAINT CHK_PagoConcesion_periodoAnio CHECK (periodoAnio >= 2020),
        CONSTRAINT CHK_PagoConcesion_monto       CHECK (monto > 0),
        CONSTRAINT UQ_PagoConcesion_periodo      UNIQUE (idConcesion, periodoAnio, periodoMes)
    );
END
GO

-- ============================================================
-- 02 - TABLAS: Ventas
-- ============================================================

-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Creacion de tablas del modulo Ventas y Precios.
--              Tablas: TipoVisitante, PrecioEntrada, TicketVenta, LineaVenta
-- Dependencias: Schemas creados por 01_creacion_db_schemas.sql
--               Tabla parques.Parque creada por modulo Parques
--               Tabla actividades.Tour creada por modulo Guias, Tours y Atracciones
--               Tabla actividades.Atraccion creada por modulo Guias, Tours y Atracciones
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- TABLA: TipoVisitante
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'TipoVisitante' AND s.name = 'ventas')
BEGIN
    CREATE TABLE ventas.TipoVisitante (
        idTipoVisitante  INT          IDENTITY(1,1)  NOT NULL,
        descripcion      VARCHAR(100)                NOT NULL,
        CONSTRAINT PK_TipoVisitante             PRIMARY KEY (idTipoVisitante),
        CONSTRAINT UQ_TipoVisitante_descripcion UNIQUE      (descripcion)
    );
END
GO

-- ============================================================
-- TABLA: PrecioEntrada
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'PrecioEntrada' AND s.name = 'ventas')
BEGIN
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
END
GO

-- ============================================================
-- TABLA: TicketVenta
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'TicketVenta' AND s.name = 'ventas')
BEGIN
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
END
GO

-- ============================================================
-- TABLA: LineaVenta
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE t.name = 'LineaVenta' AND s.name = 'ventas')
BEGIN
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
        CONSTRAINT FK_LineaVenta_TicketVenta     FOREIGN KEY (ticketAsociado)  REFERENCES ventas.TicketVenta(idTicket),
        CONSTRAINT FK_LineaVenta_Tour            FOREIGN KEY (idTour)          REFERENCES actividades.Tour(idTour),
        CONSTRAINT FK_LineaVenta_Atraccion       FOREIGN KEY (idAtraccion)     REFERENCES actividades.Atraccion(idAtraccion),
        CONSTRAINT CHK_LineaVenta_cantidad       CHECK (cantidad > 0),
        CONSTRAINT CHK_LineaVenta_precioUnitario CHECK (precioUnitario >= 0),
        CONSTRAINT CHK_LineaVenta_subtotal       CHECK (subtotal >= 0),
        CONSTRAINT CHK_LineaVenta_UnSoloItem CHECK (
            (CASE WHEN idPrecioEntrada IS NOT NULL THEN 1 ELSE 0 END +
             CASE WHEN idTour          IS NOT NULL THEN 1 ELSE 0 END +
             CASE WHEN idAtraccion     IS NOT NULL THEN 1 ELSE 0 END) = 1
        )
    );
END
GO
