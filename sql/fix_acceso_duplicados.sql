-- =====================================================================
-- RQ-IT · Limpieza de solicitudes de acceso DUPLICADAS
-- ---------------------------------------------------------------------
-- Origen del problema: acceso.html no cerraba el modal al enviar, así que
-- cada clic extra en "Enviar Solicitud" generaba otra fila idéntica.
-- (Corregido en el commit 5fc200a; este script limpia lo ya guardado.)
--
-- Criterio de duplicado: misma huella
-- Solicitante + Grupo + Usuario + DetalleAcceso + conjunto de objetos
-- Y registradas a menos de 5 minutos una de otra (ventana configurable).
-- Se conserva la de Id MENOR de cada racha y se borran las demás.
--
-- La ventana de tiempo es deliberada: dos solicitudes idénticas separadas
-- por días son un pedido legítimo repetido, NO un doble clic.
--
-- OJO con las tablas relacionadas:
-- - dbo.SolicitudAccesoObjetos  -> tiene ON DELETE CASCADE (se va sola).
-- - dbo.SolicitudNotas          -> (Tipo,SolicitudId) SIN FK  -> hay que borrarla.
-- - dbo.SolicitudDocumentos     -> (Tipo,SolicitudId) SIN FK  -> hay que borrarla.
-- - dbo.PaseProduccion          -> (Tipo,SolicitudId) SIN FK  -> hay que borrarla.
-- Si no, quedan filas huérfanas apuntando a Ids que IDENTITY reutilizará.
--
-- EJECUTA POR PASOS. No corras el archivo entero de una vez.
-- =====================================================================

USE [RQ-IT];
GO

-- ---------------------------------------------------------------------
-- Vista de trabajo: huella de cada solicitud + detección de rachas.
-- Se recrea en cada paso porque los CTE no persisten entre lotes.
-- ---------------------------------------------------------------------
IF OBJECT_ID(N'dbo.vwAccesoDuplicados', N'V') IS NOT NULL
    DROP VIEW dbo.vwAccesoDuplicados;
GO

CREATE VIEW dbo.vwAccesoDuplicados
AS
WITH fp AS (
    SELECT
        s.Id,
        s.FechaRegistro,
        s.Solicitante,
        s.Grupo,
        s.Usuario,
        s.Estado,
        s.Responsable,
        s.FechaEntrega,
        ISNULL(s.DetalleAcceso, N'')        AS Detalle,
        ISNULL(f.Objetos, N'(sin objetos)') AS Objetos,
        f.NObj
    FROM dbo.SolicitudesAcceso s
    OUTER APPLY (
        SELECT
            STUFF((
                SELECT N'|' + o.TableName
                FROM dbo.SolicitudAccesoObjetos o
                WHERE o.SolicitudId = s.Id
                ORDER BY o.TableName
                FOR XML PATH(''), TYPE
            ).value('.', 'NVARCHAR(MAX)'), 1, 1, N'') AS Objetos,
            (SELECT COUNT(*) FROM dbo.SolicitudAccesoObjetos o2 WHERE o2.SolicitudId = s.Id) AS NObj
    ) f
),
/* ¿empieza una racha nueva? (más de 5 min desde la anterior con la misma huella) */
marca AS (
    SELECT *,
        CASE WHEN DATEDIFF(SECOND,
                    LAG(FechaRegistro) OVER (
                        PARTITION BY Solicitante, Grupo, Usuario, Detalle, Objetos
                        ORDER BY Id),
                    FechaRegistro) <= 300      /* <-- VENTANA: 300 s = 5 min */
             THEN 0 ELSE 1 END AS EsNuevaRacha
    FROM fp
),
/* numera las rachas (gaps and islands) */
racha AS (
    SELECT *,
        SUM(EsNuevaRacha) OVER (
            PARTITION BY Solicitante, Grupo, Usuario, Detalle, Objetos
            ORDER BY Id ROWS UNBOUNDED PRECEDING) AS Racha
    FROM marca
)
SELECT
    r.Id,
    r.FechaRegistro,
    r.Solicitante,
    r.Grupo,
    r.Usuario,
    r.Estado,
    r.Responsable,
    r.FechaEntrega,
    r.NObj,
    r.Objetos,
    MIN(r.Id) OVER (PARTITION BY r.Solicitante, r.Grupo, r.Usuario, r.Detalle, r.Objetos, r.Racha) AS ConservarId,
    COUNT(*)  OVER (PARTITION BY r.Solicitante, r.Grupo, r.Usuario, r.Detalle, r.Objetos, r.Racha) AS EnLaRacha,
    ROW_NUMBER() OVER (PARTITION BY r.Solicitante, r.Grupo, r.Usuario, r.Detalle, r.Objetos, r.Racha
                       ORDER BY r.Id) AS Orden,
    /* señales de trabajo manual: si alguna trae esto, revísala a mano antes de borrar */
    CASE WHEN r.Responsable IS NOT NULL AND LTRIM(RTRIM(r.Responsable)) <> N'' THEN 1 ELSE 0 END
  + CASE WHEN r.FechaEntrega IS NOT NULL THEN 1 ELSE 0 END
  + CASE WHEN r.Estado IS NOT NULL AND r.Estado NOT IN (N'Nuevo') THEN 1 ELSE 0 END
  + (SELECT COUNT(*) FROM dbo.SolicitudNotas n      WHERE n.Tipo = N'acceso' AND n.SolicitudId = r.Id)
  + (SELECT COUNT(*) FROM dbo.SolicitudDocumentos d WHERE d.Tipo = N'acceso' AND d.SolicitudId = r.Id)
  + (SELECT COUNT(*) FROM dbo.PaseProduccion p      WHERE p.Tipo = N'acceso' AND p.SolicitudId = r.Id)
        AS TieneSeguimiento
FROM racha r;
GO


-- =====================================================================
-- PASO 1 · ¿Cuánto hay? (solo lectura)
-- =====================================================================
SELECT
    (SELECT COUNT(*) FROM dbo.SolicitudesAcceso)                          AS SolicitudesTotales,
    (SELECT COUNT(*) FROM dbo.vwAccesoDuplicados WHERE Orden > 1)         AS FilasABorrar,
    (SELECT COUNT(DISTINCT ConservarId) FROM dbo.vwAccesoDuplicados
      WHERE EnLaRacha > 1)                                               AS GruposConDuplicados,
    (SELECT COUNT(*) FROM dbo.vwAccesoDuplicados
      WHERE Orden > 1 AND TieneSeguimiento > 0)                          AS ABorrarConSeguimiento;
GO


-- =====================================================================
-- PASO 2 · Revisión detallada. MÍRALA antes de borrar.
-- Cada bloque de filas con el mismo ConservarId es una racha de duplicados.
-- La marca "CONSERVAR" es la que se queda.
-- =====================================================================
SELECT
    CASE WHEN Orden = 1 THEN N'CONSERVAR' ELSE N'borrar' END AS Accion,
    ConservarId,
    Id,
    FechaRegistro,
    Solicitante,
    Usuario,
    Grupo,
    Estado,
    Responsable,
    NObj                AS Objetos,
    TieneSeguimiento,
    EnLaRacha
FROM dbo.vwAccesoDuplicados
WHERE EnLaRacha > 1
ORDER BY ConservarId, Orden;
GO

-- ---- ¿Alguna a borrar tiene seguimiento manual? Revísalas una por una.
-- Si el trabajo real quedó en la COPIA y no en la original, mueve el
-- Responsable/Estado/notas a la que conservas ANTES de seguir.       ----
SELECT
    d.ConservarId, d.Id, d.FechaRegistro, d.Solicitante, d.Grupo, d.Usuario,
    d.Estado, d.Responsable, d.FechaEntrega, d.TieneSeguimiento,
    (SELECT COUNT(*) FROM dbo.SolicitudNotas n      WHERE n.Tipo = N'acceso' AND n.SolicitudId = d.Id) AS Notas,
    (SELECT COUNT(*) FROM dbo.SolicitudDocumentos x WHERE x.Tipo = N'acceso' AND x.SolicitudId = d.Id) AS Documentos,
    (SELECT COUNT(*) FROM dbo.PaseProduccion p      WHERE p.Tipo = N'acceso' AND p.SolicitudId = d.Id) AS Pases
FROM dbo.vwAccesoDuplicados d
WHERE d.Orden > 1 AND d.TieneSeguimiento > 0
ORDER BY d.ConservarId, d.Id;
GO


-- =====================================================================
-- PASO 3 · Respaldo. No te lo saltes.
-- Deja copia de todo lo que se va a borrar, por si hay que revertir.
-- =====================================================================
-- Salvaguarda: si ya hay un respaldo CON filas, no lo pisa.
-- Sin esto, re-ejecutar el archivo despues de un borrado exitoso regenera
-- los respaldos desde una tabla ya limpia y te deja sin red.
IF OBJECT_ID(N'dbo.zzBk_SolicitudesAcceso', N'U') IS NOT NULL
   AND EXISTS (SELECT 1 FROM dbo.zzBk_SolicitudesAcceso)
BEGIN
    RAISERROR(N'Ya existe un respaldo con filas. Si de verdad quieres regenerarlo, borra las tablas zzBk_* a mano.', 16, 1);
END
ELSE
BEGIN
    IF OBJECT_ID(N'dbo.zzBk_SolicitudesAcceso', N'U') IS NOT NULL DROP TABLE dbo.zzBk_SolicitudesAcceso;
    IF OBJECT_ID(N'dbo.zzBk_SolicitudAccesoObjetos', N'U') IS NOT NULL DROP TABLE dbo.zzBk_SolicitudAccesoObjetos;
    IF OBJECT_ID(N'dbo.zzBk_SolicitudNotas', N'U') IS NOT NULL DROP TABLE dbo.zzBk_SolicitudNotas;
    IF OBJECT_ID(N'dbo.zzBk_SolicitudDocumentos', N'U') IS NOT NULL DROP TABLE dbo.zzBk_SolicitudDocumentos;
    IF OBJECT_ID(N'dbo.zzBk_PaseProduccion', N'U') IS NOT NULL DROP TABLE dbo.zzBk_PaseProduccion;

    SELECT s.* INTO dbo.zzBk_SolicitudesAcceso
    FROM dbo.SolicitudesAcceso s
    WHERE s.Id IN (SELECT Id FROM dbo.vwAccesoDuplicados WHERE Orden > 1);

    SELECT o.* INTO dbo.zzBk_SolicitudAccesoObjetos
    FROM dbo.SolicitudAccesoObjetos o
    WHERE o.SolicitudId IN (SELECT Id FROM dbo.vwAccesoDuplicados WHERE Orden > 1);

    SELECT n.* INTO dbo.zzBk_SolicitudNotas
    FROM dbo.SolicitudNotas n
    WHERE n.Tipo = N'acceso' AND n.SolicitudId IN (SELECT Id FROM dbo.vwAccesoDuplicados WHERE Orden > 1);

    SELECT x.* INTO dbo.zzBk_SolicitudDocumentos
    FROM dbo.SolicitudDocumentos x
    WHERE x.Tipo = N'acceso' AND x.SolicitudId IN (SELECT Id FROM dbo.vwAccesoDuplicados WHERE Orden > 1);

    SELECT p.* INTO dbo.zzBk_PaseProduccion
    FROM dbo.PaseProduccion p
    WHERE p.Tipo = N'acceso' AND p.SolicitudId IN (SELECT Id FROM dbo.vwAccesoDuplicados WHERE Orden > 1);

END
GO

/* verificacion del respaldo, en su propio lote */
SELECT 'Respaldado' AS Estado,
       (SELECT COUNT(*) FROM dbo.zzBk_SolicitudesAcceso)      AS Solicitudes,
       (SELECT COUNT(*) FROM dbo.zzBk_SolicitudAccesoObjetos) AS Objetos,
       (SELECT COUNT(*) FROM dbo.zzBk_SolicitudNotas)         AS Notas,
       (SELECT COUNT(*) FROM dbo.zzBk_SolicitudDocumentos)    AS Documentos,
       (SELECT COUNT(*) FROM dbo.zzBk_PaseProduccion)         AS Pases;
GO


-- =====================================================================
-- PASO 4 · Borrado.
--
-- NO edites ROLLBACK/COMMIT: cambia solo la bandera @Confirmar.
-- @Confirmar = 0  -> ensayo, revierte siempre y te ensena las cuentas
-- @Confirmar = 1  -> borrado definitivo
--
-- Selecciona TODO este bloque (hasta el GO) y ejecutalo de una vez.
-- XACT_ABORT + TRY/CATCH garantizan que nunca quede una transaccion
-- abierta ni un COMMIT huerfano si algo falla a medias.
-- =====================================================================
SET XACT_ABORT ON;
SET NOCOUNT ON;
GO

DECLARE @Confirmar BIT = 0;    /* <<<<<< 0 = ensayo | 1 = borrar de verdad */

DECLARE @borrar TABLE (Id INT PRIMARY KEY);
DECLARE @notas INT = 0, @docs INT = 0, @pases INT = 0, @sols INT = 0;

/* exige el respaldo del PASO 3 antes de un borrado real */
IF @Confirmar = 1
   AND NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = N'zzBk_SolicitudesAcceso' AND schema_id = SCHEMA_ID(N'dbo'))
BEGIN
    RAISERROR(N'Falta el respaldo del PASO 3. No se borra nada.', 16, 1);
    RETURN;
END

INSERT INTO @borrar (Id)
SELECT Id FROM dbo.vwAccesoDuplicados WHERE Orden > 1;

-- --- Para EXCLUIR del borrado las que tienen seguimiento manual,
-- descomenta esta linea: ---
-- DELETE FROM @borrar WHERE Id IN (SELECT Id FROM dbo.vwAccesoDuplicados WHERE TieneSeguimiento > 0);

IF NOT EXISTS (SELECT 1 FROM @borrar)
BEGIN
    SELECT N'No hay duplicados que borrar.' AS Resultado;
    RETURN;
END

BEGIN TRY
    BEGIN TRANSACTION;

        /* hijos sin FK primero, o quedan huerfanos apuntando a Ids reutilizables */
        DELETE n FROM dbo.SolicitudNotas n
        WHERE n.Tipo = N'acceso' AND n.SolicitudId IN (SELECT Id FROM @borrar);
        SET @notas = @@ROWCOUNT;

        DELETE x FROM dbo.SolicitudDocumentos x
        WHERE x.Tipo = N'acceso' AND x.SolicitudId IN (SELECT Id FROM @borrar);
        SET @docs = @@ROWCOUNT;

        DELETE p FROM dbo.PaseProduccion p
        WHERE p.Tipo = N'acceso' AND p.SolicitudId IN (SELECT Id FROM @borrar);
        SET @pases = @@ROWCOUNT;

        /* la solicitud: SolicitudAccesoObjetos se va en cascada */
        DELETE s FROM dbo.SolicitudesAcceso s
        WHERE s.Id IN (SELECT Id FROM @borrar);
        SET @sols = @@ROWCOUNT;

    IF @Confirmar = 1
        COMMIT TRANSACTION;
    ELSE
        ROLLBACK TRANSACTION;

    SELECT CASE WHEN @Confirmar = 1 THEN N'CONFIRMADO' ELSE N'ENSAYO (revertido)' END AS Modo,
           @sols AS SolicitudesBorradas, @notas AS NotasBorradas,
           @docs AS DocsBorrados,       @pases AS PasesBorrados;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    SELECT N'ERROR — no se borro nada' AS Modo,
           ERROR_NUMBER() AS NumeroError, ERROR_LINE() AS Linea, ERROR_MESSAGE() AS Mensaje;
END CATCH
GO


-- =====================================================================
-- PASO 5 · Verificación posterior (después del COMMIT)
-- =====================================================================
SELECT
    (SELECT COUNT(*) FROM dbo.SolicitudesAcceso)                  AS SolicitudesRestantes,
    (SELECT COUNT(*) FROM dbo.vwAccesoDuplicados WHERE Orden > 1) AS DuplicadosRestantes;

/* Huérfanos: debe dar 0 en todo */
SELECT 'Objetos huerfanos' AS Chequeo, COUNT(*) AS Filas
FROM dbo.SolicitudAccesoObjetos o
WHERE NOT EXISTS (SELECT 1 FROM dbo.SolicitudesAcceso s WHERE s.Id = o.SolicitudId)
UNION ALL
SELECT 'Notas huerfanas', COUNT(*)
FROM dbo.SolicitudNotas n
WHERE n.Tipo = N'acceso'
  AND NOT EXISTS (SELECT 1 FROM dbo.SolicitudesAcceso s WHERE s.Id = n.SolicitudId)
UNION ALL
SELECT 'Documentos huerfanos', COUNT(*)
FROM dbo.SolicitudDocumentos x
WHERE x.Tipo = N'acceso'
  AND NOT EXISTS (SELECT 1 FROM dbo.SolicitudesAcceso s WHERE s.Id = x.SolicitudId)
UNION ALL
SELECT 'Pases huerfanos', COUNT(*)
FROM dbo.PaseProduccion p
WHERE p.Tipo = N'acceso'
  AND NOT EXISTS (SELECT 1 FROM dbo.SolicitudesAcceso s WHERE s.Id = p.SolicitudId);
GO


-- =====================================================================
-- PASO 6 · Limpieza final (SOLO cuando ya validaste el dashboard)
-- =====================================================================
-- DROP VIEW  dbo.vwAccesoDuplicados;
-- DROP TABLE dbo.zzBk_SolicitudesAcceso;
-- DROP TABLE dbo.zzBk_SolicitudAccesoObjetos;
-- DROP TABLE dbo.zzBk_SolicitudNotas;
-- DROP TABLE dbo.zzBk_SolicitudDocumentos;
-- DROP TABLE dbo.zzBk_PaseProduccion;
--
