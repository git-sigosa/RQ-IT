/* =====================================================================
   RQ-IT · Seed de proyectos de instalación de cámaras (CCTV)
   5 proyectos. Cada uno con:
     - Tarea principal 1: INSPECCIÓN
     - Tarea principal 2: SOLICITUD DE MATERIALES Y EQUIPOS
         · Subtarea: PROCURA
   Nombres en MAYÚSCULA. Requiere: dbo.Proyectos, dbo.ProyectoTareas
   (con columna TareaPadreId). Idempotente: no duplica si ya existen.
   Fechas/responsables quedan en blanco para ajustarlos en el Gantt.
   ===================================================================== */
USE [RQ-IT];
GO
SET NOCOUNT ON;

/* Clasificación de proyectos (Tipo / Cliente) — idempotente */
IF COL_LENGTH('dbo.Proyectos', 'Tipo') IS NULL
    ALTER TABLE dbo.Proyectos ADD Tipo NVARCHAR(60) NULL;
IF COL_LENGTH('dbo.Proyectos', 'Cliente') IS NULL
    ALTER TABLE dbo.Proyectos ADD Cliente NVARCHAR(120) NULL;
GO

DECLARE @p INT, @m2 INT;

/* helper conceptual: cada bloque inserta el proyecto (si no existe) y sus 3 tareas */

/* 1 -------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Proyectos WHERE Nombre = N'INSTALACIÓN DE CÁMARAS PTZ EN TRES SUPERMERCADOS')
BEGIN
    INSERT INTO dbo.Proyectos (Nombre, Descripcion, Estado, Tipo, Cliente)
    VALUES (N'INSTALACIÓN DE CÁMARAS PTZ EN TRES SUPERMERCADOS', N'Instalación de cámaras PTZ en tres supermercados.', N'Activo', N'CCTV', N'Supermercados');
    SET @p = SCOPE_IDENTITY();
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'INSPECCIÓN', NULL, 0, 0, 1);
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'SOLICITUD DE MATERIALES Y EQUIPOS', NULL, 0, 0, 2);
    SET @m2 = SCOPE_IDENTITY();
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'PROCURA', @m2, 0, 0, 1);
END

/* 2 -------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Proyectos WHERE Nombre = N'INSTALACIÓN DE CÁMARA EN RECEPCIÓN SIGO BOCA DE RÍO')
BEGIN
    INSERT INTO dbo.Proyectos (Nombre, Descripcion, Estado, Tipo, Cliente)
    VALUES (N'INSTALACIÓN DE CÁMARA EN RECEPCIÓN SIGO BOCA DE RÍO', N'Instalación de cámara en recepción, SIGO Boca de Río.', N'Activo', N'CCTV', N'SIGO Boca de Río');
    SET @p = SCOPE_IDENTITY();
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'INSPECCIÓN', NULL, 0, 0, 1);
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'SOLICITUD DE MATERIALES Y EQUIPOS', NULL, 0, 0, 2);
    SET @m2 = SCOPE_IDENTITY();
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'PROCURA', @m2, 0, 0, 1);
END

/* 3 -------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Proyectos WHERE Nombre = N'INSTALACIÓN DE CÁMARA, ÁREA DE PLANTA Y ESTACIONAMIENTO UCS')
BEGIN
    INSERT INTO dbo.Proyectos (Nombre, Descripcion, Estado, Tipo, Cliente)
    VALUES (N'INSTALACIÓN DE CÁMARA, ÁREA DE PLANTA Y ESTACIONAMIENTO UCS', N'Instalación de cámaras en área de planta y estacionamiento, UCS.', N'Activo', N'CCTV', N'UCS');
    SET @p = SCOPE_IDENTITY();
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'INSPECCIÓN', NULL, 0, 0, 1);
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'SOLICITUD DE MATERIALES Y EQUIPOS', NULL, 0, 0, 2);
    SET @m2 = SCOPE_IDENTITY();
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'PROCURA', @m2, 0, 0, 1);
END

/* 4 -------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Proyectos WHERE Nombre = N'INSTALACIÓN DE CÁMARAS CHILLER PORLAMAR')
BEGIN
    INSERT INTO dbo.Proyectos (Nombre, Descripcion, Estado, Tipo, Cliente)
    VALUES (N'INSTALACIÓN DE CÁMARAS CHILLER PORLAMAR', N'Instalación de cámaras, Chiller Porlamar.', N'Activo', N'CCTV', N'Porlamar');
    SET @p = SCOPE_IDENTITY();
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'INSPECCIÓN', NULL, 0, 0, 1);
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'SOLICITUD DE MATERIALES Y EQUIPOS', NULL, 0, 0, 2);
    SET @m2 = SCOPE_IDENTITY();
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'PROCURA', @m2, 0, 0, 1);
END

/* 5 -------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM dbo.Proyectos WHERE Nombre = N'INSTALACIÓN DE CÁMARAS ANDENES CPA')
BEGIN
    INSERT INTO dbo.Proyectos (Nombre, Descripcion, Estado, Tipo, Cliente)
    VALUES (N'INSTALACIÓN DE CÁMARAS ANDENES CPA', N'Instalación de cámaras en andenes, CPA.', N'Activo', N'CCTV', N'CPA');
    SET @p = SCOPE_IDENTITY();
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'INSPECCIÓN', NULL, 0, 0, 1);
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'SOLICITUD DE MATERIALES Y EQUIPOS', NULL, 0, 0, 2);
    SET @m2 = SCOPE_IDENTITY();
    INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, TareaPadreId, Progreso, EsHito, Orden) VALUES (@p, N'PROCURA', @m2, 0, 0, 1);
END
GO

/* Verificación rápida */
SELECT p.Id, p.Nombre AS Proyecto, t.Orden, t.Nombre AS Tarea,
       CASE WHEN t.TareaPadreId IS NULL THEN N'Principal' ELSE N'Subtarea' END AS Nivel
FROM dbo.Proyectos p
JOIN dbo.ProyectoTareas t ON t.ProyectoId = p.Id
WHERE p.Nombre IN (
    N'INSTALACIÓN DE CÁMARAS PTZ EN TRES SUPERMERCADOS',
    N'INSTALACIÓN DE CÁMARA EN RECEPCIÓN SIGO BOCA DE RÍO',
    N'INSTALACIÓN DE CÁMARA, ÁREA DE PLANTA Y ESTACIONAMIENTO UCS',
    N'INSTALACIÓN DE CÁMARAS CHILLER PORLAMAR',
    N'INSTALACIÓN DE CÁMARAS ANDENES CPA'
)
ORDER BY p.Id, ISNULL(t.TareaPadreId, 0), t.Orden;
GO
