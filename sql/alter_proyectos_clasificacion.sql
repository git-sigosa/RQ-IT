/* =====================================================================
   RQ-IT · Clasificación de proyectos
   Agrega Tipo (CCTV / IT / IA / ...) y Cliente a dbo.Proyectos.
   Ejecuta UNA vez. Idempotente.
   ===================================================================== */
USE [RQ-IT];
GO

IF COL_LENGTH('dbo.Proyectos', 'Tipo') IS NULL
    ALTER TABLE dbo.Proyectos ADD Tipo NVARCHAR(60) NULL;
GO
IF COL_LENGTH('dbo.Proyectos', 'Cliente') IS NULL
    ALTER TABLE dbo.Proyectos ADD Cliente NVARCHAR(120) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Proyectos_Tipo' AND object_id = OBJECT_ID('dbo.Proyectos'))
    CREATE INDEX IX_Proyectos_Tipo ON dbo.Proyectos (Tipo);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Proyectos_Cliente' AND object_id = OBJECT_ID('dbo.Proyectos'))
    CREATE INDEX IX_Proyectos_Cliente ON dbo.Proyectos (Cliente);
GO
