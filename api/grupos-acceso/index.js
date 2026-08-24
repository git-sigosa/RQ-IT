'use strict';

/*
 * /api/grupos-acceso
 *   GET   -> lista de grupos (para el desplegable)
 *   POST  -> crea el grupo si no existe -> { ok, id, nombre }
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

async function handleList(context, req, respond) {
  try {
    const pool = await getPool();
    const result = await pool.request().query('SELECT Id, Nombre FROM dbo.GruposAcceso ORDER BY Nombre');
    return respond(200, { ok: true, items: result.recordset || [] });
  } catch (err) {
    context.log.error('grupos list: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudieron consultar los grupos.', debug: { message: err.message } });
  }
}

async function handleCreate(context, req, respond) {
  const nombre = str((req.body || {}).nombre, 200);
  if (!nombre) return respond(400, { ok: false, error: 'El nombre del grupo es obligatorio.' });
  try {
    const pool = await getPool();
    const r = pool.request();
    r.input('Nombre', sql.NVarChar(200), nombre);
    // crea si no existe; devuelve el Id (nuevo o existente)
    const result = await r.query(
      'IF NOT EXISTS (SELECT 1 FROM dbo.GruposAcceso WHERE Nombre = @Nombre) ' +
      'INSERT INTO dbo.GruposAcceso (Nombre) VALUES (@Nombre); ' +
      'SELECT Id FROM dbo.GruposAcceso WHERE Nombre = @Nombre;'
    );
    const id = result.recordset && result.recordset[0] ? result.recordset[0].Id : null;
    return respond(201, { ok: true, id: id, nombre: nombre });
  } catch (err) {
    context.log.error('grupos create: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo crear el grupo.', debug: { message: err.message } });
  }
}

module.exports = async function (context, req) {
  const respond = function (status, obj) { context.res = { status: status, headers: { 'Content-Type': 'application/json' }, body: obj }; };
  if (!config.server || !config.database || !config.user || !config.password) {
    return respond(500, { ok: false, error: 'El servidor no tiene configurada la conexión a SQL.' });
  }
  const method = (req.method || 'POST').toUpperCase();
  if (method === 'GET') { return await handleList(context, req, respond); }
  return await handleCreate(context, req, respond);
};
