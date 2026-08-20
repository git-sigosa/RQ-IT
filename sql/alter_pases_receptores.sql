/* =====================================================================
   RQ-IT · Personas del Pase a Producción
   Agrega a dbo.PaseProduccion los responsables por paso:
     - ReceptorDocumentacion : quién recibe la documentación
     - ReceptorInduccion      : quién recibe la inducción
     - ContrapartePlanificacion: con quién se planifica el pase
   Ejecuta UNA vez. Idempotente.
   ===================================================================== */

USE [RQ-IT];
GO

IF COL_LENGTH('dbo.PaseProduccion','ReceptorDocumentacion') IS NULL
    ALTER TABLE dbo.PaseProduccion ADD ReceptorDocumentacion NVARCHAR(200) NULL;
GO
IF COL_LENGTH('dbo.PaseProduccion','ReceptorInduccion') IS NULL
    ALTER TABLE dbo.PaseProduccion ADD ReceptorInduccion NVARCHAR(200) NULL;
GO
IF COL_LENGTH('dbo.PaseProduccion','ContrapartePlanificacion') IS NULL
    ALTER TABLE dbo.PaseProduccion ADD ContrapartePlanificacion NVARCHAR(200) NULL;
GO
