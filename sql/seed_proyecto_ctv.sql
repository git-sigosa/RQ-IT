/* =====================================================================
   RQ-IT · Seed del proyecto CTV IP - SIGO - CPA
   Responsable: Amilcar.Roa   Inicio: 2026-08-13
   4 tareas secuenciales (2 días hábiles c/u; ajustables en el Gantt).
   Requiere: dbo.Proyectos, dbo.ProyectoTareas.
   ===================================================================== */
USE [RQ-IT];
GO
SET NOCOUNT ON;
DECLARE @proj INT;
INSERT INTO dbo.Proyectos (Nombre, Descripcion, Responsable, FechaInicio, FechaFin, Estado)
VALUES (N'CTV IP - SIGO - CPA', N'Instalación CCTV IP (18 canales) - cableado y configuración.', N'Amilcar.Roa', '2026-08-13', '2026-08-24', N'Activo');
SET @proj = SCOPE_IDENTITY();

INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, Responsable, EsHito, Orden) VALUES
(@proj, N'Cableado 5 de 18',          '2026-08-13', '2026-08-14', 0, N'Amilcar.Roa', 0, 1),
(@proj, N'Cableado 10 de 18 Canales', '2026-08-17', '2026-08-18', 0, N'Amilcar.Roa', 0, 2),
(@proj, N'Cableado 15 de 18 Canales', '2026-08-19', '2026-08-20', 0, N'Amilcar.Roa', 0, 3),
(@proj, N'Instalacion/Configuracion', '2026-08-21', '2026-08-24', 0, N'Amilcar.Roa', 0, 4);
GO
