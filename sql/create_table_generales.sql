/* =====================================================================
   RQ-IT · Solicitudes Generales
   Tabla destino para el formulario general (generales.html -> Azure Function).
   Base de datos: RQ-IT.  Ejecuta este script UNA vez.
   Ámbitos contemplados: Infraestructura, Sistemas, Accesos, Permisos en Red, Otro.
   ===================================================================== */

USE [RQ-IT];
GO

IF OBJECT_ID(N'dbo.SolicitudesGenerales', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SolicitudesGenerales
    (
        Id                 INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_SolicitudesGenerales PRIMARY KEY,
        FechaRegistro      DATETIME2(0) NOT NULL
            CONSTRAINT DF_SolicitudesGenerales_FechaRegistro DEFAULT (SYSUTCDATETIME()),

        /* --- Solicitud --- */
        Titulo             NVARCHAR(300)  NULL,   -- = Asunto
        Solicitante        NVARCHAR(200)  NULL,
        Area               NVARCHAR(200)  NULL,
        Ambito             NVARCHAR(300)  NULL,   -- p.ej. "Accesos, Permisos en Red"
        Descripcion        NVARCHAR(MAX)  NULL,   -- contexto
        Justificacion      NVARCHAR(MAX)  NULL,
        Prioridad          NVARCHAR(20)   NULL,   -- Alta / Media / Baja

        /* --- Seguimiento --- */
        Estado             NVARCHAR(50)   NULL,   -- Nuevo, En revisión, ...
        Responsable        NVARCHAR(200)  NULL,
        FechaEntrega       DATE           NULL,
        FechaActualizacion DATETIME2(0)   NULL,

        /* --- Registro estructurado completo --- */
        PayloadJson        NVARCHAR(MAX)  NULL
    );

    CREATE INDEX IX_SolicitudesGenerales_FechaRegistro ON dbo.SolicitudesGenerales (FechaRegistro DESC);
    CREATE INDEX IX_SolicitudesGenerales_Estado ON dbo.SolicitudesGenerales (Estado);
END
GO

GRANT SELECT, INSERT, UPDATE ON dbo.SolicitudesGenerales TO [app.rq-it];
GO
