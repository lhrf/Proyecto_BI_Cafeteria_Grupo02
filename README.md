# Proyecto BI Cafetería – Grupo 02

Solución de Inteligencia de Negocios para el análisis de ventas, cobros, delivery y abastecimiento de una cadena de cafeterías en Trujillo.
Curso **Base de Datos Avanzadas y Big Data** – Universidad Privada del Norte – Período 2026-2 (T2).

**Integrantes:** Llajaruna Mayzundo, A.; Ramos Zamora, E.; Rodriguez Briceño, G.; Rodriguez Flores, L.; Vasquez Barrios, A.

## Arquitectura

```
Cafeteria (SQL Server, OLTP)
   └─ SSIS: Package.dtsx (catálogo SSISDB) ──► DM_Cafeteria (esquema galaxia: 9 dimensiones + 4 hechos)
                                                 └─ SSAS multidimensional: Cubo_Grupo02 ──► Power BI (conexión dinámica)
Agente SQL Server: trabajo «Carga_Cafeteria_Diaria» (diario 23:00) = paso 1 ETL + paso 2 Process Full del cubo
```

## Estructura del repositorio

| Carpeta | Contenido |
|---|---|
| `01_Fuente/` | `Cafeteria.sql`: crea la base transaccional y genera 33 meses de datos (determinista) |
| `02_DataMart/` | `DM_Cafeteria.sql`: data mart, tabla `ETL_Control` y procedimientos |
| `03_ETL/` | Solución SSIS `BI_Cafeteria_Grupo02` (proyecto `ETL_Cafeteria_Grupo02`, `Package.dtsx`) |
| `04_Cubo/` | Solución SSAS `Cubo_Grupo02` (origen de datos, DSV, dimensiones y cubo) |
| `05_PowerBI/` | `Dashboard_Cafeteria_Grupo02.pbix` (5 páginas) |
| `06_Automatizacion/` | `Job_Carga_Cafeteria_Diaria.sql`: script del trabajo del Agente |
| `07_Pruebas/` | `validacion.sql`: conciliación y coherencia de negocio |
| `08_Evidencias/` | Capturas numeradas como las figuras del informe |
| `docs/` | Informe final y guías paso a paso (cubo y automatización) |

## Requisitos

- SQL Server 2025 con Database Engine, Integration Services, Analysis Services (modo **multidimensional**) y Agente SQL Server, en la instancia `localhost` (no LocalDB).
- Visual Studio 2026 con las extensiones de proyectos de Integration Services y Analysis Services.
- SQL Server Management Studio y Power BI Desktop.
- Microsoft OLE DB Driver for SQL Server (MSOLEDBSQL).

## Cómo reproducir

1. En SSMS (localhost) ejecutar `01_Fuente/Cafeteria.sql` y luego `02_DataMart/DM_Cafeteria.sql`.
2. Abrir `03_ETL/.../BI_Cafeteria_Grupo02.slnx`, verificar que las conexiones apunten a `localhost` y desplegar el proyecto en `SSISDB\Cafeteria`.
3. Abrir `04_Cubo/.../Cubo_Grupo02.slnx`; en el origen de datos usar la suplantación «Utilizar la cuenta de servicio»; implementar y procesar.
4. Conceder `db_datareader` sobre `DM_Cafeteria` a `NT Service\MSSQLServerOLAPService` y agregar `NT Service\SQLSERVERAGENT` como administrador de Analysis Services.
5. Ejecutar `06_Automatizacion/Job_Carga_Cafeteria_Diaria.sql` para crear el trabajo y ejecutarlo una vez.
6. Ejecutar `07_Pruebas/validacion.sql` y comparar con los valores esperados.
7. Abrir `05_PowerBI/Dashboard_Cafeteria_Grupo02.pbix` y actualizar.

El detalle campo por campo está en `docs/Guia_Cubo_Cafeteria.pdf` y `docs/Guia_Automatizacion_Cafeteria.pdf`.

## Valores esperados (dataset corregido)

| Control | Valor |
|---|---|
| Filas de hechos (ETL_Control) | 179 644 (FactVenta 105 905; FactPago 42 376; FactDelivery 10 616; FactRecepcionProducto 20 747) |
| Venta neta | S/ 3 726 299,31 |
| Pedidos / Ticket promedio | 35 310 / S/ 105,53 |
| % Margen estimado | 52,15 % |
| Monto cobrado | S/ 3 784 594,31 (= venta neta + S/ 58 295,00 de envío) |
| Compras / costo de ventas | 1,12 |

## Notas

- Los datos son académicos y ficticios; no hay contraseñas en los archivos (autenticación de Windows).
- Las carpetas `bin/`, `obj/` y `.vs/` no se versionan: se regeneran al compilar en Visual Studio.
