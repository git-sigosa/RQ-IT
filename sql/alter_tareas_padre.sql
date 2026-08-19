/* =====================================================================
   RQ-IT · Jerarquía de tareas del Gantt
   Agrega TareaPadreId a dbo.ProyectoTareas para tareas
   Principales (padre NULL) y Secundarias (padre = Id de una principal).
   Ejecuta UNA vez. Idempotente.
   ===================================================================== */

USE [RQ-IT];
GO

IF COL_LENGTH('dbo.ProyectoTareas', 'TareaPadreId') IS NULL
    ALTER TABLE dbo.ProyectoTareas ADD TareaPadreId INT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_ProyectoTareas_Padre')
    ALTER TABLE dbo.ProyectoTareas
      ADD CONSTRAINT FK_ProyectoTareas_Padre FOREIGN KEY (TareaPadreId)
      REFERENCES dbo.ProyectoTareas(Id);
GO
