'use strict';

/*
 * /api/solicitudes-acceso
 *   GET                      -> lista (filtros ?estado= &q=)
 *   GET ?resumen=modulos     -> auditoría por módulo { Service, Solicitados, Aprobados, Otorgados }
 *   GET ?resumen=detalle     -> filas objeto x solicitud para la auditoría cruzada (módulo / persona / objeto)
 *   GET /{id}                -> detalle + objetos seleccionados
 *   POST                     -> crea solicitud + objetos de datos
 *   PATCH /{id}              -> actualiza seguimiento (Estado / Responsable / FechaEntrega)
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

/* normaliza model.objetos -> [{ tableName, service }] (acepta strings u objetos) */
function normObjetos(list) {
  if (!Array.isArray(list)) return [];
  var out = [], seen = {};
  for (var i = 0; i < list.length; i++) {
    var o = list[i], tn = null, sv = null;
    if (o && typeof o === 'object') { tn = str(o.tableName || o.TableName || o.nombre, 200); sv = str(o.service || o.Service, 50); }
    else { tn = str(o, 200); }
    if (!tn || seen[tn.toLowerCase()]) continue;
    seen[tn.toLowerCase()] = 1;
    out.push({ tableName: tn, service: sv });
  }
  return out;
}

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

async function handleResumenModulos(context, req, respond) {
  try {
    const pool = await getPool();
    const result = await pool.request().query(
      'SELECT o.Service AS Service, ' +
      'COUNT(*) AS Solicitados, ' +
      "SUM(CASE WHEN s.Estado = 'Aprobado' THEN 1 ELSE 0 END) AS Aprobados, " +
      "SUM(CASE WHEN s.Estado = 'Completado' THEN 1 ELSE 0 END) AS Otorgados " +
      'FROM dbo.SolicitudAccesoObjetos o ' +
      'JOIN dbo.SolicitudesAcceso s ON s.Id = o.SolicitudId ' +
      'GROUP BY o.Service ORDER BY o.Service'
    );
    return respond(200, { ok: true, items: result.recordset || [] });
  } catch (err) {
    context.log.error('Acceso resumen error: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo consultar el resumen por módulo.', debug: { message: err.message } });
  }
}

/* Filas planas objeto x solicitud: la auditoría del dashboard arma el cruce módulo/persona/objeto en el cliente. */
async function handleResumenDetalle(context, req, respond) {
  try {
    const pool = await getPool();
    const result = await pool.request().query(
      'SELECT TOP 5000 o.SolicitudId, o.TableName, o.Service, ' +
      's.Solicitante, s.Usuario, s.Grupo, s.Estado, s.Responsable, s.FechaRegistro ' +
      'FROM dbo.SolicitudAccesoObjetos o ' +
      'JOIN dbo.SolicitudesAcceso s ON s.Id = o.SolicitudId ' +
      'ORDER BY o.SolicitudId DESC, o.Service, o.TableName'
    );
    return respond(200, { ok: true, items: result.recordset || [] });
  } catch (err) {
    context.log.error('Acceso detalle auditoría error: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo consultar el detalle de auditoría.', debug: { message: err.message } });
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
    const r2 = pool.request(); r2.input('Id', sql.Int, id);
    const objs = await r2.query('SELECT TableName, Service FROM dbo.SolicitudAccesoObjetos WHERE SolicitudId = @Id ORDER BY Service, TableName');
    return respond(200, { ok: true, item: row, objetos: (objs.recordset || []) });
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
  const objetos = normObjetos(model.objetos);
  if (!solicitante || !grupo) return respond(400, { ok: false, error: 'Faltan datos obligatorios (solicitante y grupo).' });

  const titulo = str((grupo || '') + (usuario ? (' · ' + usuario) : ''), 300);
  const pool = await getPool();
  const tx = new sql.Transaction(pool);
  try {
    await tx.begin();
    const r = new sql.Request(tx);
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

    for (let i = 0; i < objetos.length; i++) {
      const ro = new sql.Request(tx);
      ro.input('SolicitudId', sql.Int, newId);
      ro.input('TableName', sql.NVarChar(200), objetos[i].tableName);
      ro.input('Service', sql.NVarChar(50), objetos[i].service);
      await ro.query('INSERT INTO dbo.SolicitudAccesoObjetos (SolicitudId, TableName, Service) VALUES (@SolicitudId, @TableName, @Service)');
    }

    await tx.commit();
    return respond(201, { ok: true, id: newId, objetos: objetos.length });
  } catch (err) {
    try { await tx.rollback(); } catch (e) {}
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
  if (method === 'GET') {
    const resumen = req.query ? String(req.query.resumen || '').toLowerCase() : '';
    if (resumen === 'modulos') return await handleResumenModulos(context, req, respond);
    if (resumen === 'detalle') return await handleResumenDetalle(context, req, respond);
    return (req.params && req.params.id) ? await handleGetOne(context, req, respond) : await handleList(context, req, respond);
  }
  if (method === 'PATCH') { return await handleUpdate(context, req, respond); }
  return await handleCreate(context, req, respond);
};
