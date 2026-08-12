/* =====================================================================
   RQ-IT · Solicitudes de Sistema / ERP
   Tabla destino para el formulario ERP (erp.html -> Azure Function).
   Base de datos: RQ-IT.  Ejecuta este script UNA vez.
   Módulos ERP contemplados: HRM, FMS, OSM, IMS, POS, TMS.
   ===================================================================== */

USE [RQ-IT];
GO

IF OBJECT_ID(N'dbo.SolicitudesERP', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SolicitudesERP
    (
        Id                 INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_SolicitudesERP PRIMARY KEY,
        FechaRegistro      DATETIME2(0) NOT NULL
            CONSTRAINT DF_SolicitudesERP_FechaRegistro DEFAULT (SYSUTCDATETIME()),

        /* --- Solicitud --- */
        Titulo             NVARCHAR(300)  NULL,
        Solicitante        NVARCHAR(200)  NULL,
        Area               NVARCHAR(200)  NULL,
        Descripcion        NVARCHAR(MAX)  NULL,
        Modulos            NVARCHAR(300)  NULL,   -- p.ej. "HRM, FMS, POS"
        Procesos           NVARCHAR(MAX)  NULL,   -- procesos separados por " | "
        TransformarFabric  NVARCHAR(5)    NULL,   -- "Sí" / "No"
        FabricDetalle      NVARCHAR(MAX)  NULL,
        Prioridad          NVARCHAR(20)   NULL,   -- Alta / Media / Baja

        /* --- Seguimiento --- */
        Estado             NVARCHAR(50)   NULL,   -- Nuevo, En revisión, ...
        Responsable        NVARCHAR(200)  NULL,
        FechaEntrega       DATE           NULL,
        FechaActualizacion DATETIME2(0)   NULL,

        /* --- Registro estructurado completo --- */
        PayloadJson        NVARCHAR(MAX)  NULL
    );

    CREATE INDEX IX_SolicitudesERP_FechaRegistro ON dbo.SolicitudesERP (FechaRegistro DESC);
    CREATE INDEX IX_SolicitudesERP_Estado ON dbo.SolicitudesERP (Estado);
END
GO

/* Permisos para el usuario de la aplicación */
GRANT SELECT, INSERT, UPDATE ON dbo.SolicitudesERP TO [app.rq-it];
GO
