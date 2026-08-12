/* =====================================================================
   RQ-IT · Seguimiento de solicitudes
   Agrega columnas de seguimiento a dbo.Solicitudes:
     - Responsable   : persona asignada para atender la solicitud
     - FechaEntrega   : fecha compromiso / entrega
   Ejecuta este script UNA vez en la base de datos RQ-IT.
   Es idempotente: no falla si las columnas ya existen.
   ===================================================================== */

USE [RQ-IT];
GO

IF COL_LENGTH('dbo.Solicitudes', 'Responsable') IS NULL
    ALTER TABLE dbo.Solicitudes ADD Responsable NVARCHAR(200) NULL;
GO

IF COL_LENGTH('dbo.Solicitudes', 'FechaEntrega') IS NULL
    ALTER TABLE dbo.Solicitudes ADD FechaEntrega DATE NULL;
GO

/* Fecha de última actualización del seguimiento (auditoría) */
IF COL_LENGTH('dbo.Solicitudes', 'FechaActualizacion') IS NULL
    ALTER TABLE dbo.Solicitudes ADD FechaActualizacion DATETIME2(0) NULL;
GO
