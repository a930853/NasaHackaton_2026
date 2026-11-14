#!/bin/sh
# Genera un certificado autofirmado para HTTPS si no hay uno.
#
# La imagen de Nginx ejecuta los scripts de /docker-entrypoint.d/ antes de
# arrancar (por orden de nombre: este va antes del 20-envsubst-on-templates.sh).
#
# /etc/nginx/certs es un volumen (compose.yaml), así que el certificado se
# conserva entre reinicios y el navegador solo avisa la primera vez.
# Para usar uno propio (p. ej. de mkcert, sin avisos), deja cert.pem y key.pem
# en ese volumen.
set -e

dir=/etc/nginx/certs
if [ -f "$dir/cert.pem" ] && [ -f "$dir/key.pem" ]; then
  exit 0
fi

echo "15-cert.sh: generando un certificado autofirmado en $dir"
mkdir -p "$dir"
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -subj "/CN=nasa-hackaton" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
  -keyout "$dir/key.pem" -out "$dir/cert.pem" 2>/dev/null
