'use strict';

/*
 * POST /api/solicitudes
 * Recibe { model, sharepoint_row } desde el formulario y lo inserta en
 * dbo.Solicitudes (SQL Server). Las credenciales se leen de variables de
 * entorno configuradas en la Static Web App — nunca van en el código:
 *
 *   SQL_SERVER      54.68.237.199
 *   SQL_PORT        1466
 *   SQL_DATABASE    RQ-IT
 *   SQL_USER        app.rq-it
 *   SQL_PASSWORD    (secreto)
 *   SQL_ENCRYPT       (opcional, "true"/"false"; por defecto "true")
 *   SQL_TRUST_CERT    (opcional, "true"/"false"; por defecto "true")
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

// Pool reutilizable entre invocaciones "calientes" de la Function.
let poolPromise = null;
function getPool() {
  if (!poolPromise) {
    poolPromise = sql.connect(config).catch(function (err) {
      poolPromise = null; // permite reintentar en la próxima llamada
      throw err;
    });
  }
  return poolPromise;
}

/* --- helpers de coerción --- */
function str(v, max) {
  if (v === undefined || v === null) return null;
  var s = String(v).trim();
  if (s === '') return null;
  return max ? s.slice(0, max) : s;
}
function toNum(v) {
  if (v === undefined || v === null || v === '') return null;
  var n = Number(v);
  return isNaN(n) ? null : n;
}
function toInt(v) {
  var n = toNum(v);
  return n === null ? null : Math.trunc(n);
}
function toDate(v) {
  var s = str(v);
  if (!s) return null;
  var d = new Date(s);
  return isNaN(d.getTime()) ? null : d;
}

module.exports = async function (context, req) {
  const respond = function (status, obj) {
    context.res = {
      status: status,
      headers: { 'Content-Type': 'application/json' },
      body: obj
    };
  };

  // Validación básica de configuración
  if (!config.server || !config.database || !config.user || !config.password) {
    context.log.error('Faltan variables de entorno SQL_*.');
    return respond(500, { ok: false, error: 'El servidor no tiene configurada la conexión a SQL.' });
  }

  const body = req.body || {};
  const model = body.model || body;         // acepta payload envuelto o modelo directo
  const row = body.sharepoint_row || {};

  if (!model || typeof model !== 'object') {
    return respond(400, { ok: false, error: 'Cuerpo inválido: se esperaba un objeto JSON.' });
  }

  const ig = model.informacion_general || {};
  const cc = model.computo_y_contenedores || {};
  const bd = model.base_de_datos || {};
  const ra = model.redes_y_apis || {};
  const sm = model.seguridad_y_monitoreo || {};
  const cr = model.clasificacion_registro || {};

  const titulo = str(row['Título'], 300) ||
    (ig.identificador ? (ig.identificador + ' – ' + (ig.nombre_aplicacion || '')) : str(ig.nombre_aplicacion, 300));

  // Campo obligatorio mínimo del negocio
  if (!str(ig.nombre_aplicacion)) {
    return respond(400, { ok: false, error: 'Falta el nombre de la aplicación.' });
  }

  try {
    const pool = await getPool();
    const request = pool.request();

    request.input('Titulo',                 sql.NVarChar(300), titulo);
    request.input('Aplicacion',             sql.NVarChar(200), str(ig.nombre_aplicacion, 200));
    request.input('Identificador',          sql.NVarChar(100), str(ig.identificador, 100));
    request.input('Proyecto',               sql.NVarChar(200), str(ig.proyecto, 200));
    request.input('LiderProyecto',          sql.NVarChar(200), str(ig.lider_tecnico, 200));
    request.input('FechaProduccion',        sql.Date,          toDate(ig.fecha_produccion));
    request.input('Funcionalidad',          sql.NVarChar(sql.MAX), str(ig.descripcion));

    request.input('ArquitecturaDespliegue', sql.NVarChar(100), str(cc.arquitectura_despliegue, 100));
    request.input('FrontEnd',               sql.NVarChar(500), str(row['FrontEnd'], 500));
    request.input('BackendAPI',             sql.NVarChar(500), str(row['BackendAPI'], 500));
    request.input('CPURequerida',           sql.Decimal(9, 2),  toNum(cc.cpu_total_vcpu));
    request.input('RAMRequeridaGB',         sql.Decimal(9, 2),  toNum(cc.ram_total_gb));

    request.input('BaseDatos',              sql.NVarChar(100), str(bd.motor_bd, 100));
    request.input('ModeloDespliegueBD',     sql.NVarChar(100), str(bd.modelo_despliegue, 100));
    request.input('StorageGB',              sql.Decimal(12, 2), toNum(bd.almacenamiento_inicial_gb));
    request.input('CrecimientoMensualGB',   sql.Decimal(12, 2), toNum(bd.crecimiento_mensual_gb));

    request.input('DominioPublico',         sql.NVarChar(200), str(ra.dominio_publico, 200));
    request.input('TipoAcceso',             sql.NVarChar(100), str(ra.tipo_acceso, 100));

    request.input('MetodoAutenticacion',    sql.NVarChar(100), str(sm.metodo_autenticacion_usuarios, 100));
    request.input('NivelSensibilidad',      sql.NVarChar(100), str(sm.nivel_sensibilidad_datos, 100));

    request.input('Ambiente',               sql.NVarChar(50),  str(cr.ambiente, 50));
    request.input('UsuariosConcurrentes',   sql.Int,           toInt(cr.usuarios_concurrentes));
    request.input('Criticidad',             sql.NVarChar(20),  str(cr.criticidad, 20));
    request.input('RequiereHA',             sql.NVarChar(5),   str(cr.requiere_ha, 5));
    request.input('RequiereDR',             sql.NVarChar(5),   str(cr.requiere_dr, 5));
    request.input('Estado',                 sql.NVarChar(50),  str(cr.estado, 50));

    request.input('PayloadJson',            sql.NVarChar(sql.MAX), JSON.stringify(model));

    const result = await request.query(
      'INSERT INTO dbo.Solicitudes (' +
      'Titulo, Aplicacion, Identificador, Proyecto, LiderProyecto, FechaProduccion, Funcionalidad, ' +
      'ArquitecturaDespliegue, FrontEnd, BackendAPI, CPURequerida, RAMRequeridaGB, ' +
      'BaseDatos, ModeloDespliegueBD, StorageGB, CrecimientoMensualGB, ' +
      'DominioPublico, TipoAcceso, MetodoAutenticacion, NivelSensibilidad, ' +
      'Ambiente, UsuariosConcurrentes, Criticidad, RequiereHA, RequiereDR, Estado, PayloadJson) ' +
      'OUTPUT INSERTED.Id ' +
      'VALUES (' +
      '@Titulo, @Aplicacion, @Identificador, @Proyecto, @LiderProyecto, @FechaProduccion, @Funcionalidad, ' +
      '@ArquitecturaDespliegue, @FrontEnd, @BackendAPI, @CPURequerida, @RAMRequeridaGB, ' +
      '@BaseDatos, @ModeloDespliegueBD, @StorageGB, @CrecimientoMensualGB, ' +
      '@DominioPublico, @TipoAcceso, @MetodoAutenticacion, @NivelSensibilidad, ' +
      '@Ambiente, @UsuariosConcurrentes, @Criticidad, @RequiereHA, @RequiereDR, @Estado, @PayloadJson)'
    );

    const newId = result.recordset && result.recordset[0] ? result.recordset[0].Id : null;
    context.log('Solicitud guardada con Id ' + newId);
    return respond(201, { ok: true, id: newId });
  } catch (err) {
    context.log.error('Error al guardar en SQL: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo guardar en la base de datos.' });
  }
};
