# 📜 Convención y Guía de Migraciones de Base de Datos — MANI

Este directorio contiene las **migraciones versionadas e incrementales** de la base de datos de MANI. Cada archivo representa un cambio de esquema ordenado cronológicamente que se ejecuta de forma secuencial en todos los ambientes (**DEV**, **QA** y **PROD**).

---

## 🏷️ Convención de Nombres

Cada nueva migración debe seguir el formato de 3 dígitos con descripción en minúsculas separada por guiones bajos:

```text
<numero_secuencial>_<descripcion_en_ingles>.sql
```

**Ejemplos:**
* `001_initial_schema.sql` (Esquema base inicial de 17 tablas)
* `002_add_postal_code_to_sitio.sql`
* `003_create_index_solicitud_estado.sql`

---

## 🛡️ Reglas de Oro para Desarrolladores

1. **Idempotencia Obligatoria:**
   Cada script debe poder ejecutarse múltiples veces sin fallar.
   - Para crear tablas: `CREATE TABLE IF NOT EXISTS ...`
   - Para agregar columnas: `ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...`
   - Para crear índices: `CREATE INDEX IF NOT EXISTS ...`
2. **Registro al Final del Archivo:**
   Al final de cada script `.sql`, debes registrar la versión en la tabla `schema_migrations`:
   ```sql
   INSERT INTO schema_migrations (version, description)
   VALUES ('002', 'Brief description of changes made')
   ON CONFLICT (version) DO NOTHING;
   ```
3. **Inmutabilidad:**
   Una vez que una migración ha sido mezclada a `develop` o `release`, **NUNCA se modifica ni se borra**. Si necesitas corregir algo, se crea una nueva migración (ej. `003_fix_xxx.sql`).

---

## 🛠️ Cómo Aplicar Migraciones en Local (DEV)

### Opción 1: Aplicar migraciones pendientes (sin perder tus datos)
Si estás en una rama donde un compañero agregó una migración (ej. `002_xxx.sql`):

```powershell
# Ejecuta el script que aplica solo las migraciones faltantes en Docker
.\scripts\migrate-local.ps1
```

### Opción 2: Resetear la base de datos completa (Clean Slate con Seeds)
Si quieres reconstruir la base de datos desde cero aplicando todas las migraciones y datos semilla de prueba:

```bash
docker compose down -v
docker compose up -d
```

---

## 🔍 Consultar Migraciones Aplicadas

Puedes verificar qué migraciones han sido aplicadas conectándote a la base de datos (vía Adminer en `http://localhost:8088` o `psql`):

```sql
SELECT * FROM schema_migrations ORDER BY applied_at ASC;
```
