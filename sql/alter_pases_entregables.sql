/* =====================================================================
   RQ-IT · Entregables (compuertas) del Pase a Producción
   Agrega a dbo.PaseProduccion los indicadores de entregables que deben
   completarse antes de aprobar el pase:
     - DocArquitectura, DocFuncional, DocSoporte, Induccion (BIT)
   Ejecuta UNA vez. Idempotente.
   ===================================================================== */

USE [RQ-IT];
GO

IF COL_LENGTH('dbo.PaseProduccion','DocArquitectura') IS NULL
    ALTER TABLE dbo.PaseProduccion ADD DocArquitectura BIT NOT NULL CONSTRAINT DF_Pase_DocArq DEFAULT (0);
GO
IF COL_LENGTH('dbo.PaseProduccion','DocFuncional') IS NULL
    ALTER TABLE dbo.PaseProduccion ADD DocFuncional BIT NOT NULL CONSTRAINT DF_Pase_DocFun DEFAULT (0);
GO
IF COL_LENGTH('dbo.PaseProduccion','DocSoporte') IS NULL
    ALTER TABLE dbo.PaseProduccion ADD DocSoporte BIT NOT NULL CONSTRAINT DF_Pase_DocSop DEFAULT (0);
GO
IF COL_LENGTH('dbo.PaseProduccion','Induccion') IS NULL
    ALTER TABLE dbo.PaseProduccion ADD Induccion BIT NOT NULL CONSTRAINT DF_Pase_Induccion DEFAULT (0);
GO
