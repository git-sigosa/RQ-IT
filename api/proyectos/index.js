'use strict';

/*
 * /api/proyectos
 *   GET            -> lista de proyectos
 *   POST           -> crea proyecto (nombre requerido) -> { ok, id }
 *   PATCH /{id}    -> actualiza proyecto
 * Variables de entorno SQL_* (igual que las demás funciones).
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
function getPool() {
  if (!poolPromise) { poolPromise = sql.connect(config).catch(function (e) { poolPromise = null; throw e; }); }
  return poolPromise;
}
function str(v, max) { if (v == null) return null; var s = String(v).trim(); if (!s) return null; return max ? s.slice(0, max) : s; }
function toDate(v) { var s = str(v); if (!s) return null; var d = new Date(s); return isNaN(d.getTime()) ? null : d; }

async function handleList(context, req, respond) {
  try {
    const pool = await getPool();
    const result = await pool.request().query(
      'SELECT Id, Nombre, Descripcion, Responsable, FechaInicio, FechaFin, Estado, FechaRegistro ' +
      'FROM dbo.Proyectos ORDER BY Nombre'
    );
    return respond(200, { ok: true, items: result.recordset || [] });
  } catch (err) {
    context.log.error('proyectos list: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo consultar los proyectos.', debug: { message: err.message } });
  }
}

async function handleCreate(context, req, respond) {
  const b = req.body || {};
  const nombre = str(b.nombre, 200);
  if (!nombre) return respond(400, { ok: false, error: 'El nombre del proyecto es obligatorio.' });
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Nombre', sql.NVarChar(200), nombre);
    r.input('Descripcion', sql.NVarChar(sql.MAX), str(b.descripcion));
    r.input('Responsable', sql.NVarChar(200), str(b.responsable, 200));
    r.input('FechaInicio', sql.Date, toDate(b.fechaInicio));
    r.input('FechaFin', sql.Date, toDate(b.fechaFin));
    r.input('Estado', sql.NVarChar(50), str(b.estado, 50) || 'Activo');
    const result = await r.query(
      'INSERT INTO dbo.Proyectos (Nombre, Descripcion, Responsable, FechaInicio, FechaFin, Estado) ' +
      'OUTPUT INSERTED.Id VALUES (@Nombre, @Descripcion, @Responsable, @FechaInicio, @FechaFin, @Estado)'
    );
    const id = result.recordset && result.recordset[0] ? result.recordset[0].Id : null;
    return respond(201, { ok: true, id: id });
  } catch (err) {
    context.log.error('proyectos create: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo crear el proyecto.', debug: { message: err.message } });
  }
}

async function handleUpdate(context, req, respond) {
  const id = req.params && req.params.id ? parseInt(req.params.id, 10) : null;
  if (!id || isNaN(id)) return respond(400, { ok: false, error: 'Falta el Id del proyecto.' });
  const b = req.body || {};
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Id', sql.Int, id);
    r.input('Nombre', sql.NVarChar(200), str(b.nombre, 200));
    r.input('Descripcion', sql.NVarChar(sql.MAX), str(b.descripcion));
    r.input('Responsable', sql.NVarChar(200), str(b.responsable, 200));
    r.input('FechaInicio', sql.Date, toDate(b.fechaInicio));
    r.input('FechaFin', sql.Date, toDate(b.fechaFin));
    r.input('Estado', sql.NVarChar(50), str(b.estado, 50));
    const result = await r.query(
      'UPDATE dbo.Proyectos SET ' +
      'Nombre = COALESCE(@Nombre, Nombre), Descripcion = @Descripcion, Responsable = @Responsable, ' +
      'FechaInicio = @FechaInicio, FechaFin = @FechaFin, Estado = COALESCE(@Estado, Estado) WHERE Id = @Id'
    );
    const affected = result.rowsAffected && result.rowsAffected[0] ? result.rowsAffected[0] : 0;
    if (!affected) return respond(404, { ok: false, error: 'Proyecto no encontrado.' });
    return respond(200, { ok: true, id: id });
  } catch (err) {
    context.log.error('proyectos update: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo actualizar el proyecto.', debug: { message: err.message } });
  }
}

module.exports = async function (context, req) {
  const respond = function (status, obj) { context.res = { status: status, headers: { 'Content-Type': 'application/json' }, body: obj }; };
  if (!config.server || !config.database || !config.user || !config.password) {
    return respond(500, { ok: false, error: 'El servidor no tiene configurada la conexión a SQL.' });
  }
  const method = (req.method || 'POST').toUpperCase();
  if (method === 'GET')   { return await handleList(context, req, respond); }
  if (method === 'PATCH') { return await handleUpdate(context, req, respond); }
  return await handleCreate(context, req, respond);
};
