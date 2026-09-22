#!/usr/bin/env bash
set -euo pipefail

# 1. Verificar si el contenedor de PostgreSQL está corriendo
if [ -z "$(docker ps -q -f name=mani-postgres -f status=running)" ]; then
    echo "[INFO] El contenedor 'mani-postgres' no está corriendo. Iniciando con docker compose up -d..."
    docker compose up -d postgres
    sleep 3
fi

# 2. Asegurar que la tabla de control exista
docker exec -i mani-postgres psql -U postgres -d mani_db -c \
  "CREATE TABLE IF NOT EXISTS schema_migrations (version VARCHAR(50) PRIMARY KEY, description TEXT NOT NULL, applied_at TIMESTAMPTZ NOT NULL DEFAULT now());" > /dev/null

# 3. Obtener versiones ya aplicadas
APPLIED_VERSIONS=$(docker exec -i mani-postgres psql -U postgres -d mani_db -t -A -c "SELECT version FROM schema_migrations;")

PENDING_COUNT=0

# 4. Iterar sobre las migraciones ordenadas
for file in $(ls -1 database/migrations/*.sql | sort); do
    filename=$(basename "$file")
    version=$(echo "$filename" | grep -oE "^[0-9]+" || echo "$filename")

    if echo "$APPLIED_VERSIONS" | grep -qx "$version"; then
        echo "  [OK] $filename ya aplicada."
    else
        echo "  [APLICANDO] $filename..."
        docker exec -i mani-postgres psql -U postgres -d mani_db -v ON_ERROR_STOP=1 < "$file"
        echo "  [ÉXITO] $filename aplicada correctamente."
        PENDING_COUNT=$((PENDING_COUNT + 1))
    fi
done

if [ "$PENDING_COUNT" -eq 0 ]; then
    echo -e "\n[INFO] La base de datos local está completamente al día. No hay migraciones pendientes."
else
    echo -e "\n[RESUMEN] Se aplicaron exitosamente $PENDING_COUNT migración(es) pendiente(s)."
fi
