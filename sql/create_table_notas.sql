/* =====================================================================
   RQ-IT · Notas / Avances de solicitudes (bitácora)
   Registra avances con fecha y autor para cualquier tipo de solicitud.
   Tipo: 'infra' (dbo.Solicitudes), 'erp' (dbo.SolicitudesERP),
         'gen'  (dbo.SolicitudesGenerales).
   Ejecuta UNA vez. Idempotente.
   ===================================================================== */

USE [RQ-IT];
GO

IF OBJECT_ID(N'dbo.SolicitudNotas', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SolicitudNotas
    (
        Id            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SolicitudNotas PRIMARY KEY,
        Tipo          NVARCHAR(10)  NOT NULL,   -- 'infra' | 'erp' | 'gen'
        SolicitudId   INT           NOT NULL,
        Nota          NVARCHAR(MAX) NOT NULL,
        Autor         NVARCHAR(200) NULL,
        Fecha         DATETIME2(0)  NOT NULL CONSTRAINT DF_SolicitudNotas_Fecha DEFAULT (SYSUTCDATETIME())
    );
    CREATE INDEX IX_SolicitudNotas_Ref ON dbo.SolicitudNotas (Tipo, SolicitudId, Fecha DESC);
END
GO

GRANT SELECT, INSERT, DELETE ON dbo.SolicitudNotas TO [app.rq-it];
GO
