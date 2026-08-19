/* =====================================================================
   RQ-IT · Planificación de Pase a Producción
   Un registro por solicitud (Tipo + SolicitudId). Guarda fecha/ventana,
   responsable, aprobador, estado y plan de rollback.
   Tipo: 'infra' | 'erp' | 'gen'.  Ejecuta UNA vez. Idempotente.
   ===================================================================== */

USE [RQ-IT];
GO

IF OBJECT_ID(N'dbo.PaseProduccion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PaseProduccion
    (
        Id                 INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PaseProduccion PRIMARY KEY,
        Tipo               NVARCHAR(10)  NOT NULL,   -- 'infra' | 'erp' | 'gen'
        SolicitudId        INT           NOT NULL,
        Titulo             NVARCHAR(300) NULL,        -- denormalizado, para la bandeja global
        FechaPlanificada   DATE          NULL,
        VentanaInicio      DATETIME2(0)  NULL,
        VentanaFin         DATETIME2(0)  NULL,
        Responsable        NVARCHAR(200) NULL,
        Aprobador          NVARCHAR(200) NULL,
        Estado             NVARCHAR(30)  NULL CONSTRAINT DF_PaseProduccion_Estado DEFAULT (N'Planificado'),
        PlanRollback       NVARCHAR(MAX) NULL,
        FechaActualizacion DATETIME2(0)  NULL,
        CONSTRAINT UQ_PaseProduccion_Ref UNIQUE (Tipo, SolicitudId)
    );
    CREATE INDEX IX_PaseProduccion_Fecha ON dbo.PaseProduccion (FechaPlanificada);
    CREATE INDEX IX_PaseProduccion_Estado ON dbo.PaseProduccion (Estado);
END
GO

GRANT SELECT, INSERT, UPDATE ON dbo.PaseProduccion TO [app.rq-it];
GO
