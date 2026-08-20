/* =====================================================================
   RQ-IT · Fecha por entregable del Pase a Producción
   Agrega la fecha de cada entregable a dbo.PaseProduccion.
   Ejecuta UNA vez. Idempotente.
   ===================================================================== */

USE [RQ-IT];
GO

IF COL_LENGTH('dbo.PaseProduccion','DocArquitecturaFecha') IS NULL
    ALTER TABLE dbo.PaseProduccion ADD DocArquitecturaFecha DATE NULL;
GO
IF COL_LENGTH('dbo.PaseProduccion','DocFuncionalFecha') IS NULL
    ALTER TABLE dbo.PaseProduccion ADD DocFuncionalFecha DATE NULL;
GO
IF COL_LENGTH('dbo.PaseProduccion','DocSoporteFecha') IS NULL
    ALTER TABLE dbo.PaseProduccion ADD DocSoporteFecha DATE NULL;
GO
IF COL_LENGTH('dbo.PaseProduccion','InduccionFecha') IS NULL
    ALTER TABLE dbo.PaseProduccion ADD InduccionFecha DATE NULL;
GO
