-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Cifrado de datos sensibles (DNI de Guia/Guardaparque, CUIT de Empresa)
--
-- NOTA: las columnas originales (dni, cuit) se conservan en texto
-- plano dentro de la tabla porque son Primary Key / Unique y poseen Foreign
-- Keys que dependen de ellas para la integridad referencial del modelo
-- (ej: AsignacionGuia.dniGuia -> Guia.dni). Reemplazarlas por el valor
-- cifrado implicaria recodificar todas las FK del sistema.
-- En su lugar, la proteccion del dato se garantiza restringiendo el acceso
-- de lectura directa a estas columnas mediante roles de seguridad
-- (ver 02_roles_seguridad.sql), permitiendo el acceso al valor en claro
-- unicamente a traves de los SP de descifrado correspondientes.
-- =============================================

USE ParquesNacionales;
GO

-- 1. Crear Master Key
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'ClaveMaestra#ParquesNac2026!';
END
GO

-- 2. Crear certificado
IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'CertDatosSensibles')
BEGIN
    CREATE CERTIFICATE CertDatosSensibles
    WITH SUBJECT = 'Certificado para cifrado de datos sensibles - Parques Nacionales';
END
GO

-- 3. Crear clave simétrica
-- Nombre generico porque cifra tanto DNI (personas) como CUIT (empresas)
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = 'ClaveSimetricaDatosSensibles')
BEGIN
    CREATE SYMMETRIC KEY ClaveSimetricaDatosSensibles
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE CertDatosSensibles;
END
GO

-- 4. Agregar columnas cifradas

--Guia
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('personal.Guia') AND name = 'dniCifrado')
    ALTER TABLE personal.Guia ADD dniCifrado VARBINARY(256) NULL;

--Guardaparque
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('personal.Guardaparque') AND name = 'dniCifrado')
    ALTER TABLE personal.Guardaparque ADD dniCifrado VARBINARY(256) NULL;

--Empresa
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('concesiones.Empresa') AND name = 'cuitCifrado')
    ALTER TABLE concesiones.Empresa ADD cuitCifrado VARBINARY(256) NULL;
GO

-- 5. Migrar los datos existentes (cifrar solo si está vacío)

--Guia
OPEN SYMMETRIC KEY ClaveSimetricaDatosSensibles DECRYPTION BY CERTIFICATE CertDatosSensibles;

UPDATE personal.Guia 
SET dniCifrado = ENCRYPTBYKEY(KEY_GUID('ClaveSimetricaDatosSensibles'), CAST(dni AS VARCHAR(20)))
WHERE dniCifrado IS NULL;

CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
GO

--Guardaparque y Empresa
OPEN SYMMETRIC KEY ClaveSimetricaDatosSensibles DECRYPTION BY CERTIFICATE CertDatosSensibles;

UPDATE personal.Guardaparque 
SET dniCifrado = ENCRYPTBYKEY(KEY_GUID('ClaveSimetricaDatosSensibles'), CAST(dni AS VARCHAR(20)))
WHERE dniCifrado IS NULL;

UPDATE concesiones.Empresa 
SET cuitCifrado = ENCRYPTBYKEY(KEY_GUID('ClaveSimetricaDatosSensibles'), CAST(cuit AS VARCHAR(20)))
WHERE cuitCifrado IS NULL;

CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
GO

-- ==================
-- GUIA
-- ==================

-- SP de inserción: cifra el DNI antes de guardar
CREATE OR ALTER PROCEDURE personal.Guia_Insertar
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
    DECLARE @vDniCifrado VARBINARY(256);

    IF @dni IS NULL OR @dni <= 0
        SET @vErrores += '- El DNI es obligatorio y debe ser mayor a 0.' + CHAR(13);
    IF @apyn IS NULL OR LTRIM(RTRIM(@apyn)) = ''
        SET @vErrores += '- El nombre y apellido es obligatorio.' + CHAR(13);
    IF @vigenciaAutorizacion IS NULL
        SET @vErrores += '- La vigencia de autorización es obligatoria.' + CHAR(13);
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM personal.Guia WHERE dni = @dni)
        SET @vErrores += '- Ya existe un guía registrado con ese DNI.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        OPEN SYMMETRIC KEY ClaveSimetricaDatosSensibles
        DECRYPTION BY CERTIFICATE CertDatosSensibles;

        SET @vDniCifrado = ENCRYPTBYKEY(KEY_GUID('ClaveSimetricaDatosSensibles'), CAST(@dni AS VARCHAR(20)));

        INSERT INTO personal.Guia (dni, apyn, especialidad, titulo, habilitaciones, vigenciaAutorizacion, dniCifrado)
        VALUES (@dni, @apyn, @especialidad, @titulo, @habilitaciones, @vigenciaAutorizacion, @vDniCifrado);

        CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveSimetricaDatosSensibles')
            CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
        THROW;
    END CATCH
END
GO

-- SP para consultar el DNI descifrado (solo para roles autorizados)
CREATE OR ALTER PROCEDURE personal.Guia_ObtenerDniDescifrado
    @dniBusqueda INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        OPEN SYMMETRIC KEY ClaveSimetricaDatosSensibles
        DECRYPTION BY CERTIFICATE CertDatosSensibles;

        SELECT
            apyn,
            CONVERT(VARCHAR(20), DECRYPTBYKEY(dniCifrado)) AS dniDescifrado,
            especialidad,
            titulo
        FROM personal.Guia
        WHERE dni = @dniBusqueda;

        CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveSimetricaDatosSensibles')
            CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
        THROW;
    END CATCH
END
GO

-- ==================
-- GUARDAPARQUE
-- ==================

-- SP de inserción: cifra el DNI antes de guardar
CREATE OR ALTER PROCEDURE personal.Guardaparque_Insertar
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
    IF @dni IS NOT NULL AND EXISTS (SELECT 1 FROM personal.Guardaparque WHERE dni = @dni)
        SET @vErrores += '- Ya existe un guardaparque registrado con ese DNI.' + CHAR(13);
    IF @apyn IS NULL OR LTRIM(RTRIM(@apyn)) = ''
        SET @vErrores += '- El apellido y nombre es obligatorio.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        OPEN SYMMETRIC KEY ClaveSimetricaDatosSensibles DECRYPTION BY CERTIFICATE CertDatosSensibles;

        INSERT INTO personal.Guardaparque (dni, apyn, email, telefono, localidad, fechaNacimiento, dniCifrado)
        VALUES (@dni, LTRIM(RTRIM(@apyn)), @email, @telefono, @localidad, @fechaNacimiento,
                ENCRYPTBYKEY(KEY_GUID('ClaveSimetricaDatosSensibles'), CAST(@dni AS VARCHAR(20))));

        CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveSimetricaDatosSensibles')
            CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
        THROW;
    END CATCH
END
GO

-- SP para consultar el Guardaparque con DNI descifrado
CREATE OR ALTER PROCEDURE personal.Guardaparque_ObtenerDniDescifrado
    @dniBusqueda INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        OPEN SYMMETRIC KEY ClaveSimetricaDatosSensibles DECRYPTION BY CERTIFICATE CertDatosSensibles;

        SELECT apyn, email, telefono, localidad, fechaNacimiento,
               CONVERT(VARCHAR(20), DECRYPTBYKEY(dniCifrado)) AS dniDescifrado
        FROM personal.Guardaparque
        WHERE dni = @dniBusqueda;

        CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveSimetricaDatosSensibles')
            CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
        THROW;
    END CATCH
END
GO

-- ==================
-- EMPRESA
-- ==================

-- SP de inserción: cifra el CUIT antes de guardar
CREATE OR ALTER PROCEDURE concesiones.Empresa_Insertar
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
    IF @cuit IS NOT NULL AND LTRIM(RTRIM(@cuit)) != '' AND EXISTS (SELECT 1 FROM concesiones.Empresa WHERE cuit = LTRIM(RTRIM(@cuit)))
        SET @vErrores += '- Ya existe una empresa registrada con ese CUIT.' + CHAR(13);

    IF @vErrores != ''
    BEGIN
        RAISERROR(@vErrores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        OPEN SYMMETRIC KEY ClaveSimetricaDatosSensibles DECRYPTION BY CERTIFICATE CertDatosSensibles;

        INSERT INTO concesiones.Empresa (razonSocial, cuit, contacto, email, telefono, cuitCifrado)
        VALUES (LTRIM(RTRIM(@razonSocial)), LTRIM(RTRIM(@cuit)), @contacto, @email, @telefono,
                ENCRYPTBYKEY(KEY_GUID('ClaveSimetricaDatosSensibles'), LTRIM(RTRIM(@cuit))));

        CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveSimetricaDatosSensibles')
            CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
        THROW;
    END CATCH
END
GO

-- SP para consultar la Empresa con CUIT descifrado
CREATE OR ALTER PROCEDURE concesiones.Empresa_ObtenerCuitDescifrado
    @cuitBusqueda VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        OPEN SYMMETRIC KEY ClaveSimetricaDatosSensibles DECRYPTION BY CERTIFICATE CertDatosSensibles;

        SELECT razonSocial, contacto, email, telefono,
               CONVERT(VARCHAR(20), DECRYPTBYKEY(cuitCifrado)) AS cuitDescifrado
        FROM concesiones.Empresa
        WHERE CONVERT(VARCHAR(20), DECRYPTBYKEY(cuitCifrado)) = @cuitBusqueda;

        CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
    END TRY
    BEGIN CATCH
        IF EXISTS (SELECT 1 FROM sys.openkeys WHERE key_name = 'ClaveSimetricaDatosSensibles')
            CLOSE SYMMETRIC KEY ClaveSimetricaDatosSensibles;
        THROW;
    END CATCH
END
GO