/* =====================================================================
   RQ-IT · Seed del proyecto DATA WAREHOUSE (ERP -> GOLD)
   Genera el proyecto + tareas (principales=fases, secundarias=actividades)
   Inicio: 2026-05-21. Fechas en días hábiles (lun-vie), tope del estimado.
   Requiere: dbo.Proyectos, dbo.ProyectoTareas (+ TareaPadreId).
   ===================================================================== */
USE [RQ-IT];
GO
SET NOCOUNT ON;
DECLARE @proj INT, @f INT;
INSERT INTO dbo.Proyectos (Nombre, Descripcion, Responsable, FechaInicio, FechaFin, Estado)
VALUES (N'DATA WAREHOUSE (ERP -> GOLD)', N'Estimación de esfuerzo: ~40-55.5 días (fases 1-6).', N'Amilcar Roa', '2026-05-21', '2026-08-07', N'Activo');
SET @proj = SCOPE_IDENTITY();

INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, EsHito, Orden)
VALUES (@proj, N'FASE 1 - INFRAESTRUCTURA INICIAL (FABRIC/AZURE)', '2026-05-21', '2026-05-28', 0, 0, 1);
SET @f = SCOPE_IDENTITY();
INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, TareaPadreId, EsHito, Orden) VALUES
(@proj, N'CONFIGURACIÓN DE CAPACIDAD FABRIC (F2 - F8) Y TENANT PARA SERVICE PRINCIPAL', '2026-05-21', '2026-05-21', 0, @f, 0, 2),
(@proj, N'ON-PREMISES DATA GATEWAY (INSTALACIÓN, CONFIGURACIÓN Y CONECTIVIDAD A EC2)', '2026-05-22', '2026-05-22', 0, @f, 0, 3),
(@proj, N'5 MIRRORED DATABASES VÍA CDC (ERP, ERP_MPC, ERP_POS, ERP_OSM, SIGOCLIENTE)', '2026-05-25', '2026-05-26', 0, @f, 0, 4),
(@proj, N'SERVICE PRINCIPAL Y AUTENTICACIÓN PARA PIPELINES', '2026-05-27', '2026-05-27', 0, @f, 0, 5),
(@proj, N'LAKEHOUSE LH_GOLD + ORGANIZACIÓN DE ESQUEMAS Y SHORTCUTS', '2026-05-28', '2026-05-28', 0, @f, 0, 6);

INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, EsHito, Orden)
VALUES (@proj, N'FASE 2 - RÉPLICA TRANSACCIONAL SQL SERVER', '2026-05-29', '2026-06-03', 0, 0, 7);
SET @f = SCOPE_IDENTITY();
INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, TareaPadreId, EsHito, Orden) VALUES
(@proj, N'CONFIGURACIÓN DE PUBLICACIONES/SUSCRIPCIONES (100+ TABLAS EN 5 BASES)', '2026-05-29', '2026-06-01', 0, @f, 0, 8),
(@proj, N'SNAPSHOT INICIAL Y SINCRONIZACIÓN COMPLETA', '2026-06-02', '2026-06-02', 0, @f, 0, 9),
(@proj, N'VERIFICACIÓN, AJUSTES DE RENDIMIENTO Y RESOLUCIÓN DE SINCRONIZACIÓN', '2026-06-03', '2026-06-03', 0, @f, 0, 10);

INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, EsHito, Orden)
VALUES (@proj, N'FASE 3 - MODELO DIMENSIONAL EN FABRIC/PYSPARK', '2026-06-04', '2026-06-29', 0, 0, 11);
SET @f = SCOPE_IDENTITY();
INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, TareaPadreId, EsHito, Orden) VALUES
(@proj, N'7 DIMENSIONES INICIALES (DIMAREA, DIMESTATUS, DIMFECHA/DIMTIEMPO, DIMSUCURSAL, DIMPROVEEDOR, DIMCLIENTE, DIMPRODUCTO)', '2026-06-04', '2026-06-11', 0, @f, 0, 12),
(@proj, N'FACTVENTAS (DISEÑO NAIVE + REDISEÑO CON PARTICIÓN/WATERMARK)', '2026-06-12', '2026-06-16', 0, @f, 0, 13),
(@proj, N'6 DIMENSIONES NUEVAS DE COMPRAS (PATRÓN DE PLACEHOLDERS)', '2026-06-17', '2026-06-18', 0, @f, 0, 14),
(@proj, N'FACTCOMPRAS', '2026-06-19', '2026-06-22', 0, @f, 0, 15),
(@proj, N'FACTMOVIMIENTOS + FACTINVENTARIORESUMEN (EXPLORACIÓN DE TRIGGERS, DESCARTADA)', '2026-06-23', '2026-06-24', 0, @f, 0, 16),
(@proj, N'DEPURACIÓN TRANSVERSAL (CACHÉ, NOT NULL, ZORDER, CAPACIDAD, MEMORIA POWER BI)', '2026-06-25', '2026-06-29', 0, @f, 0, 17);

INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, EsHito, Orden)
VALUES (@proj, N'FASE 4 - PIVOTE A SQL SERVER Y RECONSTRUCCIÓN COMPLETA', '2026-06-30', '2026-08-03', 0, 0, 18);
SET @f = SCOPE_IDENTITY();
INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, TareaPadreId, EsHito, Orden) VALUES
(@proj, N'ANÁLISIS DE DECISIÓN (COSTO/BENEFICIO SQL SERVER VS. FABRIC)', '2026-06-30', '2026-06-30', 0, @f, 0, 19),
(@proj, N'15 DIMENSIONES RECONSTRUIDAS EN T-SQL', '2026-07-01', '2026-07-06', 0, @f, 0, 20),
(@proj, N'FACTCOMPRAS, FACTINVENTARIORESUMEN Y FACTVENTAS (3 ITERACIONES: TRIGGERS - MERGE CON VENTANA - OPTIMIZACIÓN)', '2026-07-07', '2026-07-13', 0, @f, 0, 21),
(@proj, N'FACTORDENESCOMPRAS + 2 DIMENSIONES + TABLA PUENTE', '2026-07-14', '2026-07-15', 0, @f, 0, 22),
(@proj, N'FACTRECEPCIONES + 2 DIMENSIONES (CÁLCULO DE DURACIÓN)', '2026-07-16', '2026-07-17', 0, @f, 0, 23),
(@proj, N'FACTAJUSTESINVENTARIO + 2 DIMENSIONES', '2026-07-20', '2026-07-20', 0, @f, 0, 24),
(@proj, N'FACTAJUSTESMERMA', '2026-07-21', '2026-07-21', 0, @f, 0, 25),
(@proj, N'FACTCONFIGPRECIOS + FACTCONFIGPRECIOSHISTORICO (PURGA DE 90 DÍAS)', '2026-07-22', '2026-07-23', 0, @f, 0, 26),
(@proj, N'FACTTRANSFERENCIAS + 3 DIMENSIONES (JOIN DE 3 NIVELES)', '2026-07-24', '2026-07-27', 0, @f, 0, 27),
(@proj, N'FACTDEVOLUCIONES + 1 DIMENSIÓN + AJUSTE DE DIMFECHA', '2026-07-28', '2026-07-29', 0, @f, 0, 28),
(@proj, N'INCIDENTES DE PRODUCCIÓN (CDC, TRIGGERS, DUPLICADOS, BUGS DE TIPO DE DATO)', '2026-07-30', '2026-08-03', 0, @f, 0, 29);

INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, EsHito, Orden)
VALUES (@proj, N'FASE 5 - GOBERNANZA Y ACCESO A POWER BI', '2026-08-04', '2026-08-04', 0, 0, 30);
SET @f = SCOPE_IDENTITY();
INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, TareaPadreId, EsHito, Orden) VALUES
(@proj, N'FIXED IDENTITY VS. SSO Y ACCESO SIN EXPONER EL WORKSPACE', '2026-08-04', '2026-08-04', 0, @f, 0, 31);

INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, EsHito, Orden)
VALUES (@proj, N'FASE 6 - MÓDULO FINANCIERO ERP_FMS (ARRANQUE)', '2026-08-05', '2026-08-07', 0, 0, 32);
SET @f = SCOPE_IDENTITY();
INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, TareaPadreId, EsHito, Orden) VALUES
(@proj, N'ANÁLISIS DEL SCRIPT COMPLETO (149 TABLAS, 12 ESQUEMAS)', '2026-08-05', '2026-08-05', 0, @f, 0, 33),
(@proj, N'FACTMOVIMIENTOSCONTABLES + 6 DIMENSIONES NUEVAS (ESQUEMA FINANCIAL)', '2026-08-06', '2026-08-07', 0, @f, 0, 34);
GO