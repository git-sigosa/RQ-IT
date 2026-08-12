# RQ-IT · Dashboard de Seguimiento — Puesta en marcha

El dashboard ([dashboard.html](dashboard.html)) lista las solicitudes guardadas en
SQL Server y permite actualizar el **seguimiento**: Estado, Responsable y Fecha de
entrega. Usa los endpoints de la misma Azure Function:

```
GET   /api/solicitudes           -> lista (filtros ?estado= &q=)
PATCH /api/solicitudes/{id}      -> actualiza Estado / Responsable / FechaEntrega
POST  /api/solicitudes           -> (sin cambios) crea una solicitud desde el formulario
```

El **formulario y el POST siguen públicos**. El **dashboard, el GET y el PATCH quedan
protegidos**: requieren iniciar sesión (rol `authenticated`). Hasta completar el paso 2
(Entra ID), el dashboard mostrará la pantalla de inicio de sesión y no cargará datos.

---

## 1. Migración de la base de datos (obligatorio)

Ejecuta una vez el script que agrega las columnas de seguimiento:

- [`sql/alter_add_tracking.sql`](sql/alter_add_tracking.sql) → agrega `Responsable`,
  `FechaEntrega`, `FechaActualizacion` a `dbo.Solicitudes` (idempotente).

Además, el usuario `app.rq-it` ahora necesita permisos **SELECT** y **UPDATE**
(antes solo INSERT) sobre `dbo.Solicitudes`:

```sql
GRANT SELECT, UPDATE ON dbo.Solicitudes TO [app.rq-it];
```

> Si no ejecutas la migración, el `GET` fallará porque selecciona columnas que aún no existen.

---

## 2. Proteger el dashboard con Entra ID (login)

### 2.1 Registrar la aplicación (Entra ID)

1. Portal de Azure → **Microsoft Entra ID** → **Registros de aplicaciones** → **Nuevo registro**.
   - **Nombre:** `RQ-IT Dashboard`
   - **Tipos de cuenta:** *Solo cuentas de este directorio organizativo* (inquilino único).
   - **URI de redirección** (tipo *Web*):
     `https://mango-sky-0d12b0c0f.7.azurestaticapps.net/.auth/login/aad/callback`
2. Copia el **Id. de aplicación (cliente)** y el **Id. de directorio (inquilino)**.
3. **Certificados y secretos** → **Nuevo secreto de cliente** → copia el **Valor**.

### 2.2 Variables de entorno en la Static Web App

Portal de Azure → tu Static Web App → **Configuración → Variables de entorno**:

| Nombre             | Valor                          |
|--------------------|--------------------------------|
| `AAD_CLIENT_ID`    | *(Id. de aplicación / cliente)* |
| `AAD_CLIENT_SECRET`| *(Valor del secreto)* — **secreto** |

### 2.3 Configurar el proveedor en `staticwebapp.config.json`

Pásame tu **Id. de inquilino (Tenant ID)** y agrego automáticamente este bloque
`auth` al archivo (o reemplaza `<TENANT_ID>` tú mismo y súbelo):

```json
"auth": {
  "identityProviders": {
    "azureActiveDirectory": {
      "registration": {
        "openIdIssuer": "https://login.microsoftonline.com/<TENANT_ID>/v2.0",
        "clientIdSettingName": "AAD_CLIENT_ID",
        "clientSecretSettingName": "AAD_CLIENT_SECRET"
      }
    }
  }
}
```

Con eso, al abrir `/dashboard.html` (o llamar al GET/PATCH) sin sesión, Azure redirige a
`/.auth/login/aad` para iniciar sesión con la cuenta de la organización. El enlace
**Cerrar sesión** del dashboard usa `/.auth/logout`.

---

## 3. Probar

1. Ejecuta la migración (paso 1) y despliega (push a `main`).
2. Completa el paso 2 (Entra ID) y guarda la configuración.
3. Abre `https://mango-sky-0d12b0c0f.7.azurestaticapps.net/dashboard.html`.
   - Debe pedir inicio de sesión y, tras autenticarte, mostrar la lista.
4. Cambia el Estado / Responsable / Fecha de una fila y pulsa **Guardar** → "✓ Guardado".
