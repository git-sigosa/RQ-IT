'use strict';

/*
 * GET /api/usuarios
 * Devuelve la lista de usuarios del directorio (Microsoft Entra ID) para
 * poblar los selectores de Líder / Solicitante / Responsable.
 *
 * Usa flujo client-credentials (app-only) con el MISMO registro de app del login.
 * Requiere:
 *   - Variables de entorno: AAD_TENANT_ID, AAD_CLIENT_ID, AAD_CLIENT_SECRET
 *   - Permiso de aplicación de Microsoft Graph: User.Read.All (con consentimiento de admin)
 *
 * La respuesta se cachea en memoria unos minutos para no llamar a Graph en cada carga.
 */

var CACHE = { data: null, exp: 0 };
var CACHE_MS = 5 * 60 * 1000;

function reqEnv() {
  return {
    tenant: process.env.AAD_TENANT_ID,
    clientId: process.env.AAD_CLIENT_ID,
    clientSecret: process.env.AAD_CLIENT_SECRET
  };
}

async function getToken(env) {
  var url = 'https://login.microsoftonline.com/' + env.tenant + '/oauth2/v2.0/token';
  var body = new URLSearchParams({
    client_id: env.clientId,
    client_secret: env.clientSecret,
    scope: 'https://graph.microsoft.com/.default',
    grant_type: 'client_credentials'
  });
  var r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: body });
  var j = await r.json();
  if (!r.ok) throw new Error('token: ' + (j.error_description || j.error || r.status));
  return j.access_token;
}

// Solo usuarios de este dominio (configurable con AAD_ALLOWED_DOMAIN)
var DOMAIN = '@' + (process.env.AAD_ALLOWED_DOMAIN || 'sigosa.com').replace(/^@/, '').toLowerCase();

async function fetchUsers(token) {
  var out = [];
  var url = 'https://graph.microsoft.com/v1.0/users?$select=displayName,mail,userPrincipalName,jobTitle&$top=999';
  var guard = 0;
  while (url && guard < 10) {
    guard++;
    var r = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
    var j = await r.json();
    if (!r.ok) throw new Error('graph: ' + ((j.error && j.error.message) || r.status));
    (j.value || []).forEach(function (u) {
      var name = u.displayName;
      var email = u.mail || u.userPrincipalName || '';
      // Solo miembros del dominio; excluye invitados (#EXT#) y otros dominios
      var el = email.toLowerCase();
      if (name && el.indexOf('#ext#') === -1 && el.slice(-DOMAIN.length) === DOMAIN) {
        out.push({ name: name, email: email, jobTitle: u.jobTitle || '' });
      }
    });
    url = j['@odata.nextLink'] || null;
  }
  out.sort(function (a, b) { return a.name.localeCompare(b.name, 'es'); });
  return out;
}

module.exports = async function (context, req) {
  var respond = function (status, obj) {
    context.res = { status: status, headers: { 'Content-Type': 'application/json' }, body: obj };
  };

  var now = Date.now();
  if (CACHE.data && CACHE.exp > now) {
    return respond(200, { ok: true, cached: true, items: CACHE.data });
  }

  var env = reqEnv();
  if (!env.tenant || !env.clientId || !env.clientSecret) {
    return respond(500, { ok: false, error: 'Faltan variables AAD_TENANT_ID / AAD_CLIENT_ID / AAD_CLIENT_SECRET.' });
  }

  try {
    var token = await getToken(env);
    var users = await fetchUsers(token);
    CACHE = { data: users, exp: now + CACHE_MS };
    return respond(200, { ok: true, items: users });
  } catch (err) {
    context.log.error('usuarios error: ' + err.message);
    return respond(500, { ok: false, error: 'No se pudo consultar el directorio.', debug: { message: err.message } });
  }
};
