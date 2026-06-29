-- =============================================
-- Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Grupo: 03
-- Integrantes: Ruiz Santillan, Facundo - Lago, Franco Nehuen - Del Vecchio, Fabrizio - Ocampos, Horacio.
-- Fecha: 15/06/2026
-- Descripcion: Testing del módulo de seguridad: cifrado, descifrado
--              y control de acceso por roles (positivo y negativo).
-- =============================================

USE ParquesNacionales;
GO

-- =====================================================
-- TEST 1: Verificar que el dato cifrado es ilegible
-- =====================================================
PRINT '--- TEST 1: Verificar columna cifrada en Guia ---';
-- Resultado esperado: dniCifrado se muestra en binario (0x...), no en texto plano
SELECT TOP 3 dni, dniCifrado FROM personal.Guia;
GO

-- =====================================================
-- TEST 2: Descifrado mediante SP - Guia
-- =====================================================
PRINT '--- TEST 2: Descifrado de DNI de Guia mediante SP ---';
-- Resultado esperado: se muestra apyn, dniDescifrado (igual al dni original), especialidad, titulo
EXEC personal.Guia_ObtenerDniDescifrado @dniBusqueda = 30111222;
GO

-- =====================================================
-- TEST 3: Descifrado mediante SP - Guardaparque
-- =====================================================
PRINT '--- TEST 3: Descifrado de DNI de Guardaparque mediante SP ---';
-- Resultado esperado: se muestra apyn, email, telefono, localidad, fechaNacimiento, dniDescifrado
-- Ajustar el DNI de busqueda a uno existente en la tabla Guardaparque
EXEC personal.Guardaparque_ObtenerDniDescifrado @dniBusqueda = 25333444;
GO

-- =====================================================
-- TEST 4: Descifrado mediante SP - Empresa
-- =====================================================
PRINT '--- TEST 4: Descifrado de CUIT de Empresa mediante SP ---';
-- Resultado esperado: se muestra razonSocial, contacto, email, telefono, cuitDescifrado
-- Ajustar el CUIT de busqueda a uno existente en la tabla Empresa
EXEC concesiones.Empresa_ObtenerCuitDescifrado @cuitBusqueda = '30777788889';
GO

-- =====================================================
-- TEST 5: rol_consultas NO puede leer la tabla Guia directamente
-- =====================================================
PRINT '--- TEST 5: rol_consultas sin acceso directo a tabla Guia ---';
EXECUTE AS USER = 'usr_consultas_demo';
BEGIN TRY
    SELECT * FROM personal.Guia;
    PRINT 'ERROR: rol_consultas pudo ver la tabla (SEGURIDAD FALLIDA)';
END TRY
BEGIN CATCH
    PRINT 'EXITO: Acceso denegado a la tabla Guia (SEGURIDAD OK) - ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

-- =====================================================
-- TEST 6: rol_consultas NO puede leer la tabla Empresa directamente
-- =====================================================
PRINT '--- TEST 6: rol_consultas sin acceso directo a tabla Empresa ---';
EXECUTE AS USER = 'usr_consultas_demo';
BEGIN TRY
    SELECT * FROM concesiones.Empresa;
    PRINT 'ERROR: rol_consultas pudo ver tabla Empresa (SEGURIDAD FALLIDA)';
END TRY
BEGIN CATCH
    PRINT 'EXITO: Acceso denegado a tabla Empresa (SEGURIDAD OK) - ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

-- =====================================================
-- TEST 7: rol_consultas SI puede acceder al dato vía SP de descifrado
-- =====================================================
PRINT '--- TEST 7: rol_consultas accede al DNI solo mediante el SP autorizado ---';
EXECUTE AS USER = 'usr_consultas_demo';
BEGIN TRY
    EXEC personal.Guia_ObtenerDniDescifrado @dniBusqueda = 30111222;
    PRINT 'EXITO: rol_consultas pudo descifrar via SP autorizado (SEGURIDAD OK)';
END TRY
BEGIN CATCH
    PRINT 'ERROR: rol_consultas no pudo ejecutar el SP autorizado - ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

-- =====================================================
-- TEST 8 (positivo): rol_admin SI puede ver la tabla Guia directamente
-- =====================================================
PRINT '--- TEST 8: rol_admin con acceso total (control) ---';
EXECUTE AS USER = 'usr_admin_demo';
BEGIN TRY
    SELECT TOP 1 * FROM personal.Guia;
    PRINT 'EXITO: rol_admin pudo ver la tabla Guia (PERMISOS OK)';
END TRY
BEGIN CATCH
    PRINT 'ERROR: rol_admin no pudo acceder a la tabla Guia - ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

-- =====================================================
-- TEST 9: rol_importador SI puede ejecutar SP de importación
-- =====================================================
PRINT '--- TEST 9: rol_importador con permiso sobre SP de importacion ---';
EXECUTE AS USER = 'usr_importador_demo';
BEGIN TRY
    EXEC parques.ImportarFeriados @vAnio = 2026;
    PRINT 'EXITO: rol_importador pudo ejecutar el SP de importacion (PERMISOS OK)';
END TRY
BEGIN CATCH
    PRINT 'ERROR: rol_importador no pudo ejecutar el SP - ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO

-- =====================================================
-- TEST 10: rol_importador NO puede ejecutar SP de otro modulo (negocio de ventas)
-- =====================================================
PRINT '--- TEST 10: rol_importador sin acceso a esquema de ventas ---';
EXECUTE AS USER = 'usr_importador_demo';
BEGIN TRY
    SELECT * FROM ventas.TicketVenta;
    PRINT 'ERROR: rol_importador pudo ver ventas (SEGURIDAD FALLIDA)';
END TRY
BEGIN CATCH
    PRINT 'EXITO: Acceso denegado a esquema ventas (SEGURIDAD OK) - ' + ERROR_MESSAGE();
END CATCH
REVERT;
GO