# 🐘 Base de Datos Local con Docker — MANI

Este directorio contiene los scripts de inicialización y configuración para levantar localmente la base de datos PostgreSQL con **exactamente el mismo esquema** utilizado en los ambientes de desarrollo (`dev`) y producción (`prod`).

---

## 📋 Requisitos Previos

- [Docker](https://docs.docker.com/get-docker/) y [Docker Compose](https://docs.docker.com/compose/) instalados y en ejecución.

---

## 🚀 Inicio Rápido

Desde la raíz del repositorio (`MANI-Flutter`), ejecuta:

```bash
# Iniciar la base de datos y la interfaz web en segundo plano
docker compose up -d
```

Docker descargará la imagen oficial de PostgreSQL 16 Alpine, creará el volumen persistente y ejecutará automáticamente los scripts de inicialización en orden:
1. `database/init/01-schema.sql`: Creación de extensiones (`pgcrypto`) y las 17 tablas del esquema oficial de MANI.
2. `database/init/02-seed.sql`: Inserción de datos semilla de prueba (tenant demo, zonas, usuarios, categorías y sitios).

---

## 🔑 Parámetros de Conexión

| Parámetro | Valor por Defecto |
| :--- | :--- |
| **Host** | `localhost` |
| **Puerto** | `5432` |
| **Base de Datos** | `mani_db` |
| **Usuario** | `postgres` |
| **Contraseña** | `postgres` |
| **URL de Conexión** | `postgresql://postgres:postgres@localhost:5432/mani_db` |

---

## 🖥️ Interfaz Web de Administración (Adminer)

Para explorar tablas, ejecutar consultas SQL o inspeccionar datos desde el navegador:

- **URL:** [http://localhost:8088](http://localhost:8088)
- **Motor:** PostgreSQL
- **Servidor:** `postgres`
- **Usuario:** `postgres`
- **Contraseña:** `postgres`
- **Base de datos:** `mani_db`

---

## 🛠️ Comandos de Operación

### Ver estado y logs
```bash
# Ver estado de los contenedores
docker compose ps

# Ver logs de la base de datos
docker compose logs -f postgres
```

### Detener el servicio (conservando los datos)
```bash
docker compose down
```

### Reiniciar y resetear la base de datos desde cero (Clean Slate)
Si modificas el esquema o quieres restaurar la base de datos a su estado original con los datos semilla:
```bash
docker compose down -v
docker compose up -d
```
*(La bandera `-v` elimina el volumen persistente `mani_postgres_data`, forzando la reejecución de los scripts de `/docker-entrypoint-initdb.d/`)*.

---

## 📜 Migraciones Versionadas (CFG-07)

Cuando se introducen cambios de base de datos en una rama de desarrollo (nuevas tablas, columnas o índices):

1. **Crear la migración:** Agrega un archivo numerado en [`database/migrations/`](file:///C:/Users/santi/OneDrive/Documentos/MANI-Flutter/database/migrations/) (ej. `002_add_field_to_table.sql`).
2. **Aplicar en local sin perder datos:**
   ```powershell
   # En Windows PowerShell:
   .\scripts\migrate-local.ps1

   # En Linux / Mac / WSL:
   ./scripts/migrate-local.sh
   ```
   El script consulta la tabla `schema_migrations` y ejecuta únicamente los scripts SQL que aún no se hayan aplicado.

---

## 🗄️ Tablas Incluidas en el Esquema Base

0. **Control:** `schema_migrations` (seguimiento de versiones aplicadas).
1. **Base:** `tenant`, `zona`, `usuario`.
2. **Entidades & Perfiles:** `categoria_servicio`, `aliado`, `cliente`.
3. **Detalles & Negocio:** `aliado_categoria`, `documento_kyc`, `tarifa_referencia`, `cobertura_aliado`, `sitio`.
4. **Flujo Operativo:** `solicitud`, `cotizacion`, `mensaje`, `evento_servicio`, `calificacion`, `notificacion`.

