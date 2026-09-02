# RQ-IT · Guardado en SQL Server — Despliegue

El formulario ([index.html](index.html)) guarda cada solicitud en la base de datos
**RQ-IT** de SQL Server mediante una API integrada en la Static Web App
(Azure Functions, carpeta [`api/`](api/)).

```
[Formulario]  --POST /api/solicitudes-->  [Azure Function]  --INSERT-->  [SQL Server]
```

## 1. Crear la tabla

Ejecuta una sola vez el script en tu instancia SQL Server
(`54.68.237.199,1466`, base de datos `RQ-IT`):

- [`sql/create_table.sql`](sql/create_table.sql) → crea `dbo.Solicitudes`.

## 2. Configurar la conexión (variables de entorno)

En el **portal de Azure → tu Static Web App → Configuración → Variables de entorno**
(Application settings), agrega estas claves. **Nunca van en el repositorio.**

| Nombre         | Valor                | Notas                                   |
|----------------|----------------------|-----------------------------------------|
| `SQL_SERVER`   | `54.68.237.199`      | Solo el host, sin el puerto             |
| `SQL_PORT`     | `1466`               | Puerto de tu instancia                  |
| `SQL_DATABASE` | `RQ-IT`              |                                         |
| `SQL_USER`     | `app.rq-it`          | Usuario SQL                             |
| `SQL_PASSWORD` | *(tu contraseña)*    | **Secreto** — configúralo solo en Azure |
| `SQL_ENCRYPT`  | `true`               | Opcional. `false` si el server no usa TLS |
| `SQL_TRUST_CERT` | `true`             | Opcional. `true` si el certificado es autofirmado |
| `DUP_WINDOW_MIN` | `5`                | Opcional. Minutos de la ventana anti-duplicados de `/api/solicitudes-acceso`. `0` la desactiva |

> Recomendado: da a `app.rq-it` solo permisos `INSERT` (y `SELECT` si luego consultas)
> sobre `dbo.Solicitudes`, nada más.

## 3. Firewall del SQL Server

La Function corre en la infraestructura administrada de Azure y sale a Internet con
**IPs variables del centro de datos de Azure**. Debes permitir el acceso entrante al
puerto `1466` desde esas IPs. Opciones (de más a menos segura):

- Permitir el **rango de IPs de salida de la región de Azure** de tu Static Web App
  (lista `AzureCloud.<region>` del archivo de rangos de IP de Azure que publica Microsoft).
- O, temporalmente para validar, abrir el puerto y luego restringir.

## 4. Desplegar

El workflow ya está configurado con `api_location: "api"`
([.github/workflows/azure-static-web-apps-mango-sky-0d12b0c0f.yml](.github/workflows/azure-static-web-apps-mango-sky-0d12b0c0f.yml)).
Con hacer *push* a `main`, GitHub Actions instala las dependencias de `api/`
(`mssql`) y publica la API junto al sitio.

## 5. Probar

1. Abre el sitio, completa los campos obligatorios y pulsa **Generar solicitud**.
2. Debe aparecer: **"✓ Guardado en SQL Server (Id N)"**.
3. Verifica en la base de datos:

```sql
SELECT TOP 20 Id, FechaRegistro, Aplicacion, Estado, CPURequerida, RAMRequeridaGB, StorageGB
FROM dbo.Solicitudes
ORDER BY Id DESC;
```

Si falla, el modal muestra el motivo y el botón **"↻ Reintentar guardado en SQL"**
reenvía sin volver a llenar el formulario. Revisa los logs de la Function en
**Azure → Static Web App → Funciones / Application Insights**.

## Notas de seguridad

- Las credenciales viven solo en las *Application settings* de Azure (servidor), nunca
  en el navegador ni en el repositorio.
- El `INSERT` usa **consultas parametrizadas** (sin concatenación) → sin inyección SQL.
- La API acepta únicamente `POST` y valida el cuerpo antes de insertar.
