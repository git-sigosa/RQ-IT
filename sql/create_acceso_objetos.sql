/* =====================================================================
   RQ-IT · Acceso a DATA — Objetos por solicitud
   - dbo.DataObjetos            : catálogo de tablas/objetos y su módulo
   - dbo.SolicitudAccesoObjetos : objetos seleccionados en cada solicitud
   Ejecuta UNA vez. Idempotente (puedes correrlo de nuevo sin dañar datos).
   ===================================================================== */

USE [RQ-IT];
GO

/* ---------- Catálogo de objetos ---------- */
IF OBJECT_ID(N'dbo.DataObjetos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DataObjetos
    (
        Id        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DataObjetos PRIMARY KEY,
        TableName NVARCHAR(200) NOT NULL CONSTRAINT UQ_DataObjetos_TableName UNIQUE,
        Service   NVARCHAR(50)  NOT NULL,
        Activo    BIT NOT NULL CONSTRAINT DF_DataObjetos_Activo DEFAULT (1)
    );
END
GO

/* Semilla idempotente: inserta solo lo que falte */
;WITH src(TableName, Service) AS (
    SELECT * FROM (VALUES
        (N'DimAmbiente',N'PLM'),(N'DimArea',N'MAESTRO'),(N'DimBanco',N'FMS'),
        (N'DimCentroCosto',N'FMS'),(N'DimCliente',N'CRM'),(N'DimCondicionPago',N'SRM'),
        (N'DimCorte',N'MRP'),(N'DimCuentaBancaria',N'FMS'),(N'DimDocumentoOperaciones',N'MAESTRO'),
        (N'DimEmpleadoMrp',N'MRP'),(N'DimEquipo',N'MRP'),(N'DimEstatus',N'MAESTRO'),
        (N'DimFecha',N'MAESTRO'),(N'DimFormaEntrega',N'SRM'),(N'DimFormaPago',N'SRM'),
        (N'DimMaterial',N'MRP'),(N'DimMotivo',N'MAESTRO'),(N'DimMotivoInventario',N'IMS'),
        (N'DimNegociacion',N'SRM'),(N'DimOrdenProduccionEstatus',N'MRP'),(N'DimPlanImpuesto',N'FMS'),
        (N'DimProduccionLote',N'MRP'),(N'DimProducto',N'PLM'),(N'DimProductoMrp',N'MRP'),
        (N'DimProveedor',N'MAESTRO'),(N'DimReceta',N'MRP'),(N'DimSala',N'MRP'),
        (N'DimSucursal',N'MAESTRO'),(N'DimTiempo',N'MAESTRO'),(N'DimTipoAjuste',N'IMS'),
        (N'DimTipoAnimal',N'MRP'),(N'DimTipoDevolucion',N'SRM'),(N'DimTipoEntrega',N'SRM'),
        (N'DimTipoProduccionPlanificacion',N'MRP'),(N'DimTipoProductoProcesado',N'MRP'),
        (N'DimTipoRecepcion',N'SRM'),(N'DimTipoTransferencia',N'IMS'),(N'DimTipoUso',N'IMS'),
        (N'DimTransaccion',N'MAESTRO'),(N'DimUsuario',N'SEG/AUD'),
        (N'FactAjustesIngredientes',N'MRP'),(N'FactAjustesInventario',N'IMS'),(N'FactAjustesMerma',N'IMS'),
        (N'FactCompras',N'SRM'),(N'FactConfigPrecios',N'PLM'),(N'FactConfigPreciosHistorico',N'PLM'),
        (N'FactDevoluciones',N'SRM'),(N'FactExistencias',N'IMS'),(N'FactExistenciasIngredientes',N'MRP'),
        (N'FactInventarioResumen',N'IMS'),(N'FactMovimientos',N'IMS'),(N'FactMovimientosIngredientes',N'MRP'),
        (N'FactOrdenesCompras',N'SRM'),(N'FactOrdenesProduccionDetalle',N'MRP'),
        (N'FactOrdenesProduccionPlanificacionDetalle',N'MRP'),(N'FactOrdenesProduccionReceta',N'MRP'),
        (N'FactOrdenesProduccionSalas',N'MRP'),(N'FactOrdenProduccionCancelacion',N'MRP'),
        (N'FactOrdenProduccionDerivados',N'MRP'),(N'FactPlanesMaestroDetalle',N'MRP'),
        (N'FactProductoXSucursal',N'MRP'),(N'FactRecepciones',N'SRM'),
        (N'FactRecetasDetalleXSucursal',N'MRP'),(N'FactRecetasXSucursal',N'MRP'),
        (N'FactSaldoDiario',N'IMS'),(N'FactTransferencias',N'IMS'),(N'FactVentas',N'POS'),
        (N'ProductoXMaterial',N'MRP'),
        (N'CobrosCuentasXCobrar',N'FMS'),(N'DimCuentaContable',N'FMS'),(N'DimEjercicioFiscal',N'FMS'),
        (N'DimEmpresa',N'FMS'),(N'DimLote',N'FMS'),(N'DimPeriodoFiscal',N'FMS'),
        (N'DimTipoAjusteBancario',N'FMS'),(N'DimTipoMovimientoDiario',N'FMS'),(N'DocumentosRelacionados',N'FMS'),
        (N'FactCartasPago',N'FMS'),(N'FactCobros',N'FMS'),(N'FactComprobantesISLR',N'FMS'),
        (N'FactComprobantesIVA',N'FMS'),(N'FactConciliacionesBancarias',N'FMS'),(N'FactCuentasPorCobrar',N'FMS'),
        (N'FactCuentasPorPagar',N'FMS'),(N'FactDetallesTransaccionesBancarias',N'FMS'),(N'FactDevolucionesXCuentasXPagar',N'FMS'),
        (N'FactEstadosCuenta',N'FMS'),(N'FactLibroCompras',N'FMS'),(N'FactLibroVentas',N'FMS'),
        (N'FactMovimientosContables',N'FMS'),(N'FactPagos',N'FMS'),(N'FactTransaccionesBancarias',N'FMS'),
        (N'FactTransferenciasBancarias',N'FMS'),(N'PagosXCuentasXPagar',N'FMS')
    ) v(TableName, Service)
)
INSERT INTO dbo.DataObjetos (TableName, Service)
SELECT s.TableName, s.Service
FROM src s
WHERE NOT EXISTS (SELECT 1 FROM dbo.DataObjetos d WHERE d.TableName = s.TableName);
GO

/* ---------- Objetos seleccionados por solicitud ---------- */
IF OBJECT_ID(N'dbo.SolicitudAccesoObjetos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.SolicitudAccesoObjetos
    (
        Id            INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_SolicitudAccesoObjetos PRIMARY KEY,
        SolicitudId   INT NOT NULL,
        TableName     NVARCHAR(200) NOT NULL,
        Service       NVARCHAR(50)  NULL,
        FechaRegistro DATETIME2(0) NOT NULL CONSTRAINT DF_SAO_Fecha DEFAULT (SYSUTCDATETIME()),
        CONSTRAINT FK_SAO_Solicitud FOREIGN KEY (SolicitudId)
            REFERENCES dbo.SolicitudesAcceso (Id) ON DELETE CASCADE
    );
    CREATE INDEX IX_SAO_Solicitud ON dbo.SolicitudAccesoObjetos (SolicitudId);
    CREATE INDEX IX_SAO_Service   ON dbo.SolicitudAccesoObjetos (Service);
END
GO

GRANT SELECT ON dbo.DataObjetos TO [app.rq-it];
GO
GRANT SELECT, INSERT, DELETE ON dbo.SolicitudAccesoObjetos TO [app.rq-it];
GO
