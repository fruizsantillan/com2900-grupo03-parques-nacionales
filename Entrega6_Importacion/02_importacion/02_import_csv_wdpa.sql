-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Importacion de areas protegidas desde la base de datos mundial WDPA.
--   Fuente: WDPA_WDOECM_Jun2026_Public_ARG_csv.csv
--   Origen: https://www.protectedplanet.net (UNEP-WCMC / IUCN)
--   Formato: CSV UTF-8 con BOM, separador coma, 34 columnas
--   Columnas usadas: NAME, DESIG, DESIG_TYPE, GIS_AREA
--   GIS_AREA en km2 -> se convierte a hectareas (* 100).
--   Filtra: solo DESIG_TYPE = 'National'
--   Estrategia: BULK INSERT en tabla temporal #AreasWDPA ->
--               CURSOR -> parques.TipoParque_Insertar (si el tipo no existe) ->
--               CURSOR -> parques.RegistrarParque (nuevo) o parques.Parque_Actualizar (existente)
--
-- NOTA: La tabla temporal tiene todas las columnas del CSV WDPA para que
--       BULK INSERT las pueda cargar sin FORMAT FILE. Solo se usan las relevantes.
-- Prerequisito: Ejecutar 01_tablas_staging.sql y scripts de tablas de parques (E5).
-- =============================================

USE ParquesNacionales;
GO

-- ============================================================
-- SP: sp_ImportarAreasWDPA
-- ============================================================
CREATE OR ALTER PROCEDURE parques.sp_ImportarAreasWDPA
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql              NVARCHAR(MAX);
    DECLARE @vTotalStaging     INT = 0;
    DECLARE @vProcesadas       INT = 0;
    DECLARE @vDescartadas      INT = 0;
    DECLARE @vInsertadas       INT = 0;
    DECLARE @vActualizadas     INT = 0;

    -- Cursor variables
    DECLARE @vNombre           VARCHAR(200);
    DECLARE @vDesig            VARCHAR(200);
    DECLARE @vDesigType        VARCHAR(50);
    DECLARE @vGisArea          VARCHAR(30);
    DECLARE @vDescripcionTipo  VARCHAR(200);
    DECLARE @vSuperficieHa     DECIMAL(18,2);
    DECLARE @vIdTipoParque     INT;
    DECLARE @vIdParque         INT;
    DECLARE @vIdUbicacion      INT;

    -- --------------------------------------------------------
    -- Paso 1: Tabla temporal de staging (34 columnas del CSV WDPA)
    -- Orden segun el CSV estandar WDPA Public v7
    -- --------------------------------------------------------
    CREATE TABLE #AreasWDPA (
        wdpaId          VARCHAR(50)   NULL,  -- 1  WDPAID
        wdpaPid         VARCHAR(100)  NULL,  -- 2  WDPA_PID
        paDef           VARCHAR(10)   NULL,  -- 3  PA_DEF
        name            VARCHAR(200)  NULL,  -- 4  NAME
        origName        VARCHAR(200)  NULL,  -- 5  ORIG_NAME
        desig           VARCHAR(200)  NULL,  -- 6  DESIG
        desigEng        VARCHAR(200)  NULL,  -- 7  DESIG_ENG
        desigType       VARCHAR(50)   NULL,  -- 8  DESIG_TYPE
        iucnCat         VARCHAR(20)   NULL,  -- 9  IUCN_CAT
        intCrit         VARCHAR(200)  NULL,  -- 10 INT_CRIT
        marine          VARCHAR(10)   NULL,  -- 11 MARINE
        repMArea        VARCHAR(30)   NULL,  -- 12 REP_M_AREA
        gisMArea        VARCHAR(30)   NULL,  -- 13 GIS_M_AREA
        repArea         VARCHAR(30)   NULL,  -- 14 REP_AREA
        gisArea         VARCHAR(30)   NULL,  -- 15 GIS_AREA
        noTake          VARCHAR(50)   NULL,  -- 16 NO_TAKE
        noTkArea        VARCHAR(30)   NULL,  -- 17 NO_TK_AREA
        status          VARCHAR(50)   NULL,  -- 18 STATUS
        statusYr        VARCHAR(10)   NULL,  -- 19 STATUS_YR
        govType         VARCHAR(50)   NULL,  -- 20 GOV_TYPE
        ownType         VARCHAR(50)   NULL,  -- 21 OWN_TYPE
        mangAuth        VARCHAR(200)  NULL,  -- 22 MANG_AUTH
        mangPlan        VARCHAR(200)  NULL,  -- 23 MANG_PLAN
        verif           VARCHAR(50)   NULL,  -- 24 VERIF
        metadataId      VARCHAR(20)   NULL,  -- 25 METADATAID
        subLoc          VARCHAR(200)  NULL,  -- 26 SUB_LOC
        parentIso3      VARCHAR(10)   NULL,  -- 27 PARENT_ISO3
        iso3            VARCHAR(10)   NULL,  -- 28 ISO3
        suppInfo        VARCHAR(MAX)  NULL,  -- 29 SUPP_INFO
        consObj         VARCHAR(MAX)  NULL,  -- 30 CONS_OBJ
        mangPlanRef     VARCHAR(MAX)  NULL,  -- 31 MANG_PLAN_REF
        impId           VARCHAR(50)   NULL,  -- 32 IMP_ID
        impDate         VARCHAR(50)   NULL,  -- 33 IMP_DATE
        col34           VARCHAR(200)  NULL   -- 34 (additional field if present)
    );

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT #AreasWDPA
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FORMAT          = ''CSV'',
            FIELDTERMINATOR = '','',
            ROWTERMINATOR   = ''\n'',
            FIRSTROW        = 2,
            CODEPAGE        = ''65001'',
            TABLOCK
        );
    ';
    EXEC sp_executesql @vSql;

    SELECT @vTotalStaging = COUNT(*) FROM #AreasWDPA;
    PRINT 'Filas cargadas en staging temporal: ' + CAST(@vTotalStaging AS VARCHAR);

    SELECT @vDescartadas = COUNT(*)
    FROM #AreasWDPA
    WHERE LTRIM(RTRIM(desigType)) != 'National'
       OR name IS NULL
       OR LTRIM(RTRIM(name)) = '';

    SET @vProcesadas = @vTotalStaging - @vDescartadas;
    PRINT 'A procesar (jurisdiccion Nacional): ' + CAST(@vProcesadas AS VARCHAR);
    PRINT 'Descartadas (no nacionales/sin nombre): ' + CAST(@vDescartadas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: Insertar TipoParque (si no existe) via SP de E5
    -- --------------------------------------------------------
    DECLARE tipo_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT LTRIM(RTRIM(desig))
        FROM #AreasWDPA
        WHERE LTRIM(RTRIM(desigType)) = 'National'
          AND desig IS NOT NULL
          AND LTRIM(RTRIM(desig)) != '';

    OPEN tipo_cursor;
    FETCH NEXT FROM tipo_cursor INTO @vDescripcionTipo;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM parques.TipoParque WHERE descripcion = @vDescripcionTipo)
        BEGIN
            BEGIN TRY
                EXEC parques.TipoParque_Insertar @descripcion = @vDescripcionTipo;
            END TRY
            BEGIN CATCH
                PRINT 'Aviso: no se pudo insertar TipoParque "' + @vDescripcionTipo + '": ' + ERROR_MESSAGE();
            END CATCH
        END
        FETCH NEXT FROM tipo_cursor INTO @vDescripcionTipo;
    END
    CLOSE tipo_cursor;
    DEALLOCATE tipo_cursor;
    PRINT 'TipoParque actualizado con tipos WDPA.';

    -- --------------------------------------------------------
    -- Paso 4: Insertar / actualizar Parques via SPs de E5
    -- WDPA puede tener duplicados (Polygon + Point del mismo area).
    -- El cursor usa MAX(gisArea) por nombre para tomar la mayor superficie.
    -- Si el parque no existe: llama parques.RegistrarParque (con ubicacion generica).
    -- Si ya existe: llama parques.Parque_Actualizar para actualizar superficie.
    -- --------------------------------------------------------

    -- Crear ubicacion generica si no existe
    IF NOT EXISTS (SELECT 1 FROM parques.Ubicacion WHERE direccion = 'Argentina - Pendiente de asignacion')
    BEGIN
        INSERT INTO parques.Ubicacion (direccion, provincia, latitud, longitud)
        VALUES ('Argentina - Pendiente de asignacion', 'Sin definir', -38.00, -65.00);
    END

    DECLARE wdpa_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            LTRIM(RTRIM(s.name)),
            LTRIM(RTRIM(s.desig)),
            MAX(TRY_CAST(REPLACE(LTRIM(RTRIM(s.gisArea)), ',', '.') AS DECIMAL(18,2))) * 100
        FROM #AreasWDPA s
        WHERE LTRIM(RTRIM(s.desigType)) = 'National'
          AND s.name IS NOT NULL
          AND LTRIM(RTRIM(s.name)) != ''
          AND TRY_CAST(REPLACE(LTRIM(RTRIM(s.gisArea)), ',', '.') AS DECIMAL(18,2)) IS NOT NULL
        GROUP BY LTRIM(RTRIM(s.name)), LTRIM(RTRIM(s.desig));

    OPEN wdpa_cursor;
    FETCH NEXT FROM wdpa_cursor INTO @vNombre, @vDescripcionTipo, @vSuperficieHa;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @vIdTipoParque = idTipoParque
        FROM parques.TipoParque
        WHERE descripcion = @vDescripcionTipo;

        IF @vIdTipoParque IS NOT NULL AND @vSuperficieHa IS NOT NULL AND @vSuperficieHa > 0
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE nombre = @vNombre)
            BEGIN
                BEGIN TRY
                    EXEC parques.RegistrarParque
                        @nombre       = @vNombre,
                        @superficie   = @vSuperficieHa,
                        @idTipoParque = @vIdTipoParque,
                        @direccion    = 'Argentina - Pendiente de asignacion',
                        @provincia    = 'Sin definir',
                        @latitud      = -38.00,
                        @longitud     = -65.00;
                    SET @vInsertadas += 1;
                END TRY
                BEGIN CATCH
                    PRINT 'Error al insertar parque WDPA "' + @vNombre + '": ' + ERROR_MESSAGE();
                END CATCH
            END
            ELSE
            BEGIN
                SELECT @vIdParque    = idParque,
                       @vIdUbicacion = idUbicacion,
                       @vIdTipoParque = idTipoParque
                FROM parques.Parque
                WHERE nombre = @vNombre;

                BEGIN TRY
                    EXEC parques.Parque_Actualizar
                        @idParque     = @vIdParque,
                        @nombre       = @vNombre,
                        @superficie   = @vSuperficieHa,
                        @idTipoParque = @vIdTipoParque,
                        @idUbicacion  = @vIdUbicacion;
                    SET @vActualizadas += 1;
                END TRY
                BEGIN CATCH
                    PRINT 'Error al actualizar parque WDPA "' + @vNombre + '": ' + ERROR_MESSAGE();
                END CATCH
            END
        END

        FETCH NEXT FROM wdpa_cursor INTO @vNombre, @vDescripcionTipo, @vSuperficieHa;
    END
    CLOSE wdpa_cursor;
    DEALLOCATE wdpa_cursor;

    PRINT '----------------------------------------------';
    PRINT 'Importacion WDPA completada exitosamente.';
    PRINT 'Total filas en CSV:          ' + CAST(@vTotalStaging AS VARCHAR);
    PRINT 'Procesadas (nacionales):     ' + CAST(@vProcesadas   AS VARCHAR);
    PRINT 'Descartadas:                 ' + CAST(@vDescartadas  AS VARCHAR);
    PRINT 'Parques insertados:          ' + CAST(@vInsertadas   AS VARCHAR);
    PRINT 'Parques actualizados:        ' + CAST(@vActualizadas AS VARCHAR);
    PRINT '----------------------------------------------';


    -- --------------------------------------------------------
    -- Paso 5: Seed de ventas.TipoVisitante y ventas.PrecioEntrada
    -- Asegura que los tipos de visitante existen y crea precios
    -- iniciales para cada parque x tipo que no tenga precio vigente.
    -- Residente:    $ 10.000 ARS
    -- No Residente: USD 20 x tipo de cambio oficial (o $ 10.000 si no hay TC)
    -- --------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante WHERE descripcion = 'Residente')
        EXEC ventas.TipoVisitante_Insertar @descripcion = 'Residente';
    IF NOT EXISTS (SELECT 1 FROM ventas.TipoVisitante WHERE descripcion = 'No Residente')
        EXEC ventas.TipoVisitante_Insertar @descripcion = 'No Residente';

    DECLARE @vTCVenta       DECIMAL(10,2);
    DECLARE @vFechaSeed     DATE = CAST(GETDATE() AS DATE);
    DECLARE @vIdParqueSeed  INT;
    DECLARE @vIdTVSeed      INT;
    DECLARE @vDescTVSeed    VARCHAR(100);
    DECLARE @vValorSeed     DECIMAL(18,2);

    SELECT TOP 1 @vTCVenta = venta
    FROM parques.TipoCambio
    WHERE tipo = 'oficial'
    ORDER BY fecha DESC;

    DECLARE precio_seed CURSOR LOCAL FAST_FORWARD FOR
        SELECT p.idParque, tv.idTipoVisitante, tv.descripcion
        FROM parques.Parque p
        CROSS JOIN ventas.TipoVisitante tv
        WHERE NOT EXISTS (
            SELECT 1 FROM ventas.PrecioEntrada pe
            WHERE pe.idParque        = p.idParque
              AND pe.idTipoVisitante = tv.idTipoVisitante
              AND (pe.fechaHasta IS NULL OR pe.fechaHasta >= @vFechaSeed)
        );

    OPEN precio_seed;
    FETCH NEXT FROM precio_seed INTO @vIdParqueSeed, @vIdTVSeed, @vDescTVSeed;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @vValorSeed = CASE @vDescTVSeed
            WHEN 'Residente'    THEN 10000.00
            WHEN 'No Residente' THEN
                CASE WHEN @vTCVenta > 0
                     THEN CAST(20.00 * @vTCVenta AS DECIMAL(18,2))
                     ELSE 10000.00
                END
            ELSE 10000.00
        END;

        BEGIN TRY
            EXEC ventas.PrecioEntrada_Insertar
                @fechaActualizacion = @vFechaSeed,
                @valor              = @vValorSeed,
                @idParque           = @vIdParqueSeed,
                @idTipoVisitante    = @vIdTVSeed,
                @fechaHasta         = NULL;
        END TRY
        BEGIN CATCH
            PRINT 'Aviso precio parque ' + CAST(@vIdParqueSeed AS VARCHAR)
                + ' / ' + @vDescTVSeed + ': ' + ERROR_MESSAGE();
        END CATCH

        FETCH NEXT FROM precio_seed INTO @vIdParqueSeed, @vIdTVSeed, @vDescTVSeed;
    END
    CLOSE precio_seed; DEALLOCATE precio_seed;
    PRINT 'Seed de PrecioEntrada completado.';

    INSERT INTO parques.LogImportacion (procedimiento, archivoFuente, totalLeido, insertados, actualizados, errores)
    VALUES ('parques.sp_ImportarAreasWDPA', @vRutaArchivo, @vTotalStaging,
            @vInsertadas, @vActualizadas, 0);
END
GO

-- ============================================================
-- NOTA DE USO:
-- EXEC parques.sp_ImportarAreasWDPA
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\WDPA_WDOECM_Jun2026_Public_ARG_csv.csv';
--
-- Verificacion post-importacion:
--   SELECT p.nombre, tp.descripcion AS tipo, p.superficie, u.provincia
--   FROM parques.Parque p
--   JOIN parques.TipoParque tp ON tp.idTipoParque = p.idTipoParque
--   JOIN parques.Ubicacion  u  ON u.idUbicacion   = p.idUbicacion
--   ORDER BY tp.descripcion, p.nombre;
-- ============================================================
PRINT 'SP parques.sp_ImportarAreasWDPA creado correctamente.';
GO
