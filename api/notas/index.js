'use strict';

/*
 * /api/notas  ·  bitácora de avances por solicitud
 *   GET ?tipo=&solicitudId=  -> lista de notas (más recientes primero)
 *   POST                     -> agrega nota { tipo, solicitudId, nota, autor?, fecha? }
 *   DELETE /{id}             -> elimina nota
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

let poolPromise = null;
function getPool() { if (!poolPromise) { poolPromise = sql.connect(config).catch(function (e) { poolPromise = null; throw e; }); } return poolPromise; }
function str(v, max) { if (v == null) return null; var s = String(v).trim(); if (!s) return null; return max ? s.slice(0, max) : s; }
function toInt(v) { if (v == null || v === '') return null; var n = parseInt(v, 10); return isNaN(n) ? null : n; }
function toDate(v) { var s = str(v); if (!s) return null; var d = new Date(s); return isNaN(d.getTime()) ? null : d; }
var TIPOS = { infra: 1, erp: 1, gen: 1, acceso: 1 };

async function handleList(context, req, respond) {
  const tipo = str(req.query ? req.query.tipo : null, 10);
  const sid = toInt(req.query ? req.query.solicitudId : null);
  if (!tipo || !TIPOS[tipo] || !sid) return respond(400, { ok: false, error: 'Faltan tipo/solicitudId.' });
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Tipo', sql.NVarChar(10), tipo);
    r.input('Sid', sql.Int, sid);
    const result = await r.query('SELECT Id, Tipo, SolicitudId, Nota, Autor, Fecha FROM dbo.SolicitudNotas WHERE Tipo=@Tipo AND SolicitudId=@Sid ORDER BY Fecha DESC, Id DESC');
    return respond(200, { ok: true, items: result.recordset || [] });
  } catch (err) {
    context.log.error('notas list: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudieron consultar las notas.', debug: { message: err.message } });
  }
}

async function handleCreate(context, req, respond) {
  const b = req.body || {};
  const tipo = str(b.tipo, 10);
  const sid = toInt(b.solicitudId);
  const nota = str(b.nota);
  if (!tipo || !TIPOS[tipo] || !sid) return respond(400, { ok: false, error: 'Faltan tipo/solicitudId.' });
  if (!nota) return respond(400, { ok: false, error: 'La nota no puede estar vacía.' });
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Tipo', sql.NVarChar(10), tipo);
    r.input('Sid', sql.Int, sid);
    r.input('Nota', sql.NVarChar(sql.MAX), nota);
    r.input('Autor', sql.NVarChar(200), str(b.autor, 200));
    const fecha = toDate(b.fecha);
    if (fecha) {
      r.input('Fecha', sql.DateTime2, fecha);
      var result = await r.query('INSERT INTO dbo.SolicitudNotas (Tipo, SolicitudId, Nota, Autor, Fecha) OUTPUT INSERTED.Id VALUES (@Tipo, @Sid, @Nota, @Autor, @Fecha)');
    } else {
      var result2 = await r.query('INSERT INTO dbo.SolicitudNotas (Tipo, SolicitudId, Nota, Autor) OUTPUT INSERTED.Id VALUES (@Tipo, @Sid, @Nota, @Autor)');
      result = result2;
    }
    const id = result.recordset && result.recordset[0] ? result.recordset[0].Id : null;
    return respond(201, { ok: true, id: id });
  } catch (err) {
    context.log.error('notas create: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo guardar la nota.', debug: { message: err.message } });
  }
}

async function handleDelete(context, req, respond) {
  const id = req.params && req.params.id ? parseInt(req.params.id, 10) : null;
  if (!id || isNaN(id)) return respond(400, { ok: false, error: 'Falta el Id.' });
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Id', sql.Int, id);
    await r.query('DELETE FROM dbo.SolicitudNotas WHERE Id = @Id');
    return respond(200, { ok: true, id: id });
  } catch (err) {
    context.log.error('notas delete: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo eliminar la nota.', debug: { message: err.message } });
  }
}

module.exports = async function (context, req) {
  const respond = function (status, obj) { context.res = { status: status, headers: { 'Content-Type': 'application/json' }, body: obj }; };
  if (!config.server || !config.database || !config.user || !config.password) {
    return respond(500, { ok: false, error: 'El servidor no tiene configurada la conexión a SQL.' });
  }
  const method = (req.method || 'POST').toUpperCase();
  if (method === 'GET')    { return await handleList(context, req, respond); }
  if (method === 'DELETE') { return await handleDelete(context, req, respond); }
  return await handleCreate(context, req, respond);
};
