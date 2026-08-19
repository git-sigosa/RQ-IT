'use strict';

/*
 * /api/documentos  ·  documentación adjunta (guardada EN SQL)
 *   GET ?tipo=&solicitudId=  -> lista (metadatos, sin contenido)
 *   GET /{id}                -> descarga el archivo (este link se comparte por correo)
 *   POST                     -> sube { tipo, solicitudId, nombre, contentType, base64, autor }
 *   DELETE /{id}             -> elimina
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
  requestTimeout: 30000
};

const MAX_BYTES = 10 * 1024 * 1024; // 10 MB
var TIPOS = { infra: 1, erp: 1, gen: 1 };

let poolPromise = null;
function getPool() { if (!poolPromise) { poolPromise = sql.connect(config).catch(function (e) { poolPromise = null; throw e; }); } return poolPromise; }
function str(v, max) { if (v == null) return null; var s = String(v).trim(); if (!s) return null; return max ? s.slice(0, max) : s; }
function toInt(v) { if (v == null || v === '') return null; var n = parseInt(v, 10); return isNaN(n) ? null : n; }

async function handleList(context, req, respond) {
  const tipo = str(req.query ? req.query.tipo : null, 10);
  const sid = toInt(req.query ? req.query.solicitudId : null);
  if (!tipo || !TIPOS[tipo] || !sid) return respond(400, { ok: false, error: 'Faltan tipo/solicitudId.' });
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Tipo', sql.NVarChar(10), tipo);
    r.input('Sid', sql.Int, sid);
    const result = await r.query('SELECT Id, Nombre, ContentType, Tamano, Autor, Fecha FROM dbo.SolicitudDocumentos WHERE Tipo=@Tipo AND SolicitudId=@Sid ORDER BY Fecha DESC, Id DESC');
    return respond(200, { ok: true, items: result.recordset || [] });
  } catch (err) {
    context.log.error('documentos list: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudieron consultar los documentos.', debug: { message: err.message } });
  }
}

async function handleDownload(context, req, id) {
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Id', sql.Int, id);
    const result = await r.query('SELECT Nombre, ContentType, Contenido FROM dbo.SolicitudDocumentos WHERE Id=@Id');
    const row = result.recordset && result.recordset[0];
    if (!row) { context.res = { status: 404, headers: { 'Content-Type': 'application/json' }, body: { ok: false, error: 'Documento no encontrado.' } }; return; }
    const nombre = (row.Nombre || 'documento').replace(/[\r\n"]/g, '_');
    context.res = {
      status: 200,
      headers: {
        'Content-Type': row.ContentType || 'application/octet-stream',
        'Content-Disposition': 'inline; filename="' + nombre + '"',
        'Cache-Control': 'private, max-age=60'
      },
      body: row.Contenido,
      isRaw: true
    };
  } catch (err) {
    context.log.error('documentos download: ' + err.message);
    context.res = { status: 500, headers: { 'Content-Type': 'application/json' }, body: { ok: false, error: 'No se pudo descargar.' } };
  }
}

async function handleCreate(context, req, respond) {
  const b = req.body || {};
  const tipo = str(b.tipo, 10);
  const sid = toInt(b.solicitudId);
  const nombre = str(b.nombre, 300);
  const base64 = b.base64;
  if (!tipo || !TIPOS[tipo] || !sid) return respond(400, { ok: false, error: 'Faltan tipo/solicitudId.' });
  if (!nombre) return respond(400, { ok: false, error: 'Falta el nombre del archivo.' });
  if (!base64 || typeof base64 !== 'string') return respond(400, { ok: false, error: 'Falta el contenido del archivo.' });

  var buf;
  try { buf = Buffer.from(base64, 'base64'); } catch (e) { return respond(400, { ok: false, error: 'Contenido inválido.' }); }
  if (!buf.length) return respond(400, { ok: false, error: 'El archivo está vacío.' });
  if (buf.length > MAX_BYTES) return respond(413, { ok: false, error: 'El archivo supera el límite de 10 MB.' });

  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Tipo', sql.NVarChar(10), tipo);
    r.input('Sid', sql.Int, sid);
    r.input('Nombre', sql.NVarChar(300), nombre);
    r.input('ContentType', sql.NVarChar(150), str(b.contentType, 150) || 'application/octet-stream');
    r.input('Tamano', sql.Int, buf.length);
    r.input('Contenido', sql.VarBinary(sql.MAX), buf);
    r.input('Autor', sql.NVarChar(200), str(b.autor, 200));
    const result = await r.query('INSERT INTO dbo.SolicitudDocumentos (Tipo, SolicitudId, Nombre, ContentType, Tamano, Contenido, Autor) OUTPUT INSERTED.Id VALUES (@Tipo, @Sid, @Nombre, @ContentType, @Tamano, @Contenido, @Autor)');
    const newId = result.recordset && result.recordset[0] ? result.recordset[0].Id : null;
    return respond(201, { ok: true, id: newId });
  } catch (err) {
    context.log.error('documentos create: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo guardar el documento.', debug: { message: err.message } });
  }
}

async function handleDelete(context, req, respond, id) {
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Id', sql.Int, id);
    await r.query('DELETE FROM dbo.SolicitudDocumentos WHERE Id=@Id');
    return respond(200, { ok: true, id: id });
  } catch (err) {
    context.log.error('documentos delete: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo eliminar.', debug: { message: err.message } });
  }
}

module.exports = async function (context, req) {
  const respond = function (status, obj) { context.res = { status: status, headers: { 'Content-Type': 'application/json' }, body: obj }; };
  if (!config.server || !config.database || !config.user || !config.password) {
    return respond(500, { ok: false, error: 'El servidor no tiene configurada la conexión a SQL.' });
  }
  const id = req.params && req.params.id ? parseInt(req.params.id, 10) : null;
  const method = (req.method || 'POST').toUpperCase();
  if (method === 'GET') {
    if (id) return await handleDownload(context, req, id);
    return await handleList(context, req, respond);
  }
  if (method === 'DELETE') {
    if (!id) return respond(400, { ok: false, error: 'Falta el Id.' });
    return await handleDelete(context, req, respond, id);
  }
  return await handleCreate(context, req, respond);
};
