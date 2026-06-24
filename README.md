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
| Ocampos, Horacio | horacioocampos |
| Ruiz Santillán, Facundo | fruizsantillan |
| Lago, Franco Nehuen | LagooFran |

---

## Descripción del Proyecto

Sistema centralizado para la gestión de operaciones de la Administración de Parques Nacionales. Cubre los módulos de gestión de parques, venta de entradas, atracciones y tours, concesiones, personal (guardaparques y guías) e importación de datos externos.

Motor de base de datos: **Microsoft SQL Server 2022**

---

## Estructura del Repositorio

```
📁 com2900-grupo03-parques-nacionales/
   📄 .gitignore
   📄 README.md
   
   📁 Entrega3_DER/
      📄 db_diagram.txt
      📄 E3_Com2900.pdf
      
   📁 Entrega4_Instalacion/
      📄 Com2900_Grupo03_E4.docx
      
   📁 Entrega5_BaseDeDatos/
      📁 00_eliminacion_db/
         📄 00_eliminacion_db.sql
      📁 01_creacion_db/
         📄 01_creacion_db_schemas.sql
      📁 02_tablas/
         📄 02_tablas_concesiones.sql
         📄 02_tablas_guias_tour_atracciones.sql
         📄 02_tablas_parque_guardaparque.sql
         📄 02_tablas_ventas.sql
      📁 03_abm/
         📄 03_abm_concesiones.sql
         📄 03_abm_guias_tour_atracciones.sql
         📄 03_abm_parque_guardaparque.sql
         📄 03_abm_ventas.sql
      📁 04_logica_negocio/
         📄 04_negocio_concesiones.sql
         📄 04_negocio_guias_tour_atracciones.sql
         📄 04_negocio_parque_guardaparque.sql
         📄 04_negocio_ventas.sql
      📁 05_testing/
         📄 05_testing_abm_concesiones.sql
         📄 05_testing_abm_ventas.sql
         📄 05_testing_guias_tour_atracciones.sql
         📄 05_testing_negocio_concesiones.sql
         📄 05_testing_negocio_parque_guardaparque.sql
         📄 05_testing_negocio_ventas.sql
         📄 05_testing_parque_guardaparque.sql
      📁 06_unificados/
         📄 06_unificados_abm.sql
         📄 06_unificados_negocio.sql
         📄 06_unificados_tablas.sql
         📄 entrega5_testing.sql
         📄 entrega5_unificado.sql

   📁 Entrega6_Importacion/
      📄 entrega6_importacion.sql
      📄 entrega6_testing.sql
      📄 entrega6_unificado.sql
      📁 01_staging/
         📄 01_tablas_staging.sql
      📁 02_importacion/
         📄 02_import_api_feriados.sql
         📄 02_import_api_tipocambio.sql
         📄 02_import_csv_visitas.sql
         📄 02_import_csv_visitas_anual.sql
         📄 02_import_csv_visitas_region.sql
         📄 02_import_csv_wdpa.sql
      📁 03_datos_iniciales/
         📄 03_import_csv_areas_protegidas.sql
         📄 03_seed_ventas.sql
      📁 04_testing/
         📄 04_testing_importacion.sql
      📁 datasets/
         📁 datos-gob-ar/
            📄 aprn_h_ubicacion_superycatint_ha.csv
            📄 aprn_i_visitas_porc_2024.csv
            📄 parques_nac.pdf
            📄 visitas-residentes-y-no-residentes-por-region.csv
            📄 visitas-residentes-y-no-residentes.csv
         📁 protected-planet/
            📁 WDPA_WDOECM_Jun2026_Public_ARG_csv/
               📄 WDPA_sources_Jun2026.csv
               📄 WDPA_WDOECM_Jun2026_Public_ARG_csv.csv
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
| Stored Procedures ABM | `Tabla_Accion` | `Parque_Insertar` |
| Stored Procedures negocio | `DescripcionOperacion` | `RegistrarVentaEntrada` |
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
| 5 | Base de Datos | ✅ Entregado |
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
