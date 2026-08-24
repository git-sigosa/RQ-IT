'use strict';

/*
 * /api/pases  ·  planificación del pase a producción (1 por solicitud)
 *   GET ?tipo=&solicitudId=  -> el pase de esa solicitud (item: null si no existe)
 *   GET                      -> bandeja: todos los pases (para la vista global)
 *   POST                     -> upsert { tipo, solicitudId, titulo, fechaPlanificada,
 *                                        ventanaInicio, ventanaFin, responsable,
 *                                        aprobador, estado, planRollback }
 */

const sql = require('mssql');

const config = {
  server: process.env.SQL_SERVER,
  port: parseInt(process.env.SQL_PORT || '1433', 10),
  database: process.env.SQL_DATABASE,
  user: process.env.SQL_USER,
  password: process.env.SQL_PASSWORD,
  options: {
    encrypt: (process.env.SQL_ENCRYPT || 'true').toLowerCase() === 'true',
    trustServerCertificate: (process.env.SQL_TRUST_CERT || 'true').toLowerCase() === 'true'
  },
  pool: { max: 4, min: 0, idleTimeoutMillis: 30000 },
  connectionTimeout: 20000,
  requestTimeout: 20000
};

var TIPOS = { infra: 1, erp: 1, gen: 1, acceso: 1 };
let poolPromise = null;
function getPool() { if (!poolPromise) { poolPromise = sql.connect(config).catch(function (e) { poolPromise = null; throw e; }); } return poolPromise; }
function str(v, max) { if (v == null) return null; var s = String(v).trim(); if (!s) return null; return max ? s.slice(0, max) : s; }
function toInt(v) { if (v == null || v === '') return null; var n = parseInt(v, 10); return isNaN(n) ? null : n; }
function toDate(v) { var s = str(v); if (!s) return null; var d = new Date(s); return isNaN(d.getTime()) ? null : d; }

async function handleOne(context, req, respond, tipo, sid) {
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Tipo', sql.NVarChar(10), tipo);
    r.input('Sid', sql.Int, sid);
    const result = await r.query('SELECT * FROM dbo.PaseProduccion WHERE Tipo=@Tipo AND SolicitudId=@Sid');
    const row = result.recordset && result.recordset[0];
    return respond(200, { ok: true, item: row || null });
  } catch (err) {
    context.log.error('pases one: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo consultar el pase.', debug: { message: err.message } });
  }
}

async function handleList(context, req, respond) {
  try {
    const pool = await getPool();
    const result = await pool.request().query(
      'SELECT Id, Tipo, SolicitudId, Titulo, FechaPlanificada, VentanaInicio, VentanaFin, Responsable, Aprobador, Estado, ' +
      'DocArquitectura, DocFuncional, DocSoporte, Induccion, FechaActualizacion ' +
      'FROM dbo.PaseProduccion ORDER BY CASE WHEN FechaPlanificada IS NULL THEN 1 ELSE 0 END, FechaPlanificada, Id DESC'
    );
    return respond(200, { ok: true, items: result.recordset || [] });
  } catch (err) {
    context.log.error('pases list: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo consultar la bandeja de pases.', debug: { message: err.message } });
  }
}

async function handleUpsert(context, req, respond) {
  const b = req.body || {};
  const tipo = str(b.tipo, 10);
  const sid = toInt(b.solicitudId);
  if (!tipo || !TIPOS[tipo] || !sid) return respond(400, { ok: false, error: 'Faltan tipo/solicitudId.' });
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Tipo', sql.NVarChar(10), tipo);
    r.input('Sid', sql.Int, sid);
    r.input('Titulo', sql.NVarChar(300), str(b.titulo, 300));
    r.input('FechaPlanificada', sql.Date, toDate(b.fechaPlanificada));
    r.input('VentanaInicio', sql.DateTime2, toDate(b.ventanaInicio));
    r.input('VentanaFin', sql.DateTime2, toDate(b.ventanaFin));
    r.input('Responsable', sql.NVarChar(200), str(b.responsable, 200));
    r.input('Aprobador', sql.NVarChar(200), str(b.aprobador, 200));
    r.input('Estado', sql.NVarChar(30), str(b.estado, 30) || 'Planificado');
    r.input('PlanRollback', sql.NVarChar(sql.MAX), str(b.planRollback));
    r.input('DocArquitectura', sql.Bit, b.docArquitectura ? 1 : 0);
    r.input('DocFuncional', sql.Bit, b.docFuncional ? 1 : 0);
    r.input('DocSoporte', sql.Bit, b.docSoporte ? 1 : 0);
    r.input('Induccion', sql.Bit, b.induccion ? 1 : 0);
    r.input('ReceptorDocumentacion', sql.NVarChar(200), str(b.receptorDocumentacion, 200));
    r.input('ReceptorInduccion', sql.NVarChar(200), str(b.receptorInduccion, 200));
    r.input('ContrapartePlanificacion', sql.NVarChar(200), str(b.contrapartePlanificacion, 200));
    r.input('DocArquitecturaFecha', sql.Date, toDate(b.docArquitecturaFecha));
    r.input('DocFuncionalFecha', sql.Date, toDate(b.docFuncionalFecha));
    r.input('DocSoporteFecha', sql.Date, toDate(b.docSoporteFecha));
    r.input('InduccionFecha', sql.Date, toDate(b.induccionFecha));
    await r.query(
      'MERGE dbo.PaseProduccion AS t ' +
      'USING (SELECT @Tipo AS Tipo, @Sid AS SolicitudId) AS s ON t.Tipo=s.Tipo AND t.SolicitudId=s.SolicitudId ' +
      'WHEN MATCHED THEN UPDATE SET Titulo=@Titulo, FechaPlanificada=@FechaPlanificada, VentanaInicio=@VentanaInicio, ' +
      'VentanaFin=@VentanaFin, Responsable=@Responsable, Aprobador=@Aprobador, Estado=@Estado, PlanRollback=@PlanRollback, ' +
      'DocArquitectura=@DocArquitectura, DocFuncional=@DocFuncional, DocSoporte=@DocSoporte, Induccion=@Induccion, ' +
      'DocArquitecturaFecha=@DocArquitecturaFecha, DocFuncionalFecha=@DocFuncionalFecha, DocSoporteFecha=@DocSoporteFecha, InduccionFecha=@InduccionFecha, ' +
      'ReceptorDocumentacion=@ReceptorDocumentacion, ReceptorInduccion=@ReceptorInduccion, ContrapartePlanificacion=@ContrapartePlanificacion, FechaActualizacion=SYSUTCDATETIME() ' +
      'WHEN NOT MATCHED THEN INSERT (Tipo, SolicitudId, Titulo, FechaPlanificada, VentanaInicio, VentanaFin, Responsable, Aprobador, Estado, PlanRollback, DocArquitectura, DocFuncional, DocSoporte, Induccion, DocArquitecturaFecha, DocFuncionalFecha, DocSoporteFecha, InduccionFecha, ReceptorDocumentacion, ReceptorInduccion, ContrapartePlanificacion, FechaActualizacion) ' +
      'VALUES (@Tipo, @Sid, @Titulo, @FechaPlanificada, @VentanaInicio, @VentanaFin, @Responsable, @Aprobador, @Estado, @PlanRollback, @DocArquitectura, @DocFuncional, @DocSoporte, @Induccion, @DocArquitecturaFecha, @DocFuncionalFecha, @DocSoporteFecha, @InduccionFecha, @ReceptorDocumentacion, @ReceptorInduccion, @ContrapartePlanificacion, SYSUTCDATETIME());'
    );
    return respond(200, { ok: true });
  } catch (err) {
    context.log.error('pases upsert: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo guardar el pase.', debug: { message: err.message } });
  }
}

module.exports = async function (context, req) {
  const respond = function (status, obj) { context.res = { status: status, headers: { 'Content-Type': 'application/json' }, body: obj }; };
  if (!config.server || !config.database || !config.user || !config.password) {
    return respond(500, { ok: false, error: 'El servidor no tiene configurada la conexión a SQL.' });
  }
  const method = (req.method || 'POST').toUpperCase();
  if (method === 'GET') {
    const tipo = str(req.query ? req.query.tipo : null, 10);
    const sid = toInt(req.query ? req.query.solicitudId : null);
    if (tipo && sid) return await handleOne(context, req, respond, tipo, sid);
    return await handleList(context, req, respond);
  }
  return await handleUpsert(context, req, respond);
};
