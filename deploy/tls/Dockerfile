# Proxy HTTPS para desplegar en local (compose.local.yaml): certificado autofirmado
# y reenvío al servicio "web". En Internet este papel lo hace Traefik (Coolify).
FROM nginx:1.27-alpine

# openssl para generar el certificado autofirmado al arrancar (15-cert.sh)
RUN apk add --no-cache openssl

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY 15-cert.sh /docker-entrypoint.d/
# Por si Git en Windows lo dejó con finales CRLF (sh no lo entendería).
RUN sed -i 's/\r$//' /docker-entrypoint.d/15-cert.sh && chmod +x /docker-entrypoint.d/15-cert.sh
