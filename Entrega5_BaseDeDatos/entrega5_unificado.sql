-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Script unificado Entrega 5 - Sistema de Gestion de Parques Nacionales.
--              Contiene: creacion de tablas, SPs ABM, logica de negocio y testing.
--              Todos los objetos usan el schema parques.
-- =============================================

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


-- ============================================================
-- ABM - Parques y Guardaparques
-- ============================================================

--              SPs: TipoParque             (Insertar/Actualizar/Eliminar/ObtenerPorId)
--                   Ubicacion              (Insertar/Actualizar/Eliminar/ObtenerPorId)
--                   Parque                 (Insertar/Actualizar/Eliminar/ObtenerPorId)
--                   Guardaparque           (Insertar/Actualizar/Eliminar/ObtenerPorId)
--                   AsignacionGuardaparque (Insertar/Actualizar/Eliminar/ObtenerPorId)

GO

-- TIPO DE PARQUE - INSERTAR
CREATE OR ALTER PROCEDURE parques.sp_TipoParque_Insertar
    @descripcion VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion del tipo de parque es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.TipoParque
               WHERE descripcion = LTRIM(RTRIM(@descripcion)))
        SET @vErrores += '- Ya existe un tipo de parque con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.TipoParque (descripcion)
    VALUES (LTRIM(RTRIM(@descripcion)));

    PRINT 'Tipo de parque creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

-- TIPO DE PARQUE - ACTUALIZAR
CREATE OR ALTER PROCEDURE parques.sp_TipoParque_Actualizar
    @idTipoParque INT,
    @descripcion  VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.TipoParque
                   WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- No existe un tipo de parque con el ID indicado.' + CHAR(13);

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.TipoParque
               WHERE descripcion = LTRIM(RTRIM(@descripcion))
                 AND idTipoParque != @idTipoParque)
        SET @vErrores += '- Ya existe otro tipo de parque con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.TipoParque
    SET descripcion = LTRIM(RTRIM(@descripcion))
    WHERE idTipoParque = @idTipoParque;

    PRINT 'Tipo de parque actualizado.';
END
GO

-- TIPO DE PARQUE - ELIMINAR
CREATE OR ALTER PROCEDURE parques.sp_TipoParque_Eliminar
    @idTipoParque INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.TipoParque
                   WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- No existe un tipo de parque con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Parque
               WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- No se puede eliminar: existen parques asociados a este tipo.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.TipoParque WHERE idTipoParque = @idTipoParque;
    PRINT 'Tipo de parque eliminado.';
END
GO

-- TIPO DE PARQUE - OBTENER POR ID
CREATE OR ALTER PROCEDURE parques.sp_TipoParque_ObtenerPorId
    @idTipoParque INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT idTipoParque, descripcion
    FROM parques.TipoParque
    WHERE idTipoParque = @idTipoParque;
END
GO

-- UBICACION - INSERTAR
CREATE OR ALTER PROCEDURE parques.sp_Ubicacion_Insertar
    @direccion VARCHAR(100),
    @provincia VARCHAR(50),
    @latitud   DECIMAL(9,6),
    @longitud  DECIMAL(9,6)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @direccion IS NULL OR LTRIM(RTRIM(@direccion)) = ''
        SET @vErrores += '- La direccion es obligatoria.' + CHAR(13);

    IF @provincia IS NULL OR LTRIM(RTRIM(@provincia)) = ''
        SET @vErrores += '- La provincia es obligatoria.' + CHAR(13);

    IF @latitud IS NULL OR @latitud NOT BETWEEN -90 AND 90
        SET @vErrores += '- La latitud debe estar entre -90 y 90.' + CHAR(13);

    IF @longitud IS NULL OR @longitud NOT BETWEEN -180 AND 180
        SET @vErrores += '- La longitud debe estar entre -180 y 180.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Ubicacion (direccion, provincia, latitud, longitud)
    VALUES (LTRIM(RTRIM(@direccion)), LTRIM(RTRIM(@provincia)), @latitud, @longitud);

    PRINT 'Ubicacion creada con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

-- UBICACION - ACTUALIZAR
CREATE OR ALTER PROCEDURE parques.sp_Ubicacion_Actualizar
    @idUbicacion INT,
    @direccion   VARCHAR(100),
    @provincia   VARCHAR(50),
    @latitud     DECIMAL(9,6),
    @longitud    DECIMAL(9,6)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion
                   WHERE idUbicacion = @idUbicacion)
        SET @vErrores += '- No existe una ubicacion con el ID indicado.' + CHAR(13);

    IF @direccion IS NULL OR LTRIM(RTRIM(@direccion)) = ''
        SET @vErrores += '- La direccion es obligatoria.' + CHAR(13);

    IF @provincia IS NULL OR LTRIM(RTRIM(@provincia)) = ''
        SET @vErrores += '- La provincia es obligatoria.' + CHAR(13);

    IF @latitud IS NULL OR @latitud NOT BETWEEN -90 AND 90
        SET @vErrores += '- La latitud debe estar entre -90 y 90.' + CHAR(13);

    IF @longitud IS NULL OR @longitud NOT BETWEEN -180 AND 180
        SET @vErrores += '- La longitud debe estar entre -180 y 180.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Ubicacion
    SET direccion = LTRIM(RTRIM(@direccion)),
        provincia = LTRIM(RTRIM(@provincia)),
        latitud   = @latitud,
        longitud  = @longitud
    WHERE idUbicacion = @idUbicacion;

    PRINT 'Ubicacion actualizada.';
END
GO

-- UBICACION - ELIMINAR
CREATE OR ALTER PROCEDURE parques.sp_Ubicacion_Eliminar
    @idUbicacion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion
                   WHERE idUbicacion = @idUbicacion)
        SET @vErrores += '- No existe una ubicacion con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Parque
               WHERE idUbicacion = @idUbicacion)
        SET @vErrores += '- No se puede eliminar: existen parques asociados a esta ubicacion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Ubicacion WHERE idUbicacion = @idUbicacion;
    PRINT 'Ubicacion eliminada.';
END
GO

-- UBICACION - OBTENER POR ID
CREATE OR ALTER PROCEDURE parques.sp_Ubicacion_ObtenerPorId
    @idUbicacion INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT idUbicacion, direccion, provincia, latitud, longitud
    FROM parques.Ubicacion
    WHERE idUbicacion = @idUbicacion;
END
GO

-- PARQUE - INSERTAR
CREATE OR ALTER PROCEDURE parques.sp_Parque_Insertar
    @nombre       VARCHAR(100),
    @superficie   DECIMAL(18,2),
    @idTipoParque INT,
    @idUbicacion  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores += '- El nombre del parque es obligatorio.' + CHAR(13);

    IF @superficie IS NULL OR @superficie <= 0
        SET @vErrores += '- La superficie debe ser mayor a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TipoParque
                   WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- El tipo de parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion
                   WHERE idUbicacion = @idUbicacion)
        SET @vErrores += '- La ubicacion indicada no existe.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Parque
               WHERE nombre = LTRIM(RTRIM(@nombre)))
        SET @vErrores += '- Ya existe un parque con ese nombre.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Parque (nombre, superficie, idTipoParque, idUbicacion)
    VALUES (LTRIM(RTRIM(@nombre)), @superficie, @idTipoParque, @idUbicacion);

    PRINT 'Parque registrado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

-- PARQUE - ACTUALIZAR
CREATE OR ALTER PROCEDURE parques.sp_Parque_Actualizar
    @idParque     INT,
    @nombre       VARCHAR(100),
    @superficie   DECIMAL(18,2),
    @idTipoParque INT,
    @idUbicacion  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- No existe un parque con el ID indicado.' + CHAR(13);

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores += '- El nombre del parque es obligatorio.' + CHAR(13);

    IF @superficie IS NULL OR @superficie <= 0
        SET @vErrores += '- La superficie debe ser mayor a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TipoParque
                   WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- El tipo de parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion
                   WHERE idUbicacion = @idUbicacion)
        SET @vErrores += '- La ubicacion indicada no existe.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Parque
               WHERE nombre = LTRIM(RTRIM(@nombre))
                 AND idParque != @idParque)
        SET @vErrores += '- Ya existe otro parque con ese nombre.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Parque
    SET nombre       = LTRIM(RTRIM(@nombre)),
        superficie   = @superficie,
        idTipoParque = @idTipoParque,
        idUbicacion  = @idUbicacion
    WHERE idParque = @idParque;

    PRINT 'Parque actualizado.';
END
GO

-- PARQUE - ELIMINAR
-- Un parque es referenciado desde varios modulos. NO puede eliminarse si tiene:
--   parques.Tour, parques.Atraccion, parques.AsignacionGuardaparque
--   parques.PrecioEntrada, parques.TicketVenta  (esquema ventas, modulo en construccion)
--   parques.Concesion
    
CREATE OR ALTER PROCEDURE parques.sp_Parque_Eliminar
    @idParque INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- No existe un parque con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Tour
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene tours registrados.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Atraccion
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene atracciones registradas.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.AsignacionGuardaparque
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene asignaciones de guardaparques.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.PrecioEntrada
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene precios de entrada registrados.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.TicketVenta
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene ventas registradas.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Concesion
               WHERE idParque = @idParque)
        SET @vErrores += '- No se puede eliminar: el parque tiene concesiones registradas.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Parque WHERE idParque = @idParque;
    PRINT 'Parque eliminado.';
END
GO

-- PARQUE - OBTENER POR ID
CREATE OR ALTER PROCEDURE parques.sp_Parque_ObtenerPorId
    @idParque INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT idParque, nombre, superficie, idTipoParque, idUbicacion
    FROM parques.Parque
    WHERE idParque = @idParque;
END
GO

-- GUARDAPARQUE - INSERTAR
CREATE OR ALTER PROCEDURE parques.sp_Guardaparque_Insertar
    @dni             INT,
    @apyn            VARCHAR(50),
    @email           VARCHAR(100) = NULL,
    @telefono        VARCHAR(50)  = NULL,
    @localidad       VARCHAR(50)  = NULL,
    @fechaNacimiento DATETIME     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @dni IS NULL OR @dni <= 0
        SET @vErrores += '- El DNI es obligatorio y debe ser mayor a 0.' + CHAR(13);
    ELSE IF EXISTS (SELECT 1 FROM parques.Guardaparque
                    WHERE dni = @dni)
        SET @vErrores += '- Ya existe un guardaparque registrado con ese DNI.' + CHAR(13);

    IF @apyn IS NULL OR LTRIM(RTRIM(@apyn)) = ''
        SET @vErrores += '- El apellido y nombre es obligatorio.' + CHAR(13);

    IF @email IS NOT NULL AND @email NOT LIKE '%@%.%'
        SET @vErrores += '- El formato del email no es valido.' + CHAR(13);

    IF @fechaNacimiento IS NOT NULL AND @fechaNacimiento > GETDATE()
        SET @vErrores += '- La fecha de nacimiento no puede ser futura.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Guardaparque (dni, apyn, email, telefono, localidad, fechaNacimiento)
    VALUES (@dni, LTRIM(RTRIM(@apyn)), @email, @telefono, @localidad, @fechaNacimiento);

    PRINT 'Guardaparque registrado con DNI: ' + CAST(@dni AS VARCHAR);
END
GO

-- GUARDAPARQUE - ACTUALIZAR
CREATE OR ALTER PROCEDURE parques.sp_Guardaparque_Actualizar
    @dni             INT,
    @apyn            VARCHAR(50),
    @email           VARCHAR(100) = NULL,
    @telefono        VARCHAR(50)  = NULL,
    @localidad       VARCHAR(50)  = NULL,
    @fechaNacimiento DATETIME     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Guardaparque
                   WHERE dni = @dni)
        SET @vErrores += '- No existe un guardaparque con el DNI indicado.' + CHAR(13);

    IF @apyn IS NULL OR LTRIM(RTRIM(@apyn)) = ''
        SET @vErrores += '- El apellido y nombre es obligatorio.' + CHAR(13);

    IF @email IS NOT NULL AND @email NOT LIKE '%@%.%'
        SET @vErrores += '- El formato del email no es valido.' + CHAR(13);

    IF @fechaNacimiento IS NOT NULL AND @fechaNacimiento > GETDATE()
        SET @vErrores += '- La fecha de nacimiento no puede ser futura.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Guardaparque
    SET apyn            = LTRIM(RTRIM(@apyn)),
        email           = @email,
        telefono        = @telefono,
        localidad       = @localidad,
        fechaNacimiento = @fechaNacimiento
    WHERE dni = @dni;

    PRINT 'Guardaparque actualizado.';
END
GO

-- GUARDAPARQUE - ELIMINAR
CREATE OR ALTER PROCEDURE parques.sp_Guardaparque_Eliminar
    @dni INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Guardaparque
                   WHERE dni = @dni)
        SET @vErrores += '- No existe un guardaparque con el DNI indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.AsignacionGuardaparque
               WHERE dni = @dni)
        SET @vErrores += '- No se puede eliminar: el guardaparque tiene asignaciones registradas.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Guardaparque WHERE dni = @dni;
    PRINT 'Guardaparque eliminado.';
END
GO

-- GUARDAPARQUE - OBTENER POR ID
CREATE OR ALTER PROCEDURE parques.sp_Guardaparque_ObtenerPorId
    @dni INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT dni, apyn, email, telefono, localidad, fechaNacimiento
    FROM parques.Guardaparque
    WHERE dni = @dni;
END
GO

-- ASIGNACION GUARDAPARQUE - INSERTAR
CREATE OR ALTER PROCEDURE parques.sp_AsignacionGuardaparque_Insertar
    @fechaInicio  DATE,
    @idParque     INT,
    @dni          INT,
    @fechaFin     DATE         = NULL,
    @motivoEgreso VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @fechaInicio IS NULL
        SET @vErrores += '- La fecha de inicio es obligatoria.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Guardaparque
                   WHERE dni = @dni)
        SET @vErrores += '- El guardaparque indicado no existe.' + CHAR(13);

    IF @fechaFin IS NOT NULL AND @fechaFin < @fechaInicio
        SET @vErrores += '- La fecha de fin no puede ser anterior a la fecha de inicio.' + CHAR(13);

    IF @fechaFin IS NOT NULL AND (@motivoEgreso IS NULL OR LTRIM(RTRIM(@motivoEgreso)) = '')
        SET @vErrores += '- Si se indica fecha de fin, el motivo de egreso es obligatorio.' + CHAR(13);

    IF @fechaFin IS NULL AND EXISTS (SELECT 1 FROM parques.AsignacionGuardaparque
                                     WHERE dni = @dni AND fechaFin IS NULL)
        SET @vErrores += '- El guardaparque ya tiene una asignacion activa (sin fecha de fin).' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.AsignacionGuardaparque
        (fechaInicio, fechaFin, motivoEgreso, idParque, dni)
    VALUES
        (@fechaInicio, @fechaFin, @motivoEgreso, @idParque, @dni);

    PRINT 'Asignacion registrada con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

-- ASIGNACION GUARDAPARQUE - ACTUALIZAR
CREATE OR ALTER PROCEDURE parques.sp_AsignacionGuardaparque_Actualizar
    @idAsignacion INT,
    @fechaInicio  DATE,
    @idParque     INT,
    @dni          INT,
    @fechaFin     DATE         = NULL,
    @motivoEgreso VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.AsignacionGuardaparque
                   WHERE idAsignacion = @idAsignacion)
        SET @vErrores += '- No existe una asignacion con el ID indicado.' + CHAR(13);

    IF @fechaInicio IS NULL
        SET @vErrores += '- La fecha de inicio es obligatoria.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Guardaparque
                   WHERE dni = @dni)
        SET @vErrores += '- El guardaparque indicado no existe.' + CHAR(13);

    IF @fechaFin IS NOT NULL AND @fechaFin < @fechaInicio
        SET @vErrores += '- La fecha de fin no puede ser anterior a la fecha de inicio.' + CHAR(13);

    IF @fechaFin IS NOT NULL AND (@motivoEgreso IS NULL OR LTRIM(RTRIM(@motivoEgreso)) = '')
        SET @vErrores += '- Si se indica fecha de fin, el motivo de egreso es obligatorio.' + CHAR(13);

    IF @fechaFin IS NULL AND EXISTS (SELECT 1 FROM parques.AsignacionGuardaparque
                                     WHERE dni = @dni
                                       AND fechaFin IS NULL
                                       AND idAsignacion != @idAsignacion)
        SET @vErrores += '- El guardaparque ya tiene otra asignacion activa (sin fecha de fin).' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.AsignacionGuardaparque
    SET fechaInicio  = @fechaInicio,
        fechaFin     = @fechaFin,
        motivoEgreso = @motivoEgreso,
        idParque     = @idParque,
        dni          = @dni
    WHERE idAsignacion = @idAsignacion;

    PRINT 'Asignacion actualizada.';
END
GO

-- ASIGNACION GUARDAPARQUE - ELIMINAR
CREATE OR ALTER PROCEDURE parques.sp_AsignacionGuardaparque_Eliminar
    @idAsignacion INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM parques.AsignacionGuardaparque
                   WHERE idAsignacion = @idAsignacion)
    BEGIN
        RAISERROR('- No existe una asignacion con el ID indicado.', 16, 1);
        RETURN;
    END

    DELETE FROM parques.AsignacionGuardaparque WHERE idAsignacion = @idAsignacion;
    PRINT 'Asignacion eliminada.';
END
GO

-- ASIGNACION GUARDAPARQUE - OBTENER POR ID
CREATE OR ALTER PROCEDURE parques.sp_AsignacionGuardaparque_ObtenerPorId
    @idAsignacion INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT idAsignacion, fechaInicio, fechaFin, motivoEgreso, idParque, dni
    FROM parques.AsignacionGuardaparque
    WHERE idAsignacion = @idAsignacion;
END
GO

GO


-- ============================================================
-- ABM - Concesiones
-- ============================================================

--              SPs: TipoDeConsesion (Insertar/Eliminar/Actualizar)
--                   Empresa         (Insertar/Eliminar/Actualizar)
--                   Concesion       (Insertar/Eliminar/Actualizar)
--                   PagoConcesion   (Insertar/Eliminar/Actualizar)
-- Notas: Ninguna operacion accede directamente a las tablas.
--        Cada SP reune todos los errores en un unico mensaje.

GO

-- TIPO DE CONCESION

CREATE OR ALTER PROCEDURE parques.sp_TipoConsesion_Insertar
    @descripcion VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion del tipo de concesion es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.TipoDeConsesion
               WHERE descripcion = LTRIM(RTRIM(@descripcion)))
        SET @vErrores += '- Ya existe un tipo de concesion con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.TipoDeConsesion (descripcion)
    VALUES (LTRIM(RTRIM(@descripcion)));

    PRINT 'Tipo de concesion creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE parques.sp_TipoConsesion_Eliminar
    @idTipoConcesion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.TipoDeConsesion
                   WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- No existe un tipo de concesion con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Concesion
               WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- No se puede eliminar: existen concesiones asociadas a este tipo.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.TipoDeConsesion WHERE idTipoConcesion = @idTipoConcesion;
    PRINT 'Tipo de concesion eliminado.';
END
GO

CREATE OR ALTER PROCEDURE parques.sp_TipoConsesion_Actualizar
    @idTipoConcesion INT,
    @descripcion     VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.TipoDeConsesion
                   WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- No existe un tipo de concesion con el ID indicado.' + CHAR(13);

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.TipoDeConsesion
               WHERE descripcion = LTRIM(RTRIM(@descripcion))
                 AND idTipoConcesion != @idTipoConcesion)
        SET @vErrores += '- Ya existe otro tipo de concesion con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.TipoDeConsesion
    SET descripcion = LTRIM(RTRIM(@descripcion))
    WHERE idTipoConcesion = @idTipoConcesion;

    PRINT 'Tipo de concesion actualizado.';
END
GO

-- EMPRESA

CREATE OR ALTER PROCEDURE parques.sp_Empresa_Insertar
    @razonSocial  VARCHAR(200),
    @cuit         VARCHAR(20),
    @contacto     VARCHAR(100) = NULL,
    @email        VARCHAR(100) = NULL,
    @telefono     VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @razonSocial IS NULL OR LTRIM(RTRIM(@razonSocial)) = ''
        SET @vErrores += '- La razon social es obligatoria.' + CHAR(13);

    IF @cuit IS NULL OR LTRIM(RTRIM(@cuit)) = ''
        SET @vErrores += '- El CUIT es obligatorio.' + CHAR(13);
    ELSE
    BEGIN
        IF LEN(LTRIM(RTRIM(@cuit))) != 11
            SET @vErrores += '- El CUIT debe tener exactamente 11 digitos.' + CHAR(13);

        IF EXISTS (SELECT 1 FROM parques.Empresa
                   WHERE cuit = LTRIM(RTRIM(@cuit)))
            SET @vErrores += '- Ya existe una empresa registrada con ese CUIT.' + CHAR(13);
    END

    IF @email IS NOT NULL AND @email NOT LIKE '%@%.%'
        SET @vErrores += '- El formato del email no es valido.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Empresa (razonSocial, cuit, contacto, email, telefono)
    VALUES (LTRIM(RTRIM(@razonSocial)), LTRIM(RTRIM(@cuit)), @contacto, @email, @telefono);

    PRINT 'Empresa registrada con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE parques.sp_Empresa_Eliminar
    @idEmpresa INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Empresa
                   WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- No existe una empresa con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.Concesion
               WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- No se puede eliminar la empresa: tiene concesiones registradas.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Empresa WHERE idEmpresa = @idEmpresa;
    PRINT 'Empresa eliminada.';
END
GO

CREATE OR ALTER PROCEDURE parques.sp_Empresa_Actualizar
    @idEmpresa    INT,
    @razonSocial  VARCHAR(200),
    @cuit         VARCHAR(20),
    @contacto     VARCHAR(100) = NULL,
    @email        VARCHAR(100) = NULL,
    @telefono     VARCHAR(50)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Empresa
                   WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- No existe una empresa con el ID indicado.' + CHAR(13);

    IF @razonSocial IS NULL OR LTRIM(RTRIM(@razonSocial)) = ''
        SET @vErrores += '- La razon social es obligatoria.' + CHAR(13);

    IF @cuit IS NULL OR LTRIM(RTRIM(@cuit)) = ''
        SET @vErrores += '- El CUIT es obligatorio.' + CHAR(13);
    ELSE
    BEGIN
        IF LEN(LTRIM(RTRIM(@cuit))) != 11
            SET @vErrores += '- El CUIT debe tener exactamente 11 digitos.' + CHAR(13);

        IF EXISTS (SELECT 1 FROM parques.Empresa
                   WHERE cuit = LTRIM(RTRIM(@cuit))
                     AND idEmpresa != @idEmpresa)
            SET @vErrores += '- Ya existe otra empresa registrada con ese CUIT.' + CHAR(13);
    END

    IF @email IS NOT NULL AND @email NOT LIKE '%@%.%'
        SET @vErrores += '- El formato del email no es valido.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Empresa
    SET razonSocial = LTRIM(RTRIM(@razonSocial)),
        cuit        = LTRIM(RTRIM(@cuit)),
        contacto    = @contacto,
        email       = @email,
        telefono    = @telefono
    WHERE idEmpresa = @idEmpresa;

    PRINT 'Empresa actualizada.';
END
GO

-- CONCESION

CREATE OR ALTER PROCEDURE parques.sp_Concesion_Insertar
    @descripcion     VARCHAR(100),
    @idTipoConcesion INT,
    @idParque        INT,
    @idEmpresa       INT,
    @fechaInicio     DATE,
    @fechaFin        DATE,
    @canonMensual    DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TipoDeConsesion
                   WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- El tipo de concesion indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Empresa
                   WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- La empresa indicada no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF @fechaFin <= @fechaInicio
        SET @vErrores += '- La fecha de fin debe ser posterior a la fecha de inicio.' + CHAR(13);

    IF @canonMensual <= 0
        SET @vErrores += '- El canon mensual debe ser mayor a cero.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Concesion
        (descripcion, idTipoConcesion, idParque, idEmpresa, fechaInicio, fechaFin, canonMensual)
    VALUES
        (@descripcion, @idTipoConcesion, @idParque, @idEmpresa, @fechaInicio, @fechaFin, @canonMensual);

    PRINT 'Concesion registrada con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE parques.sp_Concesion_Eliminar
    @idConcesion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Concesion
                   WHERE idConcesion = @idConcesion)
        SET @vErrores += '- No existe una concesion con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.PagoConcesion
               WHERE idConcesion = @idConcesion)
        SET @vErrores += '- No se puede eliminar la concesion: tiene pagos de canon registrados.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Concesion WHERE idConcesion = @idConcesion;
    PRINT 'Concesion eliminada.';
END
GO

CREATE OR ALTER PROCEDURE parques.sp_Concesion_Actualizar
    @idConcesion     INT,
    @descripcion     VARCHAR(100),
    @idTipoConcesion INT,
    @idParque        INT,
    @idEmpresa       INT,
    @fechaInicio     DATE,
    @fechaFin        DATE,
    @canonMensual    DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Concesion
                   WHERE idConcesion = @idConcesion)
        SET @vErrores += '- No existe una concesion con el ID indicado.' + CHAR(13);

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TipoDeConsesion
                   WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- El tipo de concesion indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Empresa
                   WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- La empresa indicada no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF @fechaFin <= @fechaInicio
        SET @vErrores += '- La fecha de fin debe ser posterior a la fecha de inicio.' + CHAR(13);

    IF @canonMensual <= 0
        SET @vErrores += '- El canon mensual debe ser mayor a cero.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Concesion
    SET descripcion     = @descripcion,
        idTipoConcesion = @idTipoConcesion,
        idParque        = @idParque,
        idEmpresa       = @idEmpresa,
        fechaInicio     = @fechaInicio,
        fechaFin        = @fechaFin,
        canonMensual    = @canonMensual
    WHERE idConcesion = @idConcesion;

    PRINT 'Concesion actualizada.';
END
GO

-- PAGO DE CONCESION

CREATE OR ALTER PROCEDURE parques.sp_PagoConcesion_Insertar
    @idConcesion INT,
    @monto       DECIMAL(18,2),
    @fechaPago   DATE,
    @periodoAnio INT,
    @periodoMes  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Concesion
                   WHERE idConcesion = @idConcesion)
        SET @vErrores += '- No existe una concesion con el ID indicado.' + CHAR(13);

    IF @monto <= 0
        SET @vErrores += '- El monto debe ser mayor a cero.' + CHAR(13);

    IF @periodoMes NOT BETWEEN 1 AND 12
        SET @vErrores += '- El mes del periodo debe estar entre 1 y 12.' + CHAR(13);

    IF @periodoAnio < 2020
        SET @vErrores += '- El anio del periodo no puede ser anterior a 2020.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.PagoConcesion
               WHERE idConcesion = @idConcesion
                 AND periodoAnio = @periodoAnio
                 AND periodoMes  = @periodoMes)
        SET @vErrores += '- Ya existe un pago registrado para esa concesion en el periodo indicado.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.PagoConcesion (idConcesion, monto, fechaPago, periodoAnio, periodoMes)
    VALUES (@idConcesion, @monto, @fechaPago, @periodoAnio, @periodoMes);

    PRINT 'Pago de canon registrado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE parques.sp_PagoConcesion_Eliminar
    @idPagoConcesion INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM parques.PagoConcesion
                   WHERE idPagoConcesion = @idPagoConcesion)
    BEGIN
        RAISERROR('- No existe un pago con el ID indicado.', 16, 1);
        RETURN;
    END

    DELETE FROM parques.PagoConcesion WHERE idPagoConcesion = @idPagoConcesion;
    PRINT 'Pago eliminado.';
END
GO

CREATE OR ALTER PROCEDURE parques.sp_PagoConcesion_Actualizar
    @idPagoConcesion INT,
    @monto           DECIMAL(18,2),
    @fechaPago       DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.PagoConcesion
                   WHERE idPagoConcesion = @idPagoConcesion)
        SET @vErrores += '- No existe un pago con el ID indicado.' + CHAR(13);

    IF @monto <= 0
        SET @vErrores += '- El monto debe ser mayor a cero.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.PagoConcesion
    SET monto     = @monto,
        fechaPago = @fechaPago
    WHERE idPagoConcesion = @idPagoConcesion;

    PRINT 'Pago actualizado.';
END
GO

GO


-- ============================================================
-- ABM - Guías, Tours y Atracciones
-- ============================================================


GO

-- GUIA - INSERTAR
CREATE OR ALTER PROCEDURE parques.sp_Guia_Insertar
    @dni                    INT,
    @apyn                   VARCHAR(100),
    @especialidad           VARCHAR(100) = NULL,
    @titulo                 VARCHAR(100) = NULL,
    @habilitaciones         VARCHAR(255) = NULL,
    @vigenciaAutorizacion   DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    -- Validaciones
    IF @dni IS NULL OR @dni <= 0
        SET @vErrores = @vErrores + '- El DNI es obligatorio y debe ser mayor a 0.' + CHAR(13);
    IF @apyn IS NULL OR LTRIM(RTRIM(@apyn)) = ''
        SET @vErrores = @vErrores + '- El nombre y apellido es obligatorio.' + CHAR(13);
    IF @vigenciaAutorizacion IS NULL
        SET @vErrores = @vErrores + '- La vigencia de autorización es obligatoria.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM parques.Guia WHERE dni = @dni)
        SET @vErrores = @vErrores + '- Ya existe un guía registrado con ese DNI.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Guia (dni, apyn, especialidad, titulo, habilitaciones, vigenciaAutorizacion)
    VALUES (@dni, @apyn, @especialidad, @titulo, @habilitaciones, @vigenciaAutorizacion);
END
GO

-- GUIA - ACTUALIZAR
CREATE OR ALTER PROCEDURE parques.sp_Guia_Actualizar
    @dni                    INT,
    @especialidad           VARCHAR(100) = NULL,
    @titulo                 VARCHAR(100) = NULL,
    @habilitaciones         VARCHAR(255) = NULL,
    @vigenciaAutorizacion   DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Guia WHERE dni = @dni)
        SET @vErrores = @vErrores + '- No existe un guía con ese DNI.' + CHAR(13);
    IF @vigenciaAutorizacion IS NULL
        SET @vErrores = @vErrores + '- La vigencia de autorización es obligatoria.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Guia
    SET especialidad = @especialidad,
        titulo = @titulo,
        habilitaciones = @habilitaciones,
        vigenciaAutorizacion = @vigenciaAutorizacion
    WHERE dni = @dni;
END
GO

-- GUIA - ELIMINAR
CREATE OR ALTER PROCEDURE parques.sp_Guia_Eliminar
    @dni INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Guia WHERE dni = @dni)
        SET @vErrores = @vErrores + '- No existe un guía con ese DNI.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM parques.AsignacionGuia WHERE dniGuia = @dni)
        SET @vErrores = @vErrores + '- El guía tiene tours asignados y no puede eliminarse.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Guia WHERE dni = @dni;
END
GO

-- GUIA - OBTENER POR ID
CREATE OR ALTER PROCEDURE parques.sp_Guia_ObtenerPorId
    @dni INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM parques.Guia WHERE dni = @dni;
END
GO

-- TOUR - INSERTAR
CREATE OR ALTER PROCEDURE parques.sp_Tour_Insertar
    @nombre      VARCHAR(100),
    @descripcion VARCHAR(255) = NULL,
    @duracion    INT,
    @cupoMaximo  INT,
    @precio      DECIMAL(18,2),
    @idParque    INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    -- Validaciones
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores = @vErrores + '- El nombre del tour es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores = @vErrores + '- La duración debe ser mayor a 0 minutos.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores = @vErrores + '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio IS NULL OR @precio < 0
        SET @vErrores = @vErrores + '- El precio no puede ser negativo.' + CHAR(13);
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores = @vErrores + '- El parque especificado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Tour (nombre, descripcion, duracion, cupoMaximo, precio, idParque)
    VALUES (@nombre, @descripcion, @duracion, @cupoMaximo, @precio, @idParque);
END;
GO

-- TOUR - ACTUALIZAR
CREATE OR ALTER PROCEDURE parques.sp_Tour_Actualizar
    @idTour      INT,
    @nombre      VARCHAR(100),
    @descripcion VARCHAR(255) = NULL,
    @duracion    INT,
    @cupoMaximo  INT,
    @precio      DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Tour WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- No existe un tour con el ID especificado.' + CHAR(13);
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores = @vErrores + '- El nombre del tour es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores = @vErrores + '- La duración debe ser mayor a 0 minutos.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores = @vErrores + '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio IS NULL OR @precio < 0
        SET @vErrores = @vErrores + '- El precio no puede ser negativo.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Tour
    SET nombre = @nombre,
        descripcion = @descripcion,
        duracion = @duracion,
        cupoMaximo = @cupoMaximo,
        precio = @precio
    WHERE idTour = @idTour;
END;
GO

-- TOUR - ELIMINAR
CREATE OR ALTER PROCEDURE parques.sp_Tour_Eliminar
    @idTour INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Tour WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- No existe el tour con el ID especificado.' + CHAR(13);
    
    -- Validar integridad si ya se vendió (Línea Venta) o si tiene guías asignados
    IF EXISTS (SELECT 1 FROM parques.AsignacionGuia WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- El tour tiene un historial de guías asignados y no puede eliminarse.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM parques.LineaVenta WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- El tour posee registros de ventas asociadas y no puede eliminarse.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Tour WHERE idTour = @idTour;
END;
GO

-- TOUR - OBTENER POR ID
CREATE OR ALTER PROCEDURE parques.sp_Tour_ObtenerPorId
    @idTour INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM parques.Tour WHERE idTour = @idTour;
END;
GO

-- ATRACCION - INSERTAR
CREATE OR ALTER PROCEDURE parques.sp_Atraccion_Insertar
    @nombre      VARCHAR(100),
    @descripcion VARCHAR(255) = NULL,
    @tipo        VARCHAR(50) = NULL,
    @precio      DECIMAL(18,2),
    @duracion    INT,
    @cupoMaximo  INT,
    @idParque    INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores = @vErrores + '- El nombre de la atracción es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores = @vErrores + '- La duración debe ser mayor a 0 minutos.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores = @vErrores + '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio IS NULL OR @precio < 0
        SET @vErrores = @vErrores + '- El precio no puede ser negativo.' + CHAR(13);
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores = @vErrores + '- El parque especificado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.Atraccion (nombre, descripcion, tipo, precio, duracion, cupoMaximo, idParque)
    VALUES (@nombre, @descripcion, @tipo, @precio, @duracion, @cupoMaximo, @idParque);
END;
GO

-- ATRACCION - ACTUALIZAR
CREATE OR ALTER PROCEDURE parques.sp_Atraccion_Actualizar
    @idAtraccion INT,
    @nombre      VARCHAR(100),
    @descripcion VARCHAR(255) = NULL,
    @tipo        VARCHAR(50) = NULL,
    @precio      DECIMAL(18,2),
    @duracion    INT,
    @cupoMaximo  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Atraccion WHERE idAtraccion = @idAtraccion)
        SET @vErrores = @vErrores + '- No existe la atracción con el ID especificado.' + CHAR(13);
    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores = @vErrores + '- El nombre es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores = @vErrores + '- La duración debe ser mayor a 0.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores = @vErrores + '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio IS NULL OR @precio < 0
        SET @vErrores = @vErrores + '- El precio no puede ser negativo.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.Atraccion
    SET nombre = @nombre,
        descripcion = @descripcion,
        tipo = @tipo,
        precio = @precio,
        duracion = @duracion,
        cupoMaximo = @cupoMaximo
    WHERE idAtraccion = @idAtraccion;
END;
GO

-- ATRACCION - ELIMINAR
CREATE OR ALTER PROCEDURE parques.sp_Atraccion_Eliminar
    @idAtraccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.Atraccion WHERE idAtraccion = @idAtraccion)
        SET @vErrores = @vErrores + '- No existe la atracción con el ID especificado.' + CHAR(13);
    IF EXISTS (SELECT 1 FROM parques.LineaVenta WHERE idAtraccion = @idAtraccion)
        SET @vErrores = @vErrores + '- La atracción posee registros de ventas asociadas y no puede eliminarse.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.Atraccion WHERE idAtraccion = @idAtraccion;
END;
GO

-- ATRACCION - OBTENER POR ID
CREATE OR ALTER PROCEDURE parques.sp_Atraccion_ObtenerPorId
    @idAtraccion INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM parques.Atraccion WHERE idAtraccion = @idAtraccion;
END;
GO

-- ASIGNACION GUIA - INSERTAR (NEGOCIO)
CREATE OR ALTER PROCEDURE parques.sp_AsignacionGuia_Insertar
    @idTour      INT,
    @dniGuia     INT,
    @fechaInicio DATE,
    @fechaFin    DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(600) = '';
    DECLARE @vVigenciaAutorizacion DATE;

    -- 1. Validaciones básicas de existencia y coherencia de fechas
    IF NOT EXISTS (SELECT 1 FROM parques.Tour WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- El Tour especificado no existe.' + CHAR(13);
    
    SELECT @vVigenciaAutorizacion = vigenciaAutorizacion FROM parques.Guia WHERE dni = @dniGuia;
    IF @vVigenciaAutorizacion IS NULL
        SET @vErrores = @vErrores + '- El Guía especificado no existe.' + CHAR(13);
        
    IF @fechaInicio IS NULL OR @fechaFin IS NULL
        SET @vErrores = @vErrores + '- Las fechas de inicio y fin son obligatorias.' + CHAR(13);
    IF @fechaInicio > @fechaFin
        SET @vErrores = @vErrores + '- La fecha de inicio no puede ser posterior a la fecha de fin.' + CHAR(13);

    -- Si las validaciones básicas fallan, frena acá para evitar errores lógicos más adelante
    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    -- 2. Regla de Negocio: Validar vigencia de autorización del guía
    -- La habilitación debe cubrir todo el rango del tour (hasta la fecha fin)
    IF @vVigenciaAutorizacion < @fechaFin
        SET @vErrores = @vErrores + '- La autorización del guía vence antes de la fecha de finalización del tour.' + CHAR(13);

    -- 3. Regla de Negocio: Validar superposición de fechas (Overlap)
    -- Hay superposición si: (InicioNuevo <= FinExistente) AND (FinNuevo >= InicioExistente)
    IF EXISTS (
        SELECT 1 FROM parques.AsignacionGuia
        WHERE dniGuia = @dniGuia
          AND @fechaInicio <= fechaFin
          AND @fechaFin >= fechaInicio
    )
    BEGIN
        SET @vErrores = @vErrores + '- El guía ya cuenta con un tour asignado en el rango de fechas solicitado.' + CHAR(13);
    END

    -- Despacho final de errores acumulados de negocio
    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    -- Si pasó todo perfectamente, inserta
    INSERT INTO parques.AsignacionGuia (idTour, dniGuia, fechaInicio, fechaFin)
    VALUES (@idTour, @dniGuia, @fechaInicio, @fechaFin);
END;
GO

-- ASIGNACION GUIA - ELIMINAR
CREATE OR ALTER PROCEDURE parques.sp_AsignacionGuia_Eliminar
    @idAsignacion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM parques.AsignacionGuia WHERE idAsignacion = @idAsignacion)
    BEGIN
        RAISERROR('- No existe la asignación especificada.', 16, 1);
        RETURN;
    END

    DELETE FROM parques.AsignacionGuia WHERE idAsignacion = @idAsignacion;
END;
GO

-- ASIGNACION GUIA - OBTENER POR ID
CREATE OR ALTER PROCEDURE parques.sp_AsignacionGuia_ObtenerPorId
    @idAsignacion INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM parques.AsignacionGuia WHERE idAsignacion = @idAsignacion;
END;
GO

GO


-- ============================================================
-- ABM - Ventas
-- ============================================================

--              SPs: TipoVisitante (Insertar/Eliminar/Actualizar)
--                   PrecioEntrada (Insertar/Eliminar/Actualizar)
--                   TicketVenta   (Insertar/Eliminar/Actualizar)
--                   LineaVenta    (Insertar/Eliminar/Actualizar)

GO

-- TIPO VISITANTE

CREATE OR ALTER PROCEDURE parques.sp_TipoVisitante_Insertar
    @descripcion VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion del tipo de visitante es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.TipoVisitante
               WHERE descripcion = LTRIM(RTRIM(@descripcion)))
        SET @vErrores += '- Ya existe un tipo de visitante con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.TipoVisitante (descripcion)
    VALUES (LTRIM(RTRIM(@descripcion)));

    PRINT 'Tipo de visitante creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE parques.sp_TipoVisitante_Eliminar
    @idTipoVisitante INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.TipoVisitante
                   WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- No existe un tipo de visitante con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.PrecioEntrada
               WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- No se puede eliminar: existen precios asociados a este tipo de visitante.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.TipoVisitante
    WHERE idTipoVisitante = @idTipoVisitante;

    PRINT 'Tipo de visitante eliminado.';
END
GO

CREATE OR ALTER PROCEDURE parques.sp_TipoVisitante_Actualizar
    @idTipoVisitante INT,
    @descripcion     VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.TipoVisitante
                   WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- No existe un tipo de visitante con el ID indicado.' + CHAR(13);

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.TipoVisitante
               WHERE descripcion = LTRIM(RTRIM(@descripcion))
                 AND idTipoVisitante != @idTipoVisitante)
        SET @vErrores += '- Ya existe otro tipo de visitante con esa descripcion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.TipoVisitante
    SET descripcion = LTRIM(RTRIM(@descripcion))
    WHERE idTipoVisitante = @idTipoVisitante;

    PRINT 'Tipo de visitante actualizado.';
END
GO

-- PRECIO ENTRADA

CREATE OR ALTER PROCEDURE parques.sp_PrecioEntrada_Insertar
    @fechaActualizacion DATE,
    @valor              DECIMAL(18,2),
    @idParque           INT,
    @idTipoVisitante    INT,
    @fechaHasta         DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @fechaActualizacion IS NULL
        SET @vErrores += '- La fecha de actualizacion es obligatoria.' + CHAR(13);

    IF @valor IS NULL OR @valor < 0
        SET @vErrores += '- El valor debe ser mayor o igual a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TipoVisitante
                   WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- El tipo de visitante indicado no existe.' + CHAR(13);

    IF @fechaHasta IS NOT NULL AND @fechaHasta < @fechaActualizacion
        SET @vErrores += '- La fecha hasta no puede ser anterior a la fecha de actualizacion.' + CHAR(13);

    IF EXISTS (
           SELECT 1
           FROM parques.PrecioEntrada
           WHERE idParque = @idParque
             AND idTipoVisitante = @idTipoVisitante
             AND fechaHasta IS NULL
       )
        SET @vErrores += '- Ya existe un precio vigente para ese parque y tipo de visitante.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.PrecioEntrada
        (fechaActualizacion, valor, idParque, idTipoVisitante, fechaHasta)
    VALUES
        (@fechaActualizacion, @valor, @idParque, @idTipoVisitante, NULL);

    PRINT 'Precio de entrada creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE parques.sp_PrecioEntrada_Eliminar
    @idPrecio INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.PrecioEntrada
                   WHERE idPrecio = @idPrecio)
        SET @vErrores += '- No existe un precio de entrada con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.LineaVenta
               WHERE idPrecioEntrada = @idPrecio)
        SET @vErrores += '- No se puede eliminar: existen lineas de venta asociadas a este precio.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.PrecioEntrada
    WHERE idPrecio = @idPrecio;

    PRINT 'Precio de entrada eliminado.';
END
GO

CREATE OR ALTER PROCEDURE parques.sp_PrecioEntrada_Actualizar
    @idPrecio           INT,
    @fechaActualizacion DATE,
    @valor              DECIMAL(18,2),
    @idParque           INT,
    @idTipoVisitante    INT,
    @fechaHasta         DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.PrecioEntrada
                   WHERE idPrecio = @idPrecio)
        SET @vErrores += '- No existe un precio de entrada con el ID indicado.' + CHAR(13);

    IF @fechaActualizacion IS NULL
        SET @vErrores += '- La fecha de actualizacion es obligatoria.' + CHAR(13);

    IF @valor IS NULL OR @valor < 0
        SET @vErrores += '- El valor debe ser mayor o igual a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque
                   WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TipoVisitante
                   WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- El tipo de visitante indicado no existe.' + CHAR(13);

    IF @fechaHasta IS NOT NULL AND @fechaHasta < @fechaActualizacion
        SET @vErrores += '- La fecha hasta no puede ser anterior a la fecha de actualizacion.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.PrecioEntrada
    SET fechaActualizacion = @fechaActualizacion,
        valor              = @valor,
        idParque           = @idParque,
        idTipoVisitante    = @idTipoVisitante,
        fechaHasta         = NULL
    WHERE idPrecio = @idPrecio;

    PRINT 'Precio de entrada actualizado.';
END
GO

-- TICKET VENTA

CREATE OR ALTER PROCEDURE parques.sp_TicketVenta_Insertar
    @fechaHora    DATETIME,
    @total        DECIMAL(18,2),
    @puntoDeVenta INT,
    @nroTicket    INT,
    @formaPago    VARCHAR(50),
    @idParque     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @fechaHora IS NULL
        SET @vErrores += '- La fecha y hora del ticket es obligatoria.' + CHAR(13);

    IF @total IS NULL OR @total < 0
        SET @vErrores += '- El total debe ser mayor o igual a cero.' + CHAR(13);

    IF @puntoDeVenta IS NULL
        SET @vErrores += '- El punto de venta es obligatorio.' + CHAR(13);

    IF @nroTicket IS NULL
        SET @vErrores += '- El numero de ticket es obligatorio.' + CHAR(13);

    IF @formaPago IS NULL OR LTRIM(RTRIM(@formaPago)) = ''
        SET @vErrores += '- La forma de pago es obligatoria.' + CHAR(13);

    IF @idParque IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM parques.Parque
                       WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.TicketVenta
        (fechaHora, total, puntoDeVenta, nroTicket, formaPago, idParque)
    VALUES
        (@fechaHora, @total, @puntoDeVenta, @nroTicket, LTRIM(RTRIM(@formaPago)), @idParque);

    PRINT 'Ticket de venta creado con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE parques.sp_TicketVenta_Eliminar
    @idTicket INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.TicketVenta
                   WHERE idTicket = @idTicket)
        SET @vErrores += '- No existe un ticket con el ID indicado.' + CHAR(13);

    IF EXISTS (SELECT 1 FROM parques.LineaVenta
               WHERE ticketAsociado = @idTicket)
        SET @vErrores += '- No se puede eliminar: existen lineas de venta asociadas a este ticket.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    DELETE FROM parques.TicketVenta
    WHERE idTicket = @idTicket;

    PRINT 'Ticket de venta eliminado.';
END
GO

CREATE OR ALTER PROCEDURE parques.sp_TicketVenta_Actualizar
    @idTicket     INT,
    @fechaHora    DATETIME,
    @total        DECIMAL(18,2),
    @puntoDeVenta INT,
    @nroTicket    INT,
    @formaPago    VARCHAR(50),
    @idParque     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.TicketVenta
                   WHERE idTicket = @idTicket)
        SET @vErrores += '- No existe un ticket con el ID indicado.' + CHAR(13);

    IF @fechaHora IS NULL
        SET @vErrores += '- La fecha y hora del ticket es obligatoria.' + CHAR(13);

    IF @total IS NULL OR @total < 0
        SET @vErrores += '- El total debe ser mayor o igual a cero.' + CHAR(13);

    IF @puntoDeVenta IS NULL
        SET @vErrores += '- El punto de venta es obligatorio.' + CHAR(13);

    IF @nroTicket IS NULL
        SET @vErrores += '- El numero de ticket es obligatorio.' + CHAR(13);

    IF @formaPago IS NULL OR LTRIM(RTRIM(@formaPago)) = ''
        SET @vErrores += '- La forma de pago es obligatoria.' + CHAR(13);

    IF @idParque IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM parques.Parque
                       WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.TicketVenta
    SET fechaHora    = @fechaHora,
        total        = @total,
        puntoDeVenta = @puntoDeVenta,
        nroTicket    = @nroTicket,
        formaPago    = LTRIM(RTRIM(@formaPago)),
        idParque     = @idParque
    WHERE idTicket = @idTicket;

    PRINT 'Ticket de venta actualizado.';
END
GO

-- LINEA VENTA

CREATE OR ALTER PROCEDURE parques.sp_LineaVenta_Insertar
    @idPrecioEntrada INT = NULL,
    @descripcion     VARCHAR(50),
    @subtotal        DECIMAL(18,2),
    @cantidad        INT,
    @precioUnitario  DECIMAL(18,2),
    @ticketAsociado  INT,
    @idTour          INT = NULL,
    @idAtraccion     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF @subtotal IS NULL OR @subtotal < 0
        SET @vErrores += '- El subtotal debe ser mayor o igual a cero.' + CHAR(13);

    IF @cantidad IS NULL OR @cantidad <= 0
        SET @vErrores += '- La cantidad debe ser mayor a cero.' + CHAR(13);

    IF @precioUnitario IS NULL OR @precioUnitario < 0
        SET @vErrores += '- El precio unitario debe ser mayor o igual a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TicketVenta
                   WHERE idTicket = @ticketAsociado)
        SET @vErrores += '- El ticket asociado no existe.' + CHAR(13);

    IF (
        CASE WHEN @idPrecioEntrada IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN @idTour IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN @idAtraccion IS NOT NULL THEN 1 ELSE 0 END
        ) <> 1
    SET @vErrores += '- La linea de venta debe tener exactamente un item asociado: PrecioEntrada, Tour o Atraccion.' + CHAR(13);

    IF @idPrecioEntrada IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM parques.PrecioEntrada
                       WHERE idPrecio = @idPrecioEntrada)
        SET @vErrores += '- El precio de entrada indicado no existe.' + CHAR(13);

    IF @idTour IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM parques.Tour
                       WHERE idTour = @idTour)
        SET @vErrores += '- El tour indicado no existe.' + CHAR(13);

    IF @idAtraccion IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM parques.Atraccion
                       WHERE idAtraccion = @idAtraccion)
        SET @vErrores += '- La atraccion indicada no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    INSERT INTO parques.LineaVenta
        (idPrecioEntrada, descripcion, subtotal, cantidad, precioUnitario,
         ticketAsociado, idTour, idAtraccion)
    VALUES
        (@idPrecioEntrada, LTRIM(RTRIM(@descripcion)), @subtotal, @cantidad,
         @precioUnitario, @ticketAsociado, @idTour, @idAtraccion);

    PRINT 'Linea de venta creada con ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
END
GO

CREATE OR ALTER PROCEDURE parques.sp_LineaVenta_Eliminar
    @idLineaVenta INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM parques.LineaVenta
                   WHERE idLineaVenta = @idLineaVenta)
    BEGIN
        RAISERROR('- No existe una linea de venta con el ID indicado.', 16, 1);
        RETURN;
    END

    DELETE FROM parques.LineaVenta
    WHERE idLineaVenta = @idLineaVenta;

    PRINT 'Linea de venta eliminada.';
END
GO

CREATE OR ALTER PROCEDURE parques.sp_LineaVenta_Actualizar
    @idLineaVenta    INT,
    @idPrecioEntrada INT = NULL,
    @descripcion     VARCHAR(50),
    @subtotal        DECIMAL(18,2),
    @cantidad        INT,
    @precioUnitario  DECIMAL(18,2),
    @ticketAsociado  INT,
    @idTour          INT = NULL,
    @idAtraccion     INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF NOT EXISTS (SELECT 1 FROM parques.LineaVenta
                   WHERE idLineaVenta = @idLineaVenta)
        SET @vErrores += '- No existe una linea de venta con el ID indicado.' + CHAR(13);

    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion es obligatoria.' + CHAR(13);

    IF @subtotal IS NULL OR @subtotal < 0
        SET @vErrores += '- El subtotal debe ser mayor o igual a cero.' + CHAR(13);

    IF @cantidad IS NULL OR @cantidad <= 0
        SET @vErrores += '- La cantidad debe ser mayor a cero.' + CHAR(13);

    IF @precioUnitario IS NULL OR @precioUnitario < 0
        SET @vErrores += '- El precio unitario debe ser mayor o igual a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TicketVenta
                   WHERE idTicket = @ticketAsociado)
        SET @vErrores += '- El ticket asociado no existe.' + CHAR(13);
    
    IF (
    CASE WHEN @idPrecioEntrada IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN @idTour IS NOT NULL THEN 1 ELSE 0 END +
    CASE WHEN @idAtraccion IS NOT NULL THEN 1 ELSE 0 END
        ) <> 1
    SET @vErrores += '- La linea de venta debe tener exactamente un item asociado: PrecioEntrada, Tour o Atraccion.' + CHAR(13);

    IF @idPrecioEntrada IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM parques.PrecioEntrada
                       WHERE idPrecio = @idPrecioEntrada)
        SET @vErrores += '- El precio de entrada indicado no existe.' + CHAR(13);

    IF @idTour IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM parques.Tour
                       WHERE idTour = @idTour)
        SET @vErrores += '- El tour indicado no existe.' + CHAR(13);

    IF @idAtraccion IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM parques.Atraccion
                       WHERE idAtraccion = @idAtraccion)
        SET @vErrores += '- La atraccion indicada no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    UPDATE parques.LineaVenta
    SET idPrecioEntrada = @idPrecioEntrada,
        descripcion     = LTRIM(RTRIM(@descripcion)),
        subtotal        = @subtotal,
        cantidad        = @cantidad,
        precioUnitario  = @precioUnitario,
        ticketAsociado  = @ticketAsociado,
        idTour          = @idTour,
        idAtraccion     = @idAtraccion
    WHERE idLineaVenta = @idLineaVenta;

    PRINT 'Linea de venta actualizada.';
END
GO

GO


-- ============================================================
-- NEGOCIO - Parques y Guardaparques
-- ============================================================

--              Operaciones que afectan varias tablas, encapsuladas en
--              transacciones que garantizan la integridad de los datos.
--              SPs: sp_RegistrarParque             (Ubicacion + Parque)
--                   sp_RegistrarGuardaparque       (Guardaparque + 1er Asignacion)
--                   sp_ReasignarGuardaparque       (cierra asignacion + abre nueva)
--                   sp_RegistrarEgresoGuardaparque (cierra asignacion vigente)

GO

-- REGISTRAR PARQUE
-- Da de alta la Ubicacion y el Parque en una sola transaccion,
-- evitando que quede un parque sin ubicacion o una ubicacion huerfana.
CREATE OR ALTER PROCEDURE parques.sp_RegistrarParque
    @nombre       VARCHAR(100),
    @superficie   DECIMAL(18,2),
    @idTipoParque INT,
    @direccion    VARCHAR(100),
    @provincia    VARCHAR(50),
    @latitud      DECIMAL(9,6),
    @longitud     DECIMAL(9,6)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @vErrores     NVARCHAR(MAX) = '';
    DECLARE @vIdUbicacion INT;
    DECLARE @vIdParque    INT;

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores += '- El nombre del parque es obligatorio.' + CHAR(13);
    ELSE IF EXISTS (SELECT 1 FROM parques.Parque WHERE nombre = LTRIM(RTRIM(@nombre)))
        SET @vErrores += '- Ya existe un parque con ese nombre.' + CHAR(13);

    IF @superficie IS NULL OR @superficie <= 0
        SET @vErrores += '- La superficie debe ser mayor a cero.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.TipoParque WHERE idTipoParque = @idTipoParque)
        SET @vErrores += '- El tipo de parque indicado no existe.' + CHAR(13);

    IF @direccion IS NULL OR LTRIM(RTRIM(@direccion)) = ''
        SET @vErrores += '- La direccion es obligatoria.' + CHAR(13);

    IF @provincia IS NULL OR LTRIM(RTRIM(@provincia)) = ''
        SET @vErrores += '- La provincia es obligatoria.' + CHAR(13);

    IF @latitud IS NULL OR @latitud NOT BETWEEN -90 AND 90
        SET @vErrores += '- La latitud debe estar entre -90 y 90.' + CHAR(13);

    IF @longitud IS NULL OR @longitud NOT BETWEEN -180 AND 180
        SET @vErrores += '- La longitud debe estar entre -180 y 180.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO parques.Ubicacion (direccion, provincia, latitud, longitud)
        VALUES (LTRIM(RTRIM(@direccion)), LTRIM(RTRIM(@provincia)), @latitud, @longitud);

        SET @vIdUbicacion = SCOPE_IDENTITY();

        INSERT INTO parques.Parque (nombre, superficie, idTipoParque, idUbicacion)
        VALUES (LTRIM(RTRIM(@nombre)), @superficie, @idTipoParque, @vIdUbicacion);

        SET @vIdParque = SCOPE_IDENTITY();

        COMMIT TRANSACTION;

        PRINT 'Parque registrado con ID: ' + CAST(@vIdParque AS VARCHAR)
            + ' (Ubicacion ID: ' + CAST(@vIdUbicacion AS VARCHAR) + ').';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- REGISTRAR GUARDAPARQUE
-- Alta completa: crea el Guardaparque y su primera asignacion
-- (parque + fecha de ingreso) en una transaccion, para que no
-- quede personal sin parque asignado.
CREATE OR ALTER PROCEDURE parques.sp_RegistrarGuardaparque
    @dni             INT,
    @apyn            VARCHAR(50),
    @idParque        INT,
    @fechaInicio     DATE,
    @email           VARCHAR(100) = NULL,
    @telefono        VARCHAR(50)  = NULL,
    @localidad       VARCHAR(50)  = NULL,
    @fechaNacimiento DATETIME     = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    IF @dni IS NULL OR @dni <= 0
        SET @vErrores += '- El DNI es obligatorio y debe ser mayor a 0.' + CHAR(13);
    ELSE IF EXISTS (SELECT 1 FROM parques.Guardaparque WHERE dni = @dni)
        SET @vErrores += '- Ya existe un guardaparque registrado con ese DNI.' + CHAR(13);

    IF @apyn IS NULL OR LTRIM(RTRIM(@apyn)) = ''
        SET @vErrores += '- El apellido y nombre es obligatorio.' + CHAR(13);

    IF @email IS NOT NULL AND @email NOT LIKE '%@%.%'
        SET @vErrores += '- El formato del email no es valido.' + CHAR(13);

    IF @fechaNacimiento IS NOT NULL AND @fechaNacimiento > GETDATE()
        SET @vErrores += '- La fecha de nacimiento no puede ser futura.' + CHAR(13);

    IF @fechaInicio IS NULL
        SET @vErrores += '- La fecha de ingreso es obligatoria.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO parques.Guardaparque (dni, apyn, email, telefono, localidad, fechaNacimiento)
        VALUES (@dni, LTRIM(RTRIM(@apyn)), @email, @telefono, @localidad, @fechaNacimiento);

        INSERT INTO parques.AsignacionGuardaparque (fechaInicio, fechaFin, motivoEgreso, idParque, dni)
        VALUES (@fechaInicio, NULL, NULL, @idParque, @dni);

        COMMIT TRANSACTION;

        PRINT 'Guardaparque ' + CAST(@dni AS VARCHAR)
            + ' registrado y asignado al parque ' + CAST(@idParque AS VARCHAR) + '.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- REASIGNAR GUARDAPARQUE
-- Cierra la asignacion vigente (le pone fechaFin y motivo) y abre
-- una nueva en el parque destino, en una sola transaccion. Asi el
-- guardaparque nunca queda sin asignacion ni con dos vigentes.
CREATE OR ALTER PROCEDURE parques.sp_ReasignarGuardaparque
    @dni               INT,
    @idParqueDestino   INT,
    @fechaReasignacion DATE,
    @motivoEgreso      VARCHAR(255) = 'Reasignacion'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @vErrores            NVARCHAR(MAX) = '';
    DECLARE @vIdAsignacionActual INT;
    DECLARE @vIdParqueActual     INT;
    DECLARE @vFechaInicioActual  DATE;

    -- Datos de la asignacion vigente (fechaFin NULL)
    SELECT @vIdAsignacionActual = idAsignacion,
           @vIdParqueActual     = idParque,
           @vFechaInicioActual  = fechaInicio
    FROM parques.AsignacionGuardaparque
    WHERE dni = @dni AND fechaFin IS NULL;

    IF NOT EXISTS (SELECT 1 FROM parques.Guardaparque WHERE dni = @dni)
        SET @vErrores += '- El guardaparque indicado no existe.' + CHAR(13);

    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParqueDestino)
        SET @vErrores += '- El parque destino indicado no existe.' + CHAR(13);

    IF @fechaReasignacion IS NULL
        SET @vErrores += '- La fecha de reasignacion es obligatoria.' + CHAR(13);

    IF @vIdAsignacionActual IS NULL
        SET @vErrores += '- El guardaparque no tiene una asignacion vigente para reasignar.' + CHAR(13);
    ELSE
    BEGIN
        IF @idParqueDestino = @vIdParqueActual
            SET @vErrores += '- El parque destino es el mismo que el parque actual.' + CHAR(13);

        IF @fechaReasignacion < @vFechaInicioActual
            SET @vErrores += '- La fecha de reasignacion no puede ser anterior al inicio de la asignacion vigente.' + CHAR(13);
    END

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- 1. Cierra la asignacion vigente (antes de abrir la nueva,
        --    para no violar el indice unico de asignacion activa).
        UPDATE parques.AsignacionGuardaparque
        SET fechaFin     = @fechaReasignacion,
            motivoEgreso = @motivoEgreso
        WHERE idAsignacion = @vIdAsignacionActual;

        -- 2. Abre la nueva asignacion en el parque destino.
        INSERT INTO parques.AsignacionGuardaparque (fechaInicio, fechaFin, motivoEgreso, idParque, dni)
        VALUES (@fechaReasignacion, NULL, NULL, @idParqueDestino, @dni);

        COMMIT TRANSACTION;

        PRINT 'Guardaparque ' + CAST(@dni AS VARCHAR) + ' reasignado del parque '
            + CAST(@vIdParqueActual AS VARCHAR) + ' al parque '
            + CAST(@idParqueDestino AS VARCHAR) + '.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- REGISTRAR EGRESO DE GUARDAPARQUE
-- Cierra la asignacion vigente con fecha y motivo de egreso,
-- sin abrir una nueva (baja definitiva del parque).
CREATE OR ALTER PROCEDURE parques.sp_RegistrarEgresoGuardaparque
    @dni          INT,
    @fechaEgreso  DATE,
    @motivoEgreso VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    DECLARE @vErrores            NVARCHAR(MAX) = '';
    DECLARE @vIdAsignacionActual INT;
    DECLARE @vFechaInicioActual  DATE;

    SELECT @vIdAsignacionActual = idAsignacion,
           @vFechaInicioActual  = fechaInicio
    FROM parques.AsignacionGuardaparque
    WHERE dni = @dni AND fechaFin IS NULL;

    IF NOT EXISTS (SELECT 1 FROM parques.Guardaparque WHERE dni = @dni)
        SET @vErrores += '- El guardaparque indicado no existe.' + CHAR(13);

    IF @fechaEgreso IS NULL
        SET @vErrores += '- La fecha de egreso es obligatoria.' + CHAR(13);

    IF @motivoEgreso IS NULL OR LTRIM(RTRIM(@motivoEgreso)) = ''
        SET @vErrores += '- El motivo de egreso es obligatorio.' + CHAR(13);

    IF @vIdAsignacionActual IS NULL
        SET @vErrores += '- El guardaparque no tiene una asignacion vigente (ya egreso o nunca fue asignado).' + CHAR(13);
    ELSE IF @fechaEgreso < @vFechaInicioActual
        SET @vErrores += '- La fecha de egreso no puede ser anterior al inicio de la asignacion vigente.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE parques.AsignacionGuardaparque
        SET fechaFin     = @fechaEgreso,
            motivoEgreso = LTRIM(RTRIM(@motivoEgreso))
        WHERE idAsignacion = @vIdAsignacionActual;

        COMMIT TRANSACTION;

        PRINT 'Egreso registrado para el guardaparque ' + CAST(@dni AS VARCHAR) + '.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

GO


-- ============================================================
-- NEGOCIO - Concesiones
-- ============================================================

--   SP 1: sp_AltaConcesionCompleta
--         Registra una nueva concesion validando integridad entre
--         empresa, parque, tipo y solapamiento de vigencias.
--   SP 2: sp_RegistrarPagoCanon
--         Registra el pago mensual del canon validando que la
--         concesion este vigente y que no exista pago duplicado
--         para el mismo periodo.

GO

-- SP: sp_AltaConcesionCompleta
-- Logica de negocio: alta de concesion con validaciones cruzadas
-- Validaciones:
--   1. Descripcion obligatoria
--   2. Empresa debe existir en el sistema
--   3. Parque debe existir en el sistema
--   4. Tipo de concesion debe existir
--   5. fechaFin debe ser posterior a fechaInicio
--   6. canonMensual debe ser mayor a cero
--   7. No puede existir otra concesion vigente para la misma
--      combinacion empresa + parque + tipo de actividad
CREATE OR ALTER PROCEDURE parques.sp_AltaConcesionCompleta
    @descripcion     VARCHAR(100),
    @idTipoConcesion INT,
    @idParque        INT,
    @idEmpresa       INT,
    @fechaInicio     DATE,
    @fechaFin        DATE,
    @canonMensual    DECIMAL(18,2)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores NVARCHAR(MAX) = '';

    -- Validacion 1: Descripcion obligatoria
    IF @descripcion IS NULL OR LTRIM(RTRIM(@descripcion)) = ''
        SET @vErrores += '- La descripcion de la concesion es obligatoria.' + CHAR(13);

    -- Validacion 2: Empresa existe
    IF NOT EXISTS (SELECT 1 FROM parques.Empresa WHERE idEmpresa = @idEmpresa)
        SET @vErrores += '- La empresa indicada no existe en el sistema.' + CHAR(13);

    -- Validacion 3: Parque existe
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe en el sistema.' + CHAR(13);

    -- Validacion 4: Tipo de concesion existe
    IF NOT EXISTS (SELECT 1 FROM parques.TipoDeConsesion WHERE idTipoConcesion = @idTipoConcesion)
        SET @vErrores += '- El tipo de concesion indicado no existe.' + CHAR(13);

    -- Validacion 5: Rango de fechas valido
    IF @fechaFin <= @fechaInicio
        SET @vErrores += '- La fecha de fin debe ser posterior a la fecha de inicio.' + CHAR(13);

    -- Validacion 6: Canon valido
    IF @canonMensual <= 0
        SET @vErrores += '- El canon mensual debe ser mayor a cero.' + CHAR(13);

    -- Validacion 7: Solapamiento de concesion vigente
    IF EXISTS (
        SELECT 1 FROM parques.Concesion
        WHERE idEmpresa       = @idEmpresa
          AND idParque        = @idParque
          AND idTipoConcesion = @idTipoConcesion
          AND fechaFin        >= CAST(GETDATE() AS DATE)
    )
        SET @vErrores += '- Ya existe una concesion vigente para esa empresa, parque y tipo de actividad. '
                       + 'Debe vencer la anterior antes de registrar una nueva.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO parques.Concesion
            (descripcion, idTipoConcesion, idParque, idEmpresa, fechaInicio, fechaFin, canonMensual)
        VALUES
            (LTRIM(RTRIM(@descripcion)), @idTipoConcesion, @idParque, @idEmpresa,
             @fechaInicio, @fechaFin, @canonMensual);

        DECLARE @vIdNuevo INT = SCOPE_IDENTITY();
        COMMIT TRANSACTION;

        PRINT 'Concesion registrada exitosamente con ID: ' + CAST(@vIdNuevo AS VARCHAR);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

-- SP: sp_RegistrarPagoCanon
-- Logica de negocio: pago mensual del canon de una concesion
-- Validaciones:
--   1. La concesion debe existir
--   2. La concesion no debe estar vencida (fechaFin >= hoy)
--   3. El periodo de pago debe estar dentro del rango de la concesion
--   4. No debe existir pago previo para el mismo periodo
--   5. El monto debe ser mayor a cero
--   6. El mes del periodo debe estar entre 1 y 12
--   7. El anio del periodo no puede ser anterior a 2020
CREATE OR ALTER PROCEDURE parques.sp_RegistrarPagoCanon
    @idConcesion INT,
    @monto       DECIMAL(18,2),
    @fechaPago   DATE,
    @periodoAnio INT,
    @periodoMes  INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores     NVARCHAR(MAX) = '';
    DECLARE @vFechaInicio DATE;
    DECLARE @vFechaFin    DATE;

    -- Obtener datos de la concesion
    SELECT @vFechaInicio = fechaInicio,
           @vFechaFin    = fechaFin
    FROM parques.Concesion
    WHERE idConcesion = @idConcesion;

    -- Validacion 1: La concesion existe
    IF @vFechaInicio IS NULL
    BEGIN
        RAISERROR('- No existe una concesion con el ID indicado.', 16, 1);
        RETURN;
    END

    -- Validacion 2: La concesion no esta vencida
    IF @vFechaFin < CAST(GETDATE() AS DATE)
        SET @vErrores += '- La concesion esta vencida (fecha de fin: '
                       + CONVERT(VARCHAR(10), @vFechaFin, 103)
                       + '). No se pueden registrar nuevos pagos.' + CHAR(13);

    -- Validacion 3: El periodo esta dentro del rango de la concesion
    IF @periodoMes BETWEEN 1 AND 12 AND @periodoAnio >= 2020
    BEGIN
        DECLARE @vFechaPeriodo DATE = DATEFROMPARTS(@periodoAnio, @periodoMes, 1);

        IF @vFechaPeriodo < DATEFROMPARTS(YEAR(@vFechaInicio), MONTH(@vFechaInicio), 1)
            SET @vErrores += '- El periodo indicado es anterior al inicio de la concesion ('
                           + CONVERT(VARCHAR(7), @vFechaInicio, 120) + ').' + CHAR(13);

        IF @vFechaPeriodo > DATEFROMPARTS(YEAR(@vFechaFin), MONTH(@vFechaFin), 1)
            SET @vErrores += '- El periodo indicado es posterior al vencimiento de la concesion ('
                           + CONVERT(VARCHAR(7), @vFechaFin, 120) + ').' + CHAR(13);
    END

    -- Validacion 4: Pago duplicado para el mismo periodo
    IF EXISTS (
        SELECT 1 FROM parques.PagoConcesion
        WHERE idConcesion = @idConcesion
          AND periodoAnio = @periodoAnio
          AND periodoMes  = @periodoMes
    )
        SET @vErrores += '- Ya existe un pago registrado para esta concesion en el periodo '
                       + CAST(@periodoMes AS VARCHAR) + '/' + CAST(@periodoAnio AS VARCHAR) + '.' + CHAR(13);

    -- Validacion 5: Monto valido
    IF @monto <= 0
        SET @vErrores += '- El monto debe ser mayor a cero.' + CHAR(13);

    -- Validacion 6: Mes valido
    IF @periodoMes NOT BETWEEN 1 AND 12
        SET @vErrores += '- El mes del periodo debe estar entre 1 y 12.' + CHAR(13);

    -- Validacion 7: Anio valido
    IF @periodoAnio < 2020
        SET @vErrores += '- El anio del periodo no puede ser anterior a 2020.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO parques.PagoConcesion
            (idConcesion, monto, fechaPago, periodoAnio, periodoMes)
        VALUES
            (@idConcesion, @monto, @fechaPago, @periodoAnio, @periodoMes);

        COMMIT TRANSACTION;
        PRINT 'Pago de canon registrado correctamente. ID: ' + CAST(SCOPE_IDENTITY() AS VARCHAR);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

GO


-- ============================================================
-- NEGOCIO - Guías, Tours y Atracciones
-- ============================================================


GO

-- SP NEGOCIO: Asignar guía a tour
-- Valida: vigencia, superposición de fechas
CREATE OR ALTER PROCEDURE parques.sp_AsignarGuiaATour
    @idTour      INT,
    @dniGuia     INT,
    @fechaInicio DATE,
    @fechaFin    DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';
    DECLARE @vVigencia DATE;

    -- Validar que el tour existe
    IF NOT EXISTS (SELECT 1 FROM parques.Tour WHERE idTour = @idTour)
        SET @vErrores = @vErrores + '- El tour especificado no existe.' + CHAR(13);

    -- Validar que el guía existe
    IF NOT EXISTS (SELECT 1 FROM parques.Guia WHERE dni = @dniGuia)
        SET @vErrores = @vErrores + '- El guía especificado no existe.' + CHAR(13);

    -- Validar fechas
    IF @fechaFin < @fechaInicio
        SET @vErrores = @vErrores + '- La fecha de fin no puede ser anterior a la fecha de inicio.' + CHAR(13);

    -- Validar vigencia de autorización del guía
    SELECT @vVigencia = vigenciaAutorizacion FROM parques.Guia WHERE dni = @dniGuia;
    IF @vVigencia < @fechaFin
        SET @vErrores = @vErrores + '- La autorización del guía vence antes de que finalice la asignación.' + CHAR(13);

    -- Validar superposición de fechas para ese guía
    IF EXISTS (
        SELECT 1 FROM parques.AsignacionGuia
        WHERE dniGuia = @dniGuia
          AND @fechaInicio <= fechaFin
          AND @fechaFin >= fechaInicio
    )
        SET @vErrores = @vErrores + '- El guía ya tiene una asignación en ese período de fechas.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO parques.AsignacionGuia (idTour, dniGuia, fechaInicio, fechaFin)
        VALUES (@idTour, @dniGuia, @fechaInicio, @fechaFin);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

-- SP NEGOCIO: Registrar atracción en un parque
CREATE OR ALTER PROCEDURE parques.sp_RegistrarAtraccion
    @nombre         VARCHAR(100),
    @descripcion    VARCHAR(255) = NULL,
    @tipo           VARCHAR(50)  = NULL,
    @precio         DECIMAL(18,2) = 0,
    @duracion       INT,
    @cupoMaximo     INT,
    @idParque       INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vErrores VARCHAR(500) = '';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = ''
        SET @vErrores = @vErrores + '- El nombre de la atracción es obligatorio.' + CHAR(13);
    IF @duracion IS NULL OR @duracion <= 0
        SET @vErrores = @vErrores + '- La duración debe ser mayor a 0 minutos.' + CHAR(13);
    IF @cupoMaximo IS NULL OR @cupoMaximo <= 0
        SET @vErrores = @vErrores + '- El cupo máximo debe ser mayor a 0.' + CHAR(13);
    IF @precio < 0
        SET @vErrores = @vErrores + '- El precio no puede ser negativo.' + CHAR(13);
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores = @vErrores + '- El parque especificado no existe.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO parques.Atraccion (nombre, descripcion, tipo, precio, duracion, cupoMaximo, idParque)
        VALUES (@nombre, @descripcion, @tipo, @precio, @duracion, @cupoMaximo, @idParque);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO

GO


-- ============================================================
-- NEGOCIO - Ventas
-- ============================================================

--   SP 1: sp_RegistrarVentaEntrada
--         Registra una venta de entrada validando parque, tipo de visitante,
--         precio existente, ticket y linea de venta. Si el ticket no existe,
--         lo crea. Si existe, agrega la linea y recalcula el total.
--   SP 2: sp_ActualizarPrecioEntrada
--         Actualiza el precio de entrada para un parque y tipo de visitante,
--         modificando el valor y la fecha de actualizacion.

GO

-- SP: sp_RegistrarVentaEntrada
-- Logica de negocio: venta completa de entrada
-- Validaciones:
--   1. Parque debe existir
--   2. Tipo de visitante debe existir
--   3. Debe existir precio de entrada para ese parque y tipo de visitante
--   4. Cantidad debe ser mayor a cero
--   5. Punto de venta obligatorio
--   6. Numero de ticket obligatorio
--   7. Forma de pago obligatoria
CREATE OR ALTER PROCEDURE parques.sp_RegistrarVentaEntrada
    @idParque        INT,
    @idTipoVisitante INT,
    @cantidad        INT,
    @puntoDeVenta    INT,
    @nroTicket       INT,
    @formaPago       VARCHAR(50),
    @fechaHora       DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores         NVARCHAR(MAX) = '';
    DECLARE @vIdTicket        INT;
    DECLARE @vIdPrecioEntrada INT;
    DECLARE @vPrecioUnitario  DECIMAL(18,2);
    DECLARE @vSubtotal        DECIMAL(18,2);
    DECLARE @vDescripcion     VARCHAR(50);

    IF @fechaHora IS NULL
        SET @fechaHora = GETDATE();

    -- Validacion 1: Parque existe
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    -- Validacion 2: Tipo de visitante existe
    IF NOT EXISTS (SELECT 1 FROM parques.TipoVisitante WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- El tipo de visitante indicado no existe.' + CHAR(13);

    -- Validacion 3: Cantidad valida
    IF @cantidad IS NULL OR @cantidad <= 0
        SET @vErrores += '- La cantidad debe ser mayor a cero.' + CHAR(13);

    -- Validacion 4: Punto de venta obligatorio
    IF @puntoDeVenta IS NULL
        SET @vErrores += '- El punto de venta es obligatorio.' + CHAR(13);

    -- Validacion 5: Numero de ticket obligatorio
    IF @nroTicket IS NULL
        SET @vErrores += '- El numero de ticket es obligatorio.' + CHAR(13);

    -- Validacion 6: Forma de pago obligatoria
    IF @formaPago IS NULL OR LTRIM(RTRIM(@formaPago)) = ''
        SET @vErrores += '- La forma de pago es obligatoria.' + CHAR(13);

    -- Obtener precio de entrada
    SELECT
        @vIdPrecioEntrada = idPrecio,
        @vPrecioUnitario  = valor
    FROM parques.PrecioEntrada
    WHERE idParque = @idParque
      AND idTipoVisitante = @idTipoVisitante;

    -- Validacion 7: Precio existente
    IF @vIdPrecioEntrada IS NULL
        SET @vErrores += '- No existe un precio de entrada para ese parque y tipo de visitante.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    SET @vSubtotal = @cantidad * @vPrecioUnitario;

    SELECT @vDescripcion = 'Entrada ' + descripcion
    FROM parques.TipoVisitante
    WHERE idTipoVisitante = @idTipoVisitante;

    BEGIN TRANSACTION;
    BEGIN TRY

        SELECT @vIdTicket = idTicket
        FROM parques.TicketVenta
        WHERE puntoDeVenta = @puntoDeVenta
          AND nroTicket = @nroTicket;

        IF @vIdTicket IS NULL
        BEGIN
            INSERT INTO parques.TicketVenta
                (fechaHora, total, puntoDeVenta, nroTicket, formaPago, idParque)
            VALUES
                (@fechaHora, 0, @puntoDeVenta, @nroTicket, LTRIM(RTRIM(@formaPago)), @idParque);

            SET @vIdTicket = SCOPE_IDENTITY();
        END

        INSERT INTO parques.LineaVenta
            (ticketAsociado, descripcion, subtotal, cantidad, precioUnitario,
             idPrecioEntrada, idTour, idAtraccion)
        VALUES
            (@vIdTicket, @vDescripcion, @vSubtotal, @cantidad, @vPrecioUnitario,
             @vIdPrecioEntrada, NULL, NULL);

        UPDATE parques.TicketVenta
        SET total = (
            SELECT SUM(subtotal)
            FROM parques.LineaVenta
            WHERE ticketAsociado = @vIdTicket
        )
        WHERE idTicket = @vIdTicket;

        COMMIT TRANSACTION;

        PRINT 'Venta de entrada registrada correctamente. Ticket ID: ' + CAST(@vIdTicket AS VARCHAR);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

-- SP: sp_ActualizarPrecioEntrada
-- Logica de negocio: actualizacion de precio de entrada
-- Validaciones:
--   1. Parque debe existir
--   2. Tipo de visitante debe existir
--   3. Debe existir precio para ese parque y tipo de visitante
--   4. Nuevo valor debe ser mayor o igual a cero
--   5. Fecha de actualizacion obligatoria
CREATE OR ALTER PROCEDURE parques.sp_ActualizarPrecioEntrada
    @idParque           INT,
    @idTipoVisitante    INT,
    @nuevoValor         DECIMAL(18,2),
    @fechaActualizacion DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @vErrores  NVARCHAR(MAX) = '';
    DECLARE @vIdPrecio INT;

    -- Validacion 1: Parque existe
    IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE idParque = @idParque)
        SET @vErrores += '- El parque indicado no existe.' + CHAR(13);

    -- Validacion 2: Tipo de visitante existe
    IF NOT EXISTS (SELECT 1 FROM parques.TipoVisitante WHERE idTipoVisitante = @idTipoVisitante)
        SET @vErrores += '- El tipo de visitante indicado no existe.' + CHAR(13);

    -- Validacion 3: Nuevo valor valido
    IF @nuevoValor IS NULL OR @nuevoValor < 0
        SET @vErrores += '- El nuevo valor debe ser mayor o igual a cero.' + CHAR(13);

    -- Validacion 4: Fecha obligatoria
    IF @fechaActualizacion IS NULL
        SET @vErrores += '- La fecha de actualizacion es obligatoria.' + CHAR(13);

    -- Obtener precio existente
    SELECT @vIdPrecio = idPrecio
    FROM parques.PrecioEntrada
    WHERE idParque = @idParque
      AND idTipoVisitante = @idTipoVisitante;

    -- Validacion 5: Precio existente
    IF @vIdPrecio IS NULL
        SET @vErrores += '- No existe un precio de entrada para ese parque y tipo de visitante.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRANSACTION;
    BEGIN TRY

        UPDATE parques.PrecioEntrada
        SET valor = @nuevoValor,
            fechaActualizacion = @fechaActualizacion
        WHERE idPrecio = @vIdPrecio;

        COMMIT TRANSACTION;

        PRINT 'Precio de entrada actualizado correctamente. ID: ' + CAST(@vIdPrecio AS VARCHAR);
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END
GO

GO


-- ============================================================
-- TESTING - ABM Parques y Guardaparques
-- ============================================================

--              Mezcla casos exitosos y casos que deben disparar validaciones.
--              Los casos de error se capturan con TRY/CATCH e imprimen el
--              mensaje esperado, para que el script no se interrumpa.
-- Pre-requisito: ejecutar 01_tablas_parques.sql y 02_abm_parques.sql.

GO

SET NOCOUNT ON;

DECLARE @idTipo INT, @idUbic INT, @idParque INT;

PRINT '===== TEST 1 (OK): alta de TipoParque =====';
-- Esperado: se crea y muestra 'Tipo de parque creado con ID: X'.
EXEC parques.sp_TipoParque_Insertar @descripcion = 'Parque Nacional';
SELECT @idTipo = idTipoParque FROM parques.TipoParque WHERE descripcion = 'Parque Nacional';

PRINT '===== TEST 2 (ERROR): TipoParque con descripcion duplicada =====';
-- Esperado: '- Ya existe un tipo de parque con esa descripcion.'
BEGIN TRY
    EXEC parques.sp_TipoParque_Insertar @descripcion = 'Parque Nacional';
    PRINT 'FALLO LA PRUEBA: se esperaba error de duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 3 (ERROR): TipoParque sin descripcion =====';
-- Esperado: '- La descripcion del tipo de parque es obligatoria.'
BEGIN TRY
    EXEC parques.sp_TipoParque_Insertar @descripcion = '';
    PRINT 'FALLO LA PRUEBA: se esperaba error de obligatoriedad.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 4 (OK): alta de Ubicacion =====';
EXEC parques.sp_Ubicacion_Insertar
     @direccion = 'Av. San Martin 100',
     @provincia = 'Neuquen',
     @latitud   = -40.123456,
     @longitud  = -71.654321;
SELECT @idUbic = idUbicacion FROM parques.Ubicacion WHERE direccion = 'Av. San Martin 100';

PRINT '===== TEST 5 (ERROR): Ubicacion con latitud fuera de rango =====';
-- Esperado: '- La latitud debe estar entre -90 y 90.'
BEGIN TRY
    EXEC parques.sp_Ubicacion_Insertar
         @direccion = 'Calle Falsa 123',
         @provincia = 'Rio Negro',
         @latitud   = 200,
         @longitud  = -71;
    PRINT 'FALLO LA PRUEBA: se esperaba error de latitud.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 6 (OK): alta de Parque =====';
EXEC parques.sp_Parque_Insertar
     @nombre       = 'Nahuel Huapi',
     @superficie   = 7050.50,
     @idTipoParque = @idTipo,
     @idUbicacion  = @idUbic;
SELECT @idParque = idParque FROM parques.Parque WHERE nombre = 'Nahuel Huapi';
-- Evidencia de los datos cargados:
SELECT idParque, nombre, superficie, idTipoParque, idUbicacion
FROM parques.Parque WHERE idParque = @idParque;

PRINT '===== TEST 7 (ERROR): Parque con varios errores a la vez =====';
-- Esperado: UN solo mensaje que junta superficie<=0 y tipo inexistente.
BEGIN TRY
    EXEC parques.sp_Parque_Insertar
         @nombre       = 'Parque Invalido',
         @superficie   = -5,
         @idTipoParque = 99999,
         @idUbicacion  = @idUbic;
    PRINT 'FALLO LA PRUEBA: se esperaban errores combinados.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 8 (OK): alta de Guardaparque =====';
EXEC parques.sp_Guardaparque_Insertar
     @dni   = 30111222,
     @apyn  = 'Perez, Juan',
     @email = 'juan.perez@parques.gob.ar';
SELECT dni, apyn, email FROM parques.Guardaparque WHERE dni = 30111222;

PRINT '===== TEST 9 (ERROR): Guardaparque con dni invalido y email mal formado =====';
-- Esperado: UN solo mensaje con dni<=0 y email invalido.
BEGIN TRY
    EXEC parques.sp_Guardaparque_Insertar
         @dni   = -1,
         @apyn  = 'Test',
         @email = 'no-es-un-email';
    PRINT 'FALLO LA PRUEBA: se esperaban errores combinados.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 10 (ERROR): eliminar un TipoParque en uso =====';
-- Esperado: '- No se puede eliminar: existen parques asociados a este tipo.'
BEGIN TRY
    EXEC parques.sp_TipoParque_Eliminar @idTipoParque = @idTipo;
    PRINT 'FALLO LA PRUEBA: se esperaba bloqueo por dependencia.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 11 (OK): obtener Parque por ID =====';
EXEC parques.sp_Parque_ObtenerPorId @idParque = @idParque;
GO

GO


-- ============================================================
-- TESTING - NEGOCIO Parques y Guardaparques
-- ============================================================

--              (03_negocio_parques.sql). Recorre el ciclo de vida de un
--              guardaparque (alta, reasignacion, egreso) y el alta de parque,
--              con casos exitosos y casos que disparan validaciones.
-- Pre-requisito: ejecutar 01_tablas_parques.sql, 02_abm_parques.sql y
--                03_negocio_parques.sql.

GO

SET NOCOUNT ON;

DECLARE @idTipo INT, @idParqueA INT, @idParqueB INT;

PRINT '===== SETUP: tipo de parque para las pruebas =====';
IF NOT EXISTS (SELECT 1 FROM parques.TipoParque WHERE descripcion = 'Reserva Natural')
    EXEC parques.sp_TipoParque_Insertar @descripcion = 'Reserva Natural';
SELECT @idTipo = idTipoParque FROM parques.TipoParque WHERE descripcion = 'Reserva Natural';

PRINT '===== TEST 1 (OK): registrar parque (Ubicacion + Parque en una transaccion) =====';
EXEC parques.sp_RegistrarParque
     @nombre       = 'Los Alerces',
     @superficie   = 2630.00,
     @idTipoParque = @idTipo,
     @direccion    = 'Ruta 71 s/n',
     @provincia    = 'Chubut',
     @latitud      = -42.800000,
     @longitud     = -71.900000;
SELECT @idParqueA = idParque FROM parques.Parque WHERE nombre = 'Los Alerces';
-- Evidencia: parque y ubicacion quedaron enlazados.
SELECT p.idParque, p.nombre, u.direccion, u.provincia
FROM parques.Parque p
JOIN parques.Ubicacion u ON u.idUbicacion = p.idUbicacion
WHERE p.idParque = @idParqueA;

PRINT '===== TEST 2 (ERROR): registrar parque con datos invalidos =====';
-- Esperado: UN solo mensaje con superficie<=0, tipo inexistente y latitud fuera de rango.
BEGIN TRY
    EXEC parques.sp_RegistrarParque
         @nombre       = 'Parque Roto',
         @superficie   = 0,
         @idTipoParque = 99999,
         @direccion    = 'Direccion X',
         @provincia    = 'Provincia X',
         @latitud      = 999,
         @longitud     = -71;
    PRINT 'FALLO LA PRUEBA: se esperaban errores combinados.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH
-- Evidencia: no debe haber quedado ninguna ubicacion suelta de este intento.
SELECT COUNT(*) AS ubicaciones_huerfanas
FROM parques.Ubicacion WHERE direccion = 'Direccion X';

PRINT '===== TEST 3 (OK): registrar guardaparque con su asignacion inicial =====';
EXEC parques.sp_RegistrarGuardaparque
     @dni         = 28999888,
     @apyn        = 'Gomez, Ana',
     @idParque    = @idParqueA,
     @fechaInicio = '2025-01-10';
-- Evidencia: queda una asignacion vigente (fechaFin NULL).
SELECT idAsignacion, dni, idParque, fechaInicio, fechaFin
FROM parques.AsignacionGuardaparque WHERE dni = 28999888;

PRINT '===== TEST 4 (ERROR): registrar guardaparque con dni ya existente =====';
-- Esperado: '- Ya existe un guardaparque registrado con ese DNI.'
BEGIN TRY
    EXEC parques.sp_RegistrarGuardaparque
         @dni         = 28999888,
         @apyn        = 'Otro Nombre',
         @idParque    = @idParqueA,
         @fechaInicio = '2025-02-01';
    PRINT 'FALLO LA PRUEBA: se esperaba error de dni duplicado.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== SETUP: segundo parque para la reasignacion =====';
EXEC parques.sp_RegistrarParque
     @nombre       = 'Lanin',
     @superficie   = 4120.00,
     @idTipoParque = @idTipo,
     @direccion    = 'Ruta 40 km 2000',
     @provincia    = 'Neuquen',
     @latitud      = -39.600000,
     @longitud     = -71.500000;
SELECT @idParqueB = idParque FROM parques.Parque WHERE nombre = 'Lanin';

PRINT '===== TEST 5 (OK): reasignar el guardaparque al segundo parque =====';
EXEC parques.sp_ReasignarGuardaparque
     @dni               = 28999888,
     @idParqueDestino   = @idParqueB,
     @fechaReasignacion = '2025-06-01';
-- Evidencia: 2 filas. La 1ra cerrada (fechaFin=2025-06-01, motivo 'Reasignacion')
-- y la 2da vigente (fechaFin NULL) en el parque B.
SELECT idAsignacion, idParque, fechaInicio, fechaFin, motivoEgreso
FROM parques.AsignacionGuardaparque
WHERE dni = 28999888
ORDER BY fechaInicio;

PRINT '===== TEST 6 (ERROR): reasignar al mismo parque en el que ya esta =====';
-- Esperado: '- El parque destino es el mismo que el parque actual.'
BEGIN TRY
    EXEC parques.sp_ReasignarGuardaparque
         @dni               = 28999888,
         @idParqueDestino   = @idParqueB,
         @fechaReasignacion = '2025-07-01';
    PRINT 'FALLO LA PRUEBA: se esperaba error de destino igual al actual.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH

PRINT '===== TEST 7 (OK): registrar el egreso del guardaparque =====';
EXEC parques.sp_RegistrarEgresoGuardaparque
     @dni          = 28999888,
     @fechaEgreso  = '2025-12-31',
     @motivoEgreso = 'Renuncia';
-- Evidencia: ya no debe quedar ninguna asignacion vigente.
SELECT COUNT(*) AS asignaciones_vigentes
FROM parques.AsignacionGuardaparque
WHERE dni = 28999888 AND fechaFin IS NULL;

PRINT '===== TEST 8 (ERROR): registrar egreso sin asignacion vigente =====';
-- Esperado: '- El guardaparque no tiene una asignacion vigente...'
BEGIN TRY
    EXEC parques.sp_RegistrarEgresoGuardaparque
         @dni          = 28999888,
         @fechaEgreso  = '2026-01-15',
         @motivoEgreso = 'Renuncia';
    PRINT 'FALLO LA PRUEBA: se esperaba error de sin asignacion vigente.';
END TRY
BEGIN CATCH
    PRINT 'OK (error esperado): ' + ERROR_MESSAGE();
END CATCH
GO

GO


-- ============================================================
-- TESTING - ABM Concesiones
-- ============================================================

--              Cubre casos exitosos con evidencia (SELECT) y casos fallidos
--              que demuestran el comportamiento de las validaciones.

GO

-- TESTING: sp_TipoConsesion_Insertar / Eliminar / Actualizar

PRINT '=== TEST: TipoDeConsesion ===';

-- [EXITOSO] Alta de tipos
PRINT '-- Alta exitosa';
EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Gastronomia';
EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Turismo aventura';
EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Comercio minorista';

-- Evidencia
SELECT * FROM parques.TipoDeConsesion;

-- [FALLIDO] Descripcion vacia
PRINT '-- Fallo: descripcion vacia';
BEGIN TRY
    EXEC parques.sp_TipoConsesion_Insertar @descripcion = '';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Descripcion duplicada
PRINT '-- Fallo: descripcion duplicada';
BEGIN TRY
    EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Gastronomia';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [EXITOSO] Actualizacion
PRINT '-- Actualizacion exitosa';
EXEC parques.sp_TipoConsesion_Actualizar @idTipoConcesion = 3, @descripcion = 'Comercio y souvenirs';
SELECT * FROM parques.TipoDeConsesion WHERE idTipoConcesion = 3;

-- [FALLIDO] Actualizar ID inexistente
PRINT '-- Fallo: ID inexistente';
BEGIN TRY
    EXEC parques.sp_TipoConsesion_Actualizar @idTipoConcesion = 999, @descripcion = 'Test';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- TESTING: sp_Empresa_Insertar / Eliminar / Actualizar

PRINT '=== TEST: Empresa ===';

-- [EXITOSO] Alta de empresas
PRINT '-- Alta exitosa';
EXEC parques.sp_Empresa_Insertar
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @contacto    = 'Carlos Fernandez',
    @email       = 'contacto@cabanabosque.com',
    @telefono    = '011-4523-9876';

EXEC parques.sp_Empresa_Insertar
    @razonSocial = 'Aventura Patagonica S.A.',
    @cuit        = '30798765432',
    @email       = 'info@aventurapatag.com';

-- Evidencia
SELECT * FROM parques.Empresa;

-- [FALLIDO] CUIT duplicado
PRINT '-- Fallo: CUIT duplicado';
BEGIN TRY
    EXEC parques.sp_Empresa_Insertar
        @razonSocial = 'Empresa Copia',
        @cuit        = '30712345678';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Multiples errores simultaneos
PRINT '-- Fallo: multiples errores simultaneos';
BEGIN TRY
    EXEC parques.sp_Empresa_Insertar
        @razonSocial = '',
        @cuit        = '123',
        @email       = 'emailinvalido';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [EXITOSO] Actualizacion
PRINT '-- Actualizacion exitosa';
EXEC parques.sp_Empresa_Actualizar
    @idEmpresa   = 1,
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @telefono    = '011-4523-0000';
SELECT * FROM parques.Empresa WHERE idEmpresa = 1;

-- TESTING: sp_Concesion_Insertar / Eliminar / Actualizar
-- (Requiere idParque valido de parques.Parque)

PRINT '=== TEST: Concesion ===';

-- [EXITOSO] Alta de concesiones
PRINT '-- Alta exitosa';
EXEC parques.sp_Concesion_Insertar
    @descripcion     = 'Restaurante principal - Parque Nahuel Huapi',
    @idTipoConcesion = 1,
    @idParque        = 1,
    @idEmpresa       = 1,
    @fechaInicio     = '2025-01-01',
    @fechaFin        = '2026-12-31',
    @canonMensual    = 150000.00;

EXEC parques.sp_Concesion_Insertar
    @descripcion     = 'Excursiones de trekking - Parque Los Glaciares',
    @idTipoConcesion = 2,
    @idParque        = 2,
    @idEmpresa       = 2,
    @fechaInicio     = '2025-03-01',
    @fechaFin        = '2027-02-28',
    @canonMensual    = 80000.00;

-- Evidencia
SELECT * FROM parques.Concesion;

-- [FALLIDO] Fecha fin anterior a inicio
PRINT '-- Fallo: fecha fin <= fecha inicio';
BEGIN TRY
    EXEC parques.sp_Concesion_Insertar
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
    EXEC parques.sp_Concesion_Insertar
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
    EXEC parques.sp_Concesion_Insertar
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
    EXEC parques.sp_TipoConsesion_Eliminar @idTipoConcesion = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [EXITOSO] Baja de concesion sin pagos
PRINT '-- Baja exitosa (concesion sin pagos)';
EXEC parques.sp_Concesion_Insertar
    @descripcion     = 'Concesion temporal para borrar',
    @idTipoConcesion = 3,
    @idParque        = 1,
    @idEmpresa       = 2,
    @fechaInicio     = '2025-01-01',
    @fechaFin        = '2025-06-30',
    @canonMensual    = 10000.00;

DECLARE @vIdTemp INT = (SELECT MAX(idConcesion) FROM parques.Concesion);
EXEC parques.sp_Concesion_Eliminar @idConcesion = @vIdTemp;
SELECT * FROM parques.Concesion;

-- TESTING: sp_PagoConcesion_Insertar / Eliminar / Actualizar

PRINT '=== TEST: PagoConcesion ===';

-- [EXITOSO] Alta de pagos
PRINT '-- Alta exitosa';
EXEC parques.sp_PagoConcesion_Insertar
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-02-05',
    @periodoAnio = 2025,
    @periodoMes  = 1;

EXEC parques.sp_PagoConcesion_Insertar
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-03-03',
    @periodoAnio = 2025,
    @periodoMes  = 2;

-- Evidencia
SELECT * FROM parques.PagoConcesion;

-- [FALLIDO] Pago duplicado mismo periodo
PRINT '-- Fallo: periodo duplicado';
BEGIN TRY
    EXEC parques.sp_PagoConcesion_Insertar
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
    EXEC parques.sp_PagoConcesion_Insertar
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
    EXEC parques.sp_PagoConcesion_Insertar
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
EXEC parques.sp_PagoConcesion_Actualizar
    @idPagoConcesion = 1,
    @monto           = 155000.00,
    @fechaPago       = '2025-02-05';
SELECT * FROM parques.PagoConcesion WHERE idPagoConcesion = 1;

-- [EXITOSO] Baja
PRINT '-- Baja exitosa';
EXEC parques.sp_PagoConcesion_Eliminar @idPagoConcesion = 2;
SELECT * FROM parques.PagoConcesion;

-- [FALLIDO] Baja ID inexistente
PRINT '-- Fallo: baja ID inexistente';
BEGIN TRY
    EXEC parques.sp_PagoConcesion_Eliminar @idPagoConcesion = 999;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH

-- [FALLIDO] Ahora si: baja de concesion con pagos
PRINT '-- Fallo: baja concesion con pagos';
BEGIN TRY
    EXEC parques.sp_Concesion_Eliminar @idConcesion = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH
GO

GO


-- ============================================================
-- TESTING - NEGOCIO Concesiones
-- ============================================================

--              Cubre casos exitosos con evidencia (SELECT) y casos fallidos
--              que demuestran el comportamiento de las validaciones.
--               y 04_negocio_parques.sql

GO

-- DATOS BASE para los tests
-- (Si ya existen de los tests ABM, comentar este bloque)

EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Gastronomia';
EXEC parques.sp_TipoConsesion_Insertar @descripcion = 'Turismo aventura';

EXEC parques.sp_Empresa_Insertar
    @razonSocial = 'La Cabana del Bosque S.R.L.',
    @cuit        = '30712345678',
    @email       = 'contacto@cabanabosque.com';

EXEC parques.sp_Empresa_Insertar
    @razonSocial = 'Aventura Patagonica S.A.',
    @cuit        = '30798765432',
    @email       = 'info@aventurapatag.com';

-- TESTING: sp_AltaConcesionCompleta

PRINT '=== TEST: sp_AltaConcesionCompleta ===';

-- [EXITOSO] Alta de concesion valida
PRINT '-- Caso exitoso: concesion nueva sin solapamiento';
EXEC parques.sp_AltaConcesionCompleta
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
FROM parques.Concesion c
JOIN parques.TipoDeConsesion t ON t.idTipoConcesion = c.idTipoConcesion
JOIN parques.Empresa e         ON e.idEmpresa       = c.idEmpresa;

-- [FALLIDO] Empresa inexistente
PRINT '-- Fallo: empresa no existe';
BEGIN TRY
    EXEC parques.sp_AltaConcesionCompleta
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
    EXEC parques.sp_AltaConcesionCompleta
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
    EXEC parques.sp_AltaConcesionCompleta
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
    EXEC parques.sp_AltaConcesionCompleta
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
EXEC parques.sp_AltaConcesionCompleta
    @descripcion     = 'Excursiones de trekking - Parque Nahuel Huapi',
    @idTipoConcesion = 2,
    @idParque        = 1,
    @idEmpresa       = 1,
    @fechaInicio     = '2025-06-01',
    @fechaFin        = '2027-05-31',
    @canonMensual    = 95000.00;

SELECT * FROM parques.Concesion;

-- TESTING: sp_RegistrarPagoCanon

PRINT '=== TEST: sp_RegistrarPagoCanon ===';

-- [EXITOSO] Pago del canon del mes 1/2025
PRINT '-- Caso exitoso: primer pago';
EXEC parques.sp_RegistrarPagoCanon
    @idConcesion = 1,
    @monto       = 150000.00,
    @fechaPago   = '2025-02-05',
    @periodoAnio = 2025,
    @periodoMes  = 1;

-- [EXITOSO] Pago del mes 2/2025
PRINT '-- Caso exitoso: segundo pago';
EXEC parques.sp_RegistrarPagoCanon
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
FROM parques.PagoConcesion p
JOIN parques.Concesion c ON c.idConcesion = p.idConcesion
ORDER BY p.periodoAnio, p.periodoMes;

-- [FALLIDO] Periodo duplicado
PRINT '-- Fallo: pago duplicado para el mismo periodo';
BEGIN TRY
    EXEC parques.sp_RegistrarPagoCanon
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
    EXEC parques.sp_RegistrarPagoCanon
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
    EXEC parques.sp_RegistrarPagoCanon
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
    EXEC parques.sp_RegistrarPagoCanon
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
    EXEC parques.sp_RegistrarPagoCanon
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
    EXEC parques.sp_RegistrarPagoCanon
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
FROM parques.PagoConcesion p
JOIN parques.Concesion c ON c.idConcesion = p.idConcesion
ORDER BY p.periodoAnio, p.periodoMes;

-- Reporte: concesiones con pagos atrasados (mes anterior sin pago)
PRINT '-- Reporte: concesiones con pagos atrasados (mes anterior sin pago)';
SELECT
    c.idConcesion,
    c.descripcion,
    e.razonSocial,
    c.canonMensual,
    c.fechaFin
FROM parques.Concesion c
JOIN parques.Empresa e ON e.idEmpresa = c.idEmpresa
WHERE c.fechaFin >= CAST(GETDATE() AS DATE)
  AND NOT EXISTS (
      SELECT 1 FROM parques.PagoConcesion p
      WHERE p.idConcesion = c.idConcesion
        AND p.periodoAnio = YEAR(DATEADD(MONTH, -1, GETDATE()))
        AND p.periodoMes  = MONTH(DATEADD(MONTH, -1, GETDATE()))
  );
GO

GO


-- ============================================================
-- TESTING - Guías, Tours y Atracciones
-- ============================================================


GO

-- TESTS EXITOSOS

PRINT '--- TEST 1: Insertar guía válido ---';
-- Resultado esperado: 1 fila insertada, sin error
EXEC parques.sp_Guia_Insertar
    @dni = 30000001,
    @apynom = 'Carlos Pérez',
    @especialidad = 'Flora patagónica',
    @titulo = 'Lic. en Biología',
    @vigenciaAutorizacion = '2027-12-31';

SELECT * FROM parques.Guia WHERE dni = 30000001;
-- Verificación: debe aparecer el registro


PRINT '--- TEST 2: Asignar guía a tour sin superposición ---';
-- Resultado esperado: asignación creada correctamente
EXEC parques.sp_AsignarGuiaATour
    @idTour = 1,
    @dniGuia = 30000001,
    @fechaInicio = '2025-01-01',
    @fechaFin = '2025-06-30';

SELECT * FROM parques.AsignacionGuia WHERE dniGuia = 30000001;


PRINT '--- TEST 3: Registrar atracción válida ---';
-- Resultado esperado: atracción insertada
EXEC parques.sp_RegistrarAtraccion
    @nombre = 'Senderismo Lago Verde',
    @tipo = 'Outdoor',
    @precio = 0,
    @duracion = 120,
    @cupoMaximo = 20,
    @idParque = 1;

SELECT * FROM parques.Atraccion WHERE nombre = 'Senderismo Lago Verde';


-- TESTS DE VALIDACIONES (ERRORES ESPERADOS)

PRINT '--- TEST 4: Insertar guía con DNI duplicado ---';
-- Resultado esperado: error "Ya existe un guía registrado con ese DNI"
BEGIN TRY
    EXEC parques.sp_Guia_Insertar
        @dni = 30000001,
        @apynom = 'Otro Guia',
        @vigenciaAutorizacion = '2026-01-01';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH


PRINT '--- TEST 5: Asignar guía con autorización vencida ---';
-- Resultado esperado: error "La autorización del guía vence antes..."
BEGIN TRY
    EXEC parques.sp_AsignarGuiaATour
        @idTour = 1,
        @dniGuia = 30000001,
        @fechaInicio = '2025-01-01',
        @fechaFin = '2030-01-01'; -- fecha posterior a la vigencia (2027-12-31)
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH


PRINT '--- TEST 6: Asignar guía con superposición de fechas ---';
-- Resultado esperado: error "El guía ya tiene una asignación en ese período"
BEGIN TRY
    EXEC parques.sp_AsignarGuiaATour
        @idTour = 2,
        @dniGuia = 30000001,
        @fechaInicio = '2025-03-01', -- se superpone con el test 2 (Ene-Jun 2025)
        @fechaFin = '2025-09-01';
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH


PRINT '--- TEST 7: Registrar atracción con cupo 0 ---';
-- Resultado esperado: error "El cupo máximo debe ser mayor a 0"
BEGIN TRY
    EXEC parques.sp_RegistrarAtraccion
        @nombre = 'Atraccion invalida',
        @duracion = 60,
        @cupoMaximo = 0,
        @idParque = 1;
END TRY
BEGIN CATCH
    PRINT ERROR_MESSAGE();
END CATCH
GO

GO
