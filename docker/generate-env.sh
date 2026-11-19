#!/bin/sh
# Ajusta assets/.env al arrancar el contenedor, para que una misma imagen sirva en DEV, QA y PROD (SCRUM-1649).
# Cada variable que llega del entorno reemplaza su línea; la que no llega (o llega vacía) conserva el valor que
# trae el .env empaquetado en la compilación. Las demás líneas del archivo no se tocan.
# Excepción: si TENANT_SLUG no llega y tampoco tiene valor en el .env empaquetado, se escribe acme-servicios,
# como hacía el script anterior (SCRUM-1361).
# El log dice qué variables vinieron del entorno y cuáles quedaron con el valor empaquetado, nunca sus valores.
set -eu

ENV_FILE="${MANI_ENV_FILE:-/usr/share/nginx/html/assets/.env}"
VARIABLES="SUPABASE_URL SUPABASE_ANON_KEY API_GATEWAY_URL TENANT_SLUG"
TENANT_SLUG_POR_DEFECTO="acme-servicios"

# ¿El .env empaquetado trae la variable con un valor no vacío?
empaquetado_tiene() {
    [ -f "$ENV_FILE" ] && grep -Eq "^[[:space:]]*$1[[:space:]]*=[[:space:]]*[^[:space:]]" "$ENV_FILE"
}

del_entorno=""
empaquetadas=""
por_defecto=""
for nombre in $VARIABLES; do
    eval "valor=\${$nombre:-}"
    if [ -n "$valor" ]; then
        del_entorno="$del_entorno $nombre"
    elif [ "$nombre" = "TENANT_SLUG" ] && ! empaquetado_tiene TENANT_SLUG; then
        TENANT_SLUG="$TENANT_SLUG_POR_DEFECTO"
        export TENANT_SLUG
        por_defecto=" TENANT_SLUG"
    else
        empaquetadas="$empaquetadas $nombre"
    fi
done
a_escribir="$del_entorno$por_defecto"

echo "[flutter-web] $ENV_FILE"
echo "[flutter-web] Tomadas del entorno:${del_entorno:- ninguna}"
echo "[flutter-web] Con el valor empaquetado:${empaquetadas:- ninguna}"
echo "[flutter-web] Con el valor por defecto del script:${por_defecto:- ninguna}"

if [ -z "$a_escribir" ]; then
    exit 0
fi

mkdir -p "$(dirname "$ENV_FILE")"
[ -f "$ENV_FILE" ] || : > "$ENV_FILE"

# Los valores se leen con ENVIRON dentro de awk, así no pasan por sed ni por la línea de comandos
# y no hay que escapar '/', '&' ni otros caracteres de URLs y claves.
temporal="$ENV_FILE.tmp.$$"
MANI_A_ESCRIBIR="$a_escribir" awk '
BEGIN {
    n = split(ENVIRON["MANI_A_ESCRIBIR"], vars, " ")
    for (i = 1; i <= n; i++) reemplazar[vars[i]] = 1
}
{
    clave = $0
    sub(/^[ \t]*/, "", clave)
    if (index(clave, "=") > 0) {
        sub(/[ \t]*=.*$/, "", clave)
        if (clave in reemplazar) {
            if (!(clave in escrita)) {
                print clave "=" ENVIRON[clave]
                escrita[clave] = 1
            }
            next
        }
    }
    print
}
END {
    for (i = 1; i <= n; i++) {
        if (!(vars[i] in escrita)) print vars[i] "=" ENVIRON[vars[i]]
    }
}
' "$ENV_FILE" > "$temporal"
mv "$temporal" "$ENV_FILE"
