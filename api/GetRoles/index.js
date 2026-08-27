'use strict';

/*
 * rolesSource para Azure Static Web Apps.
 * SWA invoca este endpoint tras el login y usa los roles devueltos
 * para autorizar rutas (staticwebapp.config.json).
 *
 * Regla:
 *   - Si el correo del usuario está en ACCESO_ONLY_EMAILS  -> rol ["acceso"]
 *     (solo puede ver /acceso.html y sus APIs).
 *   - Cualquier otro usuario autenticado                    -> rol ["interno"]
 *     (acceso completo a todos los módulos).
 *
 * Configura en la app un valor de tipo lista separada por comas/; :
 *   ACCESO_ONLY_EMAILS = persona1@sigosa.com, persona2@sigosa.com
 */

module.exports = async function (context, req) {
  try {
    const body = req.body || {};
    const email = String(body.userDetails || '').trim().toLowerCase();
    const raw = String(process.env.ACCESO_ONLY_EMAILS || '').toLowerCase();
    const list = raw.split(/[,;\s]+/).map(function (s) { return s.trim(); }).filter(Boolean);

    const roles = (email && list.indexOf(email) !== -1) ? ['acceso'] : ['interno'];

    context.res = { status: 200, headers: { 'Content-Type': 'application/json' }, body: { roles: roles } };
  } catch (err) {
    // Ante cualquier error, no bloquear a los usuarios internos.
    context.res = { status: 200, headers: { 'Content-Type': 'application/json' }, body: { roles: ['interno'] } };
  }
};
