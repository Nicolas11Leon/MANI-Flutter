<#
.SYNOPSIS
    Aplica migraciones SQL pendientes en el contenedor local de PostgreSQL (Docker) para MANI.
.DESCRIPTION
    Revisa la tabla `schema_migrations` en mani-postgres y ejecuta secuencialmente
    los scripts en `database/migrations/*.sql` que aún no hayan sido aplicados.
#>

$ErrorActionPreference = "Stop"

# 1. Verificar si el contenedor de PostgreSQL está corriendo
$containerRunning = docker ps --filter "name=mani-postgres" --filter "status=running" -q
if (-not $containerRunning) {
    Write-Host "[INFO] El contenedor 'mani-postgres' no está corriendo. Iniciando con docker compose up -d..." -ForegroundColor Yellow
    docker compose up -d postgres
    Start-Sleep -Seconds 3
}

# 2. Asegurar que la tabla de control exista
$createTableSql = "CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(50) PRIMARY KEY, description TEXT NOT NULL, applied_at TIMESTAMPTZ NOT NULL DEFAULT now());"
docker exec -i mani-postgres psql -U postgres -d mani_db -c "$createTableSql" | Out-Null

# 3. Obtener las versiones ya aplicadas
$appliedVersionsRaw = docker exec -i mani-postgres psql -U postgres -d mani_db -t -A -c "SELECT version FROM schema_migrations;"
$appliedVersions = @($appliedVersionsRaw -split "`r?`n" | Where-Object { $_ -ne "" })

# 4. Leer archivos de migración locales ordenados
$migrationFiles = Get-ChildItem -Path "database/migrations" -Filter "*.sql" | Sort-Object Name

if ($migrationFiles.Count -eq 0) {
    Write-Host "[WARN] No se encontraron archivos de migración en database/migrations/" -ForegroundColor Yellow
    exit 0
}

$pendingCount = 0

foreach ($file in $migrationFiles) {
    # Extraer el prefijo de versión (ej. 001 de 001_initial_schema.sql)
    if ($file.Name -match "^([0-9]+)_") {
        $version = $matches[1]
    } else {
        $version = $file.BaseName
    }

    if ($appliedVersions -contains $version) {
        Write-Host "  [OK] $($file.Name) ya aplicada." -ForegroundColor DarkGray
    } else {
        Write-Host "  [APLICANDO] $($file.Name)..." -ForegroundColor Cyan
        Get-Content -Path $file.FullName -Raw | docker exec -i mani-postgres psql -U postgres -d mani_db -v ON_ERROR_STOP=1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [ERROR] Falló la migración $($file.Name)" -ForegroundColor Red
            exit 1
        }
        Write-Host "  [ÉXITO] $($file.Name) aplicada correctamente." -ForegroundColor Green
        $pendingCount++
    }
}

if ($pendingCount -eq 0) {
    Write-Host "`n[INFO] La base de datos local está completamente al día. No hay migraciones pendientes." -ForegroundColor Green
} else {
    Write-Host "`n[RESUMEN] Se aplicaron exitosamente $pendingCount migración(es) pendiente(s)." -ForegroundColor Green
}
