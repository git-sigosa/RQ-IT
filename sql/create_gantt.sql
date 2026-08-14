/* =====================================================================
   RQ-IT · Proyectos y Gantt
   Tablas para el portal de proyectos (gantt.html) y el vínculo de las
   solicitudes con un proyecto. Base de datos: RQ-IT. Ejecuta UNA vez.
   Idempotente: no falla si ya existen.
   ===================================================================== */

USE [RQ-IT];
GO

/* ---- Proyectos ---- */
IF OBJECT_ID(N'dbo.Proyectos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Proyectos
    (
        Id            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Proyectos PRIMARY KEY,
        Nombre        NVARCHAR(200) NOT NULL,
        Descripcion   NVARCHAR(MAX) NULL,
        Responsable   NVARCHAR(200) NULL,
        FechaInicio   DATE NULL,
        FechaFin      DATE NULL,
        Estado        NVARCHAR(50) NULL CONSTRAINT DF_Proyectos_Estado DEFAULT (N'Activo'),
        FechaRegistro DATETIME2(0) NOT NULL CONSTRAINT DF_Proyectos_FechaReg DEFAULT (SYSUTCDATETIME())
    );
    CREATE INDEX IX_Proyectos_Nombre ON dbo.Proyectos (Nombre);
END
GO

/* ---- Tareas del Gantt ---- */
IF OBJECT_ID(N'dbo.ProyectoTareas', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ProyectoTareas
    (
        Id                 INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ProyectoTareas PRIMARY KEY,
        ProyectoId         INT NOT NULL,
        Nombre             NVARCHAR(300) NOT NULL,
        FechaInicio        DATE NULL,
        FechaFin           DATE NULL,
        Progreso           INT NULL CONSTRAINT DF_ProyectoTareas_Prog DEFAULT (0),   -- 0..100
        Responsable        NVARCHAR(200) NULL,
        DependenciaId      INT NULL,     -- id de otra tarea (fin -> inicio)
        EsHito             BIT NOT NULL CONSTRAINT DF_ProyectoTareas_Hito DEFAULT (0),
        Orden              INT NULL,
        FechaActualizacion DATETIME2(0) NULL,
        CONSTRAINT FK_ProyectoTareas_Proyecto FOREIGN KEY (ProyectoId) REFERENCES dbo.Proyectos(Id)
    );
    CREATE INDEX IX_ProyectoTareas_Proyecto ON dbo.ProyectoTareas (ProyectoId, Orden);
END
GO

/* ---- Vínculo de solicitudes con un proyecto ---- */
IF COL_LENGTH('dbo.Solicitudes', 'ProyectoId') IS NULL
    ALTER TABLE dbo.Solicitudes ADD ProyectoId INT NULL;
GO
IF COL_LENGTH('dbo.SolicitudesERP', 'ProyectoId') IS NULL
    ALTER TABLE dbo.SolicitudesERP ADD ProyectoId INT NULL;
GO
IF COL_LENGTH('dbo.SolicitudesGenerales', 'ProyectoId') IS NULL
    ALTER TABLE dbo.SolicitudesGenerales ADD ProyectoId INT NULL;
GO

/* ---- Permisos ---- */
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.ProyectoTareas TO [app.rq-it];
GO
GRANT SELECT, INSERT, UPDATE ON dbo.Proyectos TO [app.rq-it];
GO
