'use strict';

/*
 * /api/solicitudes-acceso
 *   GET                -> lista (filtros ?estado= &q=)
 *   GET /{id}          -> detalle completo
 *   POST               -> crea solicitud de acceso a DATA
 *   PATCH /{id}        -> actualiza seguimiento (Estado / Responsable / FechaEntrega)
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

async function handleList(context, req, respond) {
  try {
    const pool = await getPool();
    const request = pool.request();
    const estado = req.query ? (req.query.estado || '') : '';
    const q = req.query ? (req.query.q || '') : '';
    const where = [];
    if (estado) { request.input('estado', sql.NVarChar(50), estado); where.push('Estado = @estado'); }
    if (q) {
      request.input('q', sql.NVarChar(200), '%' + q + '%');
      where.push('(Titulo LIKE @q OR Solicitante LIKE @q OR Grupo LIKE @q OR Usuario LIKE @q)');
    }
    const whereSql = where.length ? (' WHERE ' + where.join(' AND ')) : '';
    const result = await request.query(
      'SELECT TOP 500 Id, FechaRegistro, Titulo, Solicitante, Grupo, Usuario, ' +
      'Estado, Responsable, FechaEntrega, FechaActualizacion ' +
      'FROM dbo.SolicitudesAcceso' + whereSql + ' ORDER BY Id DESC'
    );
    return respond(200, { ok: true, items: result.recordset || [] });
  } catch (err) {
    context.log.error('Acceso list error: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo consultar la base de datos.', debug: { message: err.message } });
  }
}

async function handleGetOne(context, req, respond) {
  const id = parseInt(req.params.id, 10);
  if (!id || isNaN(id)) return respond(400, { ok: false, error: 'Id inválido.' });
  try {
    const pool = await getPool();
    const r = pool.request(); r.input('Id', sql.Int, id);
    const result = await r.query('SELECT * FROM dbo.SolicitudesAcceso WHERE Id = @Id');
    const row = result.recordset && result.recordset[0];
    if (!row) return respond(404, { ok: false, error: 'Solicitud no encontrada.' });
    return respond(200, { ok: true, item: row });
  } catch (err) {
    context.log.error('Acceso detalle error: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo obtener el detalle.', debug: { message: err.message } });
  }
}

async function handleUpdate(context, req, respond) {
  const id = req.params && req.params.id ? parseInt(req.params.id, 10) : null;
  if (!id || isNaN(id)) return respond(400, { ok: false, error: 'Falta el Id de la solicitud.' });
  const body = req.body || {};
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Id', sql.Int, id);
    r.input('Estado', sql.NVarChar(50), str(body.estado, 50));
    r.input('Responsable', sql.NVarChar(200), str(body.responsable, 200));
    r.input('FechaEntrega', sql.Date, toDate(body.fechaEntrega));
    const result = await r.query(
      'UPDATE dbo.SolicitudesAcceso SET Estado = COALESCE(@Estado, Estado), Responsable = @Responsable, ' +
      'FechaEntrega = @FechaEntrega, FechaActualizacion = SYSUTCDATETIME() WHERE Id = @Id'
    );
    const affected = result.rowsAffected && result.rowsAffected[0] ? result.rowsAffected[0] : 0;
    if (!affected) return respond(404, { ok: false, error: 'Solicitud no encontrada.' });
    return respond(200, { ok: true, id: id });
  } catch (err) {
    context.log.error('Acceso update error: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo actualizar la base de datos.', debug: { message: err.message } });
  }
}

async function handleCreate(context, req, respond) {
  const body = req.body || {};
  const model = body.model || body;
  const solicitante = str(model.solicitante, 200);
  const grupo = str(model.grupo, 200);
  const usuario = str(model.usuario, 200);
  if (!solicitante || !grupo) return respond(400, { ok: false, error: 'Faltan datos obligatorios (solicitante y grupo).' });

  const titulo = str((grupo || '') + (usuario ? (' · ' + usuario) : ''), 300);
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Titulo', sql.NVarChar(300), titulo);
    r.input('Solicitante', sql.NVarChar(200), solicitante);
    r.input('GrupoId', sql.Int, toInt(model.grupo_id));
    r.input('Grupo', sql.NVarChar(200), grupo);
    r.input('Usuario', sql.NVarChar(200), usuario);
    r.input('DetalleAcceso', sql.NVarChar(sql.MAX), str(model.detalle_acceso));
    r.input('Estado', sql.NVarChar(50), str(model.estado, 50) || 'Nuevo');
    r.input('PayloadJson', sql.NVarChar(sql.MAX), JSON.stringify(model));
    const result = await r.query(
      'INSERT INTO dbo.SolicitudesAcceso (Titulo, Solicitante, GrupoId, Grupo, Usuario, DetalleAcceso, Estado, PayloadJson) ' +
      'OUTPUT INSERTED.Id VALUES (@Titulo, @Solicitante, @GrupoId, @Grupo, @Usuario, @DetalleAcceso, @Estado, @PayloadJson)'
    );
    const newId = result.recordset && result.recordset[0] ? result.recordset[0].Id : null;
    return respond(201, { ok: true, id: newId });
  } catch (err) {
    context.log.error('Acceso create error: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo guardar en la base de datos.', debug: { message: err.message } });
  }
}

module.exports = async function (context, req) {
  const respond = function (status, obj) { context.res = { status: status, headers: { 'Content-Type': 'application/json' }, body: obj }; };
  if (!config.server || !config.database || !config.user || !config.password) {
    return respond(500, { ok: false, error: 'El servidor no tiene configurada la conexión a SQL.' });
  }
  const method = (req.method || 'POST').toUpperCase();
  if (method === 'GET')   { return (req.params && req.params.id) ? await handleGetOne(context, req, respond) : await handleList(context, req, respond); }
  if (method === 'PATCH') { return await handleUpdate(context, req, respond); }
  return await handleCreate(context, req, respond);
};
