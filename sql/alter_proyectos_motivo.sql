/* =====================================================================
   RQ-IT · Motivo de estado del proyecto
   Guarda el motivo cuando un proyecto queda En pausa (On Hold) o
   Cancelado. Ej.: "En espera de procura". Ejecuta UNA vez. Idempotente.
   ===================================================================== */
USE [RQ-IT];
GO

IF COL_LENGTH('dbo.Proyectos', 'MotivoEstado') IS NULL
    ALTER TABLE dbo.Proyectos ADD MotivoEstado NVARCHAR(300) NULL;
GO
