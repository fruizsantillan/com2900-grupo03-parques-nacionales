-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Script para importar areas protegidas de datos gob ar
-- IMPORTANTE: Ajustar la variable @vBasePath con la ruta local a los datasets.
-- =============================================

CREATE OR ALTER PROCEDURE parques.ImportarAreasProtegidas
    @vRutaArchivo NVARCHAR(500)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @vSql              NVARCHAR(MAX);
    DECLARE @vFilas            INT = 0;
    DECLARE @vInsertadas       INT = 0;
    DECLARE @vActualizadas     INT = 0;

    -- Cursor variables
    DECLARE @vRegion           VARCHAR(100);
    DECLARE @vAreaProtegida    VARCHAR(200);
    DECLARE @vHectareas        VARCHAR(30);
    DECLARE @vDescripcionTipo  VARCHAR(100);
    DECLARE @vSuperficie       DECIMAL(18,2);
    DECLARE @vLat              DECIMAL(9,6);
    DECLARE @vLon              DECIMAL(9,6);
    DECLARE @vIdTipoParque     INT;
    DECLARE @vIdParque         INT;
    DECLARE @vIdUbicacion      INT;

    -- --------------------------------------------------------
    -- Paso 1: Tabla temporal de staging
    -- --------------------------------------------------------
    CREATE TABLE #AreasProtegidas (
        region                 VARCHAR(100)  NULL,
        areaProtegida          VARCHAR(200)  NULL,
        hectareas              VARCHAR(30)   NULL,
        categoriaInternacional VARCHAR(100)  NULL
    );

    -- --------------------------------------------------------
    -- Paso 2: BULK INSERT
    -- FORMAT='CSV' + FIELDQUOTE: necesario porque todos los
    -- campos vienen entre comillas dobles y categoria_internacional
    -- trae comas internas en varios registros.
    -- ROWTERMINATOR = 0x0A0D: el archivo separa las filas con
    -- LF+CR (orden invertido al CRLF habitual), no con '\n' simple.
    -- EXEC (@vSql) en vez de EXEC sp_executesql: evita el bug de
    -- SQL Server IID_IColumnsInfo al combinar FORMAT='CSV' con
    -- SQL dinamico parametrizado.
    -- --------------------------------------------------------
    SET @vSql = N'
        BULK INSERT #AreasProtegidas
        FROM ''' + @vRutaArchivo + N'''
        WITH (
            FORMAT           = ''CSV'',
            FIELDTERMINATOR  = '';'',
            ROWTERMINATOR    = ''0x0A0D'',
            FIRSTROW         = 2,
            CODEPAGE         = ''65001'',
            FIELDQUOTE       = ''"'',
            TABLOCK
        );
    ';
    EXEC (@vSql);

    SELECT @vFilas = COUNT(*) FROM #AreasProtegidas;
    PRINT 'Filas cargadas en staging temporal: ' + CAST(@vFilas AS VARCHAR);

    -- --------------------------------------------------------
    -- Paso 3: Insertar TipoParque (si no existe) via SP de E5
    -- --------------------------------------------------------
    DECLARE tipo_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT DISTINCT
            CASE
                WHEN areaProtegida LIKE 'Parque Nacional%'              THEN 'Parque Nacional'
                WHEN areaProtegida LIKE 'Parque Interjurisdiccional%'   THEN 'Parque Interjurisdiccional'
                WHEN areaProtegida LIKE 'Reserva Nacional%'             THEN 'Reserva Nacional'
                WHEN areaProtegida LIKE 'Reserva Natural%'              THEN 'Reserva Natural'
                WHEN areaProtegida LIKE 'Monumento Natural%'            THEN 'Monumento Natural'
                ELSE 'Otra Area Protegida'
            END
        FROM #AreasProtegidas
        WHERE areaProtegida IS NOT NULL;

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
    PRINT 'TipoParque actualizado.';

    -- --------------------------------------------------------
    -- Paso 4: Insertar / actualizar Parques via SPs de E5
    -- Usa parques.RegistrarParque (nuevo) o parques.Parque_Actualizar (existente).
    -- Coordenadas aproximadas por region (centroide APN).
    -- --------------------------------------------------------
    DECLARE parque_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT region, areaProtegida, hectareas
        FROM #AreasProtegidas
        WHERE areaProtegida IS NOT NULL
          AND hectareas IS NOT NULL
          AND LTRIM(RTRIM(hectareas)) != '';

    OPEN parque_cursor;
    FETCH NEXT FROM parque_cursor INTO @vRegion, @vAreaProtegida, @vHectareas;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Calcular superficie (el CSV trae el numero "plano", sin
        -- separador de miles; el REPLACE de '.' se deja como
        -- salvaguarda por si una version futura del dataset lo trae)
        SET @vSuperficie = TRY_CAST(
            REPLACE(LTRIM(RTRIM(@vHectareas)), '.', '')
            AS DECIMAL(18,2)
        );

        -- Derivar tipo del nombre
        SET @vDescripcionTipo = CASE
            WHEN @vAreaProtegida LIKE 'Parque Nacional%'              THEN 'Parque Nacional'
            WHEN @vAreaProtegida LIKE 'Parque Interjurisdiccional%'   THEN 'Parque Interjurisdiccional'
            WHEN @vAreaProtegida LIKE 'Reserva Nacional%'             THEN 'Reserva Nacional'
            WHEN @vAreaProtegida LIKE 'Reserva Natural%'              THEN 'Reserva Natural'
            WHEN @vAreaProtegida LIKE 'Monumento Natural%'            THEN 'Monumento Natural'
            ELSE 'Otra Area Protegida'
        END;

        SELECT @vIdTipoParque = idTipoParque
        FROM parques.TipoParque
        WHERE descripcion = @vDescripcionTipo;

        -- Coordenadas aproximadas por region APN
        SET @vLat = CASE LOWER(LTRIM(RTRIM(@vRegion)))
            WHEN 'centro'             THEN CAST(-31.00 AS DECIMAL(9,6))
            WHEN 'centro este'        THEN CAST(-32.00 AS DECIMAL(9,6))
            WHEN 'nea'                THEN CAST(-27.00 AS DECIMAL(9,6))
            WHEN 'noa'                THEN CAST(-24.00 AS DECIMAL(9,6))
            WHEN 'patagonia norte'    THEN CAST(-41.00 AS DECIMAL(9,6))
            WHEN 'patagonia austral'  THEN CAST(-50.00 AS DECIMAL(9,6))
            WHEN 'mar argentino'      THEN CAST(-50.00 AS DECIMAL(9,6))
            ELSE                           CAST(-35.00 AS DECIMAL(9,6))
        END;

        SET @vLon = CASE LOWER(LTRIM(RTRIM(@vRegion)))
            WHEN 'centro'             THEN CAST(-67.50 AS DECIMAL(9,6))
            WHEN 'centro este'        THEN CAST(-60.50 AS DECIMAL(9,6))
            WHEN 'nea'                THEN CAST(-57.00 AS DECIMAL(9,6))
            WHEN 'noa'                THEN CAST(-65.00 AS DECIMAL(9,6))
            WHEN 'patagonia norte'    THEN CAST(-71.00 AS DECIMAL(9,6))
            WHEN 'patagonia austral'  THEN CAST(-70.00 AS DECIMAL(9,6))
            WHEN 'mar argentino'      THEN CAST(-58.00 AS DECIMAL(9,6))
            ELSE                           CAST(-65.00 AS DECIMAL(9,6))
        END;

        IF @vSuperficie IS NOT NULL AND @vSuperficie > 0 AND @vIdTipoParque IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM parques.Parque WHERE nombre = @vAreaProtegida)
            BEGIN
                -- Parque nuevo: usar SP de negocio (crea Ubicacion + Parque)
                BEGIN TRY
                    EXEC parques.RegistrarParque
                        @nombre       = @vAreaProtegida,
                        @superficie   = @vSuperficie,
                        @idTipoParque = @vIdTipoParque,
                        @direccion    = @vAreaProtegida,
                        @provincia    = @vRegion,
                        @latitud      = @vLat,
                        @longitud     = @vLon;
                    SET @vInsertadas += 1;
                END TRY
                BEGIN CATCH
                    PRINT 'Error al insertar parque "' + @vAreaProtegida + '": ' + ERROR_MESSAGE();
                END CATCH
            END
            ELSE
            BEGIN
                -- Parque existente: actualizar solo superficie si cambio
                SELECT @vIdParque    = idParque,
                       @vIdUbicacion = idUbicacion,
                       @vIdTipoParque = idTipoParque
                FROM parques.Parque
                WHERE nombre = @vAreaProtegida;

                BEGIN TRY
                    EXEC parques.Parque_Actualizar
                        @idParque     = @vIdParque,
                        @nombre       = @vAreaProtegida,
                        @superficie   = @vSuperficie,
                        @idTipoParque = @vIdTipoParque,
                        @idUbicacion  = @vIdUbicacion;
                    SET @vActualizadas += 1;
                END TRY
                BEGIN CATCH
                    PRINT 'Error al actualizar parque "' + @vAreaProtegida + '": ' + ERROR_MESSAGE();
                END CATCH
            END
        END

        FETCH NEXT FROM parque_cursor INTO @vRegion, @vAreaProtegida, @vHectareas;
    END
    CLOSE parque_cursor;
    DEALLOCATE parque_cursor;

    PRINT 'Importacion de areas protegidas completada.';
    PRINT 'Filas CSV procesadas: '  + CAST(@vFilas         AS VARCHAR);
    PRINT 'Parques insertados:   '  + CAST(@vInsertadas    AS VARCHAR);
    PRINT 'Parques actualizados: '  + CAST(@vActualizadas  AS VARCHAR);


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
                @valor              = @vValorSeed,
                @idParque           = @vIdParqueSeed,
                @idTipoVisitante    = @vIdTVSeed;
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
    VALUES ('parques.ImportarAreasProtegidas', @vRutaArchivo, @vFilas,
            @vInsertadas, @vActualizadas, 0);
END
GO

-- ============================================================
-- NOTA DE USO:
-- EXEC parques.ImportarAreasProtegidas
--     @vRutaArchivo = 'C:\TP_ParquesNacionales\datasets\aprn_h_ubicacion_superycatint_ha.csv';
-- ============================================================

PRINT 'SP parques.ImportarAreasProtegidas creado correctamente.';
GO

PRINT '-- Caso exitoso: importacion CSV APN (separador ;)';
-- RESULTADO ESPERADO: tipos de parque creados, parques insertados con superficie en ha
EXEC parques.ImportarAreasProtegidas
    @vRutaArchivo = 'C:\Users\fran0\Downloads\com2900-grupo03-parques-nacionales-master\com2900-grupo03-parques-nacionales-master\Archivos_Finales\Entrega_6\datasets\datos-gob-ar\aprn_h_ubicacion_superycatint_ha.csv';
WAITFOR DELAY '00:00:01';

SELECT idTipoParque, descripcion
FROM parques.TipoParque
ORDER BY descripcion;

SELECT TOP 10
    p.nombre,
    tp.descripcion AS tipo,
    p.superficie   AS hectareas,
    u.provincia    AS region
FROM parques.Parque p
JOIN parques.TipoParque tp ON tp.idTipoParque = p.idTipoParque
JOIN parques.Ubicacion  u  ON u.idUbicacion   = p.idUbicacion
ORDER BY p.superficie DESC;
