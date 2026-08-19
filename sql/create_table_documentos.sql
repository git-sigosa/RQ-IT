/* =====================================================================
   RQ-IT · Documentación adjunta de solicitudes
   Guarda archivos (runbook, plan de rollback, evidencias) EN SQL.
   El link de descarga (/api/documentos/{id}) es el que se comparte por correo.
   Tipo: 'infra' | 'erp' | 'gen'.  Ejecuta UNA vez. Idempotente.
   ===================================================================== */

USE [RQ-IT];
GO

IF OBJECT_ID(N'dbo.SolicitudDocumentos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SolicitudDocumentos
    (
        Id            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SolicitudDocumentos PRIMARY KEY,
        Tipo          NVARCHAR(10)   NOT NULL,   -- 'infra' | 'erp' | 'gen'
        SolicitudId   INT            NOT NULL,
        Nombre        NVARCHAR(300)  NOT NULL,   -- nombre del archivo
        ContentType   NVARCHAR(150)  NULL,
        Tamano        INT            NULL,       -- bytes
        Contenido     VARBINARY(MAX) NOT NULL,   -- el archivo
        Autor         NVARCHAR(200)  NULL,
        Fecha         DATETIME2(0)   NOT NULL CONSTRAINT DF_SolicitudDocumentos_Fecha DEFAULT (SYSUTCDATETIME())
    );
    CREATE INDEX IX_SolicitudDocumentos_Ref ON dbo.SolicitudDocumentos (Tipo, SolicitudId, Fecha DESC);
END
GO

GRANT SELECT, INSERT, DELETE ON dbo.SolicitudDocumentos TO [app.rq-it];
GO
