/* =====================================================================
   RQ-IT · Solicitudes de Acceso a DATA
   - dbo.GruposAcceso     : catálogo de grupos (elegir o crear)
   - dbo.SolicitudesAcceso: la solicitud de acceso
   Ejecuta UNA vez. Idempotente.
   ===================================================================== */

USE [RQ-IT];
GO

IF OBJECT_ID(N'dbo.GruposAcceso', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.GruposAcceso
    (
        Id            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GruposAcceso PRIMARY KEY,
        Nombre        NVARCHAR(200) NOT NULL CONSTRAINT UQ_GruposAcceso_Nombre UNIQUE,
        FechaRegistro DATETIME2(0) NOT NULL CONSTRAINT DF_GruposAcceso_Fecha DEFAULT (SYSUTCDATETIME())
    );
END
GO

IF OBJECT_ID(N'dbo.SolicitudesAcceso', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SolicitudesAcceso
    (
        Id                 INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SolicitudesAcceso PRIMARY KEY,
        FechaRegistro      DATETIME2(0) NOT NULL CONSTRAINT DF_SolicitudesAcceso_Fecha DEFAULT (SYSUTCDATETIME()),

        Titulo             NVARCHAR(300)  NULL,   -- resumen (grupo · usuario)
        Solicitante        NVARCHAR(200)  NULL,
        GrupoId            INT            NULL,
        Grupo              NVARCHAR(200)  NULL,   -- nombre del grupo (denormalizado)
        Usuario            NVARCHAR(200)  NULL,
        DetalleAcceso      NVARCHAR(MAX)  NULL,

        /* --- Seguimiento --- */
        Estado             NVARCHAR(50)   NULL,
        Responsable        NVARCHAR(200)  NULL,
        FechaEntrega       DATE           NULL,
        FechaActualizacion DATETIME2(0)   NULL,

        PayloadJson        NVARCHAR(MAX)  NULL
    );
    CREATE INDEX IX_SolicitudesAcceso_FechaRegistro ON dbo.SolicitudesAcceso (FechaRegistro DESC);
    CREATE INDEX IX_SolicitudesAcceso_Estado ON dbo.SolicitudesAcceso (Estado);
END
GO

GRANT SELECT, INSERT, UPDATE ON dbo.GruposAcceso TO [app.rq-it];
GO
GRANT SELECT, INSERT, UPDATE ON dbo.SolicitudesAcceso TO [app.rq-it];
GO
