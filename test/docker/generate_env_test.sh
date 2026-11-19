#!/bin/sh
# Prueba de docker/generate-env.sh (SCRUM-1649). Uso: sh test/docker/generate_env_test.sh
# Los valores son de prueba; ninguno corresponde a un ambiente real.
set -eu

RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
SCRIPT="$RAIZ/docker/generate-env.sh"
TRABAJO="$(mktemp -d)"
trap 'rm -rf "$TRABAJO"' EXIT

fallos=0

empaquetado() {
    cat > "$1" <<'EOF'
# Comentario del .env empaquetado
SUPABASE_URL=https://empaquetado.example.test
SUPABASE_ANON_KEY=clave-empaquetada
API_GATEWAY_URL=https://gateway-empaquetado.example.test/api?a=1&b=2
TENANT_SLUG=tenant-empaquetado
OTRA_VARIABLE=se-conserva
EOF
}

# Ejecuta el script con un entorno limpio más las variables indicadas: ejecutar <archivo> [VAR=valor ...]
ejecutar() {
    archivo="$1"
    shift
    env -i PATH="$PATH" MANI_ENV_FILE="$archivo" "$@" sh "$SCRIPT" > "$archivo.log"
}

comparar() {
    caso="$1"
    esperado="$2"
    obtenido="$3"
    if cmp -s "$esperado" "$obtenido"; then
        echo "ok   - $caso"
    else
        echo "FALLO - $caso"
        diff "$esperado" "$obtenido" || true
        fallos=$((fallos + 1))
    fi
}

# El log no debe contener valores: sin_valores_en_log <caso> <log> <valor>...
sin_valores_en_log() {
    caso="$1"
    log="$2"
    shift 2
    for valor in "$@"; do
        if grep -qF "$valor" "$log"; then
            echo "FALLO - $caso: el log muestra un valor"
            fallos=$((fallos + 1))
            return
        fi
    done
    echo "ok   - $caso: el log no muestra valores"
}

# Caso 1: sin variables, el archivo queda igual.
empaquetado "$TRABAJO/c1.env"
cp "$TRABAJO/c1.env" "$TRABAJO/c1.esperado"
ejecutar "$TRABAJO/c1.env"
comparar "sin variables conserva el archivo" "$TRABAJO/c1.esperado" "$TRABAJO/c1.env"
grep -q "Tomadas del entorno: ninguna" "$TRABAJO/c1.env.log" \
    && echo "ok   - sin variables: el log lo indica" \
    || { echo "FALLO - sin variables: el log no lo indica"; fallos=$((fallos + 1)); }

# Caso 2: con todas, las escribe todas (la clave lleva '/', '&' y '=' para probar que no se rompe al reemplazar).
empaquetado "$TRABAJO/c2.env"
cat > "$TRABAJO/c2.esperado" <<'EOF'
# Comentario del .env empaquetado
SUPABASE_URL=https://runtime.example.test
SUPABASE_ANON_KEY=clave/runtime&con=signos
API_GATEWAY_URL=https://gateway-runtime.example.test
TENANT_SLUG=tenant-runtime
OTRA_VARIABLE=se-conserva
EOF
ejecutar "$TRABAJO/c2.env" \
    SUPABASE_URL=https://runtime.example.test \
    'SUPABASE_ANON_KEY=clave/runtime&con=signos' \
    API_GATEWAY_URL=https://gateway-runtime.example.test \
    TENANT_SLUG=tenant-runtime
comparar "con todas las variables las escribe" "$TRABAJO/c2.esperado" "$TRABAJO/c2.env"
sin_valores_en_log "con todas las variables" "$TRABAJO/c2.env.log" \
    runtime.example.test 'clave/runtime' gateway-runtime tenant-runtime

# Caso 3: solo API_GATEWAY_URL (las demás vacías), cambia esa y conserva el resto.
empaquetado "$TRABAJO/c3.env"
sed 's|^API_GATEWAY_URL=.*|API_GATEWAY_URL=https://solo-gateway.example.test|' \
    "$TRABAJO/c3.env" > "$TRABAJO/c3.esperado"
ejecutar "$TRABAJO/c3.env" API_GATEWAY_URL=https://solo-gateway.example.test SUPABASE_URL=
comparar "solo API_GATEWAY_URL cambia esa y conserva las demás" "$TRABAJO/c3.esperado" "$TRABAJO/c3.env"
grep -q "Tomadas del entorno: API_GATEWAY_URL$" "$TRABAJO/c3.env.log" \
    && echo "ok   - solo API_GATEWAY_URL: el log lo indica" \
    || { echo "FALLO - solo API_GATEWAY_URL: el log no lo indica"; fallos=$((fallos + 1)); }
sin_valores_en_log "solo API_GATEWAY_URL" "$TRABAJO/c3.env.log" solo-gateway

# Caso 4: TENANT_SLUG no llega y el empaquetado no la trae: se escribe acme-servicios, como antes.
empaquetado "$TRABAJO/c4.env"
grep -v '^TENANT_SLUG=' "$TRABAJO/c4.env" > "$TRABAJO/c4.sin" && mv "$TRABAJO/c4.sin" "$TRABAJO/c4.env"
cp "$TRABAJO/c4.env" "$TRABAJO/c4.esperado"
echo "TENANT_SLUG=acme-servicios" >> "$TRABAJO/c4.esperado"
ejecutar "$TRABAJO/c4.env"
comparar "sin TENANT_SLUG en entorno ni empaquetado escribe acme-servicios" "$TRABAJO/c4.esperado" "$TRABAJO/c4.env"
grep -q "Con el valor por defecto del script: TENANT_SLUG$" "$TRABAJO/c4.env.log" \
    && echo "ok   - TENANT_SLUG por defecto: el log lo indica" \
    || { echo "FALLO - TENANT_SLUG por defecto: el log no lo indica"; fallos=$((fallos + 1)); }

# Caso 4b: el empaquetado trae TENANT_SLUG vacía: también se escribe acme-servicios.
empaquetado "$TRABAJO/c4b.env"
sed 's|^TENANT_SLUG=.*|TENANT_SLUG=|' "$TRABAJO/c4b.env" > "$TRABAJO/c4b.vacia" && mv "$TRABAJO/c4b.vacia" "$TRABAJO/c4b.env"
sed 's|^TENANT_SLUG=.*|TENANT_SLUG=acme-servicios|' "$TRABAJO/c4b.env" > "$TRABAJO/c4b.esperado"
ejecutar "$TRABAJO/c4b.env"
comparar "TENANT_SLUG vacía en el empaquetado escribe acme-servicios" "$TRABAJO/c4b.esperado" "$TRABAJO/c4b.env"

if [ "$fallos" -ne 0 ]; then
    echo "$fallos prueba(s) fallaron"
    exit 1
fi
echo "Todas las pruebas pasaron"
