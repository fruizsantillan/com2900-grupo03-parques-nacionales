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