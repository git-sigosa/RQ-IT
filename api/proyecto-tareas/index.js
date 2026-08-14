'use strict';

/*
 * /api/proyecto-tareas
 *   GET ?proyectoId=  -> tareas de un proyecto
 *   POST              -> crea tarea
 *   PATCH /{id}       -> actualiza tarea
 *   DELETE /{id}      -> elimina tarea
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
function toDate(v) { var s = str(v); if (!s) return null; var d = new Date(s); return isNaN(d.getTime()) ? null : d; }
function toInt(v) { if (v == null || v === '') return null; var n = parseInt(v, 10); return isNaN(n) ? null : n; }
function clampProg(v) { var n = toInt(v); if (n == null) return null; return Math.max(0, Math.min(100, n)); }

async function handleList(context, req, respond) {
  const pid = req.query ? toInt(req.query.proyectoId) : null;
  if (!pid) return respond(400, { ok: false, error: 'Falta proyectoId.' });
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('pid', sql.Int, pid);
    const result = await r.query(
      'SELECT Id, ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, Responsable, DependenciaId, EsHito, Orden ' +
      'FROM dbo.ProyectoTareas WHERE ProyectoId = @pid ORDER BY ISNULL(Orden, 9999), FechaInicio, Id'
    );
    return respond(200, { ok: true, items: result.recordset || [] });
  } catch (err) {
    context.log.error('tareas list: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudieron consultar las tareas.', debug: { message: err.message } });
  }
}

async function handleCreate(context, req, respond) {
  const b = req.body || {};
  const pid = toInt(b.proyectoId);
  const nombre = str(b.nombre, 300);
  if (!pid) return respond(400, { ok: false, error: 'Falta proyectoId.' });
  if (!nombre) return respond(400, { ok: false, error: 'El nombre de la tarea es obligatorio.' });
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('ProyectoId', sql.Int, pid);
    r.input('Nombre', sql.NVarChar(300), nombre);
    r.input('FechaInicio', sql.Date, toDate(b.fechaInicio));
    r.input('FechaFin', sql.Date, toDate(b.fechaFin));
    r.input('Progreso', sql.Int, clampProg(b.progreso) || 0);
    r.input('Responsable', sql.NVarChar(200), str(b.responsable, 200));
    r.input('DependenciaId', sql.Int, toInt(b.dependenciaId));
    r.input('EsHito', sql.Bit, (b.esHito === true || b.esHito === 1 || b.esHito === '1') ? 1 : 0);
    r.input('Orden', sql.Int, toInt(b.orden));
    const result = await r.query(
      'INSERT INTO dbo.ProyectoTareas (ProyectoId, Nombre, FechaInicio, FechaFin, Progreso, Responsable, DependenciaId, EsHito, Orden) ' +
      'OUTPUT INSERTED.Id VALUES (@ProyectoId, @Nombre, @FechaInicio, @FechaFin, @Progreso, @Responsable, @DependenciaId, @EsHito, @Orden)'
    );
    const id = result.recordset && result.recordset[0] ? result.recordset[0].Id : null;
    return respond(201, { ok: true, id: id });
  } catch (err) {
    context.log.error('tareas create: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo crear la tarea.', debug: { message: err.message } });
  }
}

async function handleUpdate(context, req, respond) {
  const id = req.params && req.params.id ? parseInt(req.params.id, 10) : null;
  if (!id || isNaN(id)) return respond(400, { ok: false, error: 'Falta el Id de la tarea.' });
  const b = req.body || {};
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Id', sql.Int, id);
    r.input('Nombre', sql.NVarChar(300), str(b.nombre, 300));
    r.input('FechaInicio', sql.Date, toDate(b.fechaInicio));
    r.input('FechaFin', sql.Date, toDate(b.fechaFin));
    r.input('Progreso', sql.Int, clampProg(b.progreso));
    r.input('Responsable', sql.NVarChar(200), str(b.responsable, 200));
    r.input('DependenciaId', sql.Int, toInt(b.dependenciaId));
    r.input('EsHito', sql.Bit, (b.esHito === true || b.esHito === 1 || b.esHito === '1') ? 1 : 0);
    r.input('Orden', sql.Int, toInt(b.orden));
    const result = await r.query(
      'UPDATE dbo.ProyectoTareas SET ' +
      'Nombre = COALESCE(@Nombre, Nombre), FechaInicio = @FechaInicio, FechaFin = @FechaFin, ' +
      'Progreso = COALESCE(@Progreso, Progreso), Responsable = @Responsable, DependenciaId = @DependenciaId, ' +
      'EsHito = @EsHito, Orden = @Orden, FechaActualizacion = SYSUTCDATETIME() WHERE Id = @Id'
    );
    const affected = result.rowsAffected && result.rowsAffected[0] ? result.rowsAffected[0] : 0;
    if (!affected) return respond(404, { ok: false, error: 'Tarea no encontrada.' });
    return respond(200, { ok: true, id: id });
  } catch (err) {
    context.log.error('tareas update: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo actualizar la tarea.', debug: { message: err.message } });
  }
}

async function handleDelete(context, req, respond) {
  const id = req.params && req.params.id ? parseInt(req.params.id, 10) : null;
  if (!id || isNaN(id)) return respond(400, { ok: false, error: 'Falta el Id de la tarea.' });
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Id', sql.Int, id);
    await r.query('DELETE FROM dbo.ProyectoTareas WHERE Id = @Id');
    return respond(200, { ok: true, id: id });
  } catch (err) {
    context.log.error('tareas delete: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo eliminar la tarea.', debug: { message: err.message } });
  }
}

module.exports = async function (context, req) {
  const respond = function (status, obj) { context.res = { status: status, headers: { 'Content-Type': 'application/json' }, body: obj }; };
  if (!config.server || !config.database || !config.user || !config.password) {
    return respond(500, { ok: false, error: 'El servidor no tiene configurada la conexión a SQL.' });
  }
  const method = (req.method || 'POST').toUpperCase();
  if (method === 'GET')    { return await handleList(context, req, respond); }
  if (method === 'PATCH')  { return await handleUpdate(context, req, respond); }
  if (method === 'DELETE') { return await handleDelete(context, req, respond); }
  return await handleCreate(context, req, respond);
};
