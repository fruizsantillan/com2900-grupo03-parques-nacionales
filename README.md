# Sistema de Gestión de Parques Nacionales

**Universidad Nacional de La Matanza**  
**Asignatura:** 3641 – Bases de Datos Aplicada  
**Carrera:** Ingeniería en Informática  
**Comisión:** 01-2900 | Martes Noche  
**Grupo:** 03

---

## Integrantes

| Apellido y Nombre | GitHub |
|---|---|
| Del Vecchio, Fabrizio | fabrid022-cmyk |
| Ocampos, Horacio | — |
| Ruiz Santillán, Facundo | fruizsantillan |
| Lago, Franco Nehuen | — |

---

## Descripción del Proyecto

Sistema centralizado para la gestión de operaciones de la Administración de Parques Nacionales. Cubre los módulos de gestión de parques, venta de entradas, atracciones y tours, concesiones, personal (guardaparques y guías) e importación de datos externos.

Motor de base de datos: **Microsoft SQL Server 2022**

---

## Estructura del Repositorio

```
📁 Entregas/
    📁 Entrega3_DER/
    📁 Entrega4_Instalacion/
    📁 Entrega5_BaseDeDatos/
    📁 Entrega6_Importacion/
    📁 Entrega7_Reportes/
    📁 Entrega8_SeguridadRespaldo/
    📁 Entrega9_Final/

📁 Scripts/
    📄 01_CreacionDB.sql           -- Creación de la base de datos y esquemas
    📄 02_Tablas.sql               -- Creación de tablas y restricciones
    📄 03_SP_ABM.sql               -- Stored Procedures de alta, baja y modificación
    📄 04_SP_Negocio.sql           -- Stored Procedures de lógica de negocio
    📄 05_Vistas.sql               -- Vistas del sistema
    📄 06_Funciones.sql            -- Funciones escalares y de tabla
    📄 07_Importacion.sql          -- Stored Procedures de importación de datos externos
    📄 08_Reportes.sql             -- Stored Procedures de reportes
    📄 09_Seguridad.sql            -- Roles, permisos y cifrado
    📄 10_SeedData.sql             -- Datos de prueba (juego de datos mínimo)

📁 Testing/
    📄 TEST_SP_ABM.sql             -- Scripts de testing para SPs ABM
    📄 TEST_SP_Negocio.sql         -- Scripts de testing para lógica de negocio
    📄 TEST_Importacion.sql        -- Scripts de testing para importación

📁 Documentacion/
    📄 NormasNomenclatura.md       -- Norma de nomenclatura del grupo
    📄 DER.png                  -- Diagrama Entidad-Relación

📄 README.md
```

---

## Norma de Nomenclatura

| Objeto | Convención | Ejemplo |
|---|---|---|
| Esquema | minúsculas | `parques` |
| Tablas | PascalCase, singular | `TicketVenta`, `TipoParque` |
| Columnas | camelCase | `idParque`, `fechaInicio` |
| Primary Key | `id` + NombreTabla | `idParque` |
| Foreign Key | mismo nombre que la PK referenciada | `idParque` |
| Stored Procedures ABM | `sp_Tabla_Accion` | `sp_Parque_Insertar` |
| Stored Procedures negocio | `sp_DescripcionOperacion` | `sp_RegistrarVentaEntrada` |
| Parámetros SP | `@` + camelCase | `@idParque`, `@fechaInicio` |
| Variables locales | `@v` + camelCase | `@vTotal`, `@vMensajeError` |
| Vistas | `vw_` + PascalCase | `vw_ConcesionesVigentes` |
| Funciones | `fn_` + PascalCase | `fn_ObtenerPrecioVigente` |
| PK constraint | `PK_Tabla` | `PK_Parque` |
| FK constraint | `FK_TablaOrigen_TablaDestino` | `FK_Tour_Parque` |
| UNIQUE constraint | `UQ_Tabla_Campo` | `UQ_Parque_nombre` |
| CHECK constraint | `CHK_Tabla_Campo` | `CHK_Concesion_fechas` |
| Índices | `IX_Tabla_Campo` | `IX_TicketVenta_fechaHora` |

---

## Cabecera de Scripts

Todos los scripts deben comenzar con el siguiente comentario:

```sql
-- =============================================
-- Universidad: Universidad Nacional de La Matanza
-- Materia: 3641 - Bases de Datos Aplicada
-- Comisión: 01-2900 | Grupo 03
-- Integrantes: Del Vecchio Fabrizio, Ocampos Horacio,
--              Ruiz Santillán Facundo, Lago Franco Nehuen
-- Fecha: DD/MM/AAAA
-- Descripción: [objetivo del script]
-- =============================================
```

---

## Entregas

| # | Entrega | Estado |
|---|---|---|
| 1 | Investigación y costos On-Premise | ✅ Entregado |
| 2 | Investigación y costos Cloud | ✅ Entregado |
| 3 | Diagrama de Entidad-Relación | ✅ Entregado |
| 4 | Instalación y Configuración | ✅ Entregado |
| 5 | Base de Datos | — |
| 6 | Procesos de Importación | — |
| 7 | Reportes | — |
| 8 | Seguridad y Respaldo | — |
| 9 | Entrega Final | — |

---

## Módulos del Sistema y Responsables

| Módulo | Responsable | Tablas principales |
|---|---|---|
| Base + Parques + Personal | Lago, Franco Nehuen | `Parque`, `TipoParque`, `Ubicacion`, `Guardaparque`, `AsignacionGuardaparque` |
| Guías + Tours + Atracciones | Del Vecchio, Fabrizio | `Guia`, `AsignacionGuia`, `Tour`, `Atraccion` |
| Ventas + Precios | Ocampos, Horacio | `TicketVenta`, `LineaVenta`, `PrecioEntrada`, `TipoVisitante` |
| Concesiones + Empresas | Ruiz Santillán, Facundo | `Concesion`, `TipoDeConsesion`, `Empresa`, `PagoConcesion` |

---
