/* =====================================================================
   RQ-IT · Solicitudes de Infraestructura
   Tabla destino para el formulario (Azure Static Web App -> Azure Function)
   Base de datos: RQ-IT
   Ejecuta este script una sola vez en tu instancia SQL Server.
   ===================================================================== */

USE [RQ-IT];
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'dbo')
    EXEC(N'CREATE SCHEMA dbo');
GO

IF OBJECT_ID(N'dbo.Solicitudes', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Solicitudes
    (
        Id                    INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Solicitudes PRIMARY KEY,
        FechaRegistro         DATETIME2(0) NOT NULL
            CONSTRAINT DF_Solicitudes_FechaRegistro DEFAULT (SYSUTCDATETIME()),

        /* --- 1. General --- */
        Titulo                NVARCHAR(300)  NULL,
        Aplicacion            NVARCHAR(200)  NULL,
        Identificador         NVARCHAR(100)  NULL,
        Proyecto              NVARCHAR(200)  NULL,
        LiderProyecto         NVARCHAR(200)  NULL,
        FechaProduccion       DATE           NULL,
        Funcionalidad         NVARCHAR(MAX)  NULL,

        /* --- 2. Cómputo --- */
        ArquitecturaDespliegue NVARCHAR(100) NULL,
        FrontEnd              NVARCHAR(500)  NULL,
        BackendAPI            NVARCHAR(500)  NULL,
        CPURequerida          DECIMAL(9,2)   NULL,
        RAMRequeridaGB        DECIMAL(9,2)   NULL,

        /* --- 3. Base de datos --- */
        BaseDatos             NVARCHAR(100)  NULL,
        ModeloDespliegueBD    NVARCHAR(100)  NULL,
        StorageGB             DECIMAL(12,2)  NULL,
        CrecimientoMensualGB  DECIMAL(12,2)  NULL,

        /* --- 4. Redes --- */
        DominioPublico        NVARCHAR(200)  NULL,
        TipoAcceso            NVARCHAR(100)  NULL,

        /* --- 5. Seguridad --- */
        MetodoAutenticacion   NVARCHAR(100)  NULL,
        NivelSensibilidad     NVARCHAR(100)  NULL,

        /* --- 6. Clasificación --- */
        Ambiente              NVARCHAR(50)   NULL,
        UsuariosConcurrentes  INT            NULL,
        Criticidad            NVARCHAR(20)   NULL,
        RequiereHA            NVARCHAR(5)    NULL,
        RequiereDR            NVARCHAR(5)    NULL,
        Estado                NVARCHAR(50)   NULL,

        /* --- Registro estructurado completo (auditoría / detalle) --- */
        PayloadJson           NVARCHAR(MAX)  NULL
    );

    CREATE INDEX IX_Solicitudes_FechaRegistro ON dbo.Solicitudes (FechaRegistro DESC);
    CREATE INDEX IX_Solicitudes_Identificador ON dbo.Solicitudes (Identificador);
END
GO
